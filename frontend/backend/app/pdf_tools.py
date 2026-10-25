"""PDF parsing and rendering utilities built on PyMuPDF (fitz).

These functions are deliberately free of any FastAPI/network concerns so
they can be unit tested in isolation and reused by different entry points
(the API, a CLI, a background worker, ...).

The "Visual-Sync" idea from the project spec works like this:

1. ``extract_spans`` reads every run of text on a page together with its
   bounding box, expressed as a FRACTION of the page size (0..1). Fractions
   let the Flutter client position an overlay without knowing the page's
   absolute point size.
2. ``redact_spans`` paints a solid white rectangle over each span's original
   position, directly on the PDF page, before it is rasterised. This is what
   makes the result feel like a true overlay: once rendered, the
   original-language text is gone and only the translated text (drawn by the
   client, at the same coordinates) is visible.
3. ``build_translated_pages`` ties extraction, translation injection,
   redaction and rendering together into the shape the API returns.
"""
from __future__ import annotations

import base64
from dataclasses import dataclass, field
from typing import List, Optional

import fitz  # PyMuPDF


@dataclass
class Span:
    """A single run of text extracted from a PDF page."""

    text: str
    # [x0, y0, x1, y1], each a fraction (0..1) of the page width/height.
    bbox: List[float]

    def to_dict(self) -> dict:
        return {"text": self.text, "bbox": self.bbox}


@dataclass
class PageData:
    page: int
    width: float
    height: float
    spans: List[Span] = field(default_factory=list)
    image_png_base64: Optional[str] = None

    def to_dict(self) -> dict:
        data = {
            "page": self.page,
            "width": self.width,
            "height": self.height,
            "spans": [s.to_dict() for s in self.spans],
        }
        if self.image_png_base64 is not None:
            data["image_png_base64"] = self.image_png_base64
        return data


def extract_spans(page: "fitz.Page") -> List[Span]:
    """Extract text spans with their bounding boxes (as page fractions)."""
    width, height = page.rect.width, page.rect.height
    spans: List[Span] = []

    for block in page.get_text("dict")["blocks"]:
        if block.get("type") != 0:  # 0 == text block (1 == image block)
            continue
        for line in block.get("lines", []):
            for span in line.get("spans", []):
                text = span["text"]
                if not text.strip():
                    continue
                x0, y0, x1, y1 = span["bbox"]
                spans.append(
                    Span(
                        text=text,
                        bbox=[x0 / width, y0 / height, x1 / width, y1 / height],
                    )
                )
    return spans


def redact_spans(page: "fitz.Page", spans: List[Span]) -> None:
    """Paint a solid white rectangle over every span's original position.

    Positions are read from ``span.bbox`` (still the ORIGINAL coordinates,
    even if ``span.text`` has since been overwritten with a translation) so
    this must be called before the page is rasterised, and may be called
    with spans whose ``.text`` has already been replaced.
    """
    width, height = page.rect.width, page.rect.height
    for span in spans:
        x0, y0, x1, y1 = span.bbox
        rect = fitz.Rect(x0 * width, y0 * height, x1 * width, y1 * height)
        # A small outward pad avoids thin slivers of the old glyphs
        # remaining visible at the edges of the box.
        rect += (-0.6, -0.6, 0.6, 0.6)
        page.draw_rect(rect, color=None, fill=(1, 1, 1), width=0)


def render_page_png(page: "fitz.Page", zoom: float = 2.0) -> bytes:
    matrix = fitz.Matrix(zoom, zoom)
    pixmap = page.get_pixmap(matrix=matrix, alpha=False)
    return pixmap.tobytes("png")


def inspect_pdf(content: bytes) -> List[PageData]:
    """Extract structure only (no rendering, no redaction) — a fast preview."""
    document = fitz.open(stream=content, filetype="pdf")
    try:
        pages: List[PageData] = []
        for page_number, page in enumerate(document, start=1):
            pages.append(
                PageData(
                    page=page_number,
                    width=page.rect.width,
                    height=page.rect.height,
                    spans=extract_spans(page),
                )
            )
        return pages
    finally:
        document.close()


def build_translated_pages(
    content: bytes,
    *,
    translated_texts_by_page: List[List[str]],
    zoom: float = 2.0,
    render_images: bool = True,
) -> List[PageData]:
    """Combine extraction + redaction + rendering + translated text.

    ``translated_texts_by_page[i]`` should have exactly as many entries as
    the spans found on page ``i + 1``, in the same order. If a provider got
    the count wrong, this falls back to the original text for that page
    instead of crashing or misaligning the overlay — see the length check
    below.
    """
    document = fitz.open(stream=content, filetype="pdf")
    try:
        pages: List[PageData] = []
        for page_number, page in enumerate(document, start=1):
            spans = extract_spans(page)
            translated = (
                translated_texts_by_page[page_number - 1]
                if page_number - 1 < len(translated_texts_by_page)
                else []
            )
            if len(translated) != len(spans):
                # Safety net: never let a provider's mistake crash a page or
                # silently misalign text — just show the original instead.
                translated = [s.text for s in spans]

            for span, new_text in zip(spans, translated):
                span.text = new_text

            if render_images:
                redact_spans(page, spans)
                png_bytes = render_page_png(page, zoom=zoom)
                image_b64: Optional[str] = base64.b64encode(png_bytes).decode("ascii")
            else:
                image_b64 = None

            pages.append(
                PageData(
                    page=page_number,
                    width=page.rect.width,
                    height=page.rect.height,
                    spans=spans,
                    image_png_base64=image_b64,
                )
            )
        return pages
    finally:
        document.close()
