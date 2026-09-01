# 🧪 MedScan — Testing & Quality Assurance Manual

## 1. Overview

MedScan includes unit tests, widget tests, and integration verification workflows covering:
* Bidirectional unit conversion mathematical correctness across 92+ parameters.
* Qualitative typo autocorrection and fuzzy string matching.
* Date and time normalizer regex edge cases.
* OpenCV image preprocessing corner cases.
* FastAPI endpoint validation.

---

## 2. Running Flutter Tests

All Flutter unit and widget tests are located in `frontend/test/`.

### 2.1 Unit Converter & Biomarker Math Tests
Verifies conversion ratios for cholesterol, triglycerides, glucose, creatinine, electrolytes, HbA1c, and reference range transformations:
```bash
cd frontend
flutter test test/unit_converter_test.dart
```

### 2.2 Widget Smoke & Rendering Tests
Verifies UI bootstrap and view rendering:
```bash
flutter test test/widget_test.dart
```

### 2.3 Run Full Test Suite with Coverage
```bash
flutter test --coverage
```

---

## 3. Backend Verification Workflows

### 3.1 Python Syntax & Module Compilation
Ensure all backend modules compile without syntax errors:
```bash
python3 -m py_compile backend/main.py backend/unit_converter.py backend/services/scanner/*.py
```

### 3.2 Automated Endpoint Health Check
Verify that the FastAPI service boots and responds:
```bash
curl -i http://localhost:8000/
```
Expected response:
```http
HTTP/1.1 200 OK
content-type: application/json

{"status":"online","service":"Medical Report Digitization API","version":"2.0.0"}
```

---

## 4. Manual Verification & Test Protocol

When testing new medical report templates or camera captures, follow this verification checklist:

1. **Illumination & Alignment Test**:
   - Capture a photo with a shadow cast across the lower half.
   - Verify that `enhance_color` removes the shadow gradient and renders a clean white background.
2. **Horizontal Row-Gap Splitting Test**:
   - Upload a dense 40-row full blood count report.
   - Inspect backend logs for `[SPLITTER] Found best split at y=...` to ensure splitting occurred in a whitespace gap rather than cutting across a line of text.
3. **Typo Correction Test**:
   - On the verification screen, edit a urinalysis protein field to `"negativ"`, `"potisive"`, or `"tras"`.
   - Unfocus the field; verify that it immediately normalizes to `"Negative"`, `"Positive"`, or `"Trace"`.
4. **Duplicate Prevention Test**:
   - Finalize a report and click "Send".
   - Upload the exact same report image again.
   - Verify that the duplicate warning modal is presented and database commit prevents duplicate staging rows.
5. **Streaming Chat Test**:
   - Open AI Health Assistant.
   - Send: `"What are my abnormal parameters?"`.
   - Verify that markdown tokens stream in real-time without UI freezes or socket disconnects.
