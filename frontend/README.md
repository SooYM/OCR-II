# MedScan Application

MedScan is a comprehensive medical report OCR and tracking application built with Flutter (Frontend) and Python (Backend). It digitizes physical health reports, normalizes medical units, and tracks patient health markers over time.

## 🚀 Key Features

*   **Intelligent OCR**: Uses AI to parse physical blood test and urinalysis reports into structured digital data.
*   **Medical Unit Normalization**: Automatically converts international/SI units extracted from reports into standard US units for consistent database storage.
*   **Dynamic UI Conversion**: The `VerifyScreen` allows users to dynamically toggle between US units (e.g., `mg/dL`) and SI units (e.g., `mmol/L`). The system recalculates both the **test value** and the **reference range** in real-time.
*   **Comprehensive Biomarker Dictionary**: Supports 93 distinct medical biomarkers including Lipid Profile, Glucose, Kidney Function, Liver Function, CBC, Iron Profile, Thyroid, and Urinalysis.
*   **Trend Analysis Dashboard**: Visualizes health progress over time across multiple reports.

## 🧬 Medical Unit Conversion System

The application uses a dual-layer conversion architecture to ensure clinical accuracy:

### 1. Backend OCR Normalization (`backend/unit_converter.py`)
When a document is scanned, the OCR engine may extract values in various international formats. The backend Python script intercepts these values and normalizes them to a single standard format before saving them to the database.
*   *Example: If OCR extracts `5.17 mmol/L` for Cholesterol, the backend converts and saves it as `200 mg/dL`.*

### 2. Frontend Bidirectional Conversion (`frontend/lib/utils/unit_converter.dart`)
When a user views their report, they can change the displayed units via dropdown menus. The frontend Dart converter applies bidirectional math to update both the UI value and the reference range string.
*   **Supported Non-Linear Conversions**: Includes complex formulas such as HbA1c (`%` ↔ `mmol/mol`).
*   **Smart Formatting**: Automatically strips trailing zeros and adjusts decimal precision based on the magnitude of the unit.

## 🧪 Testing

The unit conversion logic is fully covered by automated tests on both the frontend and backend.

**Run Frontend Tests (Dart):**
```bash
cd frontend
flutter test test/unit_converter_test.dart
```

**Run Backend Tests (Python):**
```bash
cd backend
python3 -c "from unit_converter import convert_unit; # (Test suite script)"
```

## 🛠 Project Structure

*   `frontend/lib/screens/verify_screen.dart`: UI logic for report validation and unit toggling.
*   `frontend/lib/utils/biomarker_dictionary.dart`: The source of truth for all 93 supported biomarkers, their standard units, allowed alternate units, and default reference ranges.
*   `frontend/lib/utils/unit_converter.dart`: The mathematical engine for frontend bidirectional conversions.
*   `backend/unit_converter.py`: The backend normalization script for OCR data ingestion.
