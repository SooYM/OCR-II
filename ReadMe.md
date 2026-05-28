# 🩺 MedScan — Medical Report Digitization & Health Analytics

A premium, production-grade, full-stack healthcare dashboard and medical report digitizer. MedScan utilizes AI-powered computer vision (OpenAI Vision API) to extract structured clinical data from scanned blood, urine, and physiological reports, normalizes multi-source lab measurements, tracks and visualizes biomarker trends, and delivers personalized, context-aware AI health insights.

---

## 📖 Table of Contents
1. [System Architecture & Data Flow](#-system-architecture--data-flow)
2. [Database Architecture & Security Layout](#-database-architecture--security-layout)
3. [Core Engines & Pipeline Mechanics](#-core-engines--pipeline-mechanics)
   - [Content-Aware Image Splitting](#1-content-aware-image-splitting)
   - [OpenCV Image Preprocessing](#2-opencv-image-preprocessing)
   - [Robust Autocorrect & Typo Normalization](#3-robust-autocorrect--typo-normalization)
   - [Smart Duplicate Prevention Engine](#4-smart-duplicate-prevention-engine)
   - [24h Time & Date Normalization](#5-24h-time--date-normalization)
4. [API Reference Manual](#-api-reference-manual)
5. [Frontend Architecture & UI Flow](#-frontend-architecture--ui-flow)
6. [Installation & Deployment Guide](#-installation--deployment-guide)
7. [OCR Capture & Scanning Guidelines](#-ocr-capture--scanning-guidelines)
8. [Standardized Medical Data Dictionary](#-standardized-medical-data-dictionary)
9. [Troubleshooting & Support](#-troubleshooting--support)

---

## 🏗️ System Architecture & Data Flow

MedScan is built as a split-responsibility client-server system consisting of a **Flutter mobile client** and a **FastAPI backend microservice**, integrated with a secure **Supabase PostgreSQL** cloud database (or a local SQLite fallback for testing).

```
 ┌────────────────────────────────────────────────────────────────────────────────┐
 │                              FLUTTER MOBILE CLIENT                             │
 └────────────────────────────────────────────────────────────────────────────────┘
        │ (Capture Photo / Gallery Select)
        ▼
 ┌────────────────────────────────────────────────────────────────────────────────┐
 │                               FASTAPI BACKEND                                  │
 ├────────────────────────────────────────────────────────────────────────────────┤
 │ 1. Image Preprocessing (OpenCV CLAHE, Illumination Correction)                 │
 │ 2. Content-Aware Splitting (Whitespace Gap Alignment)                          │
 │ 3. OpenAI Vision API (Multi-Segment GPT-4o OCR Execution)                      │
 │ 4. Backend Autocorrection & Time/Date Normalization                            │
 │ 5. Identity Verification (Checks user NRIC/DOB/Gender against Patient metadata)│
 │ 6. Duplicate Engine (Fuzzy date, lab ID & signature overlap checking)          │
 └────────────────────────────────────────────────────────────────────────────────┘
        │
        ├──────────────────────┬────────────────────────┐
        ▼ (Supabase JSON/SQL)  ▼ (Local Test Fallback)  ▼ (API Gateway)
 ┌───────────────┐      ┌───────────────┐        ┌───────────────┐
 │   SUPABASE    │      │  SQLITE LOCAL │        │  OPENAI API   │
 │  POSTGRESQL   │      │     DB        │        │   (GPT-4o)    │
 └───────────────┘      └───────────────┘        └───────────────┘
```

### Complete End-to-End Data Pipeline Flow:
1. **Image Selection & Optimization**: The mobile client compresses captured images and posts them to the backend API (`/api/upload`).
2. **Vision Extraction**: The backend splits pages, enhances contrast, and passes segment blocks to OpenAI Vision.
3. **Typo Correction & Validation**: The backend filters structural outputs, applies `backend_autocorrect_typo` to standardize qualitative results, and returns the unified payload to the client.
4. **Human-in-the-Loop Review**: The user inspects data in the **Verify Data** screen. Unverified parameters are fully editable without modal lockups.
5. **Database Commit**: Upon clicking "Send", the client pushes the verified structure (`/api/reports/{id}`). The backend performs a final duplicate analysis, persists the document to the `reports` table, and feeds the biomarker values to the 92-column `staging_medical_records` clinical data table.

---

## 🗄️ Database Architecture & Security Layout

MedScan supports dual storage engines configured via the `STORAGE_ENGINE` environment variable: **Supabase PostgreSQL** (production) and **SQLite** (local development).

### 1. Supabase PostgreSQL Entity-Relationship Schema

The database is structured to separate report document assets from clean clinical measurements, facilitating fast timeseries lookups.

#### A. Users Table (`users`)
Stores user profiles, demographic details used for OCR report owner matches, and cached AI medical insights.
```sql
CREATE TABLE users (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email          TEXT UNIQUE NOT NULL,
    name           TEXT NOT NULL,
    gender         TEXT, -- Normalised to "Male" or "Female"
    dob            DATE, -- Normalized Date of Birth
    ic_number      TEXT, -- Normalised Identity Card / NRIC / Passport
    password_hash  TEXT NOT NULL,
    status         TEXT NOT NULL DEFAULT 'active',
    health_summary TEXT, -- Cached markdown summary
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_users_email ON users (email);
```

#### B. Reports Table (`reports`)
Stores the raw parsed payload from OpenAI, file upload reference locations, and confirmation states.
```sql
CREATE TABLE reports (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID REFERENCES users(id) ON DELETE CASCADE,
    filename         TEXT NOT NULL,
    upload_time      TIMESTAMPTZ NOT NULL DEFAULT now(),
    status           TEXT NOT NULL DEFAULT 'processing',
    raw_text         TEXT,
    structured_data  JSONB, -- Entire parsed nested dictionary
    user_verified    INTEGER DEFAULT 0, -- Toggled to 1 after user saves
    file_path        TEXT
);
CREATE INDEX idx_reports_user_id ON reports (user_id);
```

#### C. Staging Medical Records (`staging_medical_records`)
A 92-column table designed for structured analysis. Every column represents a standardized biomarker (e.g. `total_cholesterol_mg_dl` as `DOUBLE PRECISION`, `urine_colour` as `TEXT`). It links back to `reports` via a cascade-deleting foreign key.
```sql
CREATE TABLE staging_medical_records (
    report_id                  UUID PRIMARY KEY REFERENCES reports(id) ON DELETE CASCADE,
    medid                      BIGINT, -- Normalised Patient ID / NRIC digits
    original_medid             TEXT,
    labreference               TEXT, -- Specimen Sample ID
    original_labreference      TEXT,
    report_reference           TEXT, -- Episode / Accession No
    lab                        TEXT, -- Clinic / Lab Location
    collected                  DATE,
    time                       TIME,
    reported_time              TIME,
    gender                     TEXT,
    -- ... Urinalysis, CBC, Lipids, Liver, Kidney, Thyroid, HbA1c, Urine ACR, Iron profiles ...
    total_cholesterol_mg_dl    DOUBLE PRECISION,
    wbc_cells_ul               BIGINT,
    urine_colour               TEXT,
    ph                         DOUBLE PRECISION
);
```

### 2. Supabase Post-May 2026 Explicit API Grant Standards
To comply with Supabase's strict API exposure rules (effective May 30, 2026), explicit access privileges must be granted to the `anon`, `authenticated`, and `service_role` roles for all newly created tables. The project setup queries execute the following explicit grants:
```sql
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- Grant API mapping privileges
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE users TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE reports TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE staging_medical_records TO anon, authenticated, service_role;

-- Simple security policies (Production environments should restrict USING clauses based on authenticated JWT claims)
CREATE POLICY "Server bypass for users" ON users FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Server bypass for reports" ON reports FOR ALL USING (true) WITH CHECK (true);
```

---

## ⚙️ Core Engines & Pipeline Mechanics

### 1. Content-Aware Image Splitting (`splitter.py`)
To prevent token bloat while boosting vision recognition accuracy for small-font text grids, high-resolution pages are split into halves dynamically:
* **Projection Binarization**: The page is binarized using Otsu's thresholding. Pixels are summed horizontally across the page row-by-row to construct a **Horizontal Projection Profile**.
* **Whitespace Identification**: The engine scans the middle 70% of the image height to locate continuous zero-sum row bands, indicating spaces between clinical rows.
* **Smart Midpoint Slicing**: Rather than cut mathematically in half (which could split a row of letters in two), the engine identifies the whitespace gap closest to the true vertical center and cuts there.
* **3% Overlap Padding**: An overlap boundary of 3% is added to each slice to guarantee that text at the cut edge remains fully legible in at least one image block.

### 2. OpenCV Image Preprocessing (`enhancer.py`)
Environmental scanning variables (camera angles, shadow gradients, page folds) are normalized prior to OCR:
* **Illumination Correction**: Background color maps are calculated by applying a large OpenCV morphological dilation followed by a median blur (using a 21x21 kernel). Dividing the raw image by this background mask eliminates page shadows and renders a clean white backdrop.
* **CLAHE Contrast Adjustment**: Contrast Limited Adaptive Histogram Equalization is applied to amplify ink definition without blowing out thin lines.
* **Proportional Upscaling**: If an image segment height is smaller than 800px, it is upscaled proportionally using `INTER_CUBIC` interpolation to protect character edge sharpness during GPT-4o ingestion.

### 3. Robust Autocorrect & Typo Normalization
Medical reports contain highly specific qualitative results that are frequently misspelled by OCR engines or typed incorrectly by users. Both the **Flutter frontend** and **FastAPI backend** implement a standardized case-insensitive prefix-matching parser:

#### Typo Matching Matrix:
| Target Standard | Match Rules / Case-Insensitive Prefixes | Typical Typos Corrected |
|-----------------|------------------------------------------|--------------------------|
| **Negative**    | Starts with `neg`, `nag`, `nege`, or equals `nil` | `negativ`, `nege`, `nagative`, `nil` |
| **Positive**    | Starts with `pos`, `pot`, or equals `cloudy` | `posti`, `postiv`, `potisive`, `cloudy` |
| **Trace**       | Starts with `trac` or `tras` | `trac`, `trace`, `tras` |
| **Clear**       | Starts with `clea` or equals `cleari` | `clea`, `cleari`, `clear` |

#### A. Backend Implementation (`backend/main.py`)
Automatically normalizes qualitative values parsed by OpenAI Vision *before* they are returned in API JSON response payloads:
```python
def backend_autocorrect_typo(val_str: str) -> str:
    if not val_str:
        return val_str
    trimmed = val_str.strip()
    lower = trimmed.lower()
    
    if lower.startswith('neg') or lower.startswith('nag') or lower.startswith('nege') or lower == 'nil':
        return 'Negative'
    if lower.startswith('pos') or lower.startswith('pot') or lower == 'cloudy':
        return 'Positive'
    if lower.startswith('trac') or lower.startswith('tras'):
        return 'Trace'
    if lower.startswith('clea') or lower == 'cleari':
        return 'Clear'
        
    return trimmed
```

#### B. Frontend Implementation (`frontend/lib/screens/verify_screen.dart`)
Corrects manual user input in the value fields instantly when the text field loses focus (`onFocusLost` listener) or when the final "Send" button is tapped:
```dart
String _autoCorrectTypo(String input) {
  final trimmed = input.trim();
  final lower = trimmed.toLowerCase();
  
  if (lower.startsWith('neg') || lower.startsWith('nag') || lower.startsWith('nege') || lower == 'nil') {
    return 'Negative';
  }
  if (lower.startsWith('pos') || lower.startsWith('pot') || lower == 'cloudy') {
    return 'Positive';
  }
  if (lower.startsWith('trac') || lower.startsWith('tras')) {
    return 'Trace';
  }
  if (lower.startsWith('clea') || lower == 'cleari') {
    return 'Clear';
  }
  return input;
}
```

### 4. Smart Duplicate Prevention Engine
To maintain high clinical dataset integrity, uploading reports that contain identical biomarker data points is blocked. Before saving, the backend parses incoming structured data against the user's historical reports using a multi-layered check:
* **Unit Standardization**: The engine reads standard biomarker configurations (from `get_standard_unit_for_key(key)`) and normalizes incoming values using `convert_unit` before comparison.
* **2% Numeric Tolerance**: Standard numeric floats are compared. If they differ by $\le 2\%$, they are treated as matching to prevent duplicate records arising from minor conversion rounding differences.
* **Multi-Attribute Matching Matrix**:
  1. **Criteria 1 (Explicit Report ID)**: Cleaned alphanumeric `report_reference` matches exactly.
  2. **Criteria 1B (Explicit Specimen ID)**: Cleaned alphanumeric `labreference` matches exactly.
  3. **Criteria 2 (Clinical Signature Match)**: $\ge 3$ biomarker keys match with $\ge 90\%$ value identity, regardless of report date.
  4. **Criteria 3 (Non-contradicting Overlap)**: $\ge 2$ biomarker keys match with $100\%$ value identity, and dates/patient IDs do not explicitly contradict.
  5. **Criteria 4 (Same-Day Match)**: Identical collection date, matching Patient ID (`medid`), and $\ge 80\%$ biomarker matches.
  6. **Criteria 5 (Fuzzy Date Match)**: Collection dates are within $\pm 2$ days, Patient ID matches, and $\ge 80\%$ biomarkers are identical.

### 5. 24h Time & Date Normalization
* **Date Stripping**: Strips time suffixes (e.g. `12/04/2026 11:30 AM` $\rightarrow$ `12/04/2026`), cleans variable separators (`/`, `-`, `.`), maps English month names (`May`, `Jan`) to standard integer representations, and formats to `YYYY-MM-DD`.
* **Time Normalization**: Handles short-digit notation (e.g. `1430` $\rightarrow$ `14:30:00`, `930` $\rightarrow$ `09:30:00`), normalizes 12h AM/PM suffixes to standard 24h intervals (e.g. `02:30 PM` $\rightarrow$ `14:30:00`), and falls back to clean outputs.

---

## 🔌 API Reference Manual

All backend responses return standard HTTP status codes. Secured endpoints require a JWT bearer token passed in the `Authorization` header: `Bearer <token>`.

### 1. User Registration
* **Endpoint**: `POST /api/auth/register`
* **Content-Type**: `application/json`
* **Request Payload**:
  ```json
  {
    "email": "user@example.com",
    "name": "John Doe",
    "password": "StrongPassword123!",
    "gender": "Male",
    "dob": "1990-05-15",
    "ic_number": "900515-14-5678"
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "id": "e4a2bc1d-28ab-4001-ba13-432890efba12",
    "email": "user@example.com",
    "name": "John Doe",
    "gender": "Male",
    "dob": "1990-05-15",
    "ic_number": "900515-14-5678",
    "created_at": "2026-05-28T10:53:19.482Z"
  }
  ```

### 2. User Login
* **Endpoint**: `POST /api/auth/login`
* **Content-Type**: `application/json`
* **Request Payload**:
  ```json
  {
    "email": "user@example.com",
    "password": "StrongPassword123!"
  }
  ```
* **Success Response (200 OK)**:
  ```json
  {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "token_type": "bearer",
    "user": {
      "id": "e4a2bc1d-28ab-4001-ba13-432890efba12",
      "email": "user@example.com",
      "name": "John Doe",
      "gender": "Male",
      "dob": "1990-05-15",
      "ic_number": "900515-14-5678"
    }
  }
  ```

### 3. Upload Multi-Page Report (OCR Pipeline)
* **Endpoint**: `POST /api/upload-multi`
* **Content-Type**: `multipart/form-data`
* **Query Parameters**: `force` (bool, default `false` - set to `true` to override name/gender validation mismatches)
* **Body Form Parameters**: `files` (Array of binary image files)
* **Success Response (200 OK)**:
  ```json
  {
    "id": "8bfa2e41-c1e0-47b2-bd74-129840afcd5e",
    "filename": "page1.png, page2.png",
    "upload_time": "2026-05-28T10:55:00.124Z",
    "status": "completed",
    "structured_data": {
      "patient_name": "JOHN DOE",
      "patient_id": "900515145678",
      "date": "2026-05-10",
      "time": "08:30:00",
      "reported_time": "14:15:00",
      "gender": "Male",
      "test_name": "Full Blood Count & Lipid Profile",
      "doctor_name": "Dr. Sarah Connor",
      "hospital_name": "City Pathology Center",
      "notes": "Patient was fasting for 12 hours.",
      "results": [
        {
          "test_item": "Total Cholesterol",
          "value": "195",
          "unit": "mg/dL",
          "key": "total_cholesterol_mg_dl"
        },
        {
          "test_item": "Proteins",
          "value": "Negative",
          "unit": "mg/dL",
          "key": "proteins"
        }
      ]
    },
    "user_verified": false,
    "raw_text": "Extracted via OpenAI Vision API (2 page(s))"
  }
  ```

* **Validation Mismatch Response (200 OK with specific status)**:
  If the name or gender extracted from the report does not match the registered user profile details, it will flag a warning:
  ```json
  {
    "id": "8bfa2e41-c1e0-47b2-bd74-129840afcd5e",
    "filename": "page1.png",
    "upload_time": "2026-05-28T10:55:00.124Z",
    "status": "name_mismatch",
    "is_name_mismatch": true,
    "is_gender_mismatch": false,
    "is_age_mismatch": false,
    "is_duplicate": false,
    "structured_data": { ... },
    "user_verified": false
  }
  ```

---

## 📱 Frontend Architecture & UI Flow

The mobile interface is written in **Flutter (Dart)**. It uses a custom **Glassmorphism design language** consisting of translucent widgets, linear color gradients, and dynamic background blurs.

### 1. View-Mode & Verification Logic Flow (`verify_screen.dart`)
The screen utilizes a conditional modal lock depending on whether the report has already been reviewed:
* **Fresh Upload/Scan (`report.userVerified == false`)**:
  - The UI runs in **Unlocked Editing Mode**.
  - All text boxes are immediately interactive text input forms.
  - The edit icon is hidden to signify that edits do not require confirmation.
  - TYPO correction is automatically applied to qualitative inputs when the focus leaves the field.
* **Verified History Report (`report.userVerified == true`)**:
  - The UI runs in **Locked Read-Only Mode**.
  - Text fields are disabled. Clicking a field does nothing.
  - A pencil edit icon (`Icons.edit_outlined`) is rendered next to the field.
  - Tapping the pencil displays a material dialog prompt: `Are you sure you want to edit [Field Name]?`.
  - Upon user confirmation, only that specific input box is unlocked for editing.

### 2. Dynamic Password Strength Meter (`auth_screen.dart`)
During user registration, the password input dynamically updates its style according to strength rules:
* **Rules**: Must be at least 8 characters long, contain at least one uppercase letter, one number, and one special character (e.g. `!`, `@`, `#`).
* **Visual States**: An active text controller listener monitors input in real time. If the criteria are not met, the input border color, label style, and helper error text are colored **red**. As soon as the criteria are satisfied, the styling immediately reverts to standard theme colors.

---

## 🚀 Installation & Deployment Guide

### System Dependencies
Ensure the host system has **Python 3.10+**, **CMake**, and **C compiler tools** (required to compile OpenCV `cv2` extensions).

### 1. Backend Service Setup
```bash
# Clone the repository
cd OCR-II/backend

# Create a virtual environment
python3 -m venv venv
source venv/bin/activate

# Install requirements
pip install --upgrade pip
pip install -r requirements.txt

# Create your local environment file
cp .env.template .env
```

#### Environment Variables Configuration (`.env`):
```ini
PORT=8000
STORAGE_ENGINE=supabase  # or 'sqlite'
OPENAI_API_KEY=your-openai-api-key
OPENAI_MODEL=gpt-4o

# Required if STORAGE_ENGINE=supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-supabase-service-role-key

# Security
JWT_SECRET=your-secure-jwt-random-string
```

Run backend server:
```bash
python3 -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### 2. Frontend Flutter Setup
Make sure you have the Flutter SDK configured on your path (`flutter --version` $\ge$ 3.10).
```bash
cd ../frontend

# Install packages
flutter pub get

# Run on connected simulator or device
flutter run
```

---

## 📷 OCR Capture & Scanning Guidelines

To ensure the OpenAI Vision parsing pipeline yields optimal results, instruct users to adhere to these imaging guidelines:
1. **Vertical Document Alignment (Strict)**: Images must be scanned **right-side up**. Rotating the document by $90^\circ$ or $180^\circ$ causes letter alignment extraction errors, which will result in data parsing failures.
2. **Homogeneous Illumination**: Minimize light hotspots, shadow blocks, and camera reflections.
3. **Flatness & Wrinkle Removal**: Smooth paper folds to avoid skewed row text.

---

## 📖 Standardized Medical Data Dictionary

| Profile Profile / Category | Parameter Key | Target Unit | Field Type |
|-------------------|---------------|-------------|------------|
| **Urinalysis** | `urine_colour` | - | `TEXT` |
| | `appearance` | - | `TEXT` |
| | `specific_gravity` | - | `DOUBLE PRECISION` |
| | `ph` | - | `DOUBLE PRECISION` |
| | `proteins` | `mg/dL` | `TEXT` |
| | `glucose` | - | `TEXT` |
| | `bilirubin` | - | `TEXT` |
| | `ketones` | - | `TEXT` |
| | `blood` | - | `TEXT` |
| | `urobilinogen` | `EU/dL` | `TEXT` |
| | `nitrites` | - | `TEXT` |
| | `wbc_pus_cells_hpf` | `/HPF` | `TEXT` |
| | `rbc` | `/HPF` | `TEXT` |
| | `epithelial_cells_hpf`| `/HPF` | `TEXT` |
| **Complete Blood Count** | `hemoglobin_g_dl` | `g/dL` | `DOUBLE PRECISION` |
| | `rbc_count_mil_ul` | `mil/uL` | `DOUBLE PRECISION` |
| | `hematocrit_pct` | `%` | `DOUBLE PRECISION` |
| | `mcv_fl` | `fL` | `DOUBLE PRECISION` |
| | `mch_pg` | `pg` | `DOUBLE PRECISION` |
| | `mchc_g_dl` | `g/dL` | `DOUBLE PRECISION` |
| | `wbc_cells_ul` | `cells/uL` | `BIGINT` |
| **Lipid Profile** | `total_cholesterol_mg_dl` | `mg/dL` | `DOUBLE PRECISION` |
| | `hdl_mg_dl` | `mg/dL` | `DOUBLE PRECISION` |
| | `ldl_mg_dl` | `mg/dL` | `DOUBLE PRECISION` |
| | `triglycerides_mg_dl` | `mg/dL` | `DOUBLE PRECISION` |
| **Liver Function** | `alp_u_l` | `U/L` | `DOUBLE PRECISION` |
| | `alt_sgpt_u_l` | `U/L` | `DOUBLE PRECISION` |
| | `ast_sgot_u_l` | `U/L` | `DOUBLE PRECISION` |
| | `protein_total_g_dl` | `g/dL` | `DOUBLE PRECISION` |
| **Kidney Function** | `creatinine_mg_dl` | `mg/dL` | `DOUBLE PRECISION` |
| | `urea_mg_dl` | `mg/dL` | `DOUBLE PRECISION` |
| | `egfr_ml_min_173m2` | `mL/min/1.73m²` | `DOUBLE PRECISION` |
| **Thyroid Profile** | `tsh_uiu_ml` | `uIU/mL` | `DOUBLE PRECISION` |

---

## 🔍 Troubleshooting & Support

#### 1. `ModuleNotFoundError: No module named 'cv2'`
* **Cause**: OpenCV is not installed or not built correctly within your active virtual environment.
* **Solution**: Ensure your virtual environment is active (`source venv/bin/activate`) and run `pip install opencv-python-headless`. The `-headless` package is recommended for servers to avoid GUI system library dependency issues.

#### 2. Supabase `ConnectionTerminated` Errors on Long Requests
* **Cause**: HTTP/2 multiplexing dropouts between the client and Supabase Edge endpoints.
* **Solution**: In `backend/main.py`, a custom HTTP client configuration uses `http2=False` to force stable HTTP/1.1 connections:
  ```python
  httpx_client = httpx.Client(http2=False, timeout=httpx.Timeout(30.0, read=60.0))
  ```

#### 3. Supabase API Mismatch Errors (`PGRST204` or `22P02`)
* **Cause**: PostgREST fails to insert custom columns or string values into strict database fields (such as text values like "Negative" in double precision columns).
* **Solution**: The backend `mark_report_sent` includes a retry correction loop. It captures Postgres error syntax patterns, automatically identifies the failing key, cleans ranges (extracts numerical floats from ranges or symbols), or nullifies fields to prevent crashes and ensure data persistence.

---