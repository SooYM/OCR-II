"""
Medical Report Digitization API
Prototype backend — OCR processing, LLM parsing, BigQuery/SQLite storage.
JWT authentication. Designed for tester flow: Login → Snap → Verify → Send.
"""

import os
import uuid
import json
import re
import sqlite3
import base64
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Optional, Dict, Any, List as TypingList
import cv2
import numpy as np

from fastapi import FastAPI, UploadFile, File, HTTPException, Depends, Header, Request, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import aiofiles
import bcrypt
import jwt
from PIL import Image
from dotenv import load_dotenv
from openai import OpenAI
from supabase import create_client, Client

from unit_converter import convert_unit
from services.scanner.pipeline import DocumentScanner
from services.scanner.splitter import split_image_at_gap
from services.scanner.enhancer import upscale_if_small

# Google Cloud Dependencies
try:
    from google.cloud import vision
    HAS_GCP = True
except ImportError:
    HAS_GCP = False

# ─── Configuration ──────────────────────────────────────────────────────────

load_dotenv()

app = FastAPI(
    title="Medical Report Digitization API",
    description="Simplified prototype — OCR + LLM medical report processing",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

STORAGE_ENGINE = os.getenv("STORAGE_ENGINE", "supabase").lower()
GCP_PROJECT_ID = os.getenv("GCP_PROJECT_ID")

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o")

JWT_SECRET = os.getenv("JWT_SECRET", "medscan_default_secret")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_DAYS = 30

UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)
DB_PATH = Path("medical_reports.db")

# ─── LLM Client (OpenAI) ───────────────────────────────────────────────────

llm_client = OpenAI(
    api_key=OPENAI_API_KEY,
)

TEMP_REPORTS = {}

# ─── Supabase Client ─────────────────────────────────────────────────────────

supabase: Optional[Client] = None
if STORAGE_ENGINE == "supabase" and SUPABASE_URL and SUPABASE_KEY:
    try:
        import httpx
        from supabase import ClientOptions
        
        # Create a custom httpx client with http2=False to prevent ConnectionTerminated errors
        httpx_client = httpx.Client(
            http2=False,
            timeout=httpx.Timeout(30.0, read=60.0),
        )
        options = ClientOptions(
            httpx_client=httpx_client,
            postgrest_client_timeout=60.0,
            storage_client_timeout=60.0,
        )
        supabase = create_client(SUPABASE_URL, SUPABASE_KEY, options=options)
    except Exception as e:
        print(f"Failed to initialize Supabase: {e}")

# ─── Database & Storage Logic ───────────────────────────────────────────────

# ─── Pydantic Models for Auth ──────────────────────────────────────────────

class RegisterRequest(BaseModel):
    email: str
    name: str
    password: str
    gender: str
    dob: Optional[str] = ""
    ic_number: Optional[str] = ""

class LoginRequest(BaseModel):
    email: str
    password: str

class ChatMessageModel(BaseModel):
    role: str
    content: str

class AnalyzeRequest(BaseModel):
    query: Optional[str] = None
    messages: Optional[TypingList[ChatMessageModel]] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    session_id: Optional[str] = None

class CreateSessionRequest(BaseModel):
    title: str

class PreprocessedUploadRequest(BaseModel):
    filepaths: TypingList[str]
    filenames: Optional[TypingList[str]] = None

# ─── Auth Helpers ──────────────────────────────────────────────────────────

def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def verify_password(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))

def create_jwt(user_id: str, email: str) -> str:
    payload = {
        "sub": user_id,
        "email": email,
        "exp": datetime.now(timezone.utc) + timedelta(days=JWT_EXPIRE_DAYS),
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)

def decode_jwt(token: str) -> dict:
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")

