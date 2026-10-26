import os
import sys
import tempfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))

from app import translation_cache  # noqa: E402  (sys.path must be set first)

# Tests must never read or write the real translation cache: point them at a
# throw-away SQLite file (resolved lazily by app.translation_cache).
os.environ["TRANSLATION_CACHE_PATH"] = str(
    Path(tempfile.mkdtemp(prefix="lumina_cache_")) / "translation_cache.db"
)


@pytest.fixture(autouse=True)
def _isolated_translation_cache():
    """Give every test a cache in a known-empty state."""
    translation_cache.clear()
    yield
    translation_cache.clear()
