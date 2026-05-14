# 🩺 MedScan — Medical Report Digitization & Health Analytics

A premium, full-stack healthcare dashboard and medical report digitizer. MedScan uses AI-powered vision to extract structured data from blood reports, visualizes health trends over time, and provides personalized AI-driven health insights.

## ✨ Features

- **🌙 Premium Theme Toggle** — Seamlessly switch between clean light mode and premium dark mode
- **📸 Multi-Page Capture** — Photograph or pick multiple pages; the AI merges them into one unified record
- **🤖 AI-Powered Extraction** — OpenAI Vision (GPT-4o) reads images directly for high-accuracy extraction
- **📈 Interactive Dashboard** — Track health trends with categorized biomarker graphs (Lipid Profile, Liver/Kidney, CBC, etc.)
- **🔍 Full-screen Chart Expansion** — Tap any graph to expand into a detailed, full-screen trend analysis view
- **🧠 AI Health Analysis** — Get personalized insights with rich text formatting and the ability to ask custom follow-up questions
- **✅ Human-in-the-Loop Verification** — Review and correct data before submission to ensure 100% accuracy
- **🗑️ Secure Report Management** — View history and securely delete reports with ownership validation
- **🔐 User Authentication** — Secure JWT-based login and signup system for personalized data isolation
- **🎨 Premium UI/UX** — Glassmorphism design, smooth animations, and optimized layouts for all screen sizes

## 🏗️ Architecture

```
┌──────────────────────┐       ┌──────────────────────┐       ┌──────────────┐
│   Flutter Mobile App │──────▶│   FastAPI Backend     │──────▶│   Supabase   │
│                      │ HTTP  │                      │       │  PostgreSQL  │
│  • Trend Dashboard   │       │  • OpenAI GPT-4o API  │       │              │
│  • AI Analytics      │◀──────│  • Data normalization │       │  • users     │
│  • Report Management │  JSON │  • Secure JWT Auth    │       │  • reports   │
└──────────────────────┘       └──────────────────────┘       └──────────────┘
```

## 📂 Project Structure

```
OCR-II/
├── backend/
│   ├── main.py              # FastAPI server (Auth, CRUD, AI Analysis, OCR)
│   ├── requirements.txt     # Python dependencies
│   ├── .env.template        # Environment variable template
│   └── uploads/             # Temporary uploaded images
├── frontend/
│   ├── lib/
│   │   ├── main.dart        # App initialization
│   │   ├── models/          # Data models (MedicalReport, User, etc.)
│   │   ├── screens/         # Dashboard, Capture, Auth, History, Verify
│   │   ├── services/        # ApiService, AuthService, ThemeService
│   │   ├── theme/           # AppTheme (Premium Light & Dark Themes)
│   │   └── widgets/         # GlassCard, Custom Charts, AI Analysis UI
│   └── pubspec.yaml
└── ...
```

## 🚀 Getting Started

### Prerequisites

| Tool | Version |
|------|---------|
| Flutter SDK | ≥ 3.10 |
| Python | ≥ 3.10 |
| OpenAI API Key | Required |
| Supabase/SQLite | Required |

### Backend Setup

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.template .env # Configure your API keys here
python3 -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### Frontend Setup

```bash
cd frontend
flutter pub get
flutter run
```

## 📱 Usage Flow

1. **Auth** — Sign up or log in to your secure personalized account.
2. **Scan** — Capture blood report pages. The AI automatically merges multi-page documents.
3. **Verify** — Confirm the extracted values and enter the collection date.
4. **Dashboard** — View biomarker trends across your history with interactive line charts.
5. **AI Analysis** — Generate detailed summaries or ask specific questions about your results.
6. **Theme** — Toggle between Light and Dark mode using the button in the dashboard header.

## 🔌 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/auth/register` | User registration |
| `POST` | `/api/auth/login` | JWT Authentication |
| `POST` | `/api/upload-multi` | Process multi-page reports via AI Vision |
| `GET` | `/api/reports/my` | Retrieve user-specific report history |
| `DELETE` | `/api/reports/{id}` | Securely delete a report |
| `POST` | `/api/reports/analyze` | Generate rich-text AI health insights |

## 🛠️ Tech Stack

**Frontend**
- **Flutter** — Cross-platform UI
- **fl_chart** — High-performance interactive visualizations
- **flutter_markdown** — Rich text AI response rendering
- **animate_do** — Premium UI micro-interactions
- **shared_preferences** — Theme preference persistence

**Backend**
- **FastAPI** — High-performance Python backend
- **OpenAI GPT-4o** — Vision & analytical reasoning
- **Supabase/PostgreSQL** — Secure cloud storage
- **PyJWT & Bcrypt** — Industrial-grade security