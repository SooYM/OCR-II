# 🩺 MedScan — Medical Report Digitization & Health Analytics

A premium, full-stack healthcare dashboard and medical report digitizer. MedScan uses AI-powered vision to extract structured data from blood reports, visualizes health trends over time, and provides personalized AI-driven health insights.

## ✨ Features

- **🌙 Premium Theme Toggle** — Seamlessly switch between clean light mode and premium dark mode.
- **📈 Global Date Filtering** — Unified date range filter that dynamically updates all charts and tables across the dashboard.
- **📊 Comparative Trend Analysis** — Overlay multiple biomarkers (e.g., LDL vs HDL) on a single interactive line chart with synchronized tooltips.
- **📋 Collapsible Profile Groups** — Analytics table organized into 14+ standardized medical profiles (Lipid, Liver, CBC, etc.) with interactive expand/collapse functionality.
- **📸 Multi-Page Capture** — Photograph or pick multiple pages; the AI merges them into one unified record.
- **🤖 AI-Powered Extraction** — OpenAI Vision (GPT-4o) reads images directly for high-accuracy extraction.
- **➕ Manual Logging** — Add report entries manually using a dedicated "+" button directly within the dashboard.
- **🔍 Document Reference Tracking** — Surface unique report identifiers (Accession No, Report No) as `Ref:` keys on history cards and check screens.
- **🚫 Smart Duplicate Detection** — Prevents duplicate uploads using a multi-attribute checking system that compares normalized/cleaned Lab Reference numbers, Lab Numbers/Sample IDs, and clinical signature overlaps.
- **🕒 24h Time Normalization** — Automatically formats extraction and manual inputs into standard 24h `HH:MM:SS` format.
- **🔍 Full-screen Chart Expansion** — Tap any graph to expand into a detailed, full-screen trend analysis view with persistent legends.
- **✨ AI Health Summary** — Layman-friendly, empathetic dashboard summary automatically highlights out-of-range biomarkers, physiochemical connections, and features direct redirect linking to the AI Chat assistant.
- **🧠 AI Health Analysis** — Get personalized insights with rich text formatting and the ability to ask custom follow-up questions.
- **✅ Human-in-the-Loop Verification** — Review and correct data before submission to ensure 100% accuracy. Dynamically pre-populates all 92 dictionary-supported biomarkers as empty/editable entries when not extracted by OCR and handles exponent/Unicode-aware unit normalization to prevent dropdown casing crashes.
- **🔐 Secure User Authentication** — JWT-based login and signup system for personalized data isolation and ownership validation.
- **🎨 Premium UI/UX** — Glassmorphism design, smooth animations, and optimized layouts for all screen sizes.

## ⚙️ Core Pipelines & Engine Mechanics

### 1. ✂️ Content-Aware Image Splitting
To solve the standard issue of OpenAI Vision missing or misaligning small text lines on high-density medical reports, MedScan integrates a content-aware image splitting engine (`splitter.py`):
- **Horizontal Projection Profile**: Binarizes the image using Otsu's thresholding, inversion, and horizontal summation of dark pixels (text elements) along each row.
- **Whitespace Gap Detection**: Identifies contiguous vertical bands of empty whitespace separating text lines.
- **Midpoint Alignment**: Searches the middle 70% of the image to find the whitespace gap center closest to the physical midpoint, ensuring no line of text is sliced horizontally.
- **Safety Overlap Margin**: Splits the image into top and bottom halves with an automatic 3% vertical overlap on each side, guaranteeing that boundary characters are completely visible in at least one segment.

### 2. 🪄 Image Preprocessing & Contrast Enhancement
Prior to analysis, scanned images are processed to remove environmental factors (uneven lighting, shadows, creases):
- **Illumination Correction**: Extracts the background map via dilation followed by a large median blur (21x21 kernel), then divides the original color channels by this map. This normalizes lighting and converts the background to clean white.
- **Dynamic Contrast Range**: Normalizes the final image dynamic range to maximize readability.
- **Unsharp Masking**: Applies a sharpening filter kernel to enhance edge definitions, making fine character segments stand out.
- **High-Quality Upscaling**: Proportionally resizes any split section or small image with `INTER_CUBIC` interpolation to a minimum height of 800px if it falls below the threshold.