async def get_current_user(authorization: str = Header(None)) -> dict:
    """FastAPI dependency: extract user from Bearer token."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid authorization header")
    token = authorization.split(" ", 1)[1]
    payload = decode_jwt(token)
    user = get_user_by_id(payload["sub"])
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user

# ─── Database Init ─────────────────────────────────────────────────────────

def init_local_db():
    conn = sqlite3.connect(str(DB_PATH))
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            email TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            password_hash TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'active',
            gender TEXT,
            dob DATE,
            ic_number TEXT,
            created_at TEXT NOT NULL
        )
    """)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS reports (
            id TEXT PRIMARY KEY,
            user_id TEXT,
            filename TEXT NOT NULL,
            upload_time TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'processing',
            raw_text TEXT,
            structured_data TEXT,
            user_verified INTEGER DEFAULT 0,
            file_path TEXT
        )
    """)
    # Migration: add user_id column if missing
    try:
        cursor.execute("ALTER TABLE reports ADD COLUMN user_id TEXT")
    except sqlite3.OperationalError:
        pass  # Column already exists

    # Migration: add health_summary column to users if missing
    try:
        cursor.execute("ALTER TABLE users ADD COLUMN health_summary TEXT")
    except sqlite3.OperationalError:
        pass  # Column already exists

    # Migration: add gender column to users if missing
    try:
        cursor.execute("ALTER TABLE users ADD COLUMN gender TEXT")
    except sqlite3.OperationalError:
        pass  # Column already exists

    # Migration: drop age column from users if present
    try:
        cursor.execute("ALTER TABLE users DROP COLUMN age")
    except sqlite3.OperationalError:
        pass

    # Migration: add dob column to users if missing
    try:
        cursor.execute("ALTER TABLE users ADD COLUMN dob DATE")
    except sqlite3.OperationalError:
        pass  # Column already exists

    # Migration: add ic_number column to users if missing
    try:
        cursor.execute("ALTER TABLE users ADD COLUMN ic_number TEXT")
    except sqlite3.OperationalError:
        pass  # Column already exists


    cursor.execute("""
        CREATE TABLE IF NOT EXISTS health_summary_cache (
            user_id TEXT PRIMARY KEY,
            summary TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
    """)

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS chat_sessions (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            created_at TEXT NOT NULL,
            title TEXT NOT NULL
        )
    """)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS chat_messages (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            timestamp TEXT NOT NULL
        )
    """)
    conn.commit()
    conn.close()

init_local_db()

# ─── User DB Helpers ───────────────────────────────────────────────────────

def get_user_by_email(email: str) -> Optional[dict]:
    if STORAGE_ENGINE == "supabase" and supabase:
        response = supabase.table("users").select("*").eq("email", email.lower().strip()).execute()
        if response.data and len(response.data) > 0:
            return response.data[0]
        return None
    else:
        conn = sqlite3.connect(str(DB_PATH))
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users WHERE email = ?", (email.lower().strip(),))
        row = cursor.fetchone()
        conn.close()
        return dict(row) if row else None

def get_user_by_id(user_id: str) -> Optional[dict]:
    if STORAGE_ENGINE == "supabase" and supabase:
        response = supabase.table("users").select("*").eq("id", user_id).execute()
        if response.data and len(response.data) > 0:
            return response.data[0]
        return None
    else:
        conn = sqlite3.connect(str(DB_PATH))
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users WHERE id = ?", (user_id,))
        row = cursor.fetchone()
        conn.close()
        return dict(row) if row else None

def get_user_by_ic(ic_number: str) -> Optional[dict]:
    """Look up a user by their normalised IC number."""
    ic_clean = str(ic_number).strip()
    if not ic_clean:
        return None
    if STORAGE_ENGINE == "supabase" and supabase:
        response = supabase.table("users").select("*").eq("ic_number", ic_clean).execute()
        if response.data and len(response.data) > 0:
            return response.data[0]
        return None
    else:
        conn = sqlite3.connect(str(DB_PATH))
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM users WHERE ic_number = ?", (ic_clean,))
        row = cursor.fetchone()
        conn.close()
        return dict(row) if row else None

def normalize_dob(dob_str: str) -> str:
    if not dob_str or not str(dob_str).strip():
        raise ValueError("Date of birth is required")
    parsed = parse_date_robust(dob_str)
    if not parsed:
        raise ValueError(f"Invalid date of birth: '{dob_str}'. Please use YYYY-MM-DD or DD/MM/YYYY format.")
    return parsed.isoformat()

def normalize_ic(ic_str: Optional[str]) -> str:
    if not ic_str: return ""
    import re
    cleaned = re.sub(r'\D', '', str(ic_str).strip())
    if len(cleaned) == 12:
        return f"{cleaned[:6]}-{cleaned[6:8]}-{cleaned[8:]}"
    return str(ic_str).strip()

def create_user(email: str, name: str, password: str, gender: str, dob: str, ic_number: Optional[str] = "") -> dict:
    user_id = str(uuid.uuid4())
    pw_hash = hash_password(password)
    now = datetime.now().isoformat()
    norm_dob = normalize_dob(dob)
    norm_ic = normalize_ic(ic_number)
    user_data = {
        "id": user_id,
        "email": email.lower().strip(),
        "name": name.strip(),
        "password_hash": pw_hash,
        "gender": gender.strip(),
        "dob": norm_dob,
        "ic_number": norm_ic,
        "created_at": now,
    }
    if STORAGE_ENGINE == "supabase" and supabase:
        supabase.table("users").insert(user_data).execute()
    else:
        conn = sqlite3.connect(str(DB_PATH))
        conn.execute(
            "INSERT INTO users (id, email, name, password_hash, status, gender, dob, ic_number, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (user_id, email.lower().strip(), name.strip(), pw_hash, 'active', gender.strip(), norm_dob, norm_ic, now)
        )
        conn.commit()
        conn.close()
    return {"id": user_id, "email": user_data["email"], "name": user_data["name"], "gender": user_data["gender"], "dob": norm_dob, "ic_number": norm_ic, "created_at": now}

def update_user_profile(user_id: str, name: str, email: str, gender: Optional[str] = None, dob: Optional[str] = None, ic_number: Optional[str] = None):
    update_data = {"name": name, "email": email}
    if gender:
        update_data["gender"] = gender
    if dob:
        update_data["dob"] = normalize_dob(dob)
    if ic_number is not None:
        update_data["ic_number"] = normalize_ic(ic_number)

    if STORAGE_ENGINE == "supabase" and supabase:
        supabase.table("users").update(update_data).eq("id", user_id).execute()
    else:
        conn = sqlite3.connect(str(DB_PATH))
        query = "UPDATE users SET name = ?, email = ?"
        params = [name, email]
        if gender:
            query += ", gender = ?"
            params.append(gender)
        if dob:
            query += ", dob = ?"
            params.append(normalize_dob(dob))
        if ic_number is not None:
            query += ", ic_number = ?"
            params.append(normalize_ic(ic_number))
        query += " WHERE id = ?"
        params.append(user_id)
        conn.execute(query, tuple(params))
        conn.commit()
        conn.close()

def update_user_password(user_id: str, new_password: str):
    pw_hash = hash_password(new_password)
    if STORAGE_ENGINE == "supabase" and supabase:
        supabase.table("users").update({"password_hash": pw_hash}).eq("id", user_id).execute()
    else:
        conn = sqlite3.connect(str(DB_PATH))
        conn.execute("UPDATE users SET password_hash = ? WHERE id = ?", (pw_hash, user_id))
        conn.commit()
        conn.close()

def set_user_inactive(user_id: str):
    if STORAGE_ENGINE == "supabase" and supabase:
        supabase.table("users").update({"status": "inactive"}).eq("id", user_id).execute()
    else:
        conn = sqlite3.connect(str(DB_PATH))
        conn.execute("UPDATE users SET status = 'inactive' WHERE id = ?", (user_id,))
        conn.commit()
        conn.close()

# ─── Preprocessing & Extraction Logic ────────────────────────────────────────

def preprocess_image(image_path: Path) -> Path:
    """Enhance image contrast and clarity for OCR using OpenCV."""
    try:
        # Read image
        img = cv2.imread(str(image_path))
        if img is None: return image_path
        
        # Convert to grayscale
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # Increase contrast using CLAHE
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))
        contrast_img = clahe.apply(gray)
        
        # Save preprocessed image to a temp file
        processed_path = image_path.with_name(f"processed_{image_path.name}")
        cv2.imwrite(str(processed_path), contrast_img)
        return processed_path
    except Exception as e:
        print(f"Image preprocessing failed: {e}")
        return image_path

def encode_image(image_path: Path, do_upscale: bool = True) -> str:
    # Apply preprocessing before encoding
    processed_path = preprocess_image(image_path)
    
    # Optionally upscale small images (e.g. split halves) for better Vision API accuracy
    if do_upscale:
        try:
            img = cv2.imread(str(processed_path))
            if img is not None:
                upscaled = upscale_if_small(img, min_height=800)
                if upscaled is not img:  # Was upscaled
                    cv2.imwrite(str(processed_path), upscaled)
        except Exception as e:
            print(f"[ENCODE] Upscale check failed (non-fatal): {e}")
    
    with open(processed_path, "rb") as image_file:
        b64 = base64.b64encode(image_file.read()).decode('utf-8')
    # Cleanup temp file
    if processed_path != image_path and processed_path.exists():
        processed_path.unlink()
    return b64

async def parse_medical_report_llm(file_path: Path) -> Dict[str, Any]:
    """Uses OpenAI Vision to parse an image directly into structured JSON by splitting it into halves using content-aware row-gap detection."""
    split_paths = split_image_at_gap(file_path)
    image_blocks = []

    # Dynamically build the prompt based on the schema
    # Define explicit metadata keys with descriptions to ensure high accuracy and no confusion
    metadata_descriptions = [
        "patient_name (The full name of the patient as written on the report. If none is found, use '')",
        "medid (The Patient ID / Medical Record Number / NRIC / Passport / MRN / Patient Reference No. This is the unique identifier for the PATIENT themselves, NOT the report or lab sample. If none is found, use '')",
        "labreference (The unique ID for the physical LAB SAMPLE / SPECIMEN that was tested. Typical labels on the report: 'Lab No', 'Lab Number', 'Specimen No', 'Specimen ID', 'Sample ID', 'Sample No'. This identifies the tube/container of blood or urine. Do NOT put the Report No / Accession No / Reference No here — those belong in report_reference. If none is found, use '')",
        "report_reference (The unique ID for this specific REPORT DOCUMENT. Typical labels on the report: 'Report No', 'Accession No', 'Episode No', 'Reference No', 'Ref No'. This identifies the printed report sheet itself. Do NOT put the Lab No / Lab Number / Specimen No here — those belong in labreference. If none is found, use '')",
        "collected (The date when the sample was collected. If the sample collection date is not available on the report, USE the report printed/reported/completed date. This is the main date for the report. Format: YYYY-MM-DD or DD/MM/YYYY. If none is found, use '')",
        "time (The time when the sample was collected/drawn (often labeled as 'Collected', 'Drawn', 'Collection Time', 'Date & Time Col'). This is the main test time. If no collection time is explicitly available, USE the reported/printed time here. Format: HH:MM or HH:MM:SS. If none is found, use '')",
        "reported_time (The time when the report was printed, completed, or validated (often labeled as 'Reported', 'Printed', 'Completed', 'Approved Date/Time'). Format: HH:MM or HH:MM:SS. If none is found, use '')",
        "gender (The patient's gender/sex, e.g. 'Male' or 'Female'. If none is found, use '')",
        "age (The age of the patient as written on the report, e.g. '45' or '45 years'. If none is found, use '')",
        "dob (The Date of Birth of the patient as written on the report, e.g. '1980-05-15' or '15/05/1980'. If none is found, use '')",
        "ic_number (The Identity Card / NRIC / passport number of the patient as written on the report, e.g. '850512-14-5678' or similar NRIC/Passport. If none is found, use '')",
        "test_name (The overall name of the medical/blood test, e.g. 'Full Blood Count', 'Liver Function Test', 'Renal Profile', 'Urine Test'. Generate a descriptive name if not explicitly written)",
        "doctor_name (The name of the referring doctor, e.g. 'Dr. John Doe'. If none is found, use '')",
        "hospital_name (The name of the hospital, clinic, or laboratory where the test was performed. If none is found, use '')",
        "notes (Any general comments, remarks, or notes written on the report. If none is found, use '')"
    ]
    
    metadata_keys_to_exclude = ["patient_name", "medid", "labreference", "report_reference", "collected", "time", "reported_time", "gender", "lab", "notes", "age", "dob", "ic_number"]
    biomarker_keys = [k for k in STAGING_SCHEMA_KEYS if not k.startswith("original_") and k not in metadata_keys_to_exclude]
    
    all_keys = metadata_descriptions + biomarker_keys
    keys_list = "\n".join([f"- {k}" for k in all_keys])
    
    num_sections = len(split_paths)
    split_info = f"""You are given {num_sections} image section(s) of a SINGLE medical report page.
    The page has been split into top and bottom halves for better readability.
    There may be a small overlap between the sections — if the same test row appears in both halves, extract it ONCE only (deduplicate).
    Extract data from ALL sections and merge them into ONE unified JSON result.""" if num_sections > 1 else "You are given a single medical report image."

    prompt = f"""
    {split_info}

    You are an expert medical data extraction assistant.
    Extract medical data directly from the image(s) and return it as a JSON object.
    Ensure you extract ALL test items accurately and do not miss any rows.
    
    The output MUST exactly match the following JSON keys. 
    If a value is missing in the report, use an empty string "". 
    If a unit is present on the report for a test, INCLUDE the unit in the string alongside the value (e.g., "5.17 mmol/L", "150 g/L").
    DO NOT use null or omit keys.
    
    Fields to extract (all as strings):
    {keys_list}
 
    CRITICAL WARNING ON IDENTIFIERS — DO NOT SWAP labreference AND report_reference:
    There are THREE separate identifier fields. Read the label on the report carefully before assigning:
    
    1. 'medid' = PATIENT identifier. Labels: 'Patient ID', 'MRN', 'NRIC', 'Passport No', 'Patient Ref'.
    2. 'labreference' = LAB SAMPLE/SPECIMEN identifier. Labels: 'Lab No', 'Lab Number', 'Specimen No', 'Specimen ID', 'Sample ID', 'Sample No'.
       This is the ID of the PHYSICAL SAMPLE (blood tube, urine cup). It is NOT the report reference.
    3. 'report_reference' = REPORT/DOCUMENT identifier. Labels: 'Report No', 'Accession No', 'Episode No', 'Reference No', 'Ref No'.
       This is the ID of the PRINTED REPORT DOCUMENT. It is NOT the lab sample number.
    
    DECISION RULE: If the label says 'Lab No' or 'Lab Number' or 'Specimen' → it is labreference, NOT report_reference.
    If the label says 'Report No' or 'Accession No' or 'Reference No' or 'Episode No' → it is report_reference, NOT labreference.
    If the document has both, extract each into its correct field. If only one identifier exists beyond medid, determine if it identifies the report or the sample based on its label.

    CRITICAL WARNING ON TIMESTAMPS:
    - Medical reports contain multiple times: 'Collected' (collection/drawn time), 'Received' (time sample reached the lab), and 'Reported/Printed' (time report was finalized/printed).
    - Map the 'Collected' time to the 'time' key. This is the primary time of the report.
    - Map the 'Reported' or 'Printed' time to the 'reported_time' key.
    - If the report only has ONE time/timestamp (e.g. only 'Reported' or 'Printed' time), map it to BOTH the 'time' key AND the 'reported_time' key.
    - If the report has multiple times, ALWAYS prioritize the 'Collected' time for the 'time' key, and the 'Reported/Printed' time for the 'reported_time' key. Never map 'Received' or 'Reported' time to the 'time' key if a 'Collected' time is present.

    IMPORTANT MAPPING RULES & EXAMPLES:
    1. Standardize units in keys: e.g., if you see 'g/dL', map it to keys ending in '_g_dl'.
    2. Do NOT convert units yourself. Extract the EXACT unit written on the report (e.g., if the report lists "µkat/L" or "ukat/L", do NOT convert it to "U/L"; extract it exactly as "µkat/L" or "ukat/L" inside the string alongside the value).
    3. RESULT VS REFERENCE RANGE ACCURACY:
       - DO NOT confuse the patient's actual "Result/Value" column with the "Reference Range/Normal Range" column.
       - Always verify the column headers to ensure you are extracting the patient's active result. If the patient's result is empty, use "". Do NOT fall back to extracting the reference range value as the result.
       - For qualitative tests (e.g., urine proteins, glucose, nitrites, etc.), if the patient's result is written as "1+ (positive)", "2+ (positive)", "++", "1+", "+", etc. and the reference is just "positive" or "Negative", standardise/clean the result to just the clean qualitative word (e.g., "positive" or "Negative") to match the reference standard and avoid useless grader prefixes like "1+" unless explicitly requested.
    4. Map common names: 
       - 'WBC' -> 'wbc_cells_ul'
       - 'RBC' -> 'rbc_count_mil_ul'
       - 'HGB' or 'Hemoglobin' -> 'hemoglobin_g_dl'
       - 'Cholesterol' -> 'total_cholesterol_mg_dl'
    5. EDGE CASES & SYMBOLS:
       - If a result has a less-than/greater-than sign, include it: "< 0.3", "> 100".
       - If a result is a textual qualitative value, extract it exactly as written: "Negative", "Clear", "Pale Yellow".
    6. FEW-SHOT EXAMPLE:
       If the image shows: "Cholesterol Total: 5.17 mmol/L" and "WBC: 4.5 x10^3/uL",
       Your JSON should include:
       {{
          "total_cholesterol_mg_dl": "5.17 mmol/L",
          "wbc_cells_ul": "4.5 x10^3/uL"
       }}

    Return ONLY the JSON object. Do not wrap in markdown tags.
    """
    
    try:
        # Encode each split image
        for sp in split_paths:
            b64 = encode_image(sp)
            image_blocks.append({
                "type": "image_url",
                "image_url": {
                    "url": f"data:image/jpeg;base64,{b64}"
                }
            })

        response = llm_client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=[
                {"role": "system", "content": "You are an expert medical data extraction assistant. Return JSON only."},
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        *image_blocks
                    ]
                }
            ],
            response_format={"type": "json_object"}
        )
        content = response.choices[0].message.content
        print(f"--- EXTRACTED JSON FROM OPENAI VISION ---\n{content}\n-----------------------------------------")
        
        extracted_data = json.loads(content)
        return normalize_structured_data(extracted_data)
    except Exception as e:
        print(f"LLM Parsing failed: {e}")
        return normalize_structured_data({})
    finally:
        # Cleanup temp split files
        for sp in split_paths:
            if sp != file_path and sp.exists():
                try:
                    sp.unlink()
                except Exception as ex:
                    print(f"Failed to delete temp split file {sp}: {ex}")

async def parse_medical_report_multi_llm(file_paths: TypingList[Path]) -> Dict[str, Any]:
    """Uses OpenAI Vision to parse MULTIPLE page images into a single structured JSON.
    Each page is split into halves using content-aware row-gap detection for better accuracy."""
    # Build image content blocks for all pages, splitting each page into halves
    image_blocks = []
    all_split_paths = []  # Track split files for cleanup
    total_sections = 0
    
    for i, fp in enumerate(file_paths):
        # Split each page into halves using content-aware gap detection
        page_splits = split_image_at_gap(fp)
        all_split_paths.extend([sp for sp in page_splits if sp != fp])
        
        for j, sp in enumerate(page_splits):
            section_label = f"Page {i+1}"
            if len(page_splits) > 1:
                section_label += f" ({'top half' if j == 0 else 'bottom half'})"
            
            b64 = encode_image(sp)
            # Add a text label before each image so the LLM knows which section it is
            image_blocks.append({
                "type": "text",
                "text": f"--- {section_label} ---"
            })
            image_blocks.append({
                "type": "image_url",
                "image_url": {"url": f"data:image/jpeg;base64,{b64}"}
            })
            total_sections += 1

    # Dynamically build the prompt based on the schema
    # Define explicit metadata keys with descriptions to ensure high accuracy and no confusion
    metadata_descriptions = [
        "patient_name (The full name of the patient as written on the report. If none is found, use '')",
        "medid (The Patient ID / Medical Record Number / NRIC / Passport / MRN / Patient Reference No. This is the unique identifier for the PATIENT themselves, NOT the report or lab sample. If none is found, use '')",
        "labreference (The unique ID for the physical LAB SAMPLE / SPECIMEN that was tested. Typical labels on the report: 'Lab No', 'Lab Number', 'Specimen No', 'Specimen ID', 'Sample ID', 'Sample No'. This identifies the tube/container of blood or urine. Do NOT put the Report No / Accession No / Reference No here — those belong in report_reference. If none is found, use '')",
        "report_reference (The unique ID for this specific REPORT DOCUMENT. Typical labels on the report: 'Report No', 'Accession No', 'Episode No', 'Reference No', 'Ref No'. This identifies the printed report sheet itself. Do NOT put the Lab No / Lab Number / Specimen No here — those belong in labreference. If none is found, use '')",
        "collected (The date when the sample was collected. If the sample collection date is not available on the report, USE the report printed/reported/completed date. This is the main date for the report. Format: YYYY-MM-DD or DD/MM/YYYY. If none is found, use '')",
        "time (The time when the sample was collected/drawn (often labeled as 'Collected', 'Drawn', 'Collection Time', 'Date & Time Col'). This is the main test time. If no collection time is explicitly available, USE the reported/printed time here. Format: HH:MM or HH:MM:SS. If none is found, use '')",
        "reported_time (The time when the report was printed, completed, or validated (often labeled as 'Reported', 'Printed', 'Completed', 'Approved Date/Time'). Format: HH:MM or HH:MM:SS. If none is found, use '')",
        "gender (The patient's gender/sex, e.g. 'Male' or 'Female'. If none is found, use '')",
        "age (The age of the patient as written on the report, e.g. '45' or '45 years'. If none is found, use '')",
        "dob (The Date of Birth of the patient as written on the report, e.g. '1980-05-15' or '15/05/1980'. If none is found, use '')",
        "ic_number (The Identity Card / NRIC / passport number of the patient as written on the report, e.g. '850512-14-5678' or similar NRIC/Passport. If none is found, use '')",
        "test_name (The overall name of the medical/blood test, e.g. 'Full Blood Count', 'Liver Function Test', 'Renal Profile', 'Urine Test'. Generate a descriptive name if not explicitly written)",
        "doctor_name (The name of the referring doctor, e.g. 'Dr. John Doe'. If none is found, use '')",
        "hospital_name (The name of the hospital, clinic, or laboratory where the test was performed. If none is found, use '')",
        "notes (Any general comments, remarks, or notes written on the report. If none is found, use '')"
    ]
    
    metadata_keys_to_exclude = ["patient_name", "medid", "labreference", "report_reference", "collected", "time", "reported_time", "gender", "lab", "notes", "age", "dob", "ic_number"]
    biomarker_keys = [k for k in STAGING_SCHEMA_KEYS if not k.startswith("original_") and k not in metadata_keys_to_exclude]
    
    all_keys = metadata_descriptions + biomarker_keys
    keys_list = "\n".join([f"- {k}" for k in all_keys])

    prompt = f"""
    You are given {len(file_paths)} page(s) of a SINGLE medical blood report, split into {total_sections} image section(s) for improved readability.
    Each page has been split into top and bottom halves. There may be a small overlap between halves of the same page — if the same test row appears in both halves, extract it ONCE only (deduplicate).
    Extract ALL medical data from ALL sections and merge them into ONE JSON object.
    Do NOT separate results by page or section — combine everything into a unified record.
    Ensure you extract ALL test items accurately and do not miss any rows from any section.

    The output MUST exactly match the following JSON keys.
    If a value is missing in the report, use an empty string "".
    If a unit is present on the report for a test, INCLUDE the unit in the string alongside the value.
    DO NOT use null or omit keys.

    Fields to extract (all as strings):
    {keys_list}

    CRITICAL WARNING ON IDENTIFIERS — DO NOT SWAP labreference AND report_reference:
    There are THREE separate identifier fields. Read the label on the report carefully before assigning:
    
    1. 'medid' = PATIENT identifier. Labels: 'Patient ID', 'MRN', 'NRIC', 'Passport No', 'Patient Ref'.
    2. 'labreference' = LAB SAMPLE/SPECIMEN identifier. Labels: 'Lab No', 'Lab Number', 'Specimen No', 'Specimen ID', 'Sample ID', 'Sample No'.
       This is the ID of the PHYSICAL SAMPLE (blood tube, urine cup). It is NOT the report reference.
    3. 'report_reference' = REPORT/DOCUMENT identifier. Labels: 'Report No', 'Accession No', 'Episode No', 'Reference No', 'Ref No'.
       This is the ID of the PRINTED REPORT DOCUMENT. It is NOT the lab sample number.
    
    DECISION RULE: If the label says 'Lab No' or 'Lab Number' or 'Specimen' → it is labreference, NOT report_reference.
    If the label says 'Report No' or 'Accession No' or 'Reference No' or 'Episode No' → it is report_reference, NOT labreference.
    If the document has both, extract each into its correct field. If only one identifier exists beyond medid, determine if it identifies the report or the sample based on its label.

    CRITICAL WARNING ON TIMESTAMPS:
    - Medical reports contain multiple times: 'Collected' (collection/drawn time), 'Received' (time sample reached the lab), and 'Reported/Printed' (time report was finalized/printed).
    - Map the 'Collected' time to the 'time' key. This is the primary time of the report.
    - Map the 'Reported' or 'Printed' time to the 'reported_time' key.
    - If the report only has ONE time/timestamp (e.g. only 'Reported' or 'Printed' time), map it to BOTH the 'time' key AND the 'reported_time' key.
    - If the report has multiple times, ALWAYS prioritize the 'Collected' time for the 'time' key, and the 'Reported/Printed' time for the 'reported_time' key. Never map 'Received' or 'Reported' time to the 'time' key if a 'Collected' time is present.

    IMPORTANT MAPPING RULES & EXAMPLES:
    1. Map common names:
       - 'WBC' -> 'wbc_cells_ul'
       - 'RBC' -> 'rbc_count_mil_ul'
       - 'HGB' -> 'hemoglobin_g_dl'
    2. Patient info (medid, labreference, dates) should appear once — take from whichever section has it.
    3. Do NOT convert units yourself. Extract the EXACT unit written on the report (e.g., if the report lists "µkat/L" or "ukat/L", do NOT convert it to "U/L"; extract it exactly as "µkat/L" or "ukat/L" inside the string alongside the value).
    4. RESULT VS REFERENCE RANGE ACCURACY:
       - DO NOT confuse the patient's actual "Result/Value" column with the "Reference Range/Normal Range" column.
       - Always verify the column headers to ensure you are extracting the patient's active result. If the patient's result is empty, use "". Do NOT fall back to extracting the reference range value as the result.
       - For qualitative tests (e.g., urine proteins, glucose, nitrites, etc.), if the patient's result is written as "1+ (positive)", "2+ (positive)", "++", "1+", "+", etc. and the reference is just "positive" or "Negative", standardise/clean the result to just the clean qualitative word (e.g., "positive" or "Negative") to match the reference standard and avoid useless grader prefixes like "1+" unless explicitly requested.
    5. EDGE CASES & SYMBOLS:
       - If a result has a '<' or '>', include it: "< 0.5".
       - If a result is qualitative, extract exact text: "Negative", "Trace".
    6. FEW-SHOT EXAMPLE:
       If the image shows: "Cholesterol Total: 5.17 mmol/L" and "Urine Glucose: Negative",
       Your JSON should include:
       {{
          "total_cholesterol_mg_dl": "5.17 mmol/L",
          "glucose": "Negative"
       }}

    Return ONLY the JSON object. Do not wrap in markdown tags.
    """

    # Compose the message: text prompt + all image blocks
    content_parts = [{"type": "text", "text": prompt}] + image_blocks

    try:
        response = llm_client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=[
                {"role": "system", "content": "You are an expert medical data extraction assistant. You receive multi-page reports split into sections for better readability. Deduplicate overlapping data. Return JSON only."},
                {"role": "user", "content": content_parts}
            ],
            response_format={"type": "json_object"}
        )
        content = response.choices[0].message.content
        print(f"--- EXTRACTED JSON FROM OPENAI VISION (MULTI-PAGE: {len(file_paths)} pages, {total_sections} sections) ---\n{content}\n-----------------------------------------")

        extracted_data = json.loads(content)
        return normalize_structured_data(extracted_data)
    except Exception as e:
        print(f"Multi-page LLM Parsing failed: {e}")
        return normalize_structured_data({})
    finally:
        # Cleanup temp split files from multi-page splitting
        for sp in all_split_paths:
            if sp.exists():
                try:
                    sp.unlink()
                except Exception as ex:
                    print(f"Failed to delete temp split file {sp}: {ex}")

# List of exact columns in staging_medical_records table
STAGING_SCHEMA_KEYS = [
    "medid", "original_medid", "labreference", "original_labreference", "report_reference", "lab", "collected", "time", "reported_time", 
    "gender",
    "urine_colour", "appearance", "specific_gravity", "ph", "proteins", "glucose", 
    "bilirubin", "ketones", "blood", "urobilinogen", "nitrites", "wbc_pus_cells_hpf", 
    "rbc", "epithelial_cells_hpf", "casts", "crystals", "others", "hemoglobin_g_dl", 
    "rbc_count_mil_ul", "hematocrit_pct", "mcv_fl", "mch_pg", "mchc_g_dl", "rdw_cv_pct", 
    "rdw_sd_fl", "wbc_cells_ul", "neutrophils_pct", "lymphocytes_pct", "eosinophils_pct", 
    "monocytes_pct", "basophils_pct", "abs_neutrophils", "abs_lymphocytes", "abs_monocytes", 
    "abs_eosinophils", "abs_basophils", "platelet_count_x10_3_ul", "mpv_fl", "platelet_rdw_pct", 
    "pct_pct", "p_lcr_pct", "img_pct", "imm_pct", "iml_pct", "lic_pct", "total_cholesterol_mg_dl", 
    "hdl_mg_dl", "ldl_mg_dl", "vldl_mg_dl", "triglycerides_mg_dl", "non_hdl_mg_dl", 
    "total_hdl_ratio", "ldl_hdl_ratio", "bilirubin_total_mg_dl", 
    "bilirubin_direct_mg_dl", "bilirubin_indirect_mg_dl", "alp_u_l", "alt_sgpt_u_l", 
    "ast_sgot_u_l", "ggt_u_l", "protein_total_g_dl", "albumin_g_dl", "globulin_g_dl", 
    "a_g_ratio", "creatinine_mg_dl", "urea_mg_dl", "bun_mg_dl", "bun_creatinine_ratio", 
    "sodium_mmol_l", "potassium_mmol_l", "chloride_mmol_l", "uric_acid_mg_dl", 
    "egfr_ml_min_173m2", "iron_ug_dl", "uibc_ug_dl", "tibc_ug_dl", "transferrin_saturation_pct", 
    "hba1c_pct", "estimated_avg_glucose_mg_dl", "hbf_pct", "urine_albumin_mg_l", 
    "urine_creatinine_mg_dl", "albumin_creatinine_ratio", "calcium_mg_dl", "phosphorus_mg_dl", 
    "tt3_ng_dl", "tt4_ug_dl", "tsh_uiu_ml", "fasting_glucose_mg_dl", "postprandial_glucose_mg_dl", 
    "fbs_mg_dl", "plbs_mg_dl"
]

SCHEMA_TYPES = {
    "medid": "BIGINT",
    "labreference": "TEXT",
    "report_reference": "TEXT",
    "lab": "TEXT",
    "collected": "DATE",
    "time": "TIME",
    "reported_time": "TIME",
    "gender": "TEXT",
    "urine_colour": "TEXT",
    "appearance": "TEXT",
    "specific_gravity": "DOUBLE PRECISION",
    "ph": "DOUBLE PRECISION",
    "proteins": "TEXT",
    "glucose": "TEXT",
    "bilirubin": "TEXT",
    "ketones": "TEXT",
    "blood": "TEXT",
    "urobilinogen": "TEXT",
    "nitrites": "TEXT",
    "wbc_pus_cells_hpf": "TEXT",
    "rbc": "TEXT",
    "epithelial_cells_hpf": "TEXT",
    "casts": "TEXT",
    "crystals": "TEXT",
    "others": "TEXT",
    "hemoglobin_g_dl": "DOUBLE PRECISION",
    "rbc_count_mil_ul": "DOUBLE PRECISION",
    "hematocrit_pct": "DOUBLE PRECISION",
    "mcv_fl": "DOUBLE PRECISION",
    "mch_pg": "BIGINT",
    "mchc_g_dl": "DOUBLE PRECISION",
    "rdw_cv_pct": "DOUBLE PRECISION",
    "rdw_sd_fl": "DOUBLE PRECISION",
    "wbc_cells_ul": "BIGINT",
    "neutrophils_pct": "BIGINT",
    "lymphocytes_pct": "BIGINT",
    "eosinophils_pct": "BIGINT",
    "monocytes_pct": "BIGINT",
    "basophils_pct": "DOUBLE PRECISION",
    "abs_neutrophils": "DOUBLE PRECISION",
    "abs_lymphocytes": "DOUBLE PRECISION",
    "abs_monocytes": "DOUBLE PRECISION",
    "abs_eosinophils": "DOUBLE PRECISION",
    "abs_basophils": "DOUBLE PRECISION",
    "platelet_count_x10_3_ul": "BIGINT",
    "mpv_fl": "DOUBLE PRECISION",
    "platelet_rdw_pct": "BIGINT",
    "pct_pct": "DOUBLE PRECISION",
    "p_lcr_pct": "DOUBLE PRECISION",
    "img_pct": "DOUBLE PRECISION",
    "imm_pct": "DOUBLE PRECISION",
    "iml_pct": "DOUBLE PRECISION",
    "lic_pct": "DOUBLE PRECISION",
    "total_cholesterol_mg_dl": "BIGINT",
    "hdl_mg_dl": "BIGINT",
    "ldl_mg_dl": "DOUBLE PRECISION",
    "vldl_mg_dl": "DOUBLE PRECISION",
    "triglycerides_mg_dl": "DOUBLE PRECISION",
    "non_hdl_mg_dl": "BIGINT",
    "total_hdl_ratio": "DOUBLE PRECISION",
    "ldl_hdl_ratio": "DOUBLE PRECISION",
    "bilirubin_total_mg_dl": "DOUBLE PRECISION",
    "bilirubin_direct_mg_dl": "DOUBLE PRECISION",
    "bilirubin_indirect_mg_dl": "DOUBLE PRECISION",
    "alp_u_l": "BIGINT",
    "alt_sgpt_u_l": "BIGINT",
    "ast_sgot_u_l": "BIGINT",
    "ggt_u_l": "BIGINT",
    "protein_total_g_dl": "DOUBLE PRECISION",
    "albumin_g_dl": "DOUBLE PRECISION",
    "globulin_g_dl": "DOUBLE PRECISION",
    "a_g_ratio": "DOUBLE PRECISION",
    "creatinine_mg_dl": "DOUBLE PRECISION",
    "urea_mg_dl": "DOUBLE PRECISION",
    "bun_mg_dl": "DOUBLE PRECISION",
    "bun_creatinine_ratio": "DOUBLE PRECISION",
    "sodium_mmol_l": "BIGINT",
    "potassium_mmol_l": "DOUBLE PRECISION",
    "chloride_mmol_l": "BIGINT",
    "uric_acid_mg_dl": "DOUBLE PRECISION",
    "egfr_ml_min_173m2": "DOUBLE PRECISION",
    "iron_ug_dl": "BIGINT",
    "uibc_ug_dl": "BIGINT",
    "tibc_ug_dl": "BIGINT",
    "transferrin_saturation_pct": "DOUBLE PRECISION",
    "hba1c_pct": "DOUBLE PRECISION",
    "estimated_avg_glucose_mg_dl": "DOUBLE PRECISION",
    "hbf_pct": "DOUBLE PRECISION",
    "urine_albumin_mg_l": "DOUBLE PRECISION",
    "urine_creatinine_mg_dl": "DOUBLE PRECISION",
    "albumin_creatinine_ratio": "DOUBLE PRECISION",
    "calcium_mg_dl": "DOUBLE PRECISION",
    "phosphorus_mg_dl": "DOUBLE PRECISION",
    "tt3_ng_dl": "BIGINT",
    "tt4_ug_dl": "DOUBLE PRECISION",
    "tsh_uiu_ml": "DOUBLE PRECISION",
    "fasting_glucose_mg_dl": "BIGINT",
    "postprandial_glucose_mg_dl": "BIGINT",
    "fbs_mg_dl": "BIGINT",
    "plbs_mg_dl": "BIGINT",
}

def validate_and_cast_value(k: str, v: any):
    if v is None or str(v).strip() == "":
        return None
    typ = SCHEMA_TYPES.get(k)
    s = str(v).strip()
    if not typ or typ == "TEXT":
        return s
    
    if typ == "BIGINT":
        match = re.search(r'(-?\d*\.?\d+)', s)
        if match:
            return int(round(float(match.group(1))))
        return None
        
    elif typ == "DOUBLE PRECISION":
        match = re.search(r'(-?\d*\.?\d+)', s)
        if match:
            return float(match.group(1))
        return None
        
    elif typ == "DATE":
        # Robustly strip time suffix like " 10:00:00 AM" or " 10:00 AM" or " 10:00:00" or "T10:00:00"
        s_date = re.sub(r'[T\s]+\d{1,2}:\d{2}(:\d{2})?(\s*(AM|PM))?.*$', '', s, flags=re.IGNORECASE).strip()
        # Clean spaces around separators like / or - or .
        s_date = re.sub(r'\s*([/\-.])\s*', r'\1', s_date)
        
        # Resolve English month names to numeric representations to prevent locale dependencies
        months = {
            "january": "01", "february": "02", "march": "03", "april": "04",
            "june": "06", "july": "07", "august": "08",
            "september": "09", "october": "10", "november": "11", "december": "12",
            "jan": "01", "feb": "02", "mar": "03", "apr": "04",
            "may": "05", "jun": "06", "jul": "07", "aug": "08",
            "sep": "09", "oct": "10", "nov": "11", "dec": "12"
        }
        lower_s = s_date.lower()
        for name, num in months.items():
            if re.search(r'\b' + name + r'\b', lower_s):
                s_date = re.sub(r'\b' + name + r'\b', num, lower_s)
                break

        if re.match(r'^\d{4}-\d{2}-\d{2}$', s_date): return s_date
        
        formats = [
            "%d/%m/%Y", "%m/%d/%Y", "%Y/%m/%d",
            "%d-%m-%Y", "%m-%d-%Y", "%Y-%m-%d",
            "%d.%m.%Y", "%m.%d.%Y", "%Y.%m.%d",
            "%d %b %Y", "%d %B %Y", "%b %d, %Y", "%B %d, %Y",
            "%b %d %Y", "%B %d %Y",
            "%d-%b-%Y", "%b-%d-%Y", "%Y-%b-%d",
            "%d.%b.%Y", "%b.%d.%Y", "%Y.%b.%d",
            "%d-%B-%Y", "%B-%d-%Y", "%Y-%B-%d",
            "%d.%B.%Y", "%B.%d.%Y", "%Y.%B.%d",
            
            # 2-digit years
            "%d/%m/%y", "%m/%d/%y", "%y/%m/%d",
            "%d-%m-%y", "%m-%d-%y", "%y-%m-%d",
            "%d.%m.%y", "%m.%d.%y", "%y.%m.%d",
            "%d %b %y", "%d %B %y", "%b %d, %y", "%B %d, %y",
            "%b %d %y", "%B %d %y",
            "%d-%b-%y", "%b-%d-%y", "%y-%b-%d",
            "%d.%b.%y", "%b.%d.%y", "%y.%b.%d",
            "%d-%B-%y", "%B-%d-%y", "%y-%B-%d",
            "%d.%B.%y", "%B.%d.%y", "%y.%B.%d"
        ]
        from datetime import datetime
        for fmt in formats:
            try:
                dt = datetime.strptime(s_date, fmt)
                year = dt.year
                # Apply 100-year rolling window if we parsed a 2-digit year format
                if "%y" in fmt:
                    two_digit = year % 100
                    current_year = datetime.now().year
                    current_century = (current_year // 100) * 100
                    cutoff = (current_year + 20) % 100
                    year = two_digit + (current_century if two_digit <= cutoff else current_century - 100)
                    dt = dt.replace(year=year)
                return dt.strftime("%Y-%m-%d")
            except ValueError:
                pass
        raise ValueError(f"Invalid DATE format (expected YYYY-MM-DD): {s}")
        
    elif typ == "TIME":
        # Extract time part: digit(s) followed by : followed by digits, optionally followed by : and digits, and optionally AM/PM
        match = re.search(r'(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)?', s, re.IGNORECASE)
        if match:
            h = int(match.group(1))
            m = int(match.group(2))
            sec = int(match.group(3)) if match.group(3) else 0
            ampm = match.group(4)
            if ampm:
                if ampm.upper() == "PM" and h < 12:
                    h += 12
                elif ampm.upper() == "AM" and h == 12:
                    h = 0
            return f"{h:02d}:{m:02d}:{sec:02d}"
        raise ValueError(f"Invalid TIME format (expected HH:MM or HH:MM:SS): {s}")
        
    return s

def split_value_and_unit(s: str):
    s = s.strip()
    if not s:
        return "", ""
        
    # Check if the entire string is just a 10-power unit (no preceding value)
    # E.g., "10^9/L", "x10^12/L", "10^3/uL", "10^9"
    if re.match(r'^(x|X|[\*·•])?\s*10\^\d+.*$', s) or re.match(r'^(x|X)?10\^.*$', s):
        if not re.match(r'^[<>]?\s*\d', s):
            return "", s

    # Parse standard value prefixes: optional comparative symbol (<, >, <=, >=) followed by digits and optionally hyphen range
    val_match = re.match(r'^([<>]?\s*=?\s*(?:\d+(?:[.,]\d+)?\s*(?:-\s*\d+(?:[.,]\d+)?)?|\d+))', s)
    if val_match:
        clean_val = val_match.group(1).strip()
        rest = s[val_match.end():].strip()
        
        if rest:
            # Clean up multiplication marks, spaces, and outer wrapping parentheses from unit
            unit = rest
            unit = re.sub(r'^[\s\(\*·•]+', '', unit)
            unit = re.sub(r'^[xX]\s+', '', unit) # Strip 'x' separator but preserve 'x10^3/uL'
            unit = re.sub(r'[\s\)]+$', '', unit)
            unit = unit.strip()
            return clean_val, unit
        else:
            return clean_val, ""
            
    return s, ""

def backend_normalize_time(time_str: str) -> str:
    if not time_str: return ""
    time_str = str(time_str).strip()
    # Handle 3 or 4 digits without colon (e.g. 1430 -> 14:30, 930 -> 09:30)
    if re.match(r'^\d{3,4}$', time_str):
        if len(time_str) == 3:
            time_str = f"0{time_str[0]}:{time_str[1:]}"
        else:
            time_str = f"{time_str[:2]}:{time_str[2:]}"
            
    match = re.search(r'(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)?', time_str, re.IGNORECASE)
    if match:
        h = int(match.group(1))
        m = int(match.group(2))
        sec = int(match.group(3)) if match.group(3) else 0
        ampm = match.group(4)
        if ampm:
            if ampm.upper() == "PM" and h < 12:
                h += 12
            elif ampm.upper() == "AM" and h == 12:
                h = 0
        return f"{h:02d}:{m:02d}:{sec:02d}"
    return time_str

def normalize_structured_data(data: dict) -> dict:
    """Ensure all required keys exist and return a structure friendly to the Flutter UI."""
    # Robustly handle different possible input keys for collected and time
    collected_val = str(data.get("collected", data.get("date", ""))).strip()
    time_val = str(data.get("time", "")).strip()

    # Automatically extract time from collected if collected has a time and time is empty
    if collected_val and not time_val:
        time_match = re.search(r'(\d{1,2}:\d{2}(?::\d{2})?\s*(?:AM|PM)?)', collected_val, re.IGNORECASE)
        if time_match:
            time_val = time_match.group(1).strip()
            # Strip the time from collected_val
            collected_val = re.sub(r'\s*\d{1,2}:\d{2}(?::\d{2})?\s*(?:AM|PM)?.*$', '', collected_val, flags=re.IGNORECASE).strip()

    # Clean time_val to only keep the time part, stripping any date if present, and normalize to 24h
    if time_val:
        time_match = re.search(r'(\d{1,2}:\d{2}(?::\d{2})?\s*(?:AM|PM)?)', time_val, re.IGNORECASE)
        if time_match:
            time_val = backend_normalize_time(time_match.group(1))
        elif re.match(r'^\s*\d{3,4}\s*$', time_val):
            time_val = backend_normalize_time(time_val)
        else:
            time_val = ""

    # 1. Standardize the flat data
    flat = {}
    raw_medid = data.get("medid", data.get("patient_id", ""))
    raw_labref = data.get("labreference", "")
    raw_lab = data.get("lab", data.get("hospital_name", ""))
    raw_report_ref = data.get("report_reference", data.get("sample_id", ""))
    
    def clean_id(val):
        if not val: return ""
        return re.sub(r'[^a-zA-Z0-9]', '', str(val)).upper()
    
    for key in STAGING_SCHEMA_KEYS:
        if key == "original_medid":
            flat[key] = str(raw_medid) if raw_medid is not None else ""
        elif key == "original_labreference":
            flat[key] = str(raw_report_ref) if raw_report_ref is not None else ""
        elif key == "medid":
            flat[key] = clean_id(raw_medid)
        elif key == "labreference":
            # Preserve special characters like dashes/slashes for report IDs
            flat[key] = str(raw_labref).strip().upper() if raw_labref else ""
        elif key == "lab":
            flat[key] = str(raw_lab).strip()
        elif key == "report_reference":
            flat[key] = str(raw_report_ref).strip()
        elif key == "collected":
            flat[key] = collected_val
        elif key == "time":
            flat[key] = time_val
        elif key == "gender":
            val = data.get("gender", "")
            g = str(val).strip().lower() if val else ""
            if g in ("m", "male", "boy", "man"):
                flat[key] = "Male"
            elif g in ("f", "female", "girl", "woman"):
                flat[key] = "Female"
            else:
                flat[key] = str(val).strip().title() if val else ""
        else:
            val = data.get(key, "")
            flat[key] = str(val) if val is not None else ""
            
    # 2. If data already has 'results' (from UI update), merge them back into flat
    if "results" in data:
        for res in data["results"]:
            k = res.get("key")
            if k and k in STAGING_SCHEMA_KEYS:
                flat[k] = res.get("value", "")

    # 3. Map to UI Format (for the Flutter app)
    results = []
    metadata_keys = ["medid", "original_medid", "labreference", "original_labreference", "report_reference", "collected", "time", "reported_time", "gender", "lab", "notes", "age", "dob", "ic_number"]
    for key, value in flat.items():
        if key in metadata_keys or not value: continue
        
        # Determine how many trailing segments form the unit suffix
        # so we only use the non-unit segments for the display name
        unit_suffix_patterns = [
            '_g_dl', '_mg_dl', '_mil_ul', '_pct', '_fl', '_pg',
            '_ul', '_uiu_ml', '_mmol_l', '_mg_l', '_ug_dl',
            '_ng_dl', '_u_l', '_x10_3_ul', '_ml_min_173m2',
        ]
        name_part = key
        for suffix in unit_suffix_patterns:
            if key.endswith(suffix):
                name_part = key[:-len(suffix)]
                break
        name = name_part.replace('_', ' ').title()
        # Parse value and extracted unit from LLM string using our robust parser
        clean_val, extracted_unit = split_value_and_unit(str(value))

        std_unit = get_standard_unit_for_key(key)
        final_unit = extracted_unit if extracted_unit else std_unit
        
        # Include 'key' so we can map it back on update
        results.append({"test_item": name, "value": clean_val, "unit": final_unit, "key": key})

    # Return a combined object that Flutter can parse
    return {
        **flat, 
        "patient_name": str(data.get("patient_name", "")).strip(),
        "patient_id": flat["medid"],
        "date": flat["collected"],
        "results": results,
        "notes": str(data.get("notes") or "").strip(),
        "gender": flat["gender"],
        "test_name": str(data.get("test_name", "")).strip(),
        "doctor_name": str(data.get("doctor_name", "")).strip(),
        "hospital_name": flat.get("lab", "").strip(),
        "report_reference": flat.get("report_reference", "").strip(),
        "age": str(data.get("age", "")).strip(),
        "dob": str(data.get("dob", "")).strip(),
        "ic_number": str(data.get("ic_number", "")).strip(),
    }

def get_standard_unit_for_key(key: str) -> str:
    """Returns the standard unit for a given schema key as expected by unit_converter.py."""
    if key in ["wbc_cells_ul", "abs_neutrophils", "abs_lymphocytes", "abs_monocytes", "abs_eosinophils", "abs_basophils"]:
        return "cells/uL"
    if key == "rbc_count_mil_ul":
        return "mil/uL"
    if key == "platelet_count_x10_3_ul":
        return "x10^3/uL"
    if key == "egfr_ml_min_173m2":
        return "ml/min/1.73m2"
    if key in ["alp_u_l", "alt_sgpt_u_l", "ast_sgot_u_l", "ggt_u_l"]:
        return "U/L"
        
    # Suffix matching
    if key.endswith('_g_dl'): return "g/dL"
    if key.endswith('_mg_dl'): return "mg/dL"
    if key.endswith('_mil_ul'): return "mil/uL"
    if key.endswith('_pct'): return "%"
    if key.endswith('_fl'): return "fL"
    if key.endswith('_pg'): return "pg"
    if key.endswith('_ul'): return "uL"
    if key.endswith('_uiu_ml'): return "uIU/mL"
    if key.endswith('_mmol_l'): return "mmol/L"
    if key.endswith('_mg_l'): return "mg/L"
    if key.endswith('_ug_dl'): return "ug/dL"
    if key.endswith('_ng_dl'): return "ng/dL"
    return ""

def get_clean_flat_data(data: dict) -> dict:
    """Return only the keys that exist in the staging_medical_records table, converting units if needed."""
    # We apply unit conversion before saving to staging table.
    flat_data = {}
    
    # Base normalization
    normalized = normalize_structured_data(data)
    
    # Process original 'results' array if provided to convert user units to target units
    results_map = {r.get("key"): r for r in data.get("results", []) if r.get("key")}
    
    for k, v in normalized.items():
        if k in STAGING_SCHEMA_KEYS:
            # Determine standard unit from key
            std_unit = get_standard_unit_for_key(k)

            val_to_cast = v
            res = results_map.get(k)
            if res and std_unit and res.get("unit"):
                extracted_unit = res.get("unit")
                converted_val = convert_unit(k, v, extracted_unit, std_unit)
                if converted_val is not None:
                    val_to_cast = converted_val

            # OCR Mode: ignore if format not right
            try:
                flat_data[k] = validate_and_cast_value(k, val_to_cast)
            except ValueError:
                flat_data[k] = None

    return flat_data

# ─── Storage Helpers ───────────────────────────────────────────────────────


async def save_report(report: dict):
    if STORAGE_ENGINE == "supabase" and supabase:
        supabase.table("reports").insert(report).execute()
    else:
        conn = sqlite3.connect(str(DB_PATH))
        cursor = conn.cursor()
        cursor.execute("INSERT INTO reports (id, user_id, filename, upload_time, status, file_path, raw_text, structured_data) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                       (report["id"], report.get("user_id"), report["filename"], report["upload_time"], report["status"], 
                        report.get("file_path"), report.get("raw_text"), json.dumps(report.get("structured_data"))))
        conn.commit()
        conn.close()

async def update_report_in_db(report_id: str, update_dict: dict):
    # 1. Fetch existing report to prevent data loss of flat columns
    existing = await get_report_by_id(report_id)
    new_structured = update_dict.get("structured_data", {})
    
    print(f"DEBUG [update_report_in_db] incoming labreference: {new_structured.get('labreference', '(KEY MISSING)')}")
    
    if existing and existing.get("structured_data"):
        # Merge new UI edits into existing flat data
        # This ensures we keep the 90 columns even if the app doesn't send them all back
        merged = {**existing["structured_data"], **new_structured}
    else:
        merged = new_structured

    print(f"DEBUG [update_report_in_db] merged labreference: {merged.get('labreference', '(KEY MISSING)')}")

    # Normalize time if present
    if "time" in merged and merged["time"]:
        merged["time"] = backend_normalize_time(merged["time"])

    if STORAGE_ENGINE == "supabase" and supabase:
        supabase.table("reports").update({"structured_data": merged}).eq("id", report_id).execute()
    else:
        conn = sqlite3.connect(str(DB_PATH))
        cursor = conn.cursor()
        cursor.execute("UPDATE reports SET structured_data = ? WHERE id = ?",
                       (json.dumps(merged), report_id))
        conn.commit()
        conn.close()

async def mark_report_sent(report_id: str):
    """Mark a report as verified and sent."""
    report = await get_report_by_id(report_id)
    if not report:
        raise Exception("Report not found")

    if STORAGE_ENGINE == "supabase" and supabase:
        supabase.table("reports").update({"user_verified": 1, "status": "sent"}).eq("id", report_id).execute()
        if report.get("structured_data"):
            sd = report["structured_data"]
            print(f"DEBUG [mark_report_sent] structured_data labreference: {sd.get('labreference', '(KEY MISSING)')}")
            print(f"DEBUG [mark_report_sent] structured_data original_labreference: {sd.get('original_labreference', '(KEY MISSING)')}")
            
            # Ensure only valid columns are inserted into staging_medical_records
            final_data = get_clean_flat_data(sd)
            final_data["report_id"] = report_id  # Link back to reports table for cascade delete
            
            print(f"DEBUG [mark_report_sent] final_data labreference: {final_data.get('labreference', '(KEY MISSING)')}")
            print(f"DEBUG [mark_report_sent] final_data original_labreference: {final_data.get('original_labreference', '(KEY MISSING)')}")
            print(f"DEBUG [mark_report_sent] final_data keys count: {len(final_data)}")
            # Safety sanitization: re-validate every value to prevent type mismatches
            # that could silently kill the entire insert (e.g., "2-4" in a NUMERIC column)
            sanitized_data = {}
            for k, v in final_data.items():
                if k == "report_id":
                    sanitized_data[k] = v
                    continue
                if v is None:
                    sanitized_data[k] = None
                    continue
                try:
                    sanitized_data[k] = validate_and_cast_value(k, v)
                except (ValueError, TypeError):
                    sanitized_data[k] = None
            
            print(f"DEBUG [mark_report_sent] sanitized labreference: {sanitized_data.get('labreference', '(KEY MISSING)')}")
            
            try:
                # Delete existing staging record for this report (if any), then insert fresh
                # This avoids dependency on a UNIQUE constraint for upsert
                supabase.table("staging_medical_records").delete().eq("report_id", report_id).execute()
            except Exception as del_err:
                print(f"DEBUG: Delete before insert failed (might be okay if record didn't exist): {del_err}")

            # Insertion loop that handles:
            # 1. Missing columns (PGRST204) - by deleting the missing column from payload
            # 2. Type mismatch (22P02, 22007, etc.) - by parsing Postgres error, mapping to key, and casting/nullifying
            # 3. Type mismatch (numeric cast failure) - by aggressively converting string ranges to floats for non-metadata fields
            max_attempts = 15
            performed_numeric_extraction = False
            for attempt in range(max_attempts):
                try:
                    supabase.table("staging_medical_records").insert(sanitized_data).execute()
                    print(f"DEBUG: Insert to staging_medical_records successful for report: {report_id} on attempt {attempt + 1}")
                    break
                except Exception as e:
                    err_msg = str(e)
                    print(f"DEBUG: Insert attempt {attempt + 1} failed: {err_msg}")
                    
                    # 1. Check for PostgREST missing column error (PGRST204)
                    missing_col_match = re.search(r"Could not find the '([^']+)' column", err_msg)
                    if missing_col_match:
                        missing_col = missing_col_match.group(1)
                        print(f"WARNING: Column '{missing_col}' does not exist in database. Removing from payload and retrying.")
                        if missing_col in sanitized_data:
                            del sanitized_data[missing_col]
                        if attempt < max_attempts - 1:
                            continue

                    # 2. Check for type syntax/cast error (e.g., 'invalid input syntax for type bigint: "SAMHEAL1"')
                    syntax_err_match = re.search(r'invalid input syntax for type ([^:]+): "([^"]+)"', err_msg)
                    if syntax_err_match:
                        expected_type = syntax_err_match.group(1).lower()
                        bad_value = syntax_err_match.group(2)
                        
                        bad_key = None
                        for k, v in sanitized_data.items():
                            if str(v) == bad_value:
                                bad_key = k
                                break
                        
                        if bad_key:
                            print(f"WARNING: Type mismatch for key '{bad_key}'. Database expected '{expected_type}' but got value '{bad_value}'.")
                            recovered = False
                            if "int" in expected_type or expected_type == "bigint":
                                num_match = re.search(r'(\d+)', bad_value)
                                if num_match:
                                    try:
                                        sanitized_data[bad_key] = int(num_match.group(1))
                                        print(f"  -> Recovered: cast '{bad_value}' to integer {sanitized_data[bad_key]}")
                                        recovered = True
                                    except Exception:
                                        pass
                            
                            if not recovered:
                                print(f"  -> Falling back: Setting key '{bad_key}' to None.")
                                sanitized_data[bad_key] = None
                                
                            if attempt < max_attempts - 1:
                                continue
                    
                    # 3. If it's a generic type mismatch, try aggressive numeric extraction once on biomarker fields
                    has_strings = any(isinstance(v, str) for k, v in sanitized_data.items() if k != "report_id")
                    if has_strings and not performed_numeric_extraction:
                        print("WARNING: Insert failed. Performing aggressive numeric extraction for string values and retrying.")
                        performed_numeric_extraction = True
                        metadata_keys = {
                            "medid", "original_medid", "labreference", "original_labreference", 
                            "report_reference", "collected", "time", "reported_time", "gender", "report_id"
                        }
                        for k, v in list(sanitized_data.items()):
                            if k in metadata_keys or v is None:
                                continue
                            if isinstance(v, str):
                                # Try to extract a number from strings that look like ranges/qualitative
                                match = re.search(r'(-?\d*\.?\d+)', str(v))
                                if match:
                                    try:
                                        sanitized_data[k] = float(match.group(1))
                                    except (ValueError, TypeError):
                                        sanitized_data[k] = None
                        if attempt < max_attempts - 1:
                            continue
                    
                    # If we can't recover or we've run out of attempts, raise the exception
                    print(f"DEBUG: Critical failure in staging insert on attempt {attempt + 1}: {e}")
                    print(f"DEBUG: Problematic data: {sanitized_data}")
                    raise Exception(f"Failed to write to staging_medical_records: {e}")
    else:
        conn = sqlite3.connect(str(DB_PATH))
        cursor = conn.cursor()
        cursor.execute("UPDATE reports SET user_verified = 1, status = 'sent' WHERE id = ?", (report_id,))
        conn.commit()
        conn.close()

async def get_report_by_id(report_id: str):
    if report_id in TEMP_REPORTS:
        report = dict(TEMP_REPORTS[report_id])
        report["user_verified"] = bool(report.get("user_verified", 0))
        return report

    if STORAGE_ENGINE == "supabase" and supabase:
        response = supabase.table("reports").select("*").eq("id", report_id).execute()
        if response.data and len(response.data) > 0:
            report = response.data[0]
            # Convert user_verified to bool for Flutter
            report["user_verified"] = bool(report.get("user_verified", 0))
            return report
        return None
    else:
        conn = sqlite3.connect(str(DB_PATH))
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM reports WHERE id = ?", (report_id,))
        row = cursor.fetchone()
        conn.close()
        if not row: return None
        report = dict(row)
        report["structured_data"] = json.loads(report["structured_data"]) if report["structured_data"] else None
        # Convert user_verified to bool for Flutter
        report["user_verified"] = bool(report.get("user_verified", 0))
        return report

async def delete_report(report_id: str):
    if STORAGE_ENGINE == "supabase" and supabase:
        try:
            supabase.table("staging_medical_records").delete().eq("report_id", report_id).execute()
        except Exception as e:
            print(f"[DELETE STAGING] Warning: {e}")
        supabase.table("reports").delete().eq("id", report_id).execute()
    else:
        conn = sqlite3.connect(str(DB_PATH))
        cursor = conn.cursor()
        cursor.execute("DELETE FROM staging_medical_records WHERE report_id = ?", (report_id,))
        cursor.execute("DELETE FROM reports WHERE id = ?", (report_id,))
        conn.commit()
        conn.close()

def backend_normalize_date(date_str):
    if not date_str: return ""
    # Strip time if exists (split by space or 'T')
    clean = date_str.replace('T', ' ').split(' ')[0]
    # Replace separators with /
    clean = clean.replace('-', '/').replace('.', '/')
    # Handle YYYY/MM/DD -> DD/MM/YYYY
    parts = clean.split('/')
    if len(parts) == 3:
        if len(parts[0]) == 4: # YYYY/MM/DD
            return f"{parts[2]}/{parts[1]}/{parts[0]}"
        # Ensure DD/MM/YYYY format with zero padding
        return f"{parts[0].zfill(2)}/{parts[1].zfill(2)}/{parts[2]}"
    return clean

def backend_compare_values(key: str, val1: str, val2: str) -> bool:
    if not val1 or not val2:
        return val1 == val2
        
    # Convert and normalize both to standard units
    def to_std_val_and_float(v):
        v_str = str(v).strip()
        if not v_str:
            return None, None
            
        # Parse value and extracted unit using our robust parser
        clean_val, ext_unit = split_value_and_unit(v_str)
            
        # Standard unit based on key
        # Standard unit based on key
        std_unit = get_standard_unit_for_key(key)
        
        # Strip signs like < or > for numeric conversion but keep them in clean_val
        num_clean = re.sub(r'[<>\s]', '', clean_val)
        
        # If conversion is possible
        if ext_unit and std_unit:
            try:
                converted = convert_unit(key, num_clean, ext_unit, std_unit)
                if converted is not None:
                    # Re-attach any prefix if needed, or just return the float
                    prefix = ""
                    if "<" in clean_val: prefix = "<"
                    elif ">" in clean_val: prefix = ">"
                    return f"{prefix}{converted}", float(converted)
            except:
                pass
                
        try:
            return clean_val, float(num_clean)
        except:
            return clean_val, None

    v1_clean, v1_num = to_std_val_and_float(val1)
    v2_clean, v2_num = to_std_val_and_float(val2)
    
    # If both are numeric, allow a 2% tolerance for conversion/rounding differences
    if v1_num is not None and v2_num is not None:
        # Check if they have the same sign (< or >)
        sign1 = "<" in str(val1) or ">" in str(val1)
        sign2 = "<" in str(val2) or ">" in str(val2)
        if sign1 != sign2:
            return False
            
        if v1_num == 0 or v2_num == 0:
            return v1_num == v2_num
            
        # Tolerance check (within 2%)
        return abs(v1_num - v2_num) / max(abs(v1_num), abs(v2_num)) <= 0.02
        
    # Fallback to string comparison for non-numeric/qualitative values or failed conversions
    if v1_clean is not None and v2_clean is not None:
        return v1_clean.strip().lower() == v2_clean.strip().lower()
    return False
        
    # Non-numeric or fallback to string compare
    s1 = str(v1_clean).strip().lower()
    s2 = str(v2_clean).strip().lower()
    return s1 == s2

def check_name_match(user_name: str, patient_name: str) -> bool:
    if not user_name or not patient_name:
        return False
    
    def tokenize(name: str) -> set:
        n = name.lower()
        titles = {"mr", "mrs", "ms", "miss", "dr", "mdm", "bin", "binte", "bte", "al", "ap", "anak", "dato", "datuk", "sri", "sir", "madam"}
        words = re.findall(r'\b[a-z]{2,}\b', n)
        return {w for w in words if w not in titles}

    user_tokens = tokenize(user_name)
    patient_tokens = tokenize(patient_name)
    
    if not user_tokens:
        user_tokens = {w for w in re.findall(r'\w+', user_name.lower()) if len(w) > 0}
    if not patient_tokens:
        patient_tokens = {w for w in re.findall(r'\w+', patient_name.lower()) if len(w) > 0}
        
    if not user_tokens or not patient_tokens:
        return False
        
    intersection = user_tokens.intersection(patient_tokens)
    return len(intersection) > 0

def check_gender_match(user_gender: str, patient_gender: str) -> bool:
    if not user_gender or not patient_gender:
        return True
    ug = user_gender.strip().lower()
    pg = patient_gender.strip().lower()
    is_user_male = ug.startswith('m') and not ug.startswith('f')
    is_user_female = ug.startswith('f')
    is_patient_male = pg.startswith('m') and not pg.startswith('f')
    is_patient_female = pg.startswith('f')
    
    if (is_user_male or is_user_female) and (is_patient_male or is_patient_female):
        return (is_user_male and is_patient_male) or (is_user_female and is_patient_female)
    return ug == pg

def parse_date_robust(date_str: str):
    import datetime
    if not date_str:
        return None
    s = str(date_str).strip()
    
    # Try YYYY-MM-DD
    m = re.match(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})', s)
    if m:
        try:
            return datetime.date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
        except ValueError:
            pass
            
    # Try DD/MM/YYYY or DD-MM-YYYY
    m = re.match(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})', s)
    if m:
        try:
            return datetime.date(int(m.group(3)), int(m.group(2)), int(m.group(1)))
        except ValueError:
            pass

    # Try DD-MMM-YYYY or DD MMM YYYY (e.g. 12 May 1985, 12-May-1985, 12/May/1985)
    months = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
        'january': 1, 'february': 2, 'march': 3, 'april': 4, 'june': 6,
        'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12
    }
    m = re.match(r'^(\d{1,2})[-/\s]+([a-zA-Z]+)[-/\s]+(\d{4})', s)
    if m:
        m_name = m.group(2).lower()
        if m_name in months:
            try:
                return datetime.date(int(m.group(3)), months[m_name], int(m.group(1)))
            except ValueError:
                pass
                
    # Try MMM DD, YYYY (e.g. May 12, 1985)
    m = re.match(r'^([a-zA-Z]+)[-/\s]+(\d{1,2})[-/,\s]+(\d{4})', s)
    if m:
        m_name = m.group(1).lower()
        if m_name in months:
            try:
                return datetime.date(int(m.group(3)), months[m_name], int(m.group(2)))
            except ValueError:
                pass
                
    return None

def extract_dob_from_ic(ic_str: str):
    if not ic_str:
        return None
    cleaned = re.sub(r'\D', '', str(ic_str))
    if len(cleaned) == 12:
        yy = int(cleaned[0:2])
        mm = int(cleaned[2:4])
        dd = int(cleaned[4:6])
        if 1 <= mm <= 12 and 1 <= dd <= 31:
            return (yy, mm, dd)
    m = re.search(r'\b(\d{2})(\d{2})(\d{2})[-]?\d{2}[-]?\d{4}\b', str(ic_str))
    if m:
        yy = int(m.group(1))
        mm = int(m.group(2))
        dd = int(m.group(3))
        if 1 <= mm <= 12 and 1 <= dd <= 31:
            return (yy, mm, dd)
    return None

def check_age_and_identity_match(
    user_dob_str: Optional[str],
    patient_dob_str: Optional[str],
    patient_ic_str: Optional[str],
    user_ic_str: Optional[str] = None
) -> bool:
    if not patient_dob_str and not patient_ic_str:
        return True

    # 1. Clean and verify IC Number match if both are present
    if user_ic_str and patient_ic_str:
        u_ic_clean = re.sub(r'[^a-zA-Z0-9]', '', str(user_ic_str)).upper()
        p_ic_clean = re.sub(r'[^a-zA-Z0-9]', '', str(patient_ic_str)).upper()
        if u_ic_clean and p_ic_clean and u_ic_clean != p_ic_clean:
            print(f"[IDENTITY MISMATCH] IC Number mismatch: User IC '{user_ic_str}' vs Patient IC '{patient_ic_str}'")
            return False

    u_dob = parse_date_robust(user_dob_str) if user_dob_str else None
    p_dob = parse_date_robust(patient_dob_str) if patient_dob_str else None
    
    # 2. Verify DOB match
    if u_dob and p_dob:
        if u_dob != p_dob:
            print(f"[IDENTITY MISMATCH] DOB mismatch: User DOB {u_dob} vs Patient DOB {p_dob}")
            return False
            
    # 3. Verify DOB against patient's IC-extracted DOB
    p_ic_dob = extract_dob_from_ic(patient_ic_str)
    if u_dob and p_ic_dob:
        uyy_last2 = u_dob.year % 100
        umm = u_dob.month
        udd = u_dob.day
        iyy, imm, idd = p_ic_dob
        if uyy_last2 != iyy or umm != imm or udd != idd:
            print(f"[IDENTITY MISMATCH] IC DOB mismatch: User DOB {u_dob} vs Patient IC DOB {iyy:02d}{imm:02d}{idd:02d}")
            return False

    return True

async def check_duplicate_report(user_id: str, new_data: dict, exclude_id: str = None):
    """
    Compares the newly parsed data with existing reports for the user.
    Uses a highly robust multi-attribute validation system based on the intersection
    of clinical keys (shared keys that are non-empty in both reports):
    1. Cleaned/Normalized Lab Reference Match (handles spaces/dashes).
    2. High Clinical Signature Overlap (shared keys count >= 3 and match percentage >= 90%, regardless of date).
    3. Low contradiction clinical match (shared keys count >= 2 and match percentage == 100%, without date/ID contradiction).
    4. Same Date + Same Patient ID Match (same date & patient ID, shared keys count >= 1 and match percentage >= 80%).
    5. Fuzzy Date Match (+/- 2 days) + Same Patient ID Match (shared keys count >= 2 and match percentage >= 80%).
    """
    try:
        if not new_data:
            return False
            
        def clean_ref(ref_str: str) -> str:
            # Remove all non-alphanumeric characters for clean string comparison
            return re.sub(r'[^A-Z0-9]', '', str(ref_str).strip().upper())
            
        # Extract new report identifiers
        new_date = backend_normalize_date(new_data.get("collected", ""))
        new_medid = str(new_data.get("medid", "")).strip().upper()
        new_labref = clean_ref(new_data.get("labreference", ""))
        new_report_ref = clean_ref(new_data.get("report_reference", new_data.get("sample_id", "")))
        
        print(f"\n[DUPLICATE CHECK] New Report: Date={new_date}, PatientID={new_medid}, CleanedLabNumber={new_labref}, CleanedReportRef={new_report_ref}")
        
        # Fetch all reports for this user
        if STORAGE_ENGINE == "supabase" and supabase:
            response = supabase.table("reports").select("*").eq("user_id", user_id).execute()
            existing_reports = response.data or []
        else:
            conn = sqlite3.connect(str(DB_PATH))
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM reports WHERE user_id = ?", (user_id,))
            existing_reports = [dict(row) for row in cursor.fetchall()]
            conn.close()

        for report in existing_reports:
            # Skip current
            if exclude_id and report.get("id") == exclude_id:
                continue

            s_data = report.get("structured_data")
            if isinstance(s_data, str):
                try: s_data = json.loads(s_data)
                except: continue
            
            if not s_data: continue
                
            # Extract existing report identifiers
            old_date = backend_normalize_date(s_data.get("collected", ""))
            old_medid = str(s_data.get("medid", "")).strip().upper()
            old_labref = clean_ref(s_data.get("labreference", ""))
            old_report_ref = clean_ref(s_data.get("report_reference", s_data.get("sample_id", "")))

            # Calculate clinical overlap based on INTERSECTION of present keys
            match_count = 0
            shared_keys = []
            metadata_keys = ["medid", "original_medid", "labreference", "original_labreference", "report_reference", "collected", "time", "reported_time"]
            
            for key in STAGING_SCHEMA_KEYS:
                if key in metadata_keys: continue
                
                new_val = str(new_data.get(key, "")).strip()
                old_val = str(s_data.get(key, "")).strip()
                
                # Check intersection (both must be non-empty)
                if new_val and old_val:
                    shared_keys.append(key)
                    if backend_compare_values(key, new_val, old_val):
                        match_count += 1
            
            num_shared = len(shared_keys)
            match_percentage = (match_count / num_shared * 100) if num_shared > 0 else 0.0
            
            print(f" -> Comparing to existing report: Date={old_date}, PatientID={old_medid}, LabRef={old_labref}")
            print(f"    Shared keys count: {num_shared}, Match count: {match_count}, Match percentage: {match_percentage:.1f}%")

            is_dup_current = False

            # --- CRITERIA 1: Exact Cleaned Report Reference Match ---
            if new_report_ref and old_report_ref and new_report_ref == old_report_ref:
                print(f" -> MATCH FOUND: Normalized Report Reference ({new_report_ref})")
                is_dup_current = True

            # --- CRITERIA 1B: Exact Cleaned Lab Number Match ---
            if new_labref and old_labref and new_labref == old_labref:
                print(f" -> MATCH FOUND: Normalized Lab Number ({new_labref})")
                is_dup_current = True

            # --- CRITERIA 2: High Clinical Match (Regardless of Date) ---
            # If they share >= 3 keys and >= 90% match, it's a duplicate
            if num_shared >= 3 and match_percentage >= 90:
                print(f" -> MATCH FOUND: High Clinical Fingerprint Overlap ({match_percentage:.1f}%)")
                is_dup_current = True
                
            # --- CRITERIA 3: Low Contradiction Clinical Match ---
            # If they share >= 2 keys, match 100%, and dates/IDs don't contradict (either match or one is missing)
            if num_shared >= 2 and match_percentage == 100:
                dates_dont_contradict = not new_date or not old_date or new_date == old_date
                ids_dont_contradict = not new_medid or not old_medid or new_medid == old_medid
                if dates_dont_contradict and ids_dont_contradict:
                    print(f" -> MATCH FOUND: 100% clinical match of shared keys ({num_shared} keys) without contradiction")
                    is_dup_current = True

            # --- CRITERIA 4: Same Date + Same Patient ID Match ---
            if new_date and old_date and new_date == old_date:
                medid_match = (not new_medid or not old_medid or new_medid == old_medid)
                if medid_match and num_shared >= 1 and match_percentage >= 80:
                    print(f" -> MATCH FOUND: Same Date & Patient ID with {match_percentage:.1f}% clinical match")
                    is_dup_current = True

            # --- CRITERIA 5: Fuzzy Date Match (+/- 2 days) + Same Patient ID Match ---
            if new_date and old_date:
                try:
                    from datetime import datetime
                    d1 = datetime.strptime(new_date, "%Y-%m-%d")
                    d2 = datetime.strptime(old_date, "%Y-%m-%d")
                    day_diff = abs((d1 - d2).days)
                    if day_diff <= 2:
                        medid_match = (not new_medid or not old_medid or new_medid == old_medid)
                        if medid_match and num_shared >= 2 and match_percentage >= 80:
                            print(f" -> MATCH FOUND: Fuzzy Date Match ({day_diff} days diff) & {match_percentage:.1f}% clinical match")
                            is_dup_current = True
                except Exception as ex:
                    pass

            if is_dup_current:
                return True

        print(" -> NO DUPLICATE FOUND")
        return False
    except Exception as e:
        import traceback
        print(f"[DUPLICATE ERROR] {e}")
        traceback.print_exc()
        return False

# ─── API Endpoints ──────────────────────────────────────────────────────────

@app.get("/")
async def root():
    return {
        "status": "ok", 
        "version": "3.0.0",
        "ocr_engine": "openai_vision", 
        "storage": STORAGE_ENGINE,
        "llm_model": OPENAI_MODEL,
        "gcp_support": HAS_GCP
    }

# ─── Auth Endpoints ─────────────────────────────────────────────────────────

@app.post("/api/auth/register")
async def register(req: RegisterRequest):
    if not req.email or not req.password or not req.name or not req.gender:
        raise HTTPException(status_code=400, detail="Email, name, password, and gender are required")
    if len(req.password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")
    
    # Auto-extract DOB from IC number if not provided
    dob = req.dob or ""
    if not dob and req.ic_number:
        ic_dob = extract_dob_from_ic(req.ic_number)
        if ic_dob:
            yy, mm, dd = ic_dob
            now_year = datetime.now().year
            century = (now_year // 100) * 100
            full_year = century + yy
            if full_year > now_year:
                full_year -= 100
            dob = f"{full_year}-{mm:02d}-{dd:02d}"
    
    if get_user_by_email(req.email):
        raise HTTPException(status_code=409, detail="Email already registered")
    if req.ic_number and get_user_by_ic(normalize_ic(req.ic_number)):
        raise HTTPException(status_code=409, detail="IC number already registered to another account")
    try:
        user = create_user(req.email, req.name, req.password, req.gender, dob, req.ic_number)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    token = create_jwt(user["id"], user["email"])
    return {
        "token": token,
        "user": {
            "id": user["id"],
            "email": user["email"],
            "name": user["name"],
            "gender": user["gender"],
            "dob": user["dob"],
            "ic_number": user["ic_number"]
        }
    }

@app.post("/api/auth/login")
async def login(req: LoginRequest):
    user = get_user_by_email(req.email)
    if not user or not verify_password(req.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    if user.get("status") == "inactive":
        raise HTTPException(status_code=403, detail="Account is inactive. Please contact support.")
    token = create_jwt(user["id"], user["email"])
    return {
        "token": token,
        "user": {
            "id": user["id"],
            "email": user["email"],
            "name": user["name"],
            "gender": user.get("gender"),
            "dob": user.get("dob"),
            "ic_number": user.get("ic_number")
        }
    }

@app.get("/api/auth/me")
async def get_me(current_user: dict = Depends(get_current_user)):
    return {
        "id": current_user["id"],
        "email": current_user["email"],
        "name": current_user["name"],
        "gender": current_user.get("gender"),
        "dob": current_user.get("dob"),
        "ic_number": current_user.get("ic_number")
    }

@app.put("/api/auth/profile")
async def update_profile(updated_data: dict, current_user: dict = Depends(get_current_user)):
    name = updated_data.get("name")
    email = updated_data.get("email")
    gender = updated_data.get("gender")
    dob = updated_data.get("dob")
    ic_number = updated_data.get("ic_number")
    if not name or not email:
        raise HTTPException(status_code=400, detail="Name and email are required")
    
    try:
        update_user_profile(current_user["id"], name, email, gender, dob=dob, ic_number=ic_number)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    # Fetch updated user to get accurate fields
    user = get_user_by_id(current_user["id"])
    return {
        "status": "success", 
        "user": {
            "id": current_user["id"], 
            "email": email, 
            "name": name, 
            "gender": user.get("gender") if user else gender,
            "dob": user.get("dob") if user else dob,
            "ic_number": user.get("ic_number") if user else ic_number
        }
    }

@app.post("/api/auth/deactivate")
async def deactivate_account(current_user: dict = Depends(get_current_user)):
    set_user_inactive(current_user["id"])
    return {"status": "success", "message": "Account deactivated"}

@app.post("/api/auth/password")
async def change_password(data: dict, current_user: dict = Depends(get_current_user)):
    current_password = data.get("current_password")
    new_password = data.get("new_password")
    if not current_password or not new_password:
        raise HTTPException(status_code=400, detail="Current and new password are required")
    
    # Get user to verify current password
    user = get_user_by_id(current_user["id"])
    if not user or not verify_password(current_password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Incorrect current password")
    
    update_user_password(current_user["id"], new_password)
    return {"status": "success", "message": "Password updated successfully"}

# ─── My Reports ─────────────────────────────────────────────────────────────

@app.get("/api/reports/my")
async def get_my_reports(current_user: dict = Depends(get_current_user)):
    user_id = current_user["id"]
    if STORAGE_ENGINE == "supabase" and supabase:
        response = supabase.table("reports").select("*").eq("user_id", user_id).eq("status", "sent").order("upload_time", desc=True).execute()
        reports = response.data or []
        for r in reports:
            r["user_verified"] = bool(r.get("user_verified", 0))
        return reports
    else:
        conn = sqlite3.connect(str(DB_PATH))
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM reports WHERE user_id = ? AND status = 'sent' ORDER BY upload_time DESC", (user_id,))
        rows = cursor.fetchall()
        conn.close()
        results = []
        for row in rows:
            r = dict(row)
            r["structured_data"] = json.loads(r["structured_data"]) if r["structured_data"] else None
            r["user_verified"] = bool(r.get("user_verified", 0))
            results.append(r)
        return results

@app.get("/api/reports/analyze")
async def analyze_health_trends(
    query: Optional[str] = None, 
    start_date: Optional[str] = None, 
    end_date: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    user_id = current_user["id"]
    if STORAGE_ENGINE == "supabase" and supabase:
        # Fully utilize staging_medical_records: only fetch reports that have been verified and staged
        response = supabase.table("staging_medical_records").select("*, reports!inner(*)").eq("reports.user_id", user_id).execute()
        staged_records = response.data or []
        
        reports = []
        for row in staged_records:
            # Reconstruct the expected report object for the frontend
            r = row["reports"]
            r["structured_data"] = {
                "patient_id": row.get("medid"),
                "date": row.get("collected"),
                "results": [{"key": k, "value": v} for k, v in row.items() if k not in ["staging_record_id", "report_id", "reports"] and v is not None]
            }
            reports.append(r)
            
        # Sort manually since we joined
        reports.sort(key=lambda x: x.get("upload_time", ""), reverse=False)

    else:
        # SQLite fallback joining staging_medical_records
        conn = sqlite3.connect(str(DB_PATH))
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute('''
            SELECT s.*, r.upload_time, r.status, r.filename 
            FROM staging_medical_records s
            JOIN reports r ON s.report_id = r.id
            WHERE r.user_id = ? ORDER BY r.upload_time ASC
        ''', (user_id,))
        rows = cursor.fetchall()
        conn.close()
        reports = []
        for row in rows:
            d = dict(row)
            r = {
                "upload_time": d.pop("upload_time"),
                "status": d.pop("status"),
                "filename": d.pop("filename"),
                "structured_data": {
                    "patient_id": d.get("medid"),
                    "date": d.get("collected"),
                    "results": [{"key": k, "value": v} for k, v in d.items() if k not in ["staging_record_id", "report_id"] and v is not None]
                }
            }
            reports.append(r)

    # Filter completed/sent reports with structured data
    valid_reports = [r for r in reports if r.get("status") in ["completed", "sent"] and r.get("structured_data") and r["structured_data"].get("results")]
    
    if not valid_reports:
        return {"analysis": "Insufficient clinical data available for analysis. Please upload your medical reports to begin."}

    # Helper for date parsing
    def parse_dt(date_str: str, fallback_str: str) -> datetime:
        if not date_str:
            return datetime.fromisoformat(fallback_str)
        formats = [
            "%d %b %Y", "%d %B %Y", "%b %d, %Y", "%B %d, %Y",
            "%d/%m/%Y", "%m/%d/%Y", "%Y/%m/%d",
            "%Y-%m-%d", "%d-%m-%Y"
        ]
        for fmt in formats:
            try:
                return datetime.strptime(date_str.strip(), fmt)
            except ValueError:
                pass
        try:
            return datetime.fromisoformat(date_str.strip())
        except ValueError:
            pass
        return datetime.fromisoformat(fallback_str)

    # Sort reports chronologically
    valid_reports.sort(key=lambda x: parse_dt(x.get("structured_data", {}).get("date"), x["upload_time"]))
    
    # Apply date range filtering if requested
    if start_date and end_date:
        try:
            s_dt = datetime.fromisoformat(start_date.replace('Z', '+00:00'))
            e_dt = datetime.fromisoformat(end_date.replace('Z', '+00:00'))
            valid_reports = [
                r for r in valid_reports 
                if s_dt <= parse_dt(r.get("structured_data", {}).get("date"), r["upload_time"]) <= e_dt
            ]
        except Exception as e:
            print(f"Date filtering failed: {e}")

    if not valid_reports:
        return {"analysis": "No medical reports found within the selected date range."}

    data_summary = []
    for r in valid_reports:
        date_str = r.get("structured_data", {}).get("date") or r["upload_time"][:10]
        results_list = r["structured_data"]["results"]
        items = [line for res in results_list if (line := _format_result_line(res))]
        if items:
            data_summary.append(f"Examination Date: {date_str}\n" + "\n".join(items))

    if not data_summary:
        return {"analysis": "No diagnostic biomarkers found in the selected reports."}

    compiled_data = "\n\n".join(data_summary)

    prompt = f"""
    You are a highly qualified clinical medical consultant. Your task is to analyze the following longitudinal patient data and provide a professional clinical assessment.
    
    PATIENT DATA HISTORY:
    {compiled_data}
    
    ANALYTICAL CONSTRAINTS:
    1. EXCLUSIVITY: You MUST base your clinical interpretation ONLY on the exact attribute values provided below.
    2. RAW DATA ONLY: Do NOT perform statistical averaging, median calculations, or maximum-only analysis. Treat each time point as a distinct clinical event.
    3. PROFESSIONALISM: Use formal healthcare terminology and professional bedside manner. Avoid colloquialisms.
    4. TREND FOCUS: Identify significant physiological shifts or stabilities between specific dates.
    """
    
    if query and query.strip():
        prompt += f"\n\nCLINICAL INQUIRY: The patient has requested clarification on the following: '{query.strip()}'. Address this within the context of the observed trends."
    else:
        prompt += "\n\nOBJECTIVE: Provide a comprehensive diagnostic trend overview."

    prompt += """
    
    STRUCTURE OF CLINICAL REPORT:
    1. ### Clinical Executive Summary: A concise professional overview of the patient's current health status based on the provided history.
    2. ### Longitudinal Biomarker Analysis: Detail specific biomarker shifts (e.g., "Hemoglobin increased from 13.2 g/dL on Jan 1 to 14.5 g/dL on Mar 15"). Reference exact dates and values.
    3. ### Clinical Red Flags: Explicitly flag any values deviating from standard clinical reference ranges.
    4. ### Clinical Correlations & Implications: Discuss the potential physiological implications of these trends.
    5. ### Evidence-Based Recommendations: Provide actionable, data-driven lifestyle or dietary interventions.
    
    FORMATTING:
    - Use **bold** for clinical values, specific dates, and biomarkers.
    - Use *italic* for medical terms or secondary terminology.
    - Use bullet points for scannability.
    - Maintain a word count between 300 and 450 words.
    
    Return ONLY the markdown analysis.
    """

    try:
        response = llm_client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=[
                {"role": "system", "content": "You are a professional clinical consultant providing high-fidelity medical trend analysis. You strictly use provided raw data and never average results."},
                {"role": "user", "content": prompt}
            ]
        )
        analysis_text = response.choices[0].message.content.strip()
        return {"analysis": analysis_text}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Clinical analysis engine error: {e}")

def is_placeholder_health_summary(summary: Optional[str]) -> bool:
    """True when cache holds an empty-state message, not a real LLM summary."""
    if not summary or not str(summary).strip():
        return True
    lower = str(summary).lower()
    return (
        "please upload" in lower
        or "insufficient clinical" in lower
        or "no diagnostic biomarkers" in lower
    )


def user_has_staged_reports(user_id: str) -> bool:
    """Whether the user has at least one staged lab record linked to their reports."""
    if STORAGE_ENGINE == "supabase" and supabase:
        try:
            res = (
                supabase.table("staging_medical_records")
                .select("staging_record_id, reports!inner(user_id)")
                .eq("reports.user_id", user_id)
                .limit(1)
                .execute()
            )
            return bool(res.data)
        except Exception as e:
            print(f"[CACHE] Staged records check failed: {e}")
            return False
    try:
        conn = sqlite3.connect(str(DB_PATH))
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT 1 FROM staging_medical_records s
            JOIN reports r ON s.report_id = r.id
            WHERE r.user_id = ? LIMIT 1
            """,
            (user_id,),
        )
        row = cursor.fetchone()
        conn.close()
        return row is not None
    except Exception as e:
        print(f"[CACHE] Staged records check failed: {e}")
        return False


