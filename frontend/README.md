# luminaread_frontend

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# 🚀 LuminaRead AI 
### *Next-Generation Structure-Preserving Translation Reader*

LuminaRead AI is a professional book reader designed to eliminate language barriers without sacrificing the original reading experience. Unlike standard translators, LuminaRead uses a **Visual-Sync Overlay** system to replace text while keeping layouts, images, and formatting 100% intact.

---

## ✨ Key Features

- **🖼️ Visual-Sync Overlay:** Extracts PDF coordinates via `PyMuPDF` and overlays translations exactly where the original text was.
- **🧠 Hybrid AI Brain:** 
  - **Online Mode:** High-fidelity translations using `GPT-4o` and `DeepL`.
    - **Offline Mode:** Local execution via quantized `TFLite` models.
    - **♻️ Autonomous Learning (RLHF):** Integrated `FAISS` Vector Database that remembers user corrections. If you correct a translation, the AI learns it and never makes that mistake again.
    - **💎 Pixel-Color UI:** A minimalist, modern interface featuring **Glassmorphism**, Neon Cyan (#00FFD1) accents, and deep matte black backgrounds.
    - **⚡ Zero-Config Onboarding:** Manifest-driven bootstrapping that automatically initializes AI models and memory on first launch.

    ---

    ## 🛠️ Tech Stack

    | Layer | Technology |
    | :--- | :--- |
    | **Frontend** | Flutter (Dart) - Web/Android/iOS |
    | **Backend** | Python FastAPI |
    | **AI/ML** | OpenAI GPT-4o, TFLite, Sentence-Transformers |
    | **Vector DB** | FAISS (Facebook AI Similarity Search) |
    | **PDF Engine** | PyMuPDF (fitz) |
    | **DevOps** | Docker, GitHub Codespaces |

    ---

    ## 🚀 Quick Start (Codespaces)

    1. **Clone the Repo** and open in GitHub Codespaces.
    2. **Start Backend:**
       ```bash
          cd backend && uvicorn main:app --host 0.0.0.0 --port 8000
          