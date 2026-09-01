# 🏛️ MedScan — System Design Document

## 1. Executive Summary

**MedScan** is a full-stack, AI-powered clinical report digitization and health intelligence platform. It bridges the gap between physical medical laboratory documents (paper printouts, scanned PDFs, screen captures) and structured longitudinal health datasets.

MedScan employs an **AI-driven Vision-Language pipeline (OpenAI GPT-4o Vision)** combined with **OpenCV computer vision preprocessing** to parse complex, multi-format medical laboratory reports. Extracted clinical parameters are validated, normalized against a standardized clinical data dictionary, mapped to a relational database, and served through interactive patient dashboards and a streaming conversational AI health assistant.

---

## 2. System Objectives & Design Principles

| Objective | Architectural Decision | Rationale |
| :--- | :--- | :--- |
| **High OCR Accuracy on Dense Tables** | Multi-Segment Content-Aware Page Splitting & CLAHE Preprocessing | Medical reports feature tight row spacing and small fonts. Splitting along horizontal whitespace gaps prevents OCR line skipping and token truncation. |
| **Zero Ingestion of Corrupted Data** | Human-in-the-Loop Verification & Multi-Layer Typo Correction | Clinical data demands 100% fidelity. Automated prefix autocorrect fixes common optical errors, while the verification UI allows user review before database commit. |
| **Longitudinal Trend Analytics** | Standardized 92-Column Staging Schema & Unit Conversion | Laboratory data from different clinics use disparate units (e.g., mg/dL vs. mmol/L). All measurements are normalized to standard units for unified time-series charting. |
| **Data Privacy & Security** | JWT Authentication, Patient Demographic Verification & Supabase RLS | Ensures reports belong to the verified account holder by cross-referencing NRIC/Passport, DOB, and Gender metadata extracted from the document. |
| **Developer Extensibility** | Dual-Engine Abstract Persistence (Supabase PostgreSQL + SQLite Fallback) | Facilitates zero-configuration local developer testing while offering production-ready cloud scalability. |

---

## 3. High-Level System Architecture

MedScan is organized into a modular **Client-Server Service Architecture** comprising a Flutter mobile/web client, a FastAPI asynchronous backend microservice, an OpenCV computer vision engine, an OpenAI Vision/LLM gateway, and a cloud relational database.

```mermaid
flowchart TB
    subgraph Client ["Flutter Mobile Client (iOS / Android / Web)"]
        UI_Capture["Camera / Gallery Image Picker"]
        UI_Verify["Verification & Correction Screen"]
        UI_Dashboard["Health Trends & Charting Dashboard"]
        UI_Chat["Streaming AI Health Assistant (SSE)"]
        UI_Dictionary["Standard Clinical Dictionary"]
    end

    subgraph Gateway ["API Gateway & Microservice (FastAPI)"]
        AUTH["Auth & JWT Token Service"]
        SCANNER["OpenCV Scanner & Preprocessing Engine"]
        SPLITTER["Content-Aware Whitespace Gap Splitter"]
        PARSER["GPT-4o Vision & PDF Extraction Gateway"]
        NORMALIZER["Autocorrect & Unit Normalizer"]
        DUP_ENGINE["Multi-Attribute Duplicate Detection Engine"]
        ANALYTICS["Layman Summary & RAG Streaming Engine"]
    end

    subgraph External_AI ["External AI Services"]
        OAI_VISION["OpenAI Vision API (GPT-4o)"]
        OAI_CHAT["OpenAI Chat Completions API"]
    end

    subgraph Storage ["Persistence Layer"]
        POSTGRES[("Supabase PostgreSQL (Production)")]
        SQLITE[("SQLite Database (Local Dev Fallback)")]
    end

    UI_Capture -->|Multipart Upload| SCANNER
    SCANNER --> SPLITTER
    SPLITTER --> PARSER
    PARSER <-->|Base64 Image Segments| OAI_VISION
    PARSER --> NORMALIZER
    NORMALIZER --> UI_Verify
    UI_Verify -->|Verified JSON Payload| DUP_ENGINE
    DUP_ENGINE -->|Transactional Insert| POSTGRES
    DUP_ENGINE -.->|Fallback Insert| SQLITE
    POSTGRES --> ANALYTICS
    ANALYTICS <-->|Clinical Context Prompt| OAI_CHAT
    ANALYTICS -->|Server-Sent Events| UI_Chat
    POSTGRES --> UI_Dashboard
```

---

## 4. End-to-End Data Processing Lifecycle

The lifecycle of a medical report follows six discrete phases:

