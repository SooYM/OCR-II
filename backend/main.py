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

from fastapi import FastAPI, UploadFile, File, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import aiofiles
import bcrypt
import jwt
from PIL import Image
from dotenv import load_dotenv
from openai import OpenAI
from supabase import create_client, Client

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

# ─── Supabase Client ─────────────────────────────────────────────────────────

supabase: Optional[Client] = None
if STORAGE_ENGINE == "supabase" and SUPABASE_URL and SUPABASE_KEY:
    try:
        supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
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
            "INSERT INTO users (id, email, name, password_hash, created_at) VALUES (?, ?, ?, ?, ?)",
            (user_id, email.lower().strip(), name.strip(), pw_hash, now)
        )
        conn.commit()
        conn.close()
    return {"id": user_id, "email": user_data["email"], "name": user_data["name"], "created_at": now}

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

def encode_image(image_path: Path) -> str:
    with open(image_path, "rb") as image_file:
        return base64.b64encode(image_file.read()).decode('utf-8')

async def parse_medical_report_llm(file_path: Path) -> Dict[str, Any]:
    """Uses OpenAI Vision to parse an image directly into structured JSON."""
    base64_image = encode_image(file_path)

    # Dynamically build the prompt based on the schema
    # Exclude columns that are handled by the backend (original_*)
    extraction_keys = [k for k in STAGING_SCHEMA_KEYS if not k.startswith("original_")]
    
    keys_list = "\n".join([f"- {k}" for k in extraction_keys])
    
    prompt = f"""
    Extract medical data directly from the image and return it as a JSON object.
    Ensure you extract ALL test items accurately and do not miss any rows.
    
    The output MUST exactly match the following JSON keys. 
    If a value is missing in the report, use an empty string "". 
    DO NOT use null or omit keys.
    
    Fields to extract (all as strings):
    {keys_list}

    IMPORTANT MAPPING RULES:
    1. Standardize units: e.g., if you see 'g/dL', map it to keys ending in '_g_dl'.
    2. Map common names: 
       - 'WBC' -> 'wbc_cells_ul'
       - 'RBC' -> 'rbc_count_mil_ul'
       - 'HGB' -> 'hemoglobin_g_dl'
       - 'HCT' -> 'hematocrit_pct'
       - 'PLT' -> 'platelet_count_x10_3_ul'
       - 'SG' -> 'specific_gravity'
    3. If multiple tests exist for the same category, pick the most specific one.

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
    keys_list = "\n".join([f"- {k}" for k in extraction_keys])

    prompt = f"""
    You are given {len(file_paths)} page(s) of a SINGLE medical blood report.
    Extract ALL medical data from ALL pages and merge them into ONE JSON object.
    Do NOT separate results by page — combine everything into a unified record.
    Ensure you extract ALL test items accurately and do not miss any rows from any page.

    The output MUST exactly match the following JSON keys.
    If a value is missing in the report, use an empty string "".
    DO NOT use null or omit keys.

    Fields to extract (all as strings):
    {keys_list}

    IMPORTANT MAPPING RULES:
    1. Standardize units: e.g., if you see 'g/dL', map it to keys ending in '_g_dl'.
    2. Map common names:
       - 'WBC' -> 'wbc_cells_ul'
       - 'RBC' -> 'rbc_count_mil_ul'
       - 'HGB' -> 'hemoglobin_g_dl'
       - 'HCT' -> 'hematocrit_pct'
       - 'PLT' -> 'platelet_count_x10_3_ul'
       - 'SG' -> 'specific_gravity'
    3. If multiple tests exist for the same category, pick the most specific one.
    4. Patient info (medid, labreference, dates) should appear once — take from whichever page has it.

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

def normalize_structured_data(data: dict) -> dict:
    """Ensure all required keys exist and return a structure friendly to the Flutter UI."""
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
        unit = ""
        if key.endswith('_g_dl'): unit = "g/dL"
        elif key.endswith('_mg_dl'): unit = "mg/dL"
        elif key.endswith('_mil_ul'): unit = "mil/uL"
        elif key.endswith('_pct'): unit = "%"
        elif key.endswith('_fl'): unit = "fL"
        elif key.endswith('_pg'): unit = "pg"
        elif key.endswith('_ul'): unit = "uL"
        elif key.endswith('_uiu_ml'): unit = "uIU/mL"
        elif key.endswith('_mmol_l'): unit = "mmol/L"
        
        # Include 'key' so we can map it back on update
        results.append({"test_item": name, "value": value, "unit": unit, "key": key})

    # Return a combined object that Flutter can parse
    return {
        **flat, 
        "patient_id": flat["medid"],
        "date": flat["collected"],
        "results": results,
        "notes": flat["others"]
    }

