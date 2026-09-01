# 🔌 MedScan — REST API Reference Manual

## 1. Overview & Authentication Standard

The MedScan backend exposes a RESTful HTTP microservice built on FastAPI.
* **Base URL**: Configurable (e.g. `http://localhost:8000` or production reverse proxy `/backend`).
* **Content-Type**: `application/json` for standard queries; `multipart/form-data` for file uploads; `text/event-stream` for SSE streaming.
* **Authentication**: Secured endpoints require a JWT bearer token passed in the `Authorization` header:
  ```http
  Authorization: Bearer <jwt_token>
  ```

---

## 2. Authentication Endpoints

### 2.1 Register New User
* **Method & Path**: `POST /api/auth/register`
* **Description**: Creates a new user profile with medical demographic baselines.
* **Request Payload**:
  ```json
  {
    "email": "jane.doe@example.com",
    "name": "Jane Doe",
    "password": "SecurePassword123!",
    "gender": "Female",
    "dob": "1992-08-24",
    "ic_number": "920824-10-5678"
  }
  ```
* **Success Response (`200 OK`)**:
  ```json
  {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": "e4a2bc1d-28ab-4001-ba13-432890efba12",
      "email": "jane.doe@example.com",
      "name": "Jane Doe",
      "gender": "Female",
      "dob": "1992-08-24",
      "ic_number": "920824-10-5678",
      "status": "active"
    }
  }
  ```
* **Error Response (`400 Bad Request`)**: `{"detail": "Email already registered"}`

---

### 2.2 User Login
* **Method & Path**: `POST /api/auth/login`
* **Description**: Verifies credentials and issues a 30-day JWT bearer token.
* **Request Payload**:
  ```json
  {
    "email": "jane.doe@example.com",
    "password": "SecurePassword123!"
  }
  ```
* **Success Response (`200 OK`)**:
  ```json
  {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": "e4a2bc1d-28ab-4001-ba13-432890efba12",
      "email": "jane.doe@example.com",
      "name": "Jane Doe",
      "gender": "Female",
      "dob": "1992-08-24",
      "ic_number": "920824-10-5678"
    }
  }
  ```

---

### 2.3 Get Current Profile
* **Method & Path**: `GET /api/auth/me`
* **Headers**: `Authorization: Bearer <token>`
* **Success Response (`200 OK`)**: Returns current user object.

---

### 2.4 Update Profile Settings
* **Method & Path**: `PUT /api/auth/profile`
* **Headers**: `Authorization: Bearer <token>`
* **Request Payload**:
  ```json
  {
    "name": "Jane Doe Updated",
    "email": "jane.new@example.com"
  }
  ```
* **Success Response (`200 OK`)**: `{"status": "success", "user": { ... }}`

---

## 3. OCR & Image Preprocessing Endpoints

### 3.1 Single Image Upload & Extraction
* **Method & Path**: `POST /api/upload`
* **Content-Type**: `multipart/form-data`
* **Query Parameters**: `force` (bool, default `false`) — Set `true` to override identity mismatch warnings.
* **Form Data**: `file` (Binary Image File: `.png`, `.jpg`, `.jpeg`, `.pdf`)
* **Success Response (`200 OK`)**: Returns a `MedicalReport` object containing extracted structured biomarker data.

---

### 3.2 Multi-Page Report Ingestion
* **Method & Path**: `POST /api/upload-multi`
* **Content-Type**: `multipart/form-data`
* **Query Parameters**: `force` (bool, default `false`)
* **Form Data**: `files` (Array of Binary Image Files)
* **Description**: Processes all pages with OpenCV whitespace gap splitting, invokes multi-segment Vision OCR, merges parameters across pages, standardizes units, and returns the unified medical report.

---

