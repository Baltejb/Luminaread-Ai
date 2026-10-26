from unittest.mock import patch

import pytest

from app import translation_cache
from app.translation_cache import CacheStats, cache_key
from app.translators import translate_pages, translate_texts


@pytest.fixture(autouse=True)
def clean_cache():
    translation_cache.clear()
    yield
    translation_cache.clear()


def test_cache_key_is_stable_and_scoped():
    assert cache_key("offline", "pa", "Hello") == cache_key("offline", "pa", "Hello")
    assert cache_key("offline", "pa", "Hello") != cache_key("offline", "hi", "Hello")
    assert cache_key("offline", "pa", "Hello") != cache_key("openai", "pa", "Hello")
    assert cache_key("offline", "pa", "Hello") != cache_key("offline", "pa", "Hello!")


def test_get_set_roundtrip():
    key = cache_key("offline", "pa", "Hello")
    assert translation_cache.get(key) is None
    translation_cache.set(key, "ਸਤ ਸ੍ਰੀ ਅਕਾਲ")
    assert translation_cache.get(key) == "ਸਤ ਸ੍ਰੀ ਅਕਾਲ"


@pytest.mark.asyncio
async def test_repeat_call_hits_cache_and_skips_the_provider():
    first = CacheStats()
    out1 = await translate_texts(["Hello", "World"], provider="offline", target_lang="pa", stats=first)
    assert out1 == ["Hello", "World"]
    assert (first.hits, first.misses, first.provider_calls) == (0, 2, 1)

    second = CacheStats()
    out2 = await translate_texts(["Hello", "World"], provider="offline", target_lang="pa", stats=second)
    assert out2 == out1
    assert (second.hits, second.misses, second.provider_calls) == (2, 0, 0)
    assert second.hit_rate == 1.0


@pytest.mark.asyncio
async def test_only_missed_texts_are_sent_to_the_provider():
    calls = []

    async def fake(texts, **kwargs):
        calls.append(list(texts))
        return [f"T:{t}" for t in texts]

    with patch.dict("app.translators._PROVIDERS", {"fake": fake}):
        await translate_texts(["A", "B"], provider="fake", target_lang="pa")
        calls.clear()
        out = await translate_texts(["A", "B", "C"], provider="fake", target_lang="pa")

    assert calls == [["C"]], "only the never-seen text block should reach the provider"
    assert out == ["T:A", "T:B", "T:C"]


@pytest.mark.asyncio
async def test_cache_is_not_shared_across_target_languages():
    await translate_texts(["Hello"], provider="offline", target_lang="pa")

    stats = CacheStats()
    await translate_texts(["Hello"], provider="offline", target_lang="hi", stats=stats)
    assert (stats.hits, stats.misses) == (0, 1)


@pytest.mark.asyncio
async def test_translate_pages_accumulates_stats_per_text_block():
    stats = CacheStats()
    await translate_pages([["a"], ["a", "b"]], provider="offline", target_lang="pa", stats=stats)
    # "a" is a miss on page 1 and a hit on page 2; "b" is a miss.
    assert (stats.hits, stats.misses) == (1, 2)
    assert stats.provider_calls == 2  # one call per page that had misses

    again = CacheStats()
    await translate_pages([["a"], ["a", "b"]], provider="offline", target_lang="pa", stats=again)
    assert again.hits == 3
    assert again.provider_calls == 0


@pytest.mark.asyncio
async def test_cached_value_survives_a_new_lookup_after_stats_reset():
    await translate_texts(["Repeated boilerplate header"], provider="offline", target_lang="pa")
    stats = CacheStats()
    out = await translate_texts(
        ["Repeated boilerplate header"], provider="offline", target_lang="pa", stats=stats
    )
    assert out == ["Repeated boilerplate header"]
    assert stats.provider_calls == 0
