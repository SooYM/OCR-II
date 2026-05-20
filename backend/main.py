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

from fastapi import FastAPI, UploadFile, File, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import BaseModel
import aiofiles
import bcrypt
import jwt
from PIL import Image
from dotenv import load_dotenv
from openai import OpenAI
from supabase import create_client, Client
from supabase.lib.client_options import ClientOptions
import httpx

from unit_converter import convert_unit

# Google Cloud Dependencies
try:
    from google.cloud import vision
    HAS_GCP = True
except ImportError:
    HAS_GCP = False

import pytesseract

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

OCR_ENGINE = os.getenv("OCR_ENGINE", "tesseract").lower()
STORAGE_ENGINE = os.getenv("STORAGE_ENGINE", "supabase").lower()
GCP_PROJECT_ID = os.getenv("GCP_PROJECT_ID")

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

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
        # Create a custom httpx Client to disable HTTP/2 and prevent ConnectionTerminated errors
        custom_http_client = httpx.Client(http2=False, timeout=httpx.Timeout(20.0))
        options = ClientOptions(httpx_client=custom_http_client)
        supabase = create_client(SUPABASE_URL, SUPABASE_KEY, options=options)
    except Exception as e:
        print(f"Failed to initialize Supabase: {e}")

# ─── Database & Storage Logic ───────────────────────────────────────────────

# ─── Pydantic Models for Auth ──────────────────────────────────────────────

class RegisterRequest(BaseModel):
    email: str
    name: str
    password: str

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

def create_user(email: str, name: str, password: str) -> dict:
    user_id = str(uuid.uuid4())
    pw_hash = hash_password(password)
    now = datetime.now().isoformat()
    user_data = {
        "id": user_id,
        "email": email.lower().strip(),
        "name": name.strip(),
        "password_hash": pw_hash,
        "created_at": now,
    }
    if STORAGE_ENGINE == "supabase" and supabase:
        supabase.table("users").insert(user_data).execute()
    else:
        conn = sqlite3.connect(str(DB_PATH))
        conn.execute(
            "INSERT INTO users (id, email, name, password_hash, status, created_at) VALUES (?, ?, ?, ?, ?, ?)",
            (user_id, email.lower().strip(), name.strip(), pw_hash, 'active', now)
        )
        conn.commit()
        conn.close()
    return {"id": user_id, "email": user_data["email"], "name": user_data["name"], "created_at": now}

def update_user_profile(user_id: str, name: str, email: str):
    if STORAGE_ENGINE == "supabase" and supabase:
        supabase.table("users").update({"name": name, "email": email}).eq("id", user_id).execute()
    else:
        conn = sqlite3.connect(str(DB_PATH))
        conn.execute("UPDATE users SET name = ?, email = ? WHERE id = ?", (name, email, user_id))
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

# ─── OCR & Extraction Logic ────────────────────────────────────────────────

async def run_ocr(file_path: Path) -> str:
    if OCR_ENGINE == "google_vision" and HAS_GCP:
        client = vision.ImageAnnotatorClient()
        with open(file_path, "rb") as image_file:
            content = image_file.read()
        image = vision.Image(content=content)
        response = client.document_text_detection(image=image)
        if response.error.message: raise Exception(response.error.message)
        return response.full_text_annotation.text
    else:
        image = Image.open(file_path).convert("L")
        return pytesseract.image_to_string(image, lang="eng")

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

def encode_image(image_path: Path) -> str:
    # Apply preprocessing before encoding
    processed_path = preprocess_image(image_path)
    with open(processed_path, "rb") as image_file:
        b64 = base64.b64encode(image_file.read()).decode('utf-8')
    # Cleanup temp file
    if processed_path != image_path and processed_path.exists():
        processed_path.unlink()
    return b64