### 3. 🚫 Smart Duplicate Prevention Engine
To prevent database clutter and redundant chart data points, MedScan implements a multi-criteria duplicate checking algorithm (`check_duplicate_report`). Rather than a basic raw comparison, the engine analyzes reports **value-by-value** at the biomarker level:
- **Biomarker Intersection**: The check only compares biomarkers (by name/key) that are present in both the new report and the existing report (non-empty intersection).
- **Unit Standardization**: The engine dynamically standardizes clinical units before comparing values (e.g., converting RBC/WBC, platelet counts, absolute cell counts, and eGFR to a common unit to avoid false mismatches).
- **2% Numeric Tolerance**: If the standardized values are numeric, they match if the difference is within **2%** (accounting for rounding/precision differences).
- **Qualitative Comparison**: Non-numeric/qualitative biomarkers fallback to a trimmed, case-insensitive string match.
- **Multi-Criteria Validation**:
  - **Criteria 1 (Exact Reference Match)**: Matches normalized, alphanumeric-only `report_reference` (e.g. Accession/Report Number).
  - **Criteria 1B (Exact Lab Number Match)**: Matches normalized, alphanumeric-only `labreference` (e.g. Lab Specimen Number).
  - **Criteria 2 (High Clinical Fingerprint Overlap)**: Matches reports sharing $\ge 3$ biomarker keys with $\ge 90\%$ identical clinical values, regardless of date.
  - **Criteria 3 (Low Contradiction Clinical Match)**: Matches reports sharing $\ge 2$ biomarker keys with $100\%$ identical values, provided dates and patient IDs do not explicitly contradict.
  - **Criteria 4 (Same Date & Patient ID Match)**: Matches reports with identical dates, patient IDs, and $\ge 80\%$ clinical overlap.
  - **Criteria 5 (Fuzzy Date Match)**: Matches reports with dates within $\pm 2$ days, identical patient IDs, and $\ge 80\%$ clinical overlap.

### 4. 🕒 24h Time Normalization
Time values extracted from reports or entered manually are parsed and formatted into standard 24h `HH:MM:SS` format. If a report specifies a collection time and reported/printed time, both are isolated. If only one time is specified, the system maps it to both fields to prevent data gaps.

### 5. 🗃️ Database Layout, Swapped Fields, & Isolated Notes
To resolve terminology overlaps and separate clinical findings from user notes, the database schema and extraction models align as follows:
- **`report_reference`** (formerly `sample_id`): Represents the unique printed report reference document identifier (e.g. Accession No., Episode No.).
- **`labreference`** (formerly `lab_reference`): Represents the unique physical lab sample specimen container ID (e.g. Lab No., Specimen ID).
- **`original_labreference`**: Retains the raw, unmodified report reference string from the OCR engine for data verification.
- **General Notes vs. Clinical `others`**: Previously, the `others` clinical biomarker under the Urine profile was conflated with general report notes. General report-level comments and remarks are now isolated into an independent `notes` field (stored in the main `reports` database table JSON payload and exposed directly to the AI chat and dashboard), whereas the `others` field remains strictly a clinical biomarker under the Urinalysis profile.
Existing records have been fully migrated by swapping column values and updating key constraints to maintain historical consistency.

### 6. 🔐 Secure User Authentication & Isolation
MedScan features JWT-based authentication using PyJWT and bcrypt. Every database query filters records using the user ID parsed from the verified authorization headers, ensuring complete data privacy and security.

### 7. 🤖 AI Health Summary & Physiological Correlation Engine
MedScan integrates an automated clinical summary generator that delivers immediate, layman-friendly insights whenever the user refreshes or loads their trend dashboard:
- **Empathetic Layman Translation**: Avoids dry clinical tables by translating out-of-range indicators into simple, readable wellness terms.
- **Physiological Correlations**: Uses OpenAI LLM structures to trace biological dependencies between multiple metrics (e.g., lipid profile cholesterol ratios correlated with glycemic indicators).
- **Smooth Deep-Dive Transition**: Embedded link allows the user to immediately transition to the AI Chat view, auto-preserving their current dashboard context.

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

### 🗄️ Database Setup (Supabase PostgreSQL)

