# 🩺 MedScan — Medical Report Digitization

A cross-platform mobile application that digitizes medical blood reports using AI-powered vision. Snap one or multiple pages, let OpenAI Vision extract structured data, verify the results, and send them to the cloud — all in a single streamlined flow.

## ✨ Features

- **📸 Multi-Page Capture** — Photograph or pick multiple pages of a single report; the AI merges them into one unified record
- **🤖 AI-Powered Extraction** — OpenAI Vision (GPT-4o) reads images directly — no traditional OCR needed
- **✅ Human-in-the-Loop Verification** — Review, correct, and add fields before submitting
- **☁️ Cloud Storage** — Supabase (PostgreSQL) with staging table for clean downstream analytics
- **🔄 Flexible OCR Fallback** — Supports Tesseract and Google Cloud Vision as alternative OCR engines
- **🌙 Premium Dark UI** — Glassmorphism cards, smooth animations, and gradient accents

## 🏗️ Architecture

```
┌──────────────────────┐       ┌──────────────────────┐       ┌──────────────┐
│   Flutter Mobile App │──────▶│   FastAPI Backend     │──────▶│   Supabase   │
│                      │ HTTP  │                      │       │  PostgreSQL  │
│  • Multi-page capture│       │  • OpenAI Vision API  │       │              │
│  • Verify & correct  │◀──────│  • Data normalization │       │  • reports   │
│  • Send to cloud     │  JSON │  • 90+ field schema   │       │  • staging   │
└──────────────────────┘       └──────────────────────┘       └──────────────┘
```

## 📂 Project Structure

```
OCR-II/
├── backend/
│   ├── main.py              # FastAPI server (upload, OCR, LLM, storage)
│   ├── requirements.txt     # Python dependencies
│   ├── .env.template        # Environment variable template
│   └── uploads/             # Temporary uploaded images
├── frontend/
│   ├── lib/
│   │   ├── main.dart        # App entry point
│   │   ├── models/          # Data models (MedicalReport, StructuredData)
│   │   ├── screens/         # CaptureScreen, VerifyScreen
│   │   ├── services/        # ApiService (HTTP client)
│   │   ├── theme/           # AppTheme (dark mode, gradients)
│   │   └── widgets/         # GlassCard, GradientButton
│   └── pubspec.yaml
├── schema.md                # Database schema documentation
├── ImplementationPlan.md
└── SystemArchitectureFramework.md
```

## 🚀 Getting Started

### Prerequisites

| Tool | Version |
|------|---------|
| Flutter SDK | ≥ 3.10 |
| Python | ≥ 3.10 |
| Tesseract OCR | Latest (optional fallback) |
| OpenAI API Key | Required |
| Supabase Project | Required (or use SQLite locally) |

### Backend Setup

```bash
cd backend

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.template .env
# Edit .env with your keys:
#   OPENAI_API_KEY=sk-...
#   SUPABASE_URL=https://xxx.supabase.co
#   SUPABASE_KEY=eyJ...
#   STORAGE_ENGINE=supabase   (or 'sqlite' for local dev)
#   OCR_ENGINE=tesseract      (or 'google_vision')
#   OPENAI_MODEL=gpt-4o-mini  (or 'gpt-4o')

# Run the server
python3 -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### Frontend Setup

```bash
cd frontend

# Install dependencies
flutter pub get

# Run on connected device / emulator
flutter run
```

> **Tip:** On first launch, tap the ⚙️ icon to set the backend URL (e.g. `http://192.168.x.x:8000` or your localtunnel URL).

## 📱 Usage Flow

1. **Snap** — Open the app → capture pages via camera or pick from gallery
2. **Add Pages** — For multi-page reports, tap "Add pages" to capture additional pages
3. **Process** — Tap "Process N Pages" → AI extracts all fields across all pages
4. **Verify** — Review the extracted data, correct any errors, add missing fields
5. **Send** — Submit the verified data to the cloud database

## 🔌 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/` | Health check & config info |
| `POST` | `/api/upload` | Upload single image for processing |
| `POST` | `/api/upload-multi` | Upload multiple page images (merged via LLM) |
| `GET` | `/api/reports/{id}` | Get a report by ID |
| `PUT` | `/api/reports/{id}` | Update report data (tester corrections) |
| `POST` | `/api/reports/{id}/send` | Mark report as verified & submit to staging |

## 🛠️ Tech Stack

**Frontend**
- Flutter 3.10+ / Dart
- `image_picker` — camera & multi-image gallery selection
- `animate_do` — entrance animations
- `http` — REST API client

**Backend**
- Python FastAPI
- OpenAI Vision API (GPT-4o / GPT-4o-mini)
- Supabase (PostgreSQL) / SQLite fallback
- Tesseract OCR / Google Cloud Vision (optional)

## 📄 License

MIT License
