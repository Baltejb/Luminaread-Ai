# LuminaRead AI

A book reader that translates a PDF from any language into any other
language while keeping the original layout: the translated text is drawn
back exactly where the original text was, on top of the original page
image with that text painted over ("Visual-Sync" overlay).

```
backend/   FastAPI service: PDF parsing, redaction, rendering, translation
lib/       Flutter app: pick a PDF, choose a language/engine, read it
```

## 1. Run the backend

```bash
cd backend
pip install -r ../requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Check it's alive: `curl http://localhost:8000/health` → `{"status":"ok"}`.

Run the tests:

```bash
cd backend
pytest
```

### Endpoints

- `GET /health` — liveness probe.
- `POST /pdf/inspect` — upload a PDF (`file`), get back every page's text
  spans and their bounding boxes (as fractions of the page size). No
  translation, no rendering — useful while building/debugging the UI.
- `POST /translate` — the full pipeline. Form fields:
  | field | required | default | notes |
  |---|---|---|---|
  | `file` | yes | — | the PDF |
  | `target_lang` | yes | — | e.g. `pa`, `hi`, `es` |
  | `source_lang` | no | `auto` | |
  | `provider` | no | `offline` | `offline` \| `deepl` \| `gemini` \| `openai` |
  | `api_key` | no | — | required for every provider except `offline` (BYOK — never stored) |
  | `zoom` | no | `2.0` | render resolution multiplier |
  | `render_images` | no | `true` | set `false` to skip rendering and get structure + translated text only |

  Response: one entry per page with `width`, `height`, `spans` (translated
  `text` + original `bbox`) and, if requested, `image_png_base64` — the
  page rendered with the original text already painted over, ready to use
  as the Flutter `Stack`'s background image.

## 2. Run the Flutter app

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d web-server --web-port 5173
# or, on a GUI-less Codespace:
flutter run -d chrome
```

By default the app talks to `http://localhost:8000`. Point it at a
different backend (e.g. a forwarded Codespaces port) with:

```bash
flutter run --dart-define=API_BASE_URL=https://<your-forwarded-port-url>
```

If you're running both inside the same Codespace, forward port `8000`
(Ports tab → Add Port) and make sure it's set to **Public** so the Flutter
web build (served from a different port) can reach it; otherwise pass the
forwarded URL via `API_BASE_URL` as above.

## 3. Using it

1. Open the app → pick a PDF.
2. Choose a target language. Choose **Offline** to try the overlay with no
   API key (it echoes the original text), or pick **Gemini / OpenAI /
   DeepL** and paste your own key (BYOK — kept only on your device, sent
   per-request, never stored by the backend).
3. Tap **Translate & Open** → swipe through the translated pages.

## Translation providers

All four live in `backend/app/translators.py` behind one interface
(`translate_texts`/`translate_pages`), so adding a fifth provider is just
one more function + a line in `_PROVIDERS`.

- **offline** — no key, returns the original text. Swap this out for an
  on-device TFLite model later without touching any caller.
- **deepl** — uses DeepL's native array endpoint (most robust: it can't
  merge/drop/reorder lines).
- **gemini** / **openai** — prompted to return a JSON array of the exact
  same length as the input; if a provider ever gets the count wrong, that
  page silently falls back to its original-language text instead of
  crashing or misaligning the overlay.

## What's next

See the project's master prompt for the full roadmap (on-device TFLite
models, the RLHF/vector-DB learning agent, Web-RAG, Stripe billing, audio
sync). The `requirements.txt` already lists the packages for the learning
agent (`sentence-transformers`, `faiss-cpu`, `torch`) so the environment is
ready when that module starts — they aren't imported by anything yet.

## Repo layout note

An earlier commit had a second, incomplete Flutter scaffold under
`frontend/` (no Android/iOS/desktop folders, just the default counter
app). It's been removed — the Flutter app lives at the repo root, where it
already had full platform support.