```mermaid
sequenceDiagram
    autonumber
    actor User as Patient / Tester
    participant App as Flutter Mobile App
    participant API as FastAPI Backend
    participant CV as OpenCV Engine
    participant LLM as OpenAI GPT-4o
    participant DB as Supabase PostgreSQL

    User->>App: Capture / Select Report Photo
    App->>API: POST /api/upload-multi (Multipart Files)
    
    rect rgb(240, 248, 255)
        Note over API,CV: Phase 1: Computer Vision Preprocessing
        API->>CV: Detect Corners & Warp Perspective
        API->>CV: Remove Shadows & Equalize Contrast (CLAHE)
        API->>CV: Split Page at Horizontal Whitespace Gaps
    end

    rect rgb(255, 250, 240)
        Note over API,LLM: Phase 2: Vision OCR & Parameter Extraction
        API->>LLM: Pass Image Halves with Structured JSON Schema
        LLM-->>API: Return Structured Biomarker Key-Value Pairs
    end

    rect rgb(245, 255, 245)
        Note over API: Phase 3: Backend Normalization & Identity Validation
        API->>API: Autocorrect Qualitative Typos (Negative/Positive/Clear)
        API->>API: Standardize Dates (YYYY-MM-DD) & Times (HH:MM:SS)
        API->>API: Validate Name, Gender, DOB against Registered User Profile
    end

    API-->>App: Return MedicalReport Object with Validation Flags
    
    rect rgb(255, 245, 245)
        Note over User,App: Phase 4: Human-in-the-Loop Review
        App->>User: Display Unlocked Form Fields with Matched Units
        User->>App: Review / Modify Values & Tap "Send"
    end

    App->>API: POST /api/reports/{id}/send
    
    rect rgb(245, 245, 255)
        Note over API,DB: Phase 5: Duplicate Prevention & DB Persistence
        API->>API: Check Multi-Attribute Duplicate Criteria
        API->>DB: Upsert to 'reports' & 'staging_medical_records' (92 columns)
        API-->>App: Confirmation (200 OK)
    end

    rect rgb(255, 255, 240)
        Note over App,LLM: Phase 6: Health Analytics & RAG Chat
        App->>API: POST /api/reports/analyze/stream
        API->>DB: Query User Historical Biomarkers
        API->>LLM: Stream Prompt with Contextual Biomarker Matrix
        LLM-->>App: SSE Token-by-Token Markdown Stream
    end
```

---

## 5. Security & Multi-Tenant Isolation Model

### 5.1 Authentication & Token Lifecycle
* **Authentication Scheme**: Stateless JSON Web Tokens (JWT) signed using `HS256` with a configurable secret (`JWT_SECRET`) and a 30-day expiration window.
* **Password Hashing**: Passwords are encrypted using standard `bcrypt` with automatic salting.
* **Token Transport**: Clients transmit tokens via the `Authorization: Bearer <token>` HTTP header.
* **Offline Resilience**: Tokens and profile demographics are cached locally via `SharedPreferences`. The app validates tokens on startup via `/api/auth/me`, falling back gracefully to cached credentials if offline.

### 5.2 Patient Identity Verification Heuristics
To prevent accidental or unauthorized cross-patient report uploads in multi-user settings:
1. **Name Matching**: Tokenizes extracted report patient name and registered profile name. Normalizes case, removes salutations (Mr, Mrs, Dr), and computes Jaccard word-overlap. Flags mismatch if similarity $< 50\%$.
2. **Gender Matching**: Cross-references extracted gender against user profile (`Male`/`Female`). Flags mismatch on explicit discrepancy.
3. **Age & DOB Cross-Verification**: If Malaysian NRIC (`YYMMDD-PB-###G`) is detected on the report or user profile, the birth date is extracted and compared against the recorded Date of Birth.
4. **Tester Bypass Option**: A `force=true` query parameter allows developers and testers to intentionally bypass demographic mismatch blocks during development.

### 5.3 Row Level Security (RLS) & Supabase Access
* Supabase PostgreSQL tables (`users`, `reports`, `chat_sessions`, `chat_messages`, `staging_medical_records`) have **Row Level Security (RLS)** enabled.
* In accordance with Supabase Post-May 2026 standards, explicit permissions (`GRANT SELECT, INSERT, UPDATE, DELETE`) are granted to `anon`, `authenticated`, and `service_role` roles.
* API service queries enforce strict tenant separation by indexing and filtering every request by the authenticated `user_id`.

---

## 6. Fault Tolerance & Reliability Mechanisms

1. **Dual Storage Engine Fallback**: If cloud Supabase credentials are not configured or connection drops, the system seamlessly initializes a local SQLite database (`medical_reports.db`), ensuring continuous offline development and testing.
2. **HTTP/2 Connection Drop Protection**: Supabase edge gateways can terminate long-running multipart HTTP/2 connections. The backend explicitly configures `httpx.Client(http2=False, timeout=60.0)` for rock-solid HTTP/1.1 communication.
3. **Database Schema Auto-Healing**: When committing 92-column biomarker records to Postgres, string-to-numeric casting mismatches are caught dynamically. The backend catches PostgREST syntax error codes (`PGRST204`, `22P02`), isolates the conflicting column, strips non-numeric characters, and retries the transaction.
4. **Token-Aware Rate Limiting & Streaming**: AI health analysis queries stream responses via Server-Sent Events (SSE), reducing initial Time to First Byte (TTFB) to $< 800\text{ms}$.
