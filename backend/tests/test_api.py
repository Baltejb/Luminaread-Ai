import pymupdf as fitz
import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def _one_page_pdf(text: str = "Hello world") -> bytes:
    doc = fitz.open()
    page = doc.new_page(width=200, height=200)
    page.insert_text((20, 40), text, fontsize=14)
    data = doc.tobytes()
    doc.close()
    return data


def test_health():
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


def test_inspect_rejects_non_pdf():
    resp = client.post("/pdf/inspect", files={"file": ("not-a-pdf.txt", b"hello", "text/plain")})
    assert resp.status_code == 400


def test_inspect_returns_spans_for_a_real_pdf():
    resp = client.post("/pdf/inspect", files={"file": ("book.pdf", _one_page_pdf(), "application/pdf")})
    assert resp.status_code == 200
    body = resp.json()
    assert len(body["pages"]) == 1
    assert body["pages"][0]["spans"]
    assert "image_png_base64" not in body["pages"][0]


def test_translate_offline_roundtrip():
    resp = client.post(
        "/translate",
        files={"file": ("book.pdf", _one_page_pdf(), "application/pdf")},
        data={"target_lang": "pa", "provider": "offline"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["provider"] == "offline"
    page = body["pages"][0]
    assert page["image_png_base64"]
    assert page["spans"][0]["text"]


def test_translate_reports_provider_failure_instead_of_silent_fallback():
    resp = client.post(
        "/translate",
        files={"file": ("book.pdf", _one_page_pdf(), "application/pdf")},
        data={"target_lang": "pa", "provider": "gemini", "api_key": ""},
    )
    assert resp.status_code == 502
    detail = resp.json()["detail"]
    assert "API key" in detail


def test_cover_returns_first_page_image():
    resp = client.post("/pdf/cover", files={"file": ("book.pdf", _one_page_pdf(), "application/pdf")})
    assert resp.status_code == 200
    body = resp.json()
    assert body["image_png_base64"]


def test_translate_reports_cache_hit_and_miss_counts():
    form = {
        "target_lang": "pa",
        "provider": "offline",
        "file": ("book.pdf", _one_page_pdf(), "application/pdf"),
    }
    first = client.post("/translate", files={"file": form["file"]}, data={"target_lang": "pa", "provider": "offline"})
    assert first.status_code == 200
    stats = first.json()["cache"]
    assert set(stats) == {"hits", "misses", "provider_calls", "hit_rate"}
    total = stats["hits"] + stats["misses"]
    assert total > 0, "every text block should be accounted for"

    second = client.post("/translate", files={"file": form["file"]}, data={"target_lang": "pa", "provider": "offline"})
    assert second.status_code == 200
    stats2 = second.json()["cache"]
    assert stats2["misses"] == 0, "identical book must be fully cached"
    assert stats2["provider_calls"] == 0, "no provider call on a full hit"
    assert stats2["hits"] == total
    assert stats2["hit_rate"] == 1.0
