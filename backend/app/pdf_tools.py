from __future__ import annotations

import base64
from dataclasses import dataclass, field
from typing import List, Optional

import pymupdf as fitz


@dataclass
class Span:
    text: str
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
    width, height = page.rect.width, page.rect.height
    spans: List[Span] = []

    for block in page.get_text("dict")["blocks"]:
        if block.get("type") != 0:
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
    width, height = page.rect.width, page.rect.height
    for span in spans:
        x0, y0, x1, y1 = span.bbox
        rect = fitz.Rect(x0 * width, y0 * height, x1 * width, y1 * height)
        rect += (-0.6, -0.6, 0.6, 0.6)
        page.draw_rect(rect, color=None, fill=(1, 1, 1), width=0)


def render_page_png(page: "fitz.Page", zoom: float = 2.0) -> bytes:
    matrix = fitz.Matrix(zoom, zoom)
    pixmap = page.get_pixmap(matrix=matrix, alpha=False)
    return pixmap.tobytes("png")


def inspect_pdf(content: bytes) -> List[PageData]:
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