def _supabase_health_summary_available() -> bool:
    """True if users.health_summary column exists (optional migration)."""
    if STORAGE_ENGINE != "supabase" or not supabase:
        return False
    try:
        supabase.table("users").select("health_summary").limit(1).execute()
        return True
    except Exception:
        return False


def invalidate_health_summary_cache(user_id: str):
    """Clear cached summary so the next request regenerates from current data."""
    if _supabase_health_summary_available():
        try:
            supabase.table("users").update({"health_summary": None}).eq("id", user_id).execute()
        except Exception as e:
            print(f"[CACHE] Supabase health_summary clear failed: {e}")
    try:
        conn = sqlite3.connect(str(DB_PATH))
        cursor = conn.cursor()
        cursor.execute("DELETE FROM health_summary_cache WHERE user_id = ?", (user_id,))
        conn.commit()
        conn.close()
    except Exception as e:
        print(f"[CACHE ERROR] Failed to clear health_summary cache: {e}")


def get_cached_health_summary(user_id: str) -> Optional[str]:
    if _supabase_health_summary_available():
        try:
            res = supabase.table("users").select("health_summary").eq("id", user_id).execute()
            if res.data and res.data[0].get("health_summary"):
                return res.data[0]["health_summary"]
        except Exception as e:
            print(f"[CACHE] Supabase health_summary fetch failed: {e}")
    try:
        conn = sqlite3.connect(str(DB_PATH))
        cursor = conn.cursor()
        cursor.execute("SELECT summary FROM health_summary_cache WHERE user_id = ?", (user_id,))
        row = cursor.fetchone()
        conn.close()
        if row:
            return row[0]
    except Exception as e:
        print(f"[CACHE ERROR] Failed to fetch health_summary from local SQLite cache: {e}")
    return None