async def parse_medical_report_llm(file_path: Path) -> Dict[str, Any]:
    """Uses OpenAI Vision to parse an image directly into structured JSON."""
    base64_image = encode_image(file_path)

    # Dynamically build the prompt based on the schema
    # Exclude columns that are handled by the backend (original_*)
    extraction_keys = [k for k in STAGING_SCHEMA_KEYS if not k.startswith("original_")]
    # Append UI-expected metadata fields with descriptions to instruct the LLM
    all_keys = extraction_keys + [
        "test_name (The overall name of the medical/blood test, e.g. 'Full Blood Count', 'Liver Function Test', 'Renal Profile', 'Urine Test'. Generate a descriptive name if not explicitly written)",
        "doctor_name (The name of the referring doctor, e.g. 'Dr. John Doe'. If none is found, use '')",
        "hospital_name (The name of the hospital, clinic, or laboratory where the test was performed. If none is found, use '')",
        "gender (The patient's gender/sex, e.g. 'Male' or 'Female'. If none is found, use '')"
    ]
    keys_list = "\n".join([f"- {k}" for k in all_keys])
    
    prompt = f"""
    You are an expert medical data extraction assistant.
    Extract medical data directly from the image and return it as a JSON object.
    Ensure you extract ALL test items accurately and do not miss any rows.
    
    The output MUST exactly match the following JSON keys. 
    If a value is missing in the report, use an empty string "". 
    If a unit is present on the report for a test, INCLUDE the unit in the string alongside the value (e.g., "5.17 mmol/L", "150 g/L").
    DO NOT use null or omit keys.
    
    Fields to extract (all as strings):
    {keys_list}

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
        response = llm_client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=[
                {"role": "system", "content": "You are an expert medical data extraction assistant. Return JSON only."},
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{base64_image}"
                            }
                        }
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

async def parse_medical_report_multi_llm(file_paths: TypingList[Path]) -> Dict[str, Any]:
    """Uses OpenAI Vision to parse MULTIPLE page images into a single structured JSON."""
    # Build image content blocks for all pages
    image_blocks = []
    for i, fp in enumerate(file_paths):
        b64 = encode_image(fp)
        image_blocks.append({
            "type": "image_url",
            "image_url": {"url": f"data:image/jpeg;base64,{b64}"}
        })

    # Dynamically build the prompt based on the schema
    extraction_keys = [k for k in STAGING_SCHEMA_KEYS if not k.startswith("original_")]
    # Append UI-expected metadata fields with descriptions to instruct the LLM
    all_keys = extraction_keys + [
        "test_name (The overall name of the medical/blood test, e.g. 'Full Blood Count', 'Liver Function Test', 'Renal Profile', 'Urine Test'. Generate a descriptive name if not explicitly written)",
        "doctor_name (The name of the referring doctor, e.g. 'Dr. John Doe'. If none is found, use '')",
        "hospital_name (The name of the hospital, clinic, or laboratory where the test was performed. If none is found, use '')",
        "gender (The patient's gender/sex, e.g. 'Male' or 'Female'. If none is found, use '')"
    ]
    keys_list = "\n".join([f"- {k}" for k in all_keys])

    prompt = f"""
    You are given {len(file_paths)} page(s) of a SINGLE medical blood report.
    Extract ALL medical data from ALL pages and merge them into ONE JSON object.
    Do NOT separate results by page — combine everything into a unified record.
    Ensure you extract ALL test items accurately and do not miss any rows from any page.

    The output MUST exactly match the following JSON keys.
    If a value is missing in the report, use an empty string "".
    If a unit is present on the report for a test, INCLUDE the unit in the string alongside the value.
    DO NOT use null or omit keys.

    Fields to extract (all as strings):
    {keys_list}

    IMPORTANT MAPPING RULES & EXAMPLES:
    1. Map common names:
       - 'WBC' -> 'wbc_cells_ul'
       - 'RBC' -> 'rbc_count_mil_ul'
       - 'HGB' -> 'hemoglobin_g_dl'
    2. Patient info (medid, labreference, dates) should appear once — take from whichever page has it.
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
                {"role": "system", "content": "You are an expert medical data extraction assistant. You receive multi-page reports. Return JSON only."},
                {"role": "user", "content": content_parts}
            ],
            response_format={"type": "json_object"}
        )
        content = response.choices[0].message.content
        print(f"--- EXTRACTED JSON FROM OPENAI VISION (MULTI-PAGE: {len(file_paths)} pages) ---\n{content}\n-----------------------------------------")

        extracted_data = json.loads(content)
        return normalize_structured_data(extracted_data)
    except Exception as e:
        print(f"Multi-page LLM Parsing failed: {e}")
        return normalize_structured_data({})