def get_clean_flat_data(data: dict) -> dict:
    """Return only the keys that exist in the staging_medical_records table."""
    normalized = normalize_structured_data(data)
    return {k: v for k, v in normalized.items() if k in STAGING_SCHEMA_KEYS}

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
            try:
                supabase.table("staging_medical_records").insert(final_data).execute()
            except Exception as e:
                print(f"Failed to insert into staging_medical_records: {e}")
    else:
        conn = sqlite3.connect(str(DB_PATH))
        cursor = conn.cursor()
        cursor.execute("UPDATE reports SET user_verified = 1, status = 'sent' WHERE id = ?", (report_id,))
        conn.commit()
        conn.close()

async def get_report_by_id(report_id: str):
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
    token = create_jwt(user["id"], user["email"])
    return {"token": token, "user": {"id": user["id"], "email": user["email"], "name": user["name"]}}

@app.get("/api/auth/me")
async def get_me(current_user: dict = Depends(get_current_user)):
    return {"id": current_user["id"], "email": current_user["email"], "name": current_user["name"]}

# ─── My Reports ─────────────────────────────────────────────────────────────

@app.get("/api/reports/my")
async def get_my_reports(current_user: dict = Depends(get_current_user)):
    user_id = current_user["id"]
    if STORAGE_ENGINE == "supabase" and supabase:
        response = supabase.table("reports").select("*").eq("user_id", user_id).order("upload_time", desc=True).execute()
        reports = response.data or []
        for r in reports:
            r["user_verified"] = bool(r.get("user_verified", 0))
        return reports
    else:
        conn = sqlite3.connect(str(DB_PATH))
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM reports WHERE user_id = ? ORDER BY upload_time DESC", (user_id,))
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
    
    await save_report(report_metadata)

    try:
        # Use OpenAI Vision to extract data directly from the image
        structured_data = await parse_medical_report_llm(file_path)
        raw_text = "Extracted directly via OpenAI Vision API"
        
        # Update with results
        if STORAGE_ENGINE == "supabase" and supabase:
            supabase.table("reports").update({
                "status": "completed",
                "raw_text": raw_text,
                "structured_data": structured_data
            }).eq("id", report_id).execute()
        else:
            conn = sqlite3.connect(str(DB_PATH))
            cursor = conn.cursor()
            cursor.execute("UPDATE reports SET status = ?, raw_text = ?, structured_data = ? WHERE id = ?",
                           ("completed", raw_text, json.dumps(structured_data), report_id))
            conn.commit()
            conn.close()

        # Return full report metadata so Flutter fromJson doesn't fail
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

    await save_report(report_metadata)

    try:
        # Use multi-page LLM parsing
        if len(saved_paths) == 1:
            structured_data = await parse_medical_report_llm(saved_paths[0])
        else:
            structured_data = await parse_medical_report_multi_llm(saved_paths)

        raw_text = f"Extracted via OpenAI Vision API ({len(saved_paths)} page(s))"

        # Update with results
        if STORAGE_ENGINE == "supabase" and supabase:
            supabase.table("reports").update({
                "status": "completed",
                "raw_text": raw_text,
                "structured_data": structured_data
            }).eq("id", report_id).execute()
        else:
            conn = sqlite3.connect(str(DB_PATH))
            cursor = conn.cursor()
            cursor.execute("UPDATE reports SET status = ?, raw_text = ?, structured_data = ? WHERE id = ?",
                           ("completed", raw_text, json.dumps(structured_data), report_id))
            conn.commit()
            conn.close()

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
        if STORAGE_ENGINE == "supabase" and supabase:
            supabase.table("reports").update({"status": "failed"}).eq("id", report_id).execute()
        else:
            conn = sqlite3.connect(str(DB_PATH))
            conn.execute("UPDATE reports SET status='failed' WHERE id=?", (report_id,))
            conn.commit()
            conn.close()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/reports/{report_id}")
async def get_report(report_id: str):
    """Get a single report by ID."""
    report = await get_report_by_id(report_id)
    if not report: raise HTTPException(status_code=404, detail="Not found")
    return report

@app.put("/api/reports/{report_id}")
async def update_report(report_id: str, updated_data: dict):
    """Update structured data for a report (tester corrections)."""
    report = await get_report_by_id(report_id)
    if not report: raise HTTPException(status_code=404, detail="Not found")
    await update_report_in_db(report_id, updated_data)
    return {"status": "updated"}

@app.post("/api/reports/{report_id}/send")
async def send_report(report_id: str):
    """Mark report as verified and sent — the final step in the tester flow."""
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
        supabase.table("reports").delete().eq("id", report_id).execute()
    else:
        conn = sqlite3.connect(str(DB_PATH))
        conn.execute("DELETE FROM reports WHERE id = ?", (report_id,))
        conn.commit()
        conn.close()
    return {"status": "deleted", "message": "Report deleted successfully"}