def update_cached_health_summary(user_id: str, summary: Optional[str]):
    if _supabase_health_summary_available():
        try:
            supabase.table("users").update({"health_summary": summary}).eq("id", user_id).execute()
        except Exception as e:
            print(f"[CACHE] Supabase health_summary update failed: {e}")
    try:
        conn = sqlite3.connect(str(DB_PATH))
        cursor = conn.cursor()
        cursor.execute("DELETE FROM health_summary_cache WHERE user_id = ?", (user_id,))
        if summary is not None:
            updated_at = datetime.now().isoformat()
            cursor.execute(
                "INSERT INTO health_summary_cache (user_id, summary, updated_at) VALUES (?, ?, ?)",
                (user_id, summary, updated_at),
            )
        conn.commit()
        conn.close()
    except Exception as e:
        print(f"[CACHE ERROR] Failed to update health_summary in local SQLite cache: {e}")


def _format_result_line(res: dict) -> Optional[str]:
    """Build a single biomarker line from staging or structured_data result dict."""
    v = res.get("value")
    if v is None or str(v).strip() in ("", "-"):
        return None
    label = (res.get("test_item") or res.get("key") or "").strip()
    unit = (res.get("unit") or "").strip()
    if label:
        return f"{label}: {v} {unit}".strip()
    return str(v).strip()