# List of exact columns in staging_medical_records table
STAGING_SCHEMA_KEYS = [
    "medid", "original_medid", "labreference", "original_labreference", "sample_id", "collected", "time", "reported_time", 
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
    "total_hdl_ratio", "ldl_hdl_ratio", "hdl_ldl_ratio", "bilirubin_total_mg_dl", 
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
    "sample_id": "BIGINT",
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
    "vldl_mg_dl": "TEXT",
    "triglycerides_mg_dl": "TEXT",
    "non_hdl_mg_dl": "BIGINT",
    "total_hdl_ratio": "DOUBLE PRECISION",
    "ldl_hdl_ratio": "DOUBLE PRECISION",
    "hdl_ldl_ratio": "DOUBLE PRECISION",
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
    "a_g_ratio": "TEXT",
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
        raise ValueError(f"Invalid INT64 format: {s}")
        
    elif typ == "DOUBLE PRECISION":
        match = re.search(r'(-?\d*\.?\d+)', s)
        if match:
            return float(match.group(1))
        raise ValueError(f"Invalid FLOAT64 format: {s}")
        
    elif typ == "DATE":
        # Robustly strip time suffix like " 10:00:00 AM" or " 10:00 AM" or " 10:00:00" or "T10:00:00"
        s_date = re.sub(r'[T\s]+\d{1,2}:\d{2}(:\d{2})?(\s*(AM|PM))?.*$', '', s, flags=re.IGNORECASE).strip()
        # Clean spaces around separators like / or - or .
        s_date = re.sub(r'\s*([/\-.])\s*', r'\1', s_date)
        
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
            "%d.%B.%Y", "%B.%d.%Y", "%Y.%B.%d"
        ]
        from datetime import datetime
        for fmt in formats:
            try:
                dt = datetime.strptime(s_date, fmt)
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

    # 1. Standardize the flat data
    flat = {}
    raw_medid = data.get("medid", data.get("patient_id", ""))
    raw_labref = data.get("labreference", "")
    
    def clean_id(val):
        if not val: return ""
        return re.sub(r'[^a-zA-Z0-9]', '', str(val)).upper()
    
    for key in STAGING_SCHEMA_KEYS:
        if key == "original_medid":
            flat[key] = str(raw_medid) if raw_medid is not None else ""
        elif key == "original_labreference":
            flat[key] = str(raw_labref) if raw_labref is not None else ""
        elif key == "medid":
            flat[key] = clean_id(raw_medid)
        elif key == "labreference":
            flat[key] = clean_id(raw_labref)
        elif key == "collected":
            flat[key] = collected_val
        elif key == "time":
            flat[key] = time_val
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
    metadata_keys = ["medid", "original_medid", "labreference", "original_labreference", "sample_id", "collected", "time", "reported_time", "others"]
    for key, value in flat.items():
        if key in metadata_keys or not value: continue
        
        parts = key.split('_')
        name = " ".join(parts[:-1]).title() if len(parts) > 1 else key.title()
        # Parse value and extracted unit from LLM string using our robust parser
        clean_val, extracted_unit = split_value_and_unit(str(value))

        std_unit = ""
        if key.endswith('_g_dl'): std_unit = "g/dL"
        elif key.endswith('_mg_dl'): std_unit = "mg/dL"
        elif key.endswith('_mil_ul'): std_unit = "mil/uL"
        elif key.endswith('_pct'): std_unit = "%"
        elif key.endswith('_fl'): std_unit = "fL"
        elif key.endswith('_pg'): std_unit = "pg"
        elif key.endswith('_ul'): std_unit = "uL"
        elif key.endswith('_uiu_ml'): std_unit = "uIU/mL"
        elif key.endswith('_mmol_l'): std_unit = "mmol/L"
        
        final_unit = extracted_unit if extracted_unit else std_unit
        
        # Include 'key' so we can map it back on update
        results.append({"test_item": name, "value": clean_val, "unit": final_unit, "key": key})

    # Return a combined object that Flutter can parse
    return {
        **flat, 
        "patient_id": flat["medid"],
        "date": flat["collected"],
        "results": results,
        "notes": flat["others"],
        "gender": str(data.get("gender", "")).strip(),
        "test_name": str(data.get("test_name", "")).strip(),
        "doctor_name": str(data.get("doctor_name", "")).strip(),
        "hospital_name": str(data.get("hospital_name", "")).strip()
    }

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
            std_unit = ""
            if k.endswith('_g_dl'): std_unit = "g/dL"
            elif k.endswith('_mg_dl'): std_unit = "mg/dL"
            elif k.endswith('_mil_ul'): std_unit = "mil/uL"
            elif k.endswith('_pct'): std_unit = "%"
            elif k.endswith('_fl'): std_unit = "fL"
            elif k.endswith('_pg'): std_unit = "pg"
            elif k.endswith('_ul'): std_unit = "uL"
            elif k.endswith('_uiu_ml'): std_unit = "uIU/mL"
            elif k.endswith('_mmol_l'): std_unit = "mmol/L"
            elif k.endswith('_mg_l'): std_unit = "mg/L"
            elif k.endswith('_ug_dl'): std_unit = "ug/dL"

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
    
    if existing and existing.get("structured_data"):
        # Merge new UI edits into existing flat data
        # This ensures we keep the 90 columns even if the app doesn't send them all back
        merged = {**existing["structured_data"], **new_structured}
    else:
        merged = new_structured

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
            # Ensure only valid columns are inserted into staging_medical_records
            final_data = get_clean_flat_data(report["structured_data"])
            final_data["report_id"] = report_id  # Link back to reports table for cascade delete
            try:
                print(f"DEBUG: Attempting upsert to staging_medical_records for report_id: {report_id}")
                # Use upsert to either insert a new record or update the existing one for this report_id
                supabase.table("staging_medical_records").upsert(final_data, on_conflict="report_id").execute()
                print(f"DEBUG: Upsert successful for report: {report_id}")
            except Exception as e:
                print(f"DEBUG: Upsert failed: {e}. Trying Delete + Insert fallback...")
                try:
                    # Fallback for cases where the UNIQUE constraint hasn't been added to the DB yet
                    supabase.table("staging_medical_records").delete().eq("report_id", report_id).execute()
                    supabase.table("staging_medical_records").insert(final_data).execute()
                    print(f"DEBUG: Delete + Insert fallback successful for report: {report_id}")
                except Exception as e2:
                    print(f"DEBUG: Critical failure in staging update: {e2}")
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
        supabase.table("reports").delete().eq("id", report_id).execute()
    else:
        conn = sqlite3.connect(str(DB_PATH))
        cursor = conn.cursor()
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
        std_unit = ""
        if key.endswith('_g_dl'): std_unit = "g/dL"
        elif key.endswith('_mg_dl'): std_unit = "mg/dL"
        elif key.endswith('_mil_ul'): std_unit = "mil/uL"
        elif key.endswith('_pct'): std_unit = "%"
        elif key.endswith('_fl'): std_unit = "fL"
        elif key.endswith('_pg'): std_unit = "pg"
        elif key.endswith('_ul'): std_unit = "uL"
        elif key.endswith('_uiu_ml'): std_unit = "uIU/mL"
        elif key.endswith('_mmol_l'): std_unit = "mmol/L"
        elif key.endswith('_mg_l'): std_unit = "mg/L"
        elif key.endswith('_ug_dl'): std_unit = "ug/dL"
        elif key.endswith('_ng_dl'): std_unit = "ng/dL"
        
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
        
    # Non-numeric or fallback to string compare
    s1 = str(v1_clean).strip().lower()
    s2 = str(v2_clean).strip().lower()
    return s1 == s2

