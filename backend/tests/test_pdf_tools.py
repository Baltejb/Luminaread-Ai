import pymupdf as fitz

from app.pdf_tools import build_translated_pages, inspect_pdf


def _one_page_pdf(text: str = "Hello world") -> bytes:
    doc = fitz.open()
    page = doc.new_page(width=200, height=200)
    page.insert_text((20, 40), text, fontsize=14)
    data = doc.tobytes()
    doc.close()
    return data


def test_inspect_pdf_extracts_spans_with_fractional_bbox():
    pages = inspect_pdf(_one_page_pdf())
    assert len(pages) == 1

    page = pages[0]
    assert page.width == 200
    assert page.height == 200
    assert page.spans, "expected at least one text span"

    span = page.spans[0]
    assert "Hello" in span.text or "world" in span.text
    assert all(0.0 <= c <= 1.0 for c in span.bbox)


def test_build_translated_pages_replaces_text_and_renders_image():
    content = _one_page_pdf()
    structure = inspect_pdf(content)
    n_spans = len(structure[0].spans)
    assert n_spans >= 1

    translated = [["TRANSLATED"] * n_spans]
    pages = build_translated_pages(content, translated_texts_by_page=translated, zoom=1.0)

    assert len(pages) == 1
    assert pages[0].image_png_base64, "expected a rendered PNG background"
    assert all(s.text == "TRANSLATED" for s in pages[0].spans)
    for orig, new in zip(structure[0].spans, pages[0].spans):
        assert orig.bbox == new.bbox


def test_build_translated_pages_falls_back_on_length_mismatch():
    content = _one_page_pdf()
    structure = inspect_pdf(content)
    original_texts = [s.text for s in structure[0].spans]

    pages = build_translated_pages(content, translated_texts_by_page=[["too", "many", "entries", "!!"]])

    assert [s.text for s in pages[0].spans] == original_texts


def test_build_translated_pages_without_render_images_skips_png():
    content = _one_page_pdf()
    structure = inspect_pdf(content)
    n_spans = len(structure[0].spans)

    pages = build_translated_pages(
        content,
        translated_texts_by_page=[["x"] * n_spans],
        render_images=False,
    )
    assert pages[0].image_png_base64 is None


def test_render_cover_png_returns_first_page_image():
    from app.pdf_tools import render_cover_png

    content = _one_page_pdf()
    png_bytes = render_cover_png(content, zoom=1.0)
    assert png_bytes[:8] == b"\x89PNG\r\n\x1a\n"