### 3.3 Scanner Preprocessing (CamScanner Effect)
* **Method & Path**: `POST /api/scanner/preprocess`
* **Content-Type**: `multipart/form-data`
* **Query Parameters**: `mode` (`"color"` or `"bw"`, default `"color"`)
* **Form Data**: `image` (Binary Image File)
* **Success Response (`200 OK`)**:
  ```json
  {
    "success": true,
    "processed_image_url": "/uploads/processed_abc123.jpg",
    "server_filepath": "/var/www/backend/uploads/processed_abc123.jpg",
    "metadata": {
      "corners_detected": true,
      "original_size": [1920, 1080],
      "processed_size": [1800, 1050]
    }
  }
  ```

---

## 4. Report Management Endpoints

### 4.1 Get User Reports
* **Method & Path**: `GET /api/reports/my`
* **Headers**: `Authorization: Bearer <token>`
* **Success Response (`200 OK`)**: Array of `MedicalReport` JSON objects for the authenticated user.

---

### 4.2 Update Report Data (Verification Save)
* **Method & Path**: `PUT /api/reports/{report_id}`
* **Headers**: `Authorization: Bearer <token>`
* **Query Parameters**: `force` (bool, default `false`)
* **Request Payload**:
  ```json
  {
    "structured_data": {
      "patient_name": "JANE DOE",
      "date": "2026-05-12",
      "results": [
        {
          "test_item": "Total Cholesterol",
          "value": "185",
          "unit": "mg/dL",
          "key": "total_cholesterol_mg_dl"
        }
      ]
    }
  }
  ```
* **Success Response (`200 OK`)**: `{"status": "success", "report": { ... }}`

---

### 4.3 Send & Finalize Report (Commit to Staging DB)
* **Method & Path**: `POST /api/reports/{report_id}/send`
* **Headers**: `Authorization: Bearer <token>`
* **Description**: Performs final multi-attribute duplicate detection, marks `user_verified = 1`, and persists all 92 normalized biomarker fields into `staging_medical_records`.
* **Success Response (`200 OK`)**: `{"status": "success", "message": "Report finalized and recorded"}`

---

### 4.4 Delete Report
* **Method & Path**: `DELETE /api/reports/{report_id}`
* **Headers**: `Authorization: Bearer <token>`
* **Success Response (`200 OK`)**: `{"status": "success"}`

---

## 5. Health Analytics & Conversational RAG Endpoints

### 5.1 Layman Health Summary
* **Method & Path**: `GET /api/reports/health-summary`
* **Headers**: `Authorization: Bearer <token>`
* **Description**: Generates or retrieves cached accessible AI health summary of latest biomarker profiles.
* **Success Response (`200 OK`)**: `{"summary": "Your lipid profile is within optimal limits..."}`

---

### 5.2 Streaming AI Chat Assistant (SSE)
* **Method & Path**: `POST /api/reports/analyze/stream`
* **Headers**: `Authorization: Bearer <token>`, `Content-Type: application/json`
* **Request Payload**:
  ```json
  {
    "query": "How has my fasting glucose changed over the past 6 months?",
    "session_id": "8bfa2e41-c1e0-47b2-bd74-129840afcd5e",
    "start_date": "2025-11-01",
    "end_date": "2026-05-01",
    "messages": [
      {"role": "user", "content": "What is my cholesterol?"},
      {"role": "assistant", "content": "Your total cholesterol is 185 mg/dL."}
    ]
  }
  ```
* **Response Protocol**: `text/event-stream`
  ```http
  data: {"token": "Based"}

  data: {"token": " on"}

  data: {"token": " your"}

  data: {"token": " recent"}

  data: [DONE]
  ```

---

### 5.3 Chat Session Lifecycle Endpoints
* **Create Session**: `POST /api/chat/sessions` (Body: `{"title": "Blood Pressure Discussion"}`)
* **List Sessions**: `GET /api/chat/sessions`
* **Get Session Messages**: `GET /api/chat/sessions/{session_id}/messages`
* **Delete Session**: `DELETE /api/chat/sessions/{session_id}`
