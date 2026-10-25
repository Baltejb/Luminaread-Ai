"""LuminaRead AI backend — FastAPI app.

Endpoints
---------
GET  /health        liveness probe
POST /pdf/inspect    structure-only preview (spans + bbox, no images,
                      no translation) — fast, useful while building the UI
POST /translate       full pipeline: extract -> translate -> redact ->
                      render, returned as base64 PNG pages + translated
                      spans, ready for the Flutter "Visual-Sync" overlay
"""
from __future__ import annotations

from typing import Optional

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from .pdf_tools import build_translated_pages, inspect_pdf
from .translators import translate_pages

app = FastAPI(title="LuminaRead API", version="0.2.0")

# The Flutter app (web / mobile / desktop) calls this API from a different
# origin during development, so CORS is wide open here. Tighten this list
# before shipping to production.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


def _require_pdf(content: bytes) -> None:
    if not content.startswith(b"%PDF-"):
        raise HTTPException(status_code=400, detail="Please upload a PDF file.")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/pdf/inspect")
async def inspect(file: UploadFile = File(...)):
    content = await file.read()
    _require_pdf(content)
    try:
        pages = inspect_pdf(content)
    except Exception as exc:  # noqa: BLE001 - surfaced as a clean 400 for the client
        raise HTTPException(status_code=400, detail="Could not read the PDF.") from exc
    return {"pages": [p.to_dict() for p in pages]}


@app.post("/translate")
async def translate(
    file: UploadFile = File(...),
    target_lang: str = Form(...),
    source_lang: str = Form("auto"),
    provider: str = Form("offline"),
    # BYOK: the key only lives for the duration of this request and is
    # never persisted server-side. In production, prefer sending this as a
    # header instead of a form field so it never ends up in access logs.
    api_key: Optional[str] = Form(None),
    zoom: float = Form(2.0),
    render_images: bool = Form(True),
):
    content = await file.read()
    _require_pdf(content)

    try:
        structure = inspect_pdf(content)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=400, detail="Could not read the PDF.") from exc

    texts_by_page = [[s.text for s in page.spans] for page in structure]
    translated_by_page = await translate_pages(
        texts_by_page,
        provider=provider,
        target_lang=target_lang,
        source_lang=source_lang,
        api_key=api_key,
    )

    pages = build_translated_pages(
        content,
        translated_texts_by_page=translated_by_page,
        zoom=zoom,
        render_images=render_images,
    )
    return {
        "target_lang": target_lang,
        "source_lang": source_lang,
        "provider": provider,
        "pages": [p.to_dict() for p in pages],
    }