async def check_duplicate_report(user_id: str, new_data: dict, exclude_id: str = None):
    """
    Compares the newly parsed data with existing reports for the user.
    Uses a multi-attribute scoring system.
    """
    try:
        if not new_data:
            return False
        
        # Extract identifiers
        new_date = backend_normalize_date(new_data.get("collected", ""))
        new_medid = str(new_data.get("medid", "")).strip().upper()
        new_labref = str(new_data.get("labreference", "")).strip().upper()
        
        print(f"\n[DUPLICATE CHECK] New Report: Date={new_date}, PatientID={new_medid}, LabRef={new_labref}")
        
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
                
            # 1. Extract existing identifiers
            old_date = backend_normalize_date(s_data.get("collected", ""))
            old_medid = str(s_data.get("medid", "")).strip().upper()
            old_labref = str(s_data.get("labreference", "")).strip().upper()

            # --- CRITERIA 1: Exact Lab Reference Match ---
            if new_labref and old_labref and new_labref == old_labref:
                print(f" -> MATCH FOUND: Lab Reference ({new_labref})")
                return True

            # --- CRITERIA 2: Patient ID + Date + Attribute Overlap ---
            if new_date and old_date and new_date == old_date:
                # Match Patient ID if both exist
                medid_match = (not new_medid or not old_medid or new_medid == old_medid)
                
                if medid_match:
                    # Compare clinical results
                    match_count = 0
                    total_keys = 0
                    metadata_keys = ["medid", "original_medid", "labreference", "original_labreference", "sample_id", "collected", "time", "reported_time", "others"]
                    
                    for key in STAGING_SCHEMA_KEYS:
                        if key in metadata_keys: continue
                        
                        new_val = new_data.get(key, "")
                        old_val = s_data.get(key, "")
                        
                        if new_val or old_val:
                            total_keys += 1
                            if backend_compare_values(key, new_val, old_val):
                                match_count += 1
                    
                    if total_keys > 0:
                        overlap = (match_count / total_keys) * 100
                        print(f" -> CHECKING: Date MATCH ({old_date}), Overlap={overlap:.1f}% ({match_count}/{total_keys})")
                        
                        # If date matches, we use a much lower threshold (60% instead of 85%)
                        # because it's very unlikely to have two different reports on the same day.
                        if overlap >= 60: 
                            print(f" -> MATCH FOUND: Clinical Signature on same date")
                            return True

        print(" -> NO DUPLICATE FOUND")
        return False
    except Exception as e:
        import traceback
        print(f"[DUPLICATE ERROR] {e}")
        traceback.print_exc()
        return False # Fallback to not duplicate if check fails