async def generate_and_cache_health_summary(user_id: str) -> str:
    """Generates the health summary using LLM and updates the cache."""
    if STORAGE_ENGINE == "supabase" and supabase:
        response = supabase.table("staging_medical_records").select("*, reports!inner(*)").eq("reports.user_id", user_id).execute()
        staged_records = response.data or []
        
        reports = []
        for row in staged_records:
            r = row["reports"]
            r["structured_data"] = {
                "patient_id": row.get("medid"),
                "date": row.get("collected"),
                "results": [{"key": k, "value": v} for k, v in row.items() if k not in ["staging_record_id", "report_id", "reports"] and v is not None]
            }
            reports.append(r)
            
        reports.sort(key=lambda x: x.get("upload_time", ""), reverse=False)

    else:
        conn = sqlite3.connect(str(DB_PATH))
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute('''
            SELECT s.*, r.upload_time, r.status, r.filename 
            FROM staging_medical_records s
            JOIN reports r ON s.report_id = r.id
            WHERE r.user_id = ? ORDER BY r.upload_time ASC
        ''', (user_id,))
        rows = cursor.fetchall()
        conn.close()
        reports = []
        for row in rows:
            d = dict(row)
            r = {
                "upload_time": d.pop("upload_time"),
                "status": d.pop("status"),
                "filename": d.pop("filename"),
                "structured_data": {
                    "patient_id": d.get("medid"),
                    "date": d.get("collected"),
                    "results": [{"key": k, "value": v} for k, v in d.items() if k not in ["staging_record_id", "report_id"] and v is not None]
                }
            }
            reports.append(r)

    valid_reports = [r for r in reports if r.get("status") in ["completed", "sent"] and r.get("structured_data") and r["structured_data"].get("results")]
    
    if not valid_reports:
        summary_text = "Please upload some medical reports to see your AI health summary here."
        update_cached_health_summary(user_id, summary_text)
        return summary_text

    def parse_dt(date_str: str, fallback_str: str) -> datetime:
        if not date_str:
            return datetime.fromisoformat(fallback_str)
        formats = [
            "%d %b %Y", "%d %B %Y", "%b %d, %Y", "%B %d, %Y",
            "%d/%m/%Y", "%m/%d/%Y", "%Y/%m/%d",
            "%Y-%m-%d", "%d-%m-%Y"
        ]
        for fmt in formats:
            try:
                return datetime.strptime(date_str.strip(), fmt)
            except ValueError:
                pass
        try:
            return datetime.fromisoformat(date_str.strip())
        except ValueError:
            pass
        return datetime.fromisoformat(fallback_str)

    valid_reports.sort(key=lambda x: parse_dt(x.get("structured_data", {}).get("date"), x["upload_time"]))

    data_summary = []
    for r in valid_reports:
        date_str = r.get("structured_data", {}).get("date") or r["upload_time"][:10]
        results_list = r["structured_data"]["results"]
        items = []
        for res in results_list:
            line = _format_result_line(res)
            if line:
                items.append(line)
        if items:
            data_summary.append(f"Date: {date_str}\n" + "\n".join(items))

    if not data_summary:
        summary_text = "Please upload some medical reports with biomarker values to see your AI health summary here."
        update_cached_health_summary(user_id, summary_text)
        return summary_text

    compiled_data = "\n\n".join(data_summary)

    prompt = f"""
    You are an empathetic, warm, and highly professional clinical AI assistant. Your task is to provide a highly concise, information-dense, layman-friendly health summary for a patient based on their medical report history.

    PATIENT MEDICAL HISTORY DATA:
    {compiled_data}

    YOUR TASKS:
    1. SUMMARY: Provide a single direct sentence summarizing the overall health trajectory based on the latest data.
    2. ABNORMAL BIOMARKERS & PHYSIOLOGICAL CORRELATIONS: Compactly identify biomarkers that are out of standard clinical reference ranges, stating their exact values. Explain in a single simple sentence how these out-of-range metrics physiologically connect (e.g. how lipid and glucose issues relate to metabolic energy).
    3. ACTIONABLE STEPS: Suggest exactly 2 simple, high-impact, and supportive lifestyle/dietary adjustments.

    CONSTRAINTS:
    - Tone/Language: Empathetic, supportive, and in simple layman terms. Use plain English; define any necessary medical terms instantly.
    - Style: Start directly with the analysis. STRICTLY avoid introductory sentences (like "Based on your reports...") or polite final remarks (like "Consult your doctor..."). 
    - Formatting: Clean markdown. Use **bolding** for biomarker names and values/units. Use concise bullet points for scannability.
    - Length: Word count MUST be between 100 to 175 words. Do not exceed this limit; it must fit compactly on a mobile dashboard screen while preserving all key clinical data points.
    - Do not include any HTML tags.
    """

    response = llm_client.chat.completions.create(
        model=OPENAI_MODEL,
        messages=[
            {"role": "system", "content": "You are a warm, supportive, and expert clinical AI assistant summarizing patient lab reports in simple layman terms."},
            {"role": "user", "content": prompt}
        ]
    )
    summary_text = response.choices[0].message.content.strip()
    update_cached_health_summary(user_id, summary_text)
    return summary_text