If you are using Supabase as your storage backend (`STORAGE_ENGINE=supabase` in `.env`), run the setup SQL scripts in the **Supabase SQL Editor** (Dashboard > SQL Editor) to provision the database schema:

#### 1. Core Tables & RLS Policies Setup
Run the script below (available in [supabase_auth_setup.sql](file:///Users/sooyauming/Desktop/Intern/OCR%20II/backend/supabase_auth_setup.sql)) to create the `users` authentication table, add foreign key relationships to `reports`, and set up Row Level Security (RLS) policies:

```sql
-- Create users table for app-level authentication
CREATE TABLE IF NOT EXISTS users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email         TEXT UNIQUE NOT NULL,
    name          TEXT NOT NULL,
    gender        TEXT, -- Normalize to "Male" or "Female"
    password_hash TEXT NOT NULL,
    status        TEXT NOT NULL DEFAULT 'active',
    health_summary TEXT, -- Cached AI health summary
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fast email lookups during login
CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);

-- Create reports table for storing digitized files and structured metadata
CREATE TABLE IF NOT EXISTS reports (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    filename        TEXT NOT NULL,
    upload_time     TIMESTAMPTZ NOT NULL DEFAULT now(),
    status          TEXT NOT NULL DEFAULT 'processing',
    raw_text        TEXT,
    structured_data JSONB,
    user_verified   INTEGER DEFAULT 0,
    file_path       TEXT
);

-- Ensure user_id column exists and links to users table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'reports' AND column_name = 'user_id'
    ) THEN
        ALTER TABLE reports ADD COLUMN user_id UUID REFERENCES users(id);
    END IF;
END $$;

-- Index for fetching reports by user
CREATE INDEX IF NOT EXISTS idx_reports_user_id ON reports (user_id);

-- Create chat_sessions table for medical chat history context
CREATE TABLE IF NOT EXISTS chat_sessions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    title       TEXT NOT NULL
);

-- Index for fast session lookup by user
CREATE INDEX IF NOT EXISTS idx_chat_sessions_user_id ON chat_sessions (user_id);

-- Create chat_messages table for session message log
CREATE TABLE IF NOT EXISTS chat_messages (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id  UUID REFERENCES chat_sessions(id) ON DELETE CASCADE,
    role        TEXT NOT NULL,
    content     TEXT NOT NULL,
    timestamp   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for message ordering per session
CREATE INDEX IF NOT EXISTS idx_chat_messages_session_id ON chat_messages (session_id);

-- Enable Row Level Security (RLS) on all core tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Allow service role / API anon key full access (server-side auth bypass)
CREATE POLICY "Allow all access to users" ON users FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access to reports" ON reports FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access to chat_sessions" ON chat_sessions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access to chat_messages" ON chat_messages FOR ALL USING (true) WITH CHECK (true);

-- Grant explicit API privileges (required for Supabase projects after May 30, 2026)
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE users TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE reports TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE chat_sessions TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE chat_messages TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE staging_medical_records TO anon, authenticated, service_role;
```

#### 2. Adding Gender Column (Existing Databases)
If you already had a database instance running, make sure to add the `gender` column using [add_gender_column.sql](file:///Users/sooyauming/Desktop/Intern/OCR%20II/backend/add_gender_column.sql):

```sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS gender TEXT;
```

#### 3. Local SQLite Storage Engine
If you are running the backend in local mode (`STORAGE_ENGINE=sqlite`), the database file (`medical_reports.db`) and schema modifications (including the `gender` column auto-migration) will be provisioned and configured **automatically** on startup.


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

MedScan standardizes all extracted medical data into the following 14 profiles and units to ensure consistent trend tracking across different laboratories.

| Profile / Category | Parameter | Standard Unit | Description |
|--------------------|-----------|---------------|-------------|
| **Urine** | Urine Colour | - | The visual color of the urine sample. |
|  | Appearance | - | The clarity or turbidity of the urine. |
|  | Specific Gravity | - | Measures the concentration of particles in the urine. |
|  | pH | - | Measures the acidity or alkalinity of the urine. |
|  | Proteins | `mg/dL` | Detects the presence of protein in the urine. |
|  | Glucose (Urine) | - | Detects the presence of sugar in the urine. |
|  | Bilirubin (Urine) | - | Detects processed bilirubin in the urine. |
|  | Ketones | - | Detects ketones, a byproduct of fat breakdown. |
|  | Blood (Urine) | - | Detects the presence of blood or hemoglobin in the urine. |
|  | Urobilinogen | `EU/dL` | A byproduct of bilirubin breakdown found in urine. |
|  | Nitrites | - | Often indicates the presence of a urinary tract infection (UTI). |
|  | WBC / Pus Cells | `/HPF` | Presence of white blood cells in urine, indicating infection or inflammation. |
|  | RBC (Urine) | `/HPF` | Presence of red blood cells in urine. |
|  | Epithelial Cells | `/HPF` | Cells that line the urinary tract. |
|  | Casts | `/LPF` | Cylindrical structures formed in the kidney tubules. |
|  | Crystals | - | Solid particles formed from chemicals in the urine. |
|  | Others | - | Any other elements observed in urine. |
| **CBC** | Hemoglobin | `g/dL` | The protein in red blood cells that carries oxygen throughout the body. |
|  | RBC Count | `mil/uL` | The total number of red blood cells in a volume of blood. |
|  | Hematocrit | `%` | The proportion of blood that consists of red blood cells. |
|  | MCV | `fL` | The average size of your red blood cells. |
|  | MCH | `pg` | The average amount of hemoglobin in each red blood cell. |
|  | MCHC | `g/dL` | The average concentration of hemoglobin in a given volume of red blood cells. |
|  | RDW-CV | `%` | A measure of the variation in size of red blood cells. |
|  | RDW-SD | `fL` | The actual measurement of the width of the red blood cell distribution curve. |
|  | WBC | `cells/uL` | The total number of white blood cells, which help the body fight infections. |
|  | Neutrophils | `%` | The most common type of white blood cell, primarily responsible for fighting bacterial infections. |
|  | Lymphocytes | `%` | White blood cells that are key to the immune system, including T cells and B cells. |
|  | Eosinophils | `%` | White blood cells active during allergic reactions and parasitic infections. |
|  | Monocytes | `%` | White blood cells that migrate to tissues and become macrophages to consume pathogens. |
|  | Basophils | `%` | The least common white blood cell, involved in inflammatory and allergic responses. |
|  | Abs. Neutrophils | `cells/uL` | The actual number of neutrophils present in the blood. |
|  | Abs. Lymphocytes | `cells/uL` | The actual number of lymphocytes present in the blood. |
|  | Abs. Monocytes | `cells/uL` | The actual number of monocytes present in the blood. |
|  | Abs. Eosinophils | `cells/uL` | The actual number of eosinophils present in the blood. |
|  | Abs. Basophils | `cells/uL` | The actual number of basophils present in the blood. |
| **Platelet Profile** | Platelet Count | `x10³/uL` | Cells that help the blood clot to stop bleeding. |
|  | MPV | `fL` | The average size of the platelets in your blood. |
|  | Platelet RDW | `%` | Measurement of how much platelets vary in size. |
|  | PCT | `%` | The volume occupied by platelets in the blood. |
|  | P-LCR | `%` | The percentage of large-sized platelets. |
|  | IMG | `%` | Immature Granulocyte percentage. |
|  | IMM | `%` | Immature Monocyte percentage. |
|  | IML | `%` | Immature Lymphocyte percentage. |
|  | LIC | `%` | Large Immature Cell percentage. |
| **Lipid Profile** | Total Cholesterol | `mg/dL` | The total amount of cholesterol found in your blood. |
|  | HDL Cholesterol | `mg/dL` | Known as 'good' cholesterol; it helps remove other forms of cholesterol from your bloodstream. |
|  | LDL Cholesterol | `mg/dL` | Known as 'bad' cholesterol; high levels can lead to plaque buildup in arteries. |
|  | VLDL Cholesterol | `mg/dL` | A type of blood fat that carries triglycerides. |
|  | Triglycerides | `mg/dL` | A type of fat (lipid) found in your blood, used for energy. |
|  | Non-HDL Cholesterol | `mg/dL` | Total cholesterol minus HDL; represents all potentially harmful cholesterol. |
|  | Total/HDL Ratio | - | The ratio of total cholesterol to HDL, used to assess heart disease risk. |
|  | LDL/HDL Ratio | - | The ratio of LDL to HDL cholesterol. |
| **Liver Function** | Bilirubin Total | `mg/dL` | A yellow pigment produced during the normal breakdown of red blood cells. |
|  | Bilirubin Direct | `mg/dL` | Bilirubin that has been processed by the liver and is ready for excretion. |
|  | Bilirubin Indirect | `mg/dL` | Bilirubin that has not yet been processed by the liver. |
|  | ALP | `U/L` | An enzyme found in the liver, bones, kidneys, and digestive system. |
|  | ALT (SGPT) | `U/L` | An enzyme found mostly in the liver; high levels suggest liver damage. |
|  | AST (SGOT) | `U/L` | An enzyme found in the liver, heart, and muscles. |
|  | GGT | `U/L` | An enzyme found in the liver and bile ducts; sensitive to alcohol and bile duct issues. |
|  | Total Protein | `g/dL` | The total amount of albumin and globulin in the blood. |
|  | Albumin | `g/dL` | A protein made by the liver that keeps fluid from leaking out of blood vessels. |
|  | Globulin | `g/dL` | A group of proteins in the blood that help the immune system and liver function. |
|  | A/G Ratio | - | The ratio of albumin to globulin in the blood. |
| **Kidney Function** | Creatinine | `mg/dL` | A waste product from muscle breakdown, filtered by the kidneys. |
|  | Urea | `mg/dL` | A waste product formed in the liver when protein is broken down. |
|  | BUN | `mg/dL` | The amount of nitrogen in your blood that comes from the waste product urea. |
|  | BUN/Creatinine Ratio | - | The ratio of BUN to creatinine, used to diagnose acute kidney issues. |
|  | Sodium | `mmol/L` | An electrolyte that helps maintain fluid balance and nerve function. |
|  | Potassium | `mmol/L` | An electrolyte vital for heart and muscle function. |
|  | Chloride | `mmol/L` | An electrolyte that helps maintain proper blood volume and pressure. |
|  | Uric Acid | `mg/dL` | A waste product from the breakdown of purines; high levels can cause gout. |
|  | eGFR | `mL/min/1.73m²` | A calculation of how well the kidneys are filtering waste from the blood. |
| **Iron Profile** | Iron | `ug/dL` | A mineral used by the body to make hemoglobin. |
|  | UIBC | `ug/dL` | The reserve capacity of transferrin to bind iron. |
|  | TIBC | `ug/dL` | The total capacity of the blood to carry iron. |
|  | Transferrin Saturation | `%` | The percentage of transferrin that is saturated with iron. |
| **HbA1c** | HbA1c | `%` | Measures average blood sugar levels over the past 2-3 months. |
|  | Estimated Avg. Glucose | `mg/dL` | A calculated average of blood glucose based on HbA1c results. |
|  | HbF | `%` | A form of hemoglobin that is normal in infants but low in adults. |
| **Urine ACR** | Urine Albumin | `mg/L` | Small amounts of albumin in the urine, an early sign of kidney disease. |
|  | Urine Creatinine | `mg/dL` | Creatinine measured in a urine sample. |
|  | Albumin/Creatinine Ratio | - | The ratio of albumin to creatinine in the urine, used to detect kidney damage. |
| **Calcium & Phos** | Calcium | `mg/dL` | Important for bone health, muscle function, and nerve signaling. |
|  | Phosphorus | `mg/dL` | A mineral that works with calcium to build bones and teeth. |
| **Thyroid Profile** | Total T3 | `ng/dL` | One of the two main hormones produced by the thyroid gland. |
|  | Total T4 | `ug/dL` | The main hormone produced by the thyroid gland. |
|  | TSH | `uIU/mL` | Hormone from the pituitary gland that tells the thyroid to make T3 and T4. |
| **Glucose - Fasting** | Fasting Glucose | `mg/dL` | Blood sugar level measured after an 8-12 hour fast. |
| **Glucose - PP** | Postprandial Glucose | `mg/dL` | Blood sugar level measured 2 hours after a meal. |
| **Glucose (Diagnopath)** | FBS | `mg/dL` | Fasting Blood Sugar (Diagnostic specific). |
|  | PLBS | `mg/dL` | Post Lunch Blood Sugar (Diagnostic specific). |