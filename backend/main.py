from fastapi import FastAPI, File, HTTPException, UploadFile
import fitz

app = FastAPI(title="LuminaRead API")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/pdf/inspect")
async def inspect_pdf(file: UploadFile = File(...)):
    content = await file.read()

    if not content.startswith(b"%PDF-"):
        raise HTTPException(status_code=400, detail="Please upload a PDF file.")

    try:
        document = fitz.open(stream=content, filetype="pdf")
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Could not read the PDF.") from exc

    pages = []
    for page_number, page in enumerate(document, start=1):
        width, height = page.rect.width, page.rect.height
        spans = []

        for block in page.get_text("dict")["blocks"]:
            if block.get("type") != 0:
                continue

            for line in block.get("lines", []):
                for span in line.get("spans", []):
                    text = span["text"]
                    if not text.strip():
                        continue

                    x0, y0, x1, y1 = span["bbox"]
                    spans.append({
                        "text": text,
                        # Coordinates are fractions of the page size (0 to 1).
                        "bbox": [
                            x0 / width, y0 / height,
                            x1 / width, y1 / height,
                        ],
                    })

        pages.append({
            "page": page_number,
            "width": width,
            "height": height,
            "spans": spans,
        })

    document.close()
    return {"pages": pages}