from __future__ import annotations

from typing import Optional

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from .pdf_tools import build_translated_pages, inspect_pdf
from .translators import translate_pages

app = FastAPI(title="LuminaRead API", version="0.2.0")

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
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Could not read the PDF.") from exc
    return {"pages": [p.to_dict() for p in pages]}


@app.post("/translate")
async def translate(
    file: UploadFile = File(...),
    target_lang: str = Form(...),
    source_lang: str = Form("auto"),
    provider: str = Form("offline"),
    api_key: Optional[str] = Form(None),
    zoom: float = Form(2.0),
    render_images: bool = Form(True),
):
    content = await file.read()
    _require_pdf(content)

    try:
        structure = inspect_pdf(content)
    except Exception as exc:
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
