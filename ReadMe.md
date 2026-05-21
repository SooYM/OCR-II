# 🩺 MedScan — Medical Report Digitization & Health Analytics

A premium, full-stack healthcare dashboard and medical report digitizer. MedScan uses AI-powered vision to extract structured data from blood reports, visualizes health trends over time, and provides personalized AI-driven health insights.

## ✨ Features

- **🌙 Premium Theme Toggle** — Seamlessly switch between clean light mode and premium dark mode.
- **📈 Global Date Filtering** — Unified date range filter that dynamically updates all charts and tables across the dashboard.
- **📊 Comparative Trend Analysis** — Overlay multiple biomarkers (e.g., LDL vs HDL) on a single interactive line chart with synchronized tooltips.
- **📋 Collapsible Profile Groups** — Analytics table organized into 14+ standardized medical profiles (Lipid, Liver, CBC, etc.) with interactive expand/collapse functionality.
- **📸 Multi-Page Capture** — Photograph or pick multiple pages; the AI merges them into one unified record.
- **🤖 AI-Powered Extraction** — OpenAI Vision (GPT-4o-mini) reads images directly for high-accuracy extraction.
- **➕ Manual Logging** — Add report entries manually using a dedicated "+" button directly within the dashboard.
- **🔍 Document Reference Tracking** — Surface unique report identifiers (Accession No, Report No) as `Ref:` keys on history cards and check screens.
- **🕒 24h Time Normalization** — Automatically formats extraction and manual inputs into standard 24h `HH:MM:SS` format.
- **🔍 Full-screen Chart Expansion** — Tap any graph to expand into a detailed, full-screen trend analysis view with persistent legends.
- **🧠 AI Health Analysis** — Get personalized insights with rich text formatting and the ability to ask custom follow-up questions.
- **✅ Human-in-the-Loop Verification** — Review and correct data before submission to ensure 100% accuracy.
- **🔐 Secure User Authentication** — JWT-based login and signup system for personalized data isolation and ownership validation.
- **🎨 Premium UI/UX** — Glassmorphism design, smooth animations, and optimized layouts for all screen sizes.

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
| Supabase/PostgreSQL | Required |

### Backend Setup

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.template .env # Configure your API keys and Database URL
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
2. **Scan or Add** — Capture blood report pages for AI auto-merging, or tap the "+" icon to log data manually.
3. **Verify** — Confirm/correct the extracted values and check the collection date/reference code.
4. **Dashboard** — Filter by date range and analyze trends using individual or comparative charts.
5. **Table** — Expand specific medical profiles in the analytics table to view detailed biomarker history.
6. **AI Analysis** — Generate detailed summaries or ask specific questions about your results.

## 🔌 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/auth/register` | User registration |
| `POST` | `/api/auth/login` | JWT Authentication |
| `POST` | `/api/upload-multi` | Process multi-page reports via AI Vision |
| `POST` | `/api/reports/manual` | Initialize a blank manual entry report |
| `GET` | `/api/reports/my` | Retrieve user-specific report history |
| `DELETE` | `/api/reports/{id}` | Securely delete a report |
| `POST` | `/api/reports/analyze` | Generate rich-text AI health insights |

## 📷 OCR Scan & Capture Guidelines

For high-accuracy data extraction, please ensure you follow these capture guidelines:

* **Document Orientation (Critical)**: Always capture or upload images **right-side up**. If a document is uploaded upside down ($180^\circ$ rotated), the characters will be extracted upside down (resulting in garbled text) and the parsing engine will fail to map the values, falling back to a raw text block in the Notes field.
* **Lighting**: Capture under uniform, bright lighting to avoid heavy shadows and glares.
* **Flatness**: Keep the document as flat as possible. Wrinkles and bends can distort text lines and cause incorrect biomarker matching.

## 🛠️ Tech Stack

**Frontend**
- **Flutter** — Cross-platform UI
- **fl_chart** — High-performance interactive visualizations
- **flutter_markdown** — Rich text AI response rendering
- **animate_do** — Premium UI micro-interactions
- **shared_preferences** — Theme preference persistence

- **PyJWT & Bcrypt** — Industrial-grade security

## 📖 Data Dictionary & Standardized Units

MedScan standardizes all extracted medical data into the following profiles and units to ensure consistent trend tracking across different laboratories.

| Category | Parameter | Unit | Description |
|----------|-----------|------|-------------|
| **Hematology (CBC)** | Hemoglobin | g/dL | Oxygen-carrying protein in red blood cells |
| | RBC Count | mil/µL | Total number of red blood cells |
| | WBC Count | cells/µL | Total white blood cell count (Leukocytes) |
| | Platelet Count | x10³/µL | Cells responsible for blood clotting |
| | Hematocrit | % | Proportion of blood volume occupied by RBCs |
| | MCV / MCH / MCHC | fL / pg / g/dL | Red blood cell indices |
| **Lipid Profile** | Total Cholesterol | mg/dL | Combined measure of all cholesterol |
| | HDL Cholesterol | mg/dL | "Good" cholesterol (High-Density Lipoprotein) |
| | LDL Cholesterol | mg/dL | "Bad" cholesterol (Low-Density Lipoprotein) |
| | Triglycerides | mg/dL | Type of fat (lipid) found in the blood |
| **Renal (Kidney)** | Creatinine | mg/dL | Waste product used to measure kidney function |
| | Urea / BUN | mg/dL | Measures amount of nitrogen in blood from urea |
| | eGFR | mL/min/1.73m² | Estimated Glomerular Filtration Rate |
| | Uric Acid | mg/dL | Waste product of purine metabolism |
| **Liver Function** | ALT (SGPT) | U/L | Enzyme found primarily in the liver |
| | AST (SGOT) | U/L | Enzyme found in liver and heart |
| | ALP / GGT | U/L | Enzymes related to bile ducts and bone |
| | Bilirubin (Total/Dir) | mg/dL | Yellow pigment from RBC breakdown |
| | Albumin / Globulin | g/dL | Blood proteins produced by liver |
| **Diabetes** | HbA1c | % | Average blood sugar levels over 3 months |
| | Fasting Glucose | mg/dL | Blood sugar after fasting period |
| **Electrolytes** | Sodium / Potassium | mmol/L | Essential minerals for cell function |
| | Calcium / Phosphorus | mg/dL | Key minerals for bone health |
| **Urine Analysis** | Specific Gravity | - | Concentration of particles in urine |
| | pH | - | Acidity/alkalinity of urine |
| | Protein / Glucose | - | Presence of these in urine (qualitative) |