# ─── API Endpoints ──────────────────────────────────────────────────────────

@app.get("/")
async def root():
    return {
        "status": "ok", 
        "version": "3.0.0",
        "ocr_engine": OCR_ENGINE, 
        "storage": STORAGE_ENGINE,
        "llm_model": OPENAI_MODEL,
        "gcp_support": HAS_GCP
    }

# ─── Auth Endpoints ─────────────────────────────────────────────────────────

@app.post("/api/auth/register")
async def register(req: RegisterRequest):
    if not req.email or not req.password or not req.name:
        raise HTTPException(status_code=400, detail="Email, name, and password are required")
    if len(req.password) < 6:
        raise HTTPException(status_code=400, detail="Password must be at least 6 characters")
    if get_user_by_email(req.email):
        raise HTTPException(status_code=409, detail="Email already registered")
    user = create_user(req.email, req.name, req.password)
    token = create_jwt(user["id"], user["email"])
    return {"token": token, "user": {"id": user["id"], "email": user["email"], "name": user["name"]}}

@app.post("/api/auth/login")
async def login(req: LoginRequest):
    user = get_user_by_email(req.email)
    if not user or not verify_password(req.password, user["password_hash"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    if user.get("status") == "inactive":
        raise HTTPException(status_code=403, detail="Account is inactive. Please contact support.")
    token = create_jwt(user["id"], user["email"])
    return {"token": token, "user": {"id": user["id"], "email": user["email"], "name": user["name"]}}

@app.get("/api/auth/me")
async def get_me(current_user: dict = Depends(get_current_user)):
    return {"id": current_user["id"], "email": current_user["email"], "name": current_user["name"]}

@app.put("/api/auth/profile")
async def update_profile(updated_data: dict, current_user: dict = Depends(get_current_user)):
    name = updated_data.get("name")
    email = updated_data.get("email")
    if not name or not email:
        raise HTTPException(status_code=400, detail="Name and email are required")
    
    update_user_profile(current_user["id"], name, email)
    return {"status": "success", "user": {"id": current_user["id"], "email": email, "name": name}}

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
        items = [f"{res.get('test_item', '')}: {res.get('value', '')} {res.get('unit', '')}".strip() for res in results_list if res.get('value') and res.get('value') != '-']
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

@app.post("/api/chat/sessions")
async def create_chat_session(request: CreateSessionRequest, current_user: dict = Depends(get_current_user)):
    user_id = current_user["id"]
    session_id = str(uuid.uuid4())
    created_at = datetime.now().isoformat()
    if STORAGE_ENGINE == "supabase" and supabase:
        supabase.table("chat_sessions").insert({
            "id": session_id,
            "user_id": user_id,
            "created_at": created_at,
            "title": request.title
        }).execute()
    else:
        conn = sqlite3.connect(str(DB_PATH))
        conn.execute(
            "INSERT INTO chat_sessions (id, user_id, created_at, title) VALUES (?, ?, ?, ?)",
            (session_id, user_id, created_at, request.title)
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
        items = [f"{res.get('test_item', '')}: {res.get('value', '')} {res.get('unit', '')}".strip() for res in results_list if res.get('value') and res.get('value') != '-']
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
async def upload_report(file: UploadFile = File(...), current_user: dict = Depends(get_current_user)):
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

        # --- DUPLICATE CHECK ---
        is_duplicate = False
        try:
            is_duplicate = await check_duplicate_report(current_user["id"], structured_data, exclude_id=report_id)
        except Exception as e:
            print(f"[DUPLICATE CHECK ERROR] {e}")

        if is_duplicate:
            # Delete from DB immediately as requested
            try:
                await delete_report(report_id)
            except Exception as e:
                print(f"[DELETE ERROR] {e}")

            return {
                "id": report_id,
                "filename": file.filename,
                "upload_time": report_metadata["upload_time"],
                "status": "duplicate",
                "is_duplicate": True,
                "structured_data": structured_data,
                "user_verified": False,
                "raw_text": raw_text
            }

        # Save to TEMP_REPORTS instead of DB
        report_metadata["status"] = "completed"
        report_metadata["raw_text"] = raw_text
        report_metadata["structured_data"] = structured_data
        TEMP_REPORTS[report_id] = report_metadata
        
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
async def upload_multi_report(files: list[UploadFile] = File(...), current_user: dict = Depends(get_current_user)):
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

        # --- DUPLICATE CHECK ---
        is_duplicate = False
        try:
            is_duplicate = await check_duplicate_report(current_user["id"], structured_data, exclude_id=report_id)
        except Exception as e:
            print(f"[DUPLICATE CHECK ERROR] {e}")

        if is_duplicate:
            # Delete from DB immediately as requested
            try:
                await delete_report(report_id)
            except Exception as e:
                print(f"[DELETE ERROR] {e}")

            return {
                "id": report_id,
                "filename": ", ".join(filenames),
                "upload_time": report_metadata["upload_time"],
                "status": "duplicate",
                "is_duplicate": True,
                "structured_data": structured_data,
                "user_verified": False,
                "raw_text": raw_text
            }

        # Save to TEMP_REPORTS instead of DB
        report_metadata["status"] = "completed"
        report_metadata["raw_text"] = raw_text
        report_metadata["structured_data"] = structured_data
        TEMP_REPORTS[report_id] = report_metadata

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

@app.get("/api/reports/{report_id}")
async def get_report(report_id: str):
    """Get a single report by ID."""
    report = await get_report_by_id(report_id)
    if not report: raise HTTPException(status_code=404, detail="Not found")
    return report

@app.put("/api/reports/{report_id}")
async def update_report(report_id: str, updated_data: dict):
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

    for item in incoming_results:
        k = item.get("key")
        v = item.get("value")
        if k in SCHEMA_TYPES:
            try:
                validate_and_cast_value(k, v)
            except ValueError as e:
                raise HTTPException(status_code=400, detail=f"Warning: The format for '{k}' is incorrect. Expected {SCHEMA_TYPES[k]}. Error: {str(e)}")

    if "date" in incoming_struct:
        try:
            validate_and_cast_value("collected", incoming_struct["date"])
        except ValueError as e:
            raise HTTPException(status_code=400, detail=f"Warning: The format for 'date' is incorrect. Expected DATE. Error: {str(e)}")

    if "time" in incoming_struct and incoming_struct["time"]:
        try:
            validate_and_cast_value("time", incoming_struct["time"])
        except ValueError as e:
            raise HTTPException(status_code=400, detail=f"Warning: The format for 'time' is incorrect. Expected TIME (HH:MM or HH:MM:SS). Error: {str(e)}")

    await update_report_in_db(report_id, updated_data)
    return {"status": "updated"}

@app.post("/api/reports/{report_id}/send")
async def send_report(report_id: str):
    """Mark report as verified and sent — the final step in the tester flow."""
    # Just in case send_report is called and the report is still in TEMP_REPORTS, persist it now
    if report_id in TEMP_REPORTS:
        report_metadata = TEMP_REPORTS[report_id]
        await save_report(report_metadata)
        del TEMP_REPORTS[report_id]

    report = await get_report_by_id(report_id)
    if not report: raise HTTPException(status_code=404, detail="Not found")
    await mark_report_sent(report_id)
    return {"status": "sent", "message": "Report verified and submitted successfully"}

@app.delete("/api/reports/{report_id}")
async def delete_report(report_id: str, current_user: dict = Depends(get_current_user)):
    """Delete a report."""
    user_id = current_user["id"]
    report = await get_report_by_id(report_id)
    if not report: raise HTTPException(status_code=404, detail="Not found")
    # Verify ownership
    if report.get("user_id") and report.get("user_id") != user_id:
        raise HTTPException(status_code=403, detail="Forbidden")
        
    if STORAGE_ENGINE == "supabase" and supabase:
        # Delete from staging_medical_records first (child table)
        try:
            supabase.table("staging_medical_records").delete().eq("report_id", report_id).execute()
        except Exception as e:
            print(f"[DELETE STAGING] Warning: {e}")
        # Then delete from reports
        supabase.table("reports").delete().eq("id", report_id).execute()
    else:
        conn = sqlite3.connect(str(DB_PATH))
        conn.execute("DELETE FROM reports WHERE id = ?", (report_id,))
        conn.commit()
        conn.close()
    return {"status": "deleted", "message": "Report deleted successfully"}

