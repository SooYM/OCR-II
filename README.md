# 🩺 MedScan — Medical Report Digitization & Health Intelligence Platform

[![Flutter](https://img.shields.io/badge/Flutter-3.10%2B-blue.svg?logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-2.0.0-009688.svg?logo=fastapi)](https://fastapi.tiangolo.com)
[![Python](https://img.shields.io/badge/Python-3.10%2B-3776AB.svg?logo=python)](https://python.org)
[![OpenCV](https://img.shields.io/badge/OpenCV-Headless-5C3EE8.svg?logo=opencv)](https://opencv.org)
[![PostgreSQL](https://img.shields.io/badge/Supabase-PostgreSQL%2015-3ECF8E.svg?logo=supabase)](https://supabase.com)
[![OpenAI](https://img.shields.io/badge/OpenAI-GPT--4o%20Vision-412991.svg?logo=openai)](https://openai.com)

A full-stack clinical report digitization and health analytics application. MedScan transforms unstructured medical laboratory reports (paper printouts, scanned PDFs, screen captures) into structured, queryable clinical data, normalizes measurements across 92+ biomarkers, tracks longitudinal trends, and provides interactive, context-aware AI health insights.

---

## 🧭 Orientation & Which Files to Look at First

If you are new to the MedScan codebase, start with the following key entry points:

### 1. Presentation Tier (`frontend/lib/`)
* **[`frontend/lib/main.dart`](file:///Users/sooyauming/Desktop/Intern/OCR%20II/frontend/lib/main.dart)**: App initialization, global theme setup, SSL certificate overrides, and route bootstrapper.
* **[`frontend/lib/screens/main_screen.dart`](file:///Users/sooyauming/Desktop/Intern/OCR%20II/frontend/lib/screens/main_screen.dart)**: Central 5-tab application controller (Dashboard, Scanner, AI Assistant, Dictionary, Settings).
* **[`frontend/lib/screens/verify_screen.dart`](file:///Users/sooyauming/Desktop/Intern/OCR%20II/frontend/lib/screens/verify_screen.dart)**: Human-in-the-loop clinical parameter review, autocorrect listeners, and database commit triggers.
* **[`frontend/lib/services/api_service.dart`](file:///Users/sooyauming/Desktop/Intern/OCR%20II/frontend/lib/services/api_service.dart)**: HTTP client for multipart uploads, report persistence, and SSE token streaming.
* **[`frontend/lib/utils/unit_converter.dart`](file:///Users/sooyauming/Desktop/Intern/OCR%20II/frontend/lib/utils/unit_converter.dart)**: Bidirectional unit conversion mathematical formulas and reference range parsers.
* **[`frontend/lib/utils/biomarker_dictionary.dart`](file:///Users/sooyauming/Desktop/Intern/OCR%20II/frontend/lib/utils/biomarker_dictionary.dart)**: Searchable encyclopedia of 92+ biomarkers with alias fuzzy-matching.

### 2. Application & Vision Tier (`backend/`)
* **[`backend/main.py`](file:///Users/sooyauming/Desktop/Intern/OCR%20II/backend/main.py)**: Primary FastAPI microservice — JWT authentication, report ingest, duplicate detection, and streaming RAG endpoints.
* **[`backend/services/scanner/pipeline.py`](file:///Users/sooyauming/Desktop/Intern/OCR%20II/backend/services/scanner/pipeline.py)**: OpenCV preprocessing orchestrator — corner detection, perspective warping, and CLAHE enhancement.
* **[`backend/services/scanner/splitter.py`](file:///Users/sooyauming/Desktop/Intern/OCR%20II/backend/services/scanner/splitter.py)**: Otsu horizontal projection whitespace row-gap splitter for dense medical tables.
* **[`backend/unit_converter.py`](file:///Users/sooyauming/Desktop/Intern/OCR%20II/backend/unit_converter.py)**: Server-side unit normalization engine for database persistence.

---

## 📚 Complete Documentation Suite

Detailed technical guides are maintained in the [`docs/`](file:///Users/sooyauming/Desktop/Intern/OCR%20II/docs) directory:

| Document | Purpose & Contents |
| :--- | :--- |
| **[🏛️ System Design](file:///Users/sooyauming/Desktop/Intern/OCR%20II/docs/system_design.md)** | End-to-end processing pipeline, component boundaries, security model, and multi-tenancy. |
| **[🏗️ Architecture Deep-Dive](file:///Users/sooyauming/Desktop/Intern/OCR%20II/docs/architecture.md)** | Frontend Flutter architecture, OpenCV computer vision pipeline, and streaming RAG chat engine. |
| **[🗄️ Database Schema](file:///Users/sooyauming/Desktop/Intern/OCR%20II/docs/database_schema.md)** | Mermaid ER diagrams, 92-column staging table definition, RLS policies, and Post-May 2026 Supabase grants. |
| **[🔌 REST API Reference](file:///Users/sooyauming/Desktop/Intern/OCR%20II/docs/api_reference.md)** | Complete HTTP endpoint manual: request/response JSON schemas, query params, and status codes. |
| **[📖 Biomarker Data Dictionary](file:///Users/sooyauming/Desktop/Intern/OCR%20II/docs/data_dictionary.md)** | Clinical reference: 92+ parameters, categories, conventional vs SI units, and conversion algorithms. |
| **[🚀 Getting Started Guide](file:///Users/sooyauming/Desktop/Intern/OCR%20II/docs/getting_started.md)** | Step-by-step local setup instructions for Python backend and Flutter mobile client. |
| **[🧪 Testing & QA Manual](file:///Users/sooyauming/Desktop/Intern/OCR%20II/docs/testing.md)** | Unit test suites, widget smoke tests, and manual clinical report verification checklists. |
| **[🔍 Debugging Guide](file:///Users/sooyauming/Desktop/Intern/OCR%20II/docs/debugging.md)** | Common troubleshooting scenarios: OpenCV builds, Supabase HTTP/2 drops, and PostgREST type handling. |
| **[🚢 Release & Deployment](file:///Users/sooyauming/Desktop/Intern/OCR%20II/docs/release_and_deployment.md)** | Docker containerization, cPanel / WSGI deployment, and Flutter Android APK / iOS archive builds. |
| **[📜 Design Decisions Archive](file:///Users/sooyauming/Desktop/Intern/OCR%20II/docs/design_decisions_archive.md)** | Historical design documentation: GPT-4o Vision vs OCR, whitespace splitting, and duplicate engine tradeoffs. |

---

## ⚡ Quick Start

### 1. Start the Backend API
```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.template .env
# Edit .env with your OPENAI_API_KEY and STORAGE_ENGINE (supabase or sqlite)
python3 -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```
Interactive Swagger docs: `http://localhost:8000/docs`

### 2. Launch the Flutter Client
```bash
cd frontend
flutter pub get
flutter run
```

---

## 📁 Repository Directory Structure

```
OCR II/
 ├── docs/                           # Complete technical documentation suite
 │    ├── system_design.md           # System design & end-to-end data lifecycle
 │    ├── architecture.md            # Frontend, backend & OpenCV architecture
 │    ├── database_schema.md         # ERD, 92-column staging schema, SQL DDL
 │    ├── api_reference.md           # REST API reference manual
 │    ├── data_dictionary.md         # Clinical biomarker reference & unit formulas
 │    ├── getting_started.md         # Developer setup & onboarding
 │    ├── testing.md                 # Unit, widget & integration testing
 │    ├── debugging.md               # Troubleshooting & error resolution
 │    ├── release_and_deployment.md  # Docker, WSGI & mobile release packaging
 │    └── design_decisions_archive.md# Architectural decisions & PRD archive
 ├── backend/                        # FastAPI Python microservice
 │    ├── services/scanner/          # OpenCV edge detection, CLAHE & splitting
 │    │    ├── detector.py           # 4-point document corner detection
 │    │    ├── enhancer.py           # Illumination division & CLAHE contrast
 │    │    ├── perspective.py        # Perspective warping
 │    │    ├── pipeline.py           # Scanner pipeline orchestrator
 │    │    └── splitter.py           # Otsu horizontal projection gap splitter
 │    ├── main.py                    # Primary FastAPI app & route handlers
 │    ├── unit_converter.py          # Server-side clinical unit conversions
 │    ├── requirements.txt           # Python package dependencies
 │    ├── Dockerfile                 # Production container definition
 │    └── supabase_auth_setup.sql    # Supabase DDL migration script
 ├── frontend/                       # Flutter cross-platform mobile application
 │    ├── lib/
 │    │    ├── main.dart             # App entrypoint & theme setup
 │    │    ├── models/               # Data models (MedicalReport, ChatMessage)
 │    │    ├── screens/              # UI Views (Dashboard, Verify, Chat, etc.)
 │    │    ├── services/             # API, Auth, Theme singletons
 │    │    ├── utils/                # Unit converter, dictionary, date formatters
 │    │    └── widgets/              # Glassmorphism cards, custom painters
 │    ├── test/                      # Flutter unit and widget tests
 │    └── pubspec.yaml               # Dart package dependencies
 ├── .gitignore                      # Clean Git tracking configuration
 └── README.md                       # Main project overview & orientation
```

---

## 👥 Maintainers & Contact

* **Project**: MedScan Healthcare Analytics
* **Maintainer**: Soo YM
* **Repository**: [https://github.com/SooYM/OCR-II](https://github.com/SooYM/OCR-II)
* **License**: Proprietary / MIT License