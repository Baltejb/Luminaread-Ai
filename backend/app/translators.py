from __future__ import annotations

import json
from typing import Awaitable, Callable, Dict, List, Optional

import httpx

TIMEOUT = httpx.Timeout(60.0, connect=10.0)


class TranslationError(RuntimeError):
    pass


ProviderFn = Callable[..., Awaitable[List[str]]]


async def _offline_translate(
    texts: List[str], *, target_lang: str, source_lang: str, api_key: Optional[str]
) -> List[str]:
    return list(texts)


async def _deepl_translate(
    texts: List[str], *, target_lang: str, source_lang: str, api_key: Optional[str]
) -> List[str]:
    if not api_key:
        raise TranslationError("DeepL translation needs an API key.")
    # Free keys end with ":fx" and only work on the api-free host; Pro keys
    # must use api.deepl.com.
    host = "api-free.deepl.com" if api_key.endswith(":fx") else "api.deepl.com"
    url = f"https://{host}/v2/translate"
    data = [("target_lang", target_lang.upper())]
    if source_lang and source_lang.lower() != "auto":
        data.append(("source_lang", source_lang.upper()))
    data.extend(("text", t) for t in texts)
    headers = {"Authorization": f"DeepL-Auth-Key {api_key}"}

    async with httpx.AsyncClient(timeout=TIMEOUT) as client:
        resp = await client.post(url, data=data, headers=headers)

    if resp.status_code != 200:
        raise TranslationError(f"DeepL error {resp.status_code}: {resp.text[:200]}")

    translations = resp.json().get("translations", [])
    if len(translations) != len(texts):
        raise TranslationError("DeepL returned an unexpected number of translations.")
    return [t["text"] for t in translations]


_JSON_ARRAY_SYSTEM_PROMPT = (
    "You translate book pages. You will receive a JSON array of short text "
    "fragments extracted from one PDF page, in reading order. Translate "
    "each fragment into {target} (source language: {source}). Keep names, "
    "numbers and punctuation style sensible for the target language. Reply "
    "with ONLY a JSON array of strings, in the exact same order, with "
    "EXACTLY the same number of elements as the input array -- never merge, "
    "split, or drop a fragment, even if it is a single word or looks "
    "incomplete out of context."
)


async def _gemini_translate(
    texts: List[str], *, target_lang: str, source_lang: str, api_key: Optional[str]
) -> List[str]:
    if not api_key:
        raise TranslationError("Gemini translation needs an API key.")
    model = "gemini-3.8-flash"
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
    prompt = _JSON_ARRAY_SYSTEM_PROMPT.format(target=target_lang, source=source_lang or "auto-detect")
    body = {
        "contents": [
            {"role": "user", "parts": [{"text": prompt + "\n\n" + json.dumps(texts, ensure_ascii=False)}]}
        ],
        "generationConfig": {"temperature": 0.2, "responseMimeType": "application/json"},
    }

    async with httpx.AsyncClient(timeout=TIMEOUT) as client:
        resp = await client.post(url, json=body)

    if resp.status_code != 200:
        raise TranslationError(f"Gemini error {resp.status_code}: {resp.text[:200]}")

    payload = resp.json()
    try:
        raw = payload["candidates"][0]["content"]["parts"][0]["text"]
        result = json.loads(raw)
    except (KeyError, IndexError, json.JSONDecodeError) as exc:
        raise TranslationError("Gemini returned an unparseable response.") from exc

    if not isinstance(result, list) or len(result) != len(texts):
        raise TranslationError("Gemini returned an unexpected number of translations.")
    return [str(t) for t in result]


async def _openai_translate(
    texts: List[str], *, target_lang: str, source_lang: str, api_key: Optional[str]
) -> List[str]:
    if not api_key:
        raise TranslationError("OpenAI translation needs an API key.")
    url = "https://api.openai.com/v1/chat/completions"
    prompt = _JSON_ARRAY_SYSTEM_PROMPT.format(target=target_lang, source=source_lang or "auto-detect")
    body = {
        "model": "gpt-4o-mini",
        "temperature": 0.2,
        "response_format": {"type": "json_object"},
        "messages": [
            {
                "role": "system",
                "content": prompt + ' Wrap the array in an object exactly like {"translations": [...]}.',
            },
            {"role": "user", "content": json.dumps(texts, ensure_ascii=False)},
        ],
    }
    headers = {"Authorization": f"Bearer {api_key}"}

    async with httpx.AsyncClient(timeout=TIMEOUT) as client:
        resp = await client.post(url, json=body, headers=headers)

    if resp.status_code != 200:
        raise TranslationError(f"OpenAI error {resp.status_code}: {resp.text[:200]}")

    payload = resp.json()
    try:
        raw = payload["choices"][0]["message"]["content"]
        result = json.loads(raw).get("translations")
    except (KeyError, IndexError, json.JSONDecodeError, AttributeError) as exc:
        raise TranslationError("OpenAI returned an unparseable response.") from exc

    if not isinstance(result, list) or len(result) != len(texts):
        raise TranslationError("OpenAI returned an unexpected number of translations.")
    return [str(t) for t in result]


_PROVIDERS: Dict[str, ProviderFn] = {
    "offline": _offline_translate,
    "deepl": _deepl_translate,
    "gemini": _gemini_translate,
    "openai": _openai_translate,
}


async def translate_texts(
    texts: List[str],
    *,
    provider: str,
    target_lang: str,
    source_lang: str = "auto",
    api_key: Optional[str] = None,
) -> List[str]:
    if not texts:
        return []
    fn = _PROVIDERS.get(provider)
    if fn is None:
        raise TranslationError(f"Unknown provider '{provider}'. Choose one of: {', '.join(_PROVIDERS)}.")
    try:
        return await fn(texts, target_lang=target_lang, source_lang=source_lang, api_key=api_key)
    except httpx.HTTPError as exc:
        # Network-level failure (DNS, timeout, refused connection).
        raise TranslationError(f"{provider} request failed: {exc}") from exc


async def translate_pages(
    spans_by_page: List[List[str]],
    *,
    provider: str,
    target_lang: str,
    source_lang: str = "auto",
    api_key: Optional[str] = None,
) -> List[List[str]]:
    # A provider failure is raised to the caller (the API turns it into a 502)
    # rather than silently returning the original, untranslated text.
    results: List[List[str]] = []
    for texts in spans_by_page:
        results.append(
            await translate_texts(
                texts,
                provider=provider,
                target_lang=target_lang,
                source_lang=source_lang,
                api_key=api_key,
            )
        )
    return results