@app.get("/api/reports/health-summary")
async def get_health_summary(current_user: dict = Depends(get_current_user)):
    user_id = current_user["id"]
    cached_summary = get_cached_health_summary(user_id)
    # Regenerate when cache still says "upload reports" but CSV/import data exists
    if cached_summary and not (
        is_placeholder_health_summary(cached_summary) and user_has_staged_reports(user_id)
    ):
        return {"summary": cached_summary}

    try:
        summary_text = await generate_and_cache_health_summary(user_id)
        return {"summary": summary_text}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Summary generation error: {e}")


@app.post("/api/chat/sessions")
async def create_chat_session(request: CreateSessionRequest, current_user: dict = Depends(get_current_user)):
    user_id = current_user["id"]
    session_id = str(uuid.uuid4())
    created_at = datetime.now().isoformat()
    
    summary = get_cached_health_summary(user_id)
    if not summary:
        try:
            summary = await generate_and_cache_health_summary(user_id)
        except Exception:
            summary = "Hello! I'm your AI Clinical Consultant."

    if STORAGE_ENGINE == "supabase" and supabase:
        supabase.table("chat_sessions").insert({
            "id": session_id,
            "user_id": user_id,
            "created_at": created_at,
            "title": request.title
        }).execute()
        
        # Save summary as first assistant message
        msg_id = str(uuid.uuid4())
        supabase.table("chat_messages").insert({
            "id": msg_id,
            "session_id": session_id,
            "role": "assistant",
            "content": summary,
            "timestamp": created_at
        }).execute()
    else:
        conn = sqlite3.connect(str(DB_PATH))
        conn.execute(
            "INSERT INTO chat_sessions (id, user_id, created_at, title) VALUES (?, ?, ?, ?)",
            (session_id, user_id, created_at, request.title)
        )
        
        # Save summary as first assistant message
        msg_id = str(uuid.uuid4())
        conn.execute(
            "INSERT INTO chat_messages (id, session_id, role, content, timestamp) VALUES (?, ?, ?, ?, ?)",
            (msg_id, session_id, "assistant", summary, created_at)
        )
        conn.commit()
        conn.close()
    return {"id": session_id, "title": request.title}

@app.get("/api/chat/sessions")
async def get_chat_sessions(current_user: dict = Depends(get_current_user)):
    user_id = current_user["id"]
    if STORAGE_ENGINE == "supabase" and supabase:
        response = supabase.table("chat_sessions").select("*").eq("user_id", user_id).order("created_at", desc=True).execute()
        return response.data or []
    else:
        conn = sqlite3.connect(str(DB_PATH))
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM chat_sessions WHERE user_id = ? ORDER BY created_at DESC", (user_id,))
        rows = cursor.fetchall()
        conn.close()
        return [dict(r) for r in rows]

@app.get("/api/chat/sessions/{session_id}/messages")
async def get_chat_messages(session_id: str, current_user: dict = Depends(get_current_user)):
    if STORAGE_ENGINE == "supabase" and supabase:
        response = supabase.table("chat_messages").select("*").eq("session_id", session_id).order("timestamp", desc=False).execute()
        return response.data or []
    else:
        conn = sqlite3.connect(str(DB_PATH))
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM chat_messages WHERE session_id = ? ORDER BY timestamp ASC", (session_id,))
        rows = cursor.fetchall()
        conn.close()
        return [dict(r) for r in rows]

@app.delete("/api/chat/sessions/{session_id}")
async def delete_chat_session(session_id: str, current_user: dict = Depends(get_current_user)):
    """Delete a chat session and all its messages."""
    user_id = current_user["id"]
    if STORAGE_ENGINE == "supabase" and supabase:
        # Verify ownership
        session = supabase.table("chat_sessions").select("*").eq("id", session_id).eq("user_id", user_id).execute()
        if not session.data:
            raise HTTPException(status_code=404, detail="Session not found")
        supabase.table("chat_messages").delete().eq("session_id", session_id).execute()
        supabase.table("chat_sessions").delete().eq("id", session_id).eq("user_id", user_id).execute()
    else:
        conn = sqlite3.connect(str(DB_PATH))
        cursor = conn.cursor()
        cursor.execute("SELECT id FROM chat_sessions WHERE id = ? AND user_id = ?", (session_id, user_id))
        if not cursor.fetchone():
            conn.close()
            raise HTTPException(status_code=404, detail="Session not found")
        conn.execute("DELETE FROM chat_messages WHERE session_id = ?", (session_id,))
        conn.execute("DELETE FROM chat_sessions WHERE id = ? AND user_id = ?", (session_id, user_id))
        conn.commit()
        conn.close()
    return {"status": "deleted"}

@app.post("/api/reports/analyze/stream")
async def analyze_health_trends_stream(
    request: AnalyzeRequest,
    current_user: dict = Depends(get_current_user)
):
    """Stream AI analysis token-by-token using Server-Sent Events, including history."""
    user_id = current_user["id"]
    query = request.query
    start_date = request.start_date
    end_date = request.end_date
    if STORAGE_ENGINE == "supabase" and supabase:
        response = supabase.table("reports").select("*").eq("user_id", user_id).order("upload_time", desc=True).execute()
        reports = response.data or []
    else:
        conn = sqlite3.connect(str(DB_PATH))
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM reports WHERE user_id = ? ORDER BY upload_time ASC", (user_id,))
        rows = cursor.fetchall()
        conn.close()
        reports = []
        for row in rows:
            r = dict(row)
            r["structured_data"] = json.loads(r["structured_data"]) if r["structured_data"] else None
            reports.append(r)

    valid_reports = [r for r in reports if r.get("status") in ["completed", "sent"] and r.get("structured_data") and r["structured_data"].get("results")]
    
    if not valid_reports:
        async def empty_gen():
            yield "data: No medical reports found for analysis.\n\n"
            yield "data: [DONE]\n\n"
        return StreamingResponse(empty_gen(), media_type="text/event-stream")

    def parse_dt(date_str, fallback_str):
        if not date_str:
            return datetime.fromisoformat(fallback_str)
        formats = ["%d %b %Y", "%d %B %Y", "%b %d, %Y", "%B %d, %Y", "%d/%m/%Y", "%m/%d/%Y", "%Y/%m/%d", "%Y-%m-%d", "%d-%m-%Y", "%d / %m / %Y"]
        for fmt in formats:
            try: return datetime.strptime(date_str.strip(), fmt)
            except ValueError: pass
        try: return datetime.fromisoformat(date_str.strip())
        except ValueError: pass
        return datetime.fromisoformat(fallback_str)

    valid_reports.sort(key=lambda x: parse_dt(x.get("structured_data", {}).get("date"), x["upload_time"]))
    
    if start_date and end_date:
        try:
            s_dt = datetime.fromisoformat(start_date.replace('Z', '+00:00'))
            e_dt = datetime.fromisoformat(end_date.replace('Z', '+00:00'))
            valid_reports = [r for r in valid_reports if s_dt <= parse_dt(r.get("structured_data", {}).get("date"), r["upload_time"]) <= e_dt]
        except Exception: pass

    if not valid_reports:
        async def no_data_gen():
            yield "data: No reports found within the selected date range.\n\n"
            yield "data: [DONE]\n\n"
        return StreamingResponse(no_data_gen(), media_type="text/event-stream")

    data_summary = []
    for r in valid_reports:
        date_str = r.get("structured_data", {}).get("date") or r["upload_time"][:10]
        results_list = r["structured_data"]["results"]
        items = [line for res in results_list if (line := _format_result_line(res))]
        if items:
            data_summary.append(f"Examination Date: {date_str}\n" + "\n".join(items))

    if not data_summary:
        async def no_biomarkers_gen():
            yield "data: No diagnostic biomarkers found in the selected reports.\n\n"
            yield "data: [DONE]\n\n"
        return StreamingResponse(no_biomarkers_gen(), media_type="text/event-stream")

    compiled_data = "\n\n".join(data_summary)
    prompt = f"""
    You are a highly qualified clinical medical consultant. Your task is to analyze the following longitudinal patient data and provide a professional clinical assessment.
    
    PATIENT DATA HISTORY:
    {compiled_data}
    
    ANALYTICAL CONSTRAINTS:
    1. EXCLUSIVITY: You MUST base your clinical interpretation ONLY on the exact attribute values provided below.
    2. RAW DATA ONLY: Do NOT perform statistical averaging, median calculations, or maximum-only analysis. Treat each time point as a distinct clinical event.
    3. PROFESSIONALISM: Use formal healthcare terminology and professional bedside manner. Avoid colloquialisms.
    4. TREND FOCUS: Identify significant physiological shifts or stabilities between specific dates.
    """
    
    if query and query.strip():
        prompt += f"\n\nCLINICAL INQUIRY: The patient has requested clarification on the following: '{query.strip()}'. Address this within the context of the observed trends."
    else:
        prompt += "\n\nOBJECTIVE: Provide a comprehensive diagnostic trend overview."

    prompt += """
    
    STRUCTURE OF CLINICAL REPORT:
    1. ### Clinical Executive Summary: A concise professional overview of the patient's current health status based on the provided history.
    2. ### Longitudinal Biomarker Analysis: Detail specific biomarker shifts (e.g., "Hemoglobin increased from 13.2 g/dL on Jan 1 to 14.5 g/dL on Mar 15"). Reference exact dates and values.
    3. ### Clinical Red Flags: Explicitly flag any values deviating from standard clinical reference ranges.
    4. ### Clinical Correlations & Implications: Discuss the potential physiological implications of these trends.
    5. ### Evidence-Based Recommendations: Provide actionable, data-driven lifestyle or dietary interventions.
    
    FORMATTING:
    - Use **bold** for clinical values, specific dates, and biomarkers.
    - Use *italic* for medical terms or secondary terminology.
    - Use bullet points for scannability.
    - Maintain a word count between 300 and 450 words.
    
    Return ONLY the markdown analysis.
    """

    llm_messages = [
        {"role": "system", "content": "You are a professional clinical consultant providing high-fidelity medical trend analysis. You strictly use provided raw data and never average results."}
    ]
    
    # Add context (the data + instructions) as a system message
    llm_messages.append({"role": "system", "content": prompt})

    # Add conversation history
    if request.messages:
        for msg in request.messages:
            llm_messages.append({"role": msg.role, "content": msg.content})

    # If there's a new query and no history, it's handled by the prompt above.
    # If there's a new query and we DO have history, append it as a user message.
    if request.messages and query and query.strip():
        llm_messages.append({"role": "user", "content": query.strip()})
    elif not request.messages and not (query and query.strip()):
        # Just generate overview
        llm_messages.append({"role": "user", "content": "Please provide the clinical analysis based on my data."})

    async def token_generator():
        try:
            if request.session_id and query and query.strip():
                msg_id = str(uuid.uuid4())
                ts = datetime.now().isoformat()
                if STORAGE_ENGINE == "supabase" and supabase:
                    supabase.table("chat_messages").insert({
                        "id": msg_id,
                        "session_id": request.session_id,
                        "role": "user",
                        "content": query.strip(),
                        "timestamp": ts
                    }).execute()
                elif STORAGE_ENGINE == "sqlite":
                    conn = sqlite3.connect(str(DB_PATH))
                    conn.execute(
                        "INSERT INTO chat_messages (id, session_id, role, content, timestamp) VALUES (?, ?, ?, ?, ?)",
                        (msg_id, request.session_id, "user", query.strip(), ts)
                    )
                    conn.commit()
                    conn.close()

            stream = llm_client.chat.completions.create(
                model=OPENAI_MODEL,
                messages=llm_messages,
                stream=True
            )
            assistant_content = ""
            for chunk in stream:
                if chunk.choices and chunk.choices[0].delta and chunk.choices[0].delta.content:
                    token = chunk.choices[0].delta.content
                    assistant_content += token
                    yield f"data: {json.dumps({'token': token})}\n\n"
            
            if request.session_id:
                msg_id = str(uuid.uuid4())
                ts = datetime.now().isoformat()
                if STORAGE_ENGINE == "supabase" and supabase:
                    supabase.table("chat_messages").insert({
                        "id": msg_id,
                        "session_id": request.session_id,
                        "role": "assistant",
                        "content": assistant_content,
                        "timestamp": ts
                    }).execute()
                elif STORAGE_ENGINE == "sqlite":
                    conn = sqlite3.connect(str(DB_PATH))
                    conn.execute(
                        "INSERT INTO chat_messages (id, session_id, role, content, timestamp) VALUES (?, ?, ?, ?, ?)",
                        (msg_id, request.session_id, "assistant", assistant_content, ts)
                    )
                    conn.commit()
                    conn.close()

            yield "data: [DONE]\n\n"
        except Exception as e:
            yield f"data: {json.dumps({'error': str(e)})}\n\n"
            yield "data: [DONE]\n\n"

    return StreamingResponse(token_generator(), media_type="text/event-stream")

