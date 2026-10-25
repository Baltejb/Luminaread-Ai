from unittest.mock import patch

import pytest

from app.translators import TranslationError, translate_pages, translate_texts


@pytest.mark.asyncio
async def test_offline_passthrough():
    out = await translate_texts(["Hello", "World"], provider="offline", target_lang="pa")
    assert out == ["Hello", "World"]


@pytest.mark.asyncio
async def test_unknown_provider_raises():
    with pytest.raises(TranslationError):
        await translate_texts(["Hi"], provider="not-a-real-provider", target_lang="pa")


@pytest.mark.asyncio
async def test_online_providers_require_an_api_key():
    for provider in ("deepl", "gemini", "openai"):
        with pytest.raises(TranslationError):
            await translate_texts(["Hi"], provider=provider, target_lang="pa", api_key=None)


@pytest.mark.asyncio
async def test_translate_pages_falls_back_to_original_on_provider_error():
    async def boom(*args, **kwargs):
        raise TranslationError("simulated failure")

    with patch.dict("app.translators._PROVIDERS", {"offline": boom}):
        out = await translate_pages([["Hello"], ["World", "!"]], provider="offline", target_lang="pa")

    assert out == [["Hello"], ["World", "!"]]  # fell back to originals, nothing crashed


@pytest.mark.asyncio
async def test_deepl_translate_calls_api_and_returns_texts_in_order(monkeypatch):
    class FakeResponse:
        status_code = 200

        def json(self):
            return {"translations": [{"text": "ਸਤ ਸ੍ਰੀ ਅਕਾਲ"}, {"text": "ਦੁਨਿਆ"}]}

    class FakeClient:
        def __init__(self, *a, **k):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *a):
            return False

        async def post(self, *a, **k):
            return FakeResponse()

    monkeypatch.setattr("app.translators.httpx.AsyncClient", FakeClient)
    out = await translate_texts(["Hello", "World"], provider="deepl", target_lang="pa", api_key="fake-key")
    assert out == ["ਸਤ ਸ੍ਰੀ ਅਕਾਲ", "ਦੁਨਿਆ"]


@pytest.mark.asyncio
async def test_deepl_length_mismatch_raises(monkeypatch):
    class FakeResponse:
        status_code = 200

        def json(self):
            return {"translations": [{"text": "only one"}]}

    class FakeClient:
        def __init__(self, *a, **k):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *a):
            return False

        async def post(self, *a, **k):
            return FakeResponse()

    monkeypatch.setattr("app.translators.httpx.AsyncClient", FakeClient)
    with pytest.raises(TranslationError):
        await translate_texts(["Hello", "World"], provider="deepl", target_lang="pa", api_key="fake-key")
