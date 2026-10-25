"""Entry point kept at ``backend/main.py`` for backward compatibility with
``uvicorn main:app --reload`` run from inside the ``backend/`` folder.

The actual implementation lives in the ``app`` package next to this file
(``backend/app/``), split into ``pdf_tools.py`` (PyMuPDF extraction,
redaction, rendering), ``translators.py`` (pluggable translation providers)
and ``main.py`` (the FastAPI routes).
"""
from app.main import app  # noqa: F401