@app.post("/api/upload")
async def upload_report(file: UploadFile = File(...), force: bool = False, current_user: dict = Depends(get_current_user)):
    """Upload an image, run OCR + LLM parsing, return structured data."""
    report_id = str(uuid.uuid4())
    file_ext = Path(file.filename).suffix or ".jpg"
    file_path = UPLOAD_DIR / f"{report_id}{file_ext}"

    async with aiofiles.open(file_path, "wb") as f:
        content = await file.read()
        await f.write(content)

    report_metadata = {
        "id": report_id,
        "user_id": current_user["id"],
        "filename": file.filename,
        "upload_time": datetime.now().isoformat(),
        "status": "processing",
        "file_path": str(file_path),
        "raw_text": None,
        "structured_data": None,
        "user_verified": 0
    }
    
    try:
        # Use OpenAI Vision to extract data directly from the image
        structured_data = await parse_medical_report_llm(file_path)
        raw_text = f"Extracted via OpenAI Vision API (1 page)"

        # Set default values for demographics if missing
        user_dob = current_user.get("dob")
        user_ic = current_user.get("ic_number")

        if user_dob and not structured_data.get("dob"):
            structured_data["dob"] = user_dob
        if user_ic and not structured_data.get("ic_number"):
            structured_data["ic_number"] = user_ic

        is_name_mismatched = False
        is_gender_mismatched = False
        is_age_mismatched = False
        is_duplicate = False

        if not force:
            # --- NAME VALIDATION ---
            user_name = current_user.get("name", "")
            patient_name = structured_data.get("patient_name", "")
            if patient_name and not check_name_match(user_name, patient_name):
                is_name_mismatched = True

            # --- GENDER VALIDATION ---
            user_gender = current_user.get("gender", "")
            patient_gender = structured_data.get("gender", "")
            if user_gender and patient_gender and not check_gender_match(user_gender, patient_gender):
                is_gender_mismatched = True

            # --- AGE & IDENTITY VALIDATION ---
            patient_dob = structured_data.get("dob", "")
            patient_ic = structured_data.get("ic_number", "")

            if (user_dob or user_ic) and not check_age_and_identity_match(
                user_dob, patient_dob, patient_ic, user_ic
            ):
                is_age_mismatched = True

            # --- DUPLICATE CHECK ---
            try:
                is_duplicate = await check_duplicate_report(current_user["id"], structured_data, exclude_id=report_id)
            except Exception as e:
                print(f"[DUPLICATE CHECK ERROR] {e}")

        # Always save to TEMP_REPORTS so they can proceed if they confirm
        report_metadata["status"] = "completed"
        report_metadata["raw_text"] = raw_text
        report_metadata["structured_data"] = structured_data
        TEMP_REPORTS[report_id] = report_metadata

        if is_name_mismatched or is_gender_mismatched or is_age_mismatched or is_duplicate:
            status_val = "completed"
            if is_name_mismatched: status_val = "name_mismatch"
            elif is_gender_mismatched: status_val = "gender_mismatch"
            elif is_age_mismatched: status_val = "age_mismatch"
            elif is_duplicate: status_val = "duplicate"
            
            return {
                "id": report_id,
                "filename": file.filename,
                "upload_time": report_metadata["upload_time"],
                "status": status_val,
                "is_name_mismatch": is_name_mismatched,
                "is_gender_mismatch": is_gender_mismatched,
                "is_age_mismatch": is_age_mismatched,
                "is_duplicate": is_duplicate,
                "structured_data": structured_data,
                "user_verified": False,
                "raw_text": raw_text
            }

        return {
            "id": report_id,
            "filename": file.filename,
            "upload_time": report_metadata["upload_time"],
            "status": "completed",
            "structured_data": structured_data,
            "user_verified": False,
            "raw_text": raw_text
        }
    except Exception as e:
        if STORAGE_ENGINE == "supabase" and supabase:
            supabase.table("reports").update({"status": "failed"}).eq("id", report_id).execute()
        else:
            conn = sqlite3.connect(str(DB_PATH))
            conn.execute("UPDATE reports SET status='failed' WHERE id=?", (report_id,))
            conn.commit()
            conn.close()
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/upload-multi")
async def upload_multi_report(files: list[UploadFile] = File(...), force: bool = False, current_user: dict = Depends(get_current_user)):
    """Upload multiple page images for a single report. Merges all pages via LLM."""
    if not files:
        raise HTTPException(status_code=400, detail="No files provided")

    report_id = str(uuid.uuid4())
    saved_paths: list[Path] = []
    filenames: list[str] = []

    # Save all uploaded files
    for i, file in enumerate(files):
        file_ext = Path(file.filename).suffix or ".jpg"
        file_path = UPLOAD_DIR / f"{report_id}_page{i+1}{file_ext}"
        async with aiofiles.open(file_path, "wb") as f:
            content = await file.read()
            await f.write(content)
        saved_paths.append(file_path)
        filenames.append(file.filename)

    report_metadata = {
        "id": report_id,
        "user_id": current_user["id"],
        "filename": ", ".join(filenames),
        "upload_time": datetime.now().isoformat(),
        "status": "processing",
        "file_path": str(saved_paths[0]),
        "raw_text": None,
        "structured_data": None,
        "user_verified": 0
    }

    try:
        # Use multi-page LLM parsing
        if len(saved_paths) == 1:
            structured_data = await parse_medical_report_llm(saved_paths[0])
        else:
            structured_data = await parse_medical_report_multi_llm(saved_paths)

        raw_text = f"Extracted via OpenAI Vision API ({len(saved_paths)} page(s))"

        # Set default values for demographics if missing
        user_dob = current_user.get("dob")
        user_ic = current_user.get("ic_number")

        if user_dob and not structured_data.get("dob"):
            structured_data["dob"] = user_dob
        if user_ic and not structured_data.get("ic_number"):
            structured_data["ic_number"] = user_ic

        is_name_mismatched = False
        is_gender_mismatched = False
        is_age_mismatched = False
        is_duplicate = False

        if not force:
            # --- NAME VALIDATION ---
            user_name = current_user.get("name", "")
            patient_name = structured_data.get("patient_name", "")
            if patient_name and not check_name_match(user_name, patient_name):
                is_name_mismatched = True

            # --- GENDER VALIDATION ---
            user_gender = current_user.get("gender", "")
            patient_gender = structured_data.get("gender", "")
            if user_gender and patient_gender and not check_gender_match(user_gender, patient_gender):
                is_gender_mismatched = True

            # --- AGE & IDENTITY VALIDATION ---
            patient_dob = structured_data.get("dob", "")
            patient_ic = structured_data.get("ic_number", "")

            if (user_dob or user_ic) and not check_age_and_identity_match(
                user_dob, patient_dob, patient_ic, user_ic
            ):
                is_age_mismatched = True

            # --- DUPLICATE CHECK ---
            try:
                is_duplicate = await check_duplicate_report(current_user["id"], structured_data, exclude_id=report_id)
            except Exception as e:
                print(f"[DUPLICATE CHECK ERROR] {e}")

        # Always save to TEMP_REPORTS so they can proceed if they confirm
        report_metadata["status"] = "completed"
        report_metadata["raw_text"] = raw_text
        report_metadata["structured_data"] = structured_data
        TEMP_REPORTS[report_id] = report_metadata

        if is_name_mismatched or is_gender_mismatched or is_age_mismatched or is_duplicate:
            status_val = "completed"
            if is_name_mismatched: status_val = "name_mismatch"
            elif is_gender_mismatched: status_val = "gender_mismatch"
            elif is_age_mismatched: status_val = "age_mismatch"
            elif is_duplicate: status_val = "duplicate"
            
            return {
                "id": report_id,
                "filename": ", ".join(filenames),
                "upload_time": report_metadata["upload_time"],
                "status": status_val,
                "is_name_mismatch": is_name_mismatched,
                "is_gender_mismatch": is_gender_mismatched,
                "is_age_mismatch": is_age_mismatched,
                "is_duplicate": is_duplicate,
                "structured_data": structured_data,
                "user_verified": False,
                "raw_text": raw_text
            }

        return {
            "id": report_id,
            "filename": ", ".join(filenames),
            "upload_time": report_metadata["upload_time"],
            "status": "completed",
            "structured_data": structured_data,
            "user_verified": False,
            "raw_text": raw_text
        }
    except Exception as e:
        import traceback
        traceback.print_exc()
        if STORAGE_ENGINE == "supabase" and supabase:
            supabase.table("reports").update({"status": "failed"}).eq("id", report_id).execute()
        else:
            conn = sqlite3.connect(str(DB_PATH))
            conn.execute("UPDATE reports SET status='failed' WHERE id=?", (report_id,))
            conn.commit()
            conn.close()
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {str(e)}")

@app.post("/api/scanner/preprocess")
async def scanner_preprocess(
    request: Request,
    image: UploadFile = File(...),
    mode: str = "color",
    current_user: dict = Depends(get_current_user)
):
    """
    Accepts raw captured image, saves it temporarily, runs the document scanning pipeline
    (edge detection, perspective warp, CamScanner division enhancement), and saves the enhanced
    output image in static uploads/ directory.
    """
    # Generate unique ID for this preprocess session
    scan_id = str(uuid.uuid4())
    file_ext = Path(image.filename).suffix or ".jpg"
    
    # Paths for raw and preprocessed images
    raw_path = UPLOAD_DIR / f"raw_{scan_id}{file_ext}"
    processed_filename = f"scan_{scan_id}.png"
    processed_path = UPLOAD_DIR / processed_filename
    
    # Save the raw file
    async with aiofiles.open(raw_path, "wb") as f:
        content = await image.read()
        await f.write(content)
        
    try:
        # Run document scanner pipeline
        _, metadata = DocumentScanner.process_image(
            input_source=str(raw_path),
            output_path=str(processed_path),
            mode=mode
        )
        
        # Build serving URL for client
        base_url = str(request.base_url)
        # Ensure trailing slash
        if not base_url.endswith("/"):
            base_url += "/"
        processed_url = f"{base_url}uploads/{processed_filename}"
        
        # Cleanup raw image to save disk space
        if raw_path.exists():
            os.remove(raw_path)
            
        return {
            "success": True,
            "processed_image_url": processed_url,
            "filepath": str(processed_path),
            "metadata": metadata
        }
    except Exception as e:
        # Cleanup raw image on failure
        if raw_path.exists():
            try:
                os.remove(raw_path)
            except Exception:
                pass
        print(f"DEBUG [scanner] Preprocessing error: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Scanner preprocessing failed: {str(e)}")

@app.post("/api/upload-multi/preprocessed")
async def upload_multi_preprocessed(
    request: PreprocessedUploadRequest,
    force: bool = False,
    current_user: dict = Depends(get_current_user)
):
    """
    Runs OCR + LLM parsing on already preprocessed images stored in uploads/ on the server.
    Accepts single or multiple files.
    """
    if not request.filepaths:
        raise HTTPException(status_code=400, detail="No file paths provided")
        
    # Verify all files exist
    paths: TypingList[Path] = []
    for fp in request.filepaths:
        path_obj = Path(fp)
        if not path_obj.exists():
            raise HTTPException(status_code=400, detail=f"File does not exist on server: {fp}")
        paths.append(path_obj)
        
    # Generate unified report_id
    report_id = str(uuid.uuid4())
    
    # Filenames formatting
    filenames = request.filenames or [p.name for p in paths]
    
    report_metadata = {
        "id": report_id,
        "user_id": current_user["id"],
        "filename": ", ".join(filenames),
        "upload_time": datetime.now().isoformat(),
        "status": "processing",
        "file_path": str(paths[0]),
        "raw_text": None,
        "structured_data": None,
        "user_verified": 0
    }
    
    try:
        # Extract structured data
        if len(paths) == 1:
            structured_data = await parse_medical_report_llm(paths[0])
        else:
            structured_data = await parse_medical_report_multi_llm(paths)
            
        raw_text = f"Extracted via OpenAI Vision API ({len(paths)} preprocessed page(s))"

        # Set default values for demographics if missing
        user_dob = current_user.get("dob")
        user_ic = current_user.get("ic_number")

        if user_dob and not structured_data.get("dob"):
            structured_data["dob"] = user_dob
        if user_ic and not structured_data.get("ic_number"):
            structured_data["ic_number"] = user_ic

        is_name_mismatched = False
        is_gender_mismatched = False
        is_age_mismatched = False
        is_duplicate = False

        if not force:
            # --- NAME VALIDATION ---
            user_name = current_user.get("name", "")
            patient_name = structured_data.get("patient_name", "")
            if patient_name and not check_name_match(user_name, patient_name):
                is_name_mismatched = True

            # --- GENDER VALIDATION ---
            user_gender = current_user.get("gender", "")
            patient_gender = structured_data.get("gender", "")
            if user_gender and patient_gender and not check_gender_match(user_gender, patient_gender):
                is_gender_mismatched = True

            # --- AGE & IDENTITY VALIDATION ---
            patient_dob = structured_data.get("dob", "")
            patient_ic = structured_data.get("ic_number", "")

            if (user_dob or user_ic) and not check_age_and_identity_match(
                user_dob, patient_dob, patient_ic, user_ic
            ):
                is_age_mismatched = True

            # --- DUPLICATE CHECK ---
            try:
                is_duplicate = await check_duplicate_report(current_user["id"], structured_data, exclude_id=report_id)
            except Exception as e:
                print(f"[DUPLICATE CHECK ERROR] {e}")

        # Always save to TEMP_REPORTS so they can proceed if they confirm
        report_metadata["status"] = "completed"
        report_metadata["raw_text"] = raw_text
        report_metadata["structured_data"] = structured_data
        TEMP_REPORTS[report_id] = report_metadata

        if is_name_mismatched or is_gender_mismatched or is_age_mismatched or is_duplicate:
            status_val = "completed"
            if is_name_mismatched: status_val = "name_mismatch"
            elif is_gender_mismatched: status_val = "gender_mismatch"
            elif is_age_mismatched: status_val = "age_mismatch"
            elif is_duplicate: status_val = "duplicate"
            
            return {
                "id": report_id,
                "filename": ", ".join(filenames),
                "upload_time": report_metadata["upload_time"],
                "status": status_val,
                "is_name_mismatch": is_name_mismatched,
                "is_gender_mismatch": is_gender_mismatched,
                "is_age_mismatch": is_age_mismatched,
                "is_duplicate": is_duplicate,
                "structured_data": structured_data,
                "user_verified": False,
                "raw_text": raw_text
            }

        return {
            "id": report_id,
            "filename": ", ".join(filenames),
            "upload_time": report_metadata["upload_time"],
            "status": "completed",
            "structured_data": structured_data,
            "user_verified": False,
            "raw_text": raw_text
        }
    except Exception as e:
        import traceback
        traceback.print_exc()
        if STORAGE_ENGINE == "supabase" and supabase:
            supabase.table("reports").update({"status": "failed"}).eq("id", report_id).execute()
        else:
            conn = sqlite3.connect(str(DB_PATH))
            conn.execute("UPDATE reports SET status='failed' WHERE id=?", (report_id,))
            conn.commit()
            conn.close()
        raise HTTPException(status_code=500, detail=f"Internal Server Error during extraction: {str(e)}")

