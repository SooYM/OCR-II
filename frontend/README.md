# MedScan Application

MedScan is a comprehensive medical report OCR and tracking application built with Flutter (Frontend) and Python (FastAPI Backend). It digitizes physical health reports, normalizes medical units, tracks patient health markers over time, and provides an interactive AI medical assistant.

## 🚀 Key Features

*   **Intelligent OCR Data Ingestion**: Uses advanced AI to parse physical blood test and urinalysis reports into structured digital data.
*   **Medical Unit Normalization**: Automatically converts international/SI units extracted from reports into standard US units for consistent database storage, regardless of the lab source.
*   **Verification Mismatch & Duplicate Bypass Flow**:
    *   Compares extracted report metadata (Name, Gender, IC, DOB) against the user's profile.
    *   On mismatch detection or duplication, shows detailed clinical flags and justifications.
    *   Provides a double-confirmation bypass dialog flow allowing patients to force upload/save reports if they insist.
*   **Privacy-Friendly Authentication & Optional Profile Data**:
    *   Allows users to choose "Prefer not to say" for both IC/NRIC number and Date of Birth (DOB) during registration.
    *   Includes inline disclaimers clarifying that verification data is strictly for report validation, and users have a legal/privacy right to skip them.
*   **Interactive Trend Analysis Dashboard**: 
    *   **Full-Screen Charting**: Visualizes health progress over time across multiple reports using discrete data point connections.
    *   **Dynamic Unit Switching**: Directly on the charts, users can toggle between units (e.g. `mg/dL` to `mmol/L`). The chart scales dynamically and retroactively converts all historical data points to the selected unit.
    *   **Visual Reference Bands**: The graphs overlay horizontal reference bands (High/Low) to easily visualize if historical results fall within healthy clinical ranges.
    *   **Chronological Data Logs**: A sleek scrollable interface allows users to review their exact test dates, values, and units, complete with automated highlighting for out-of-range results.
*   **ChatGPT-like AI Medical Assistant**:
    *   Integrated contextual AI chat for discussing medical reports.
    *   Features real-time token streaming, persistent session memory, and swipe-to-delete history management.
*   **Comprehensive Biomarker Dictionary**: Supports 93 distinct medical biomarkers (Lipid Profile, Glucose, Kidney Function, Liver Function, CBC, Thyroid, etc.), standard units, and clinical reference ranges.
*   **Terms & Conditions of Usage**: Built directly into settings, offering users full legal transparency on acceptance of terms, medical disclaimers, data collection & privacy policy, and mismatch flows.
*   **Modern Premium UI**: Built with glassmorphism cards, collapsible animated settings, responsive greetings, and sleek micro-animations for a premium healthcare experience.

## 🧬 Medical Unit Conversion System

The application uses a dual-layer conversion architecture to ensure clinical accuracy across the entire stack:

### 1. Backend OCR Normalization (`backend/unit_converter.py`)
When a document is scanned, the OCR engine may extract values in various international formats. The backend Python script intercepts these values and normalizes them to a single standard format before saving them to the database.
*   *Example: If OCR extracts `5.17 mmol/L` for Cholesterol, the backend converts and saves it as `200 mg/dL`.*

### 2. Frontend Bidirectional Conversion (`frontend/lib/utils/unit_converter.dart`)
When a user views their report or interacts with the trend graphs, they can change the displayed units via dropdown menus. The frontend Dart converter applies bidirectional math to automatically update UI values, historical plot points, and the reference range strings.
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

*   `frontend/lib/screens/main_screen.dart`: The core dashboard, interactive data graphing, and full-screen data point analysis logic.
*   `frontend/lib/screens/ai_chat_screen.dart`: Multi-turn persistent AI assistant interface.
*   `frontend/lib/utils/biomarker_dictionary.dart`: The source of truth for all 93 supported biomarkers, their standard units, allowed alternate units, and default reference ranges.
*   `frontend/lib/utils/unit_converter.dart`: The mathematical engine for frontend bidirectional conversions.
*   `backend/main.py`: The FastAPI backend handling OCR submission, database storage (SQLite/Supabase), and AI chat session management.
*   `backend/unit_converter.py`: The backend normalization script for OCR data ingestion.