@app.get("/api/reports/{report_id}")
async def get_report(report_id: str):
    """Get a single report by ID."""
    report = await get_report_by_id(report_id)
    if not report: raise HTTPException(status_code=404, detail="Not found")
    return report

@app.put("/api/reports/{report_id}")
async def update_report(report_id: str, updated_data: dict, background_tasks: BackgroundTasks, force: bool = False):
    """Update structured data for a report (tester corrections)."""
    # If this is the first update (e.g. during Send), persist the report from TEMP_REPORTS to the DB
    if report_id in TEMP_REPORTS:
        report_metadata = TEMP_REPORTS[report_id]
        await save_report(report_metadata)
        del TEMP_REPORTS[report_id]

    report = await get_report_by_id(report_id)
    if not report: raise HTTPException(status_code=404, detail="Not found")

    # User Entry Validation Mode: warning user if format not right
    incoming_results = updated_data.get("structured_data", {}).get("results", [])
    incoming_struct = updated_data.get("structured_data", {})
    
    print(f"DEBUG: PUT /api/reports/{report_id} incoming keys: {list(incoming_struct.keys())}")
    print(f"DEBUG: date={incoming_struct.get('date')}, time={incoming_struct.get('time')}, gender={incoming_struct.get('gender')}")

    for item in incoming_results:
        k = item.get("key")
        v = item.get("value")
        if k in SCHEMA_TYPES:
            try:
                validate_and_cast_value(k, v)
            except ValueError as e:
                print(f"VALIDATION ERROR: key={k}, value={v}, type={SCHEMA_TYPES[k]}, error={e}")
                raise HTTPException(status_code=400, detail=f"Warning: The format for '{k}' is incorrect. Expected {SCHEMA_TYPES[k]}. Error: {str(e)}")

    if "date" in incoming_struct and incoming_struct["date"]:
        try:
            validate_and_cast_value("collected", incoming_struct["date"])
        except ValueError as e:
            print(f"VALIDATION ERROR: date={incoming_struct['date']}, error={e}")
            raise HTTPException(status_code=400, detail=f"Warning: The format for 'date' is incorrect. Expected DATE. Error: {str(e)}")

    if "time" in incoming_struct and incoming_struct["time"]:
        try:
            validate_and_cast_value("time", incoming_struct["time"])
        except ValueError as e:
            print(f"VALIDATION ERROR: time={incoming_struct['time']}, error={e}")
            raise HTTPException(status_code=400, detail=f"Warning: The format for 'time' is incorrect. Expected TIME (HH:MM or HH:MM:SS). Error: {str(e)}")

    # Normalize the incoming data to flat structure for the duplicate check
    normalized_incoming = normalize_structured_data(updated_data.get("structured_data", {}))
    
    if not force:
        # --- NAME VALIDATION ---
        user = get_user_by_id(report.get("user_id"))
        user_name = user.get("name", "") if user else ""
        patient_name = normalized_incoming.get("patient_name", "")
        if patient_name and not check_name_match(user_name, patient_name):
            raise HTTPException(
                status_code=400,
                detail=f"Name Mismatch: The patient name on the report ('{patient_name}') does not match your registered name ('{user_name}')."
            )

        # --- GENDER VALIDATION ---
        user_gender = user.get("gender", "") if user else ""
        patient_gender = normalized_incoming.get("gender", "")
        if user_gender and patient_gender and not check_gender_match(user_gender, patient_gender):
            raise HTTPException(
                status_code=400,
                detail=f"Gender Mismatch: The patient gender on the report ('{patient_gender}') does not match your registered gender ('{user_gender}')."
            )

        # --- AGE & IDENTITY VALIDATION ---
        user_dob = user.get("dob") if user else None
        user_ic = user.get("ic_number") if user else None
        patient_dob = normalized_incoming.get("dob", "")
        patient_ic = normalized_incoming.get("ic_number", "")

        if (user_dob or user_ic) and not check_age_and_identity_match(
            user_dob, patient_dob, patient_ic, user_ic
        ):
            raise HTTPException(
                status_code=400,
                detail=f"Identity Mismatch: The patient Date of Birth or IC number on this report does not match your registered credentials."
            )

        # Run duplicate check
        is_duplicate = False
        try:
            is_duplicate = await check_duplicate_report(report.get("user_id"), normalized_incoming, exclude_id=report_id)
        except Exception as e:
            print(f"[DUPLICATE CHECK ERROR] {e}")

        if is_duplicate:
            # Delete from DB immediately to maintain data integrity
            try:
                await delete_report(report_id)
            except Exception as e:
                print(f"[DELETE DUPLICATE ERROR] {e}")
                
            raise HTTPException(
                status_code=400, 
                detail="Duplicate Report: A report with the same date/patient ID/clinical values already exists in your records. This duplicate entry has been discarded."
            )

    await update_report_in_db(report_id, updated_data)
    
    if report.get("status") == "sent" and report.get("user_id"):
        invalidate_health_summary_cache(report.get("user_id"))
        background_tasks.add_task(generate_and_cache_health_summary, report.get("user_id"))

    return {"status": "updated"}

@app.post("/api/reports/manual")
async def create_manual_report(current_user: dict = Depends(get_current_user)):
    """Create a blank report for manual entry (no OCR/LLM). User fills it via VerifyScreen."""
    report_id = str(uuid.uuid4())
    now = datetime.now().isoformat()
    
    # Build empty structured data using normalize
    structured_data = normalize_structured_data({})
    
    report_metadata = {
        "id": report_id,
        "user_id": current_user["id"],
        "filename": "manual_entry",
        "upload_time": now,
        "status": "completed",
        "file_path": None,
        "raw_text": "Manual entry — no OCR",
        "structured_data": structured_data,
        "user_verified": 0
    }
    
    # Store in TEMP_REPORTS (will be persisted on send)
    TEMP_REPORTS[report_id] = report_metadata
    
    return {
        "id": report_id,
        "filename": "manual_entry",
        "upload_time": now,
        "status": "completed",
        "structured_data": structured_data,
        "user_verified": False,
        "raw_text": "Manual entry — no OCR"
    }

@app.post("/api/reports/{report_id}/send")
async def send_report(report_id: str, background_tasks: BackgroundTasks):
    """Mark report as verified and sent — the final step in the tester flow."""
    # Just in case send_report is called and the report is still in TEMP_REPORTS, persist it now
    if report_id in TEMP_REPORTS:
        report_metadata = TEMP_REPORTS[report_id]
        await save_report(report_metadata)
        del TEMP_REPORTS[report_id]

    report = await get_report_by_id(report_id)
    if not report: raise HTTPException(status_code=404, detail="Not found")
    await mark_report_sent(report_id)
    
    user_id = report.get("user_id")
    if user_id:
        invalidate_health_summary_cache(user_id)
        background_tasks.add_task(generate_and_cache_health_summary, user_id)

    return {"status": "sent", "message": "Report verified and submitted successfully"}

@app.delete("/api/reports/{report_id}")
async def delete_report_endpoint(report_id: str, background_tasks: BackgroundTasks, current_user: dict = Depends(get_current_user)):
    """Delete a report."""
    user_id = current_user["id"]
    report = await get_report_by_id(report_id)
    if not report: raise HTTPException(status_code=404, detail="Not found")
    # Verify ownership
    if report.get("user_id") and report.get("user_id") != user_id:
        raise HTTPException(status_code=403, detail="Forbidden")
        
    await delete_report(report_id)
    
    invalidate_health_summary_cache(user_id)
    background_tasks.add_task(generate_and_cache_health_summary, user_id)
    
    return {"status": "deleted", "message": "Report deleted successfully"}

def migrate_existing_users_gender():
    print("[STARTUP GENDER MIGRATION] Running backfill migration...")
    try:
        if STORAGE_ENGINE == "supabase" and supabase:
            res = supabase.table("users").select("*").execute()
            users = res.data or []
            for u in users:
                cur_gender = u.get("gender")
                if not cur_gender or str(cur_gender).strip() == "":
                    # Fetch reports
                    rep_res = supabase.table("reports").select("structured_data").eq("user_id", u["id"]).execute()
                    reps = rep_res.data or []
                    extracted = None
                    for r in reps:
                        sd = r.get("structured_data")
                        if sd:
                            if isinstance(sd, str):
                                try:
                                    sd = json.loads(sd)
                                except Exception:
                                    continue
                            g = sd.get("gender")
                            if g and str(g).strip().lower() in ("male", "female", "m", "f"):
                                cg = str(g).strip().lower()
                                if cg.startswith("m"):
                                    extracted = "Male"
                                elif cg.startswith("f"):
                                    extracted = "Female"
                                break
                    if extracted:
                        print(f"[STARTUP GENDER MIGRATION] Updating Supabase User {u['email']} gender to {extracted}")
                        supabase.table("users").update({"gender": extracted}).eq("id", u["id"]).execute()
        else:
            conn = sqlite3.connect(str(DB_PATH))
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM users")
            users = [dict(row) for row in cursor.fetchall()]
            for u in users:
                cur_gender = u.get("gender")
                if not cur_gender or str(cur_gender).strip() == "":
                    cursor.execute("SELECT structured_data FROM reports WHERE user_id = ?", (u["id"],))
                    reps = cursor.fetchall()
                    extracted = None
                    for r in reps:
                        sd_str = r["structured_data"]
                        if sd_str:
                            try:
                                sd = json.loads(sd_str)
                            except Exception:
                                continue
                            g = sd.get("gender")
                            if g and str(g).strip().lower() in ("male", "female", "m", "f"):
                                cg = str(g).strip().lower()
                                if cg.startswith("m"):
                                    extracted = "Male"
                                elif cg.startswith("f"):
                                    extracted = "Female"
                                break
                    if extracted:
                        print(f"[STARTUP GENDER MIGRATION] Updating SQLite User {u['email']} gender to {extracted}")
                        cursor.execute("UPDATE users SET gender = ? WHERE id = ?", (extracted, u["id"]))
            conn.commit()
            conn.close()
    except Exception as e:
        print(f"[STARTUP GENDER MIGRATION ERROR] {e}")

def migrate_existing_users_dob():
    print("[STARTUP DOB MIGRATION] Running backfill migration...")
    import datetime
    try:
        if STORAGE_ENGINE == "supabase" and supabase:
            res = supabase.table("users").select("*").execute()
            users = res.data or []
            for u in users:
                cur_dob = u.get("dob")
                if not cur_dob:
                    rep_res = supabase.table("reports").select("structured_data").eq("user_id", u["id"]).execute()
                    reps = rep_res.data or []
                    extracted_dob = None
                    
                    for r in reps:
                        sd = r.get("structured_data")
                        if sd:
                            if isinstance(sd, str):
                                try:
                                    sd = json.loads(sd)
                                except Exception:
                                    continue
                            
                            dob_val = sd.get("dob")
                            p_dob = parse_date_robust(str(dob_val)) if dob_val else None
                            if p_dob:
                                extracted_dob = p_dob
                            
                            ic_val = sd.get("ic_number")
                            ic_dob_tuple = extract_dob_from_ic(str(ic_val)) if ic_val else None
                            if ic_dob_tuple and not extracted_dob:
                                yy, mm, dd = ic_dob_tuple
                                century = 2000 if yy <= int(datetime.date.today().year % 100) else 1900
                                try:
                                    extracted_dob = datetime.date(century + yy, mm, dd)
                                except ValueError:
                                    pass
                                    
                            age_val = sd.get("age")
                            report_date_val = sd.get("collected")
                            p_age = None
                            if age_val:
                                m = re.search(r'\b\d+\b', str(age_val))
                                if m:
                                    p_age = int(m.group(0))
                            
                            p_rep_date = parse_date_robust(str(report_date_val)) if report_date_val else None
                            
                            if p_age is not None:
                                if p_rep_date:
                                    birth_year = p_rep_date.year - p_age
                                    if not extracted_dob:
                                        extracted_dob = datetime.date(birth_year, 1, 1)
                            
                            if extracted_dob:
                                break
                                
                    update_payload = {}
                    if not cur_dob and extracted_dob:
                        update_payload["dob"] = extracted_dob.isoformat()
                        
                    if update_payload:
                        print(f"[STARTUP DOB MIGRATION] Updating Supabase User {u['email']}: {update_payload}")
                        supabase.table("users").update(update_payload).eq("id", u["id"]).execute()
        else:
            conn = sqlite3.connect(str(DB_PATH))
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM users")
            users = [dict(row) for row in cursor.fetchall()]
            for u in users:
                cur_dob = u.get("dob")
                if not cur_dob:
                    cursor.execute("SELECT structured_data FROM reports WHERE user_id = ?", (u["id"],))
                    reps = cursor.fetchall()
                    extracted_dob = None
                    
                    for r in reps:
                        sd_str = r["structured_data"]
                        if sd_str:
                            try:
                                sd = json.loads(sd_str)
                            except Exception:
                                continue
                            
                            dob_val = sd.get("dob")
                            p_dob = parse_date_robust(str(dob_val)) if dob_val else None
                            if p_dob:
                                extracted_dob = p_dob
                            
                            ic_val = sd.get("ic_number")
                            ic_dob_tuple = extract_dob_from_ic(str(ic_val)) if ic_val else None
                            if ic_dob_tuple and not extracted_dob:
                                yy, mm, dd = ic_dob_tuple
                                century = 2000 if yy <= int(datetime.date.today().year % 100) else 1900
                                try:
                                    extracted_dob = datetime.date(century + yy, mm, dd)
                                except ValueError:
                                    pass
                                    
                            age_val = sd.get("age")
                            report_date_val = sd.get("collected")
                            p_age = None
                            if age_val:
                                m = re.search(r'\b\d+\b', str(age_val))
                                if m:
                                    p_age = int(m.group(0))
                            
                            p_rep_date = parse_date_robust(str(report_date_val)) if report_date_val else None
                            
                            if p_age is not None:
                                if p_rep_date:
                                    birth_year = p_rep_date.year - p_age
                                    if not extracted_dob:
                                        extracted_dob = datetime.date(birth_year, 1, 1)
                            
                            if extracted_dob:
                                break
                                
                    update_parts = []
                    params = []
                    if not cur_dob and extracted_dob:
                        update_parts.append("dob = ?")
                        params.append(extracted_dob.isoformat())
                        
                    if update_parts:
                        params.append(u["id"])
                        sql = f"UPDATE users SET {', '.join(update_parts)} WHERE id = ?"
                        print(f"[STARTUP DOB MIGRATION] Updating SQLite User {u['email']}: {sql} with params {params[:-1]}")
                        cursor.execute(sql, tuple(params))
            conn.commit()
            conn.close()
    except Exception as e:
        print(f"[STARTUP DOB MIGRATION ERROR] {e}")

def backfill_existing_reports_demographics():
    print("[STARTUP REPORTS DEMOGRAPHICS BACKFILL] Running backfill for reports...")
    try:
        user_cache = {}
        
        def get_user_demographics(user_id):
            if user_id in user_cache:
                return user_cache[user_id]
            dob, ic = None, None
            if STORAGE_ENGINE == "supabase" and supabase:
                res = supabase.table("users").select("dob", "ic_number").eq("id", user_id).execute()
                if res.data:
                    dob = res.data[0].get("dob")
                    ic = res.data[0].get("ic_number")
            else:
                conn = sqlite3.connect(str(DB_PATH))
                cursor = conn.cursor()
                cursor.execute("SELECT dob, ic_number FROM users WHERE id = ?", (user_id,))
                row = cursor.fetchone()
                if row:
                    dob, ic = row[0], row[1]
                conn.close()
            user_cache[user_id] = (dob, ic)
            return dob, ic

        if STORAGE_ENGINE == "supabase" and supabase:
            res = supabase.table("reports").select("id", "user_id", "structured_data").execute()
            reports = res.data or []
            for r in reports:
                user_id = r.get("user_id")
                if not user_id:
                    continue
                sd = r.get("structured_data")
                if sd:
                    if isinstance(sd, str):
                        try:
                            sd = json.loads(sd)
                        except Exception:
                            continue
                    
                    dob_val = sd.get("dob")
                    ic_val = sd.get("ic_number")
                    
                    if not dob_val or not ic_val:
                        user_dob, user_ic = get_user_demographics(user_id)
                        updated = False
                        if not dob_val and user_dob:
                            sd["dob"] = user_dob
                            updated = True
                        if not ic_val and user_ic:
                            sd["ic_number"] = user_ic
                            updated = True
                        
                        if updated:
                            print(f"[STARTUP REPORTS DEMOGRAPHICS BACKFILL] Updating Supabase Report {r['id']}")
                            supabase.table("reports").update({"structured_data": sd}).eq("id", r["id"]).execute()
        else:
            conn = sqlite3.connect(str(DB_PATH))
            conn.row_factory = sqlite3.Row
            cursor = conn.cursor()
            cursor.execute("SELECT id, user_id, structured_data FROM reports")
            reports = [dict(row) for row in cursor.fetchall()]
            for r in reports:
                user_id = r.get("user_id")
                if not user_id:
                    continue
                sd_str = r.get("structured_data")
                if sd_str:
                    try:
                        sd = json.loads(sd_str)
                    except Exception:
                        continue
                    
                    dob_val = sd.get("dob")
                    ic_val = sd.get("ic_number")
                    
                    if not dob_val or not ic_val:
                        user_dob, user_ic = get_user_demographics(user_id)
                        updated = False
                        if not dob_val and user_dob:
                            sd["dob"] = user_dob
                            updated = True
                        if not ic_val and user_ic:
                            sd["ic_number"] = user_ic
                            updated = True
                        
                        if updated:
                            print(f"[STARTUP REPORTS DEMOGRAPHICS BACKFILL] Updating SQLite Report {r['id']}")
                            cursor.execute("UPDATE reports SET structured_data = ? WHERE id = ?", (json.dumps(sd), r["id"]))
            conn.commit()
            conn.close()
    except Exception as e:
        print(f"[STARTUP REPORTS DEMOGRAPHICS BACKFILL ERROR] {e}")

@app.on_event("startup")
def startup_migration():
    migrate_existing_users_gender()
    migrate_existing_users_dob()
    backfill_existing_reports_demographics()



