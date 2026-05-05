"""
Medical Report Digitization API
Simplified prototype backend — OCR processing, LLM parsing, BigQuery/SQLite storage.
No authentication. Designed for tester flow: Snap → Verify → Send.
"""

import os
import uuid
import json
import re
import sqlite3
import base64
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, Any

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import aiofiles
from PIL import Image
from dotenv import load_dotenv
from openai import OpenAI
from motor.motor_asyncio import AsyncIOMotorClient

# Google Cloud Dependencies
try:
    from google.cloud import vision
    from google.cloud import bigquery
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
STORAGE_ENGINE = os.getenv("STORAGE_ENGINE", "mongodb").lower()
GCP_PROJECT_ID = os.getenv("GCP_PROJECT_ID")
BQ_DATASET = os.getenv("BIGQUERY_DATASET", "medical_reports")
BQ_TABLE = os.getenv("BIGQUERY_TABLE", "reports")

MONGODB_URI = os.getenv("MONGODB_URI")
MONGODB_DB = os.getenv("MONGODB_DB", "medical_reports")

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)
DB_PATH = Path("medical_reports.db")

# ─── LLM Client (OpenAI) ───────────────────────────────────────────────────

llm_client = OpenAI(
    api_key=OPENAI_API_KEY,
)

# ─── BigQuery & MongoDB Client ───────────────────────────────────────────────

bq_client = None
if HAS_GCP and STORAGE_ENGINE == "bigquery":
    try:
        bq_client = bigquery.Client()
    except Exception as e:
        print(f"Failed to initialize BigQuery: {e}")

mongo_client = None
db = None
if STORAGE_ENGINE == "mongodb" and MONGODB_URI:
    mongo_client = AsyncIOMotorClient(MONGODB_URI, tlsAllowInvalidCertificates=True)
    db = mongo_client[MONGODB_DB]

# ─── Database & Storage Logic ───────────────────────────────────────────────

def init_local_db():
    conn = sqlite3.connect(str(DB_PATH))
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS reports (
            id TEXT PRIMARY KEY,
            filename TEXT NOT NULL,
            upload_time TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'processing',
            raw_text TEXT,
            structured_data TEXT,
            user_verified INTEGER DEFAULT 0,
            file_path TEXT
        )
    """)
    conn.commit()
    conn.close()

init_local_db()

def get_bq_table_id():
    return f"{GCP_PROJECT_ID}.{BQ_DATASET}.{BQ_TABLE}"

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

    prompt = """
    Extract medical data directly from the image and return it as a JSON object.
    Ensure you extract ALL test items accurately and do not miss any rows.
    Fields to extract:
    - patient_name
    - patient_id
    - date (ISO format if possible)
    - test_name
    - doctor_name
    - hospital_name
    - results: a list of objects with [test_item, value, unit, reference_range]
    - notes: any other relevant info

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
        return json.loads(content)
    except Exception as e:
        print(f"LLM Parsing failed: {e}")
        return parse_medical_report_regex("")

def parse_medical_report_regex(raw_text: str) -> Dict[str, Any]:
    """Fallback regex-based parser."""
    data = {"patient_name": None, "patient_id": None, "date": None, "test_name": None, "doctor_name": None, "hospital_name": None, "results": [], "notes": raw_text}
    name_match = re.search(r"(?:patient\s*name|name|nama)\s*[:\-]\s*(.+)", raw_text, re.I)
    if name_match: data["patient_name"] = name_match.group(1).strip()
    return data

# ─── Storage Helpers ───────────────────────────────────────────────────────

async def save_report(report: dict):
    if STORAGE_ENGINE == "mongodb" and db is not None:
        await db.reports.insert_one(report)
    elif STORAGE_ENGINE == "bigquery" and bq_client:
        bq_report = report.copy()
        bq_report["structured_data"] = json.dumps(bq_report["structured_data"]) if bq_report["structured_data"] else None
        
        query = f"""
            INSERT INTO `{get_bq_table_id()}` 
            (id, filename, upload_time, status, file_path, raw_text, structured_data, user_verified)
            VALUES (@id, @filename, @upload_time, @status, @file_path, @raw_text, @structured_data, @user_verified)
        """
        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("id", "STRING", bq_report.get("id")),
                bigquery.ScalarQueryParameter("filename", "STRING", bq_report.get("filename")),
                bigquery.ScalarQueryParameter("upload_time", "STRING", bq_report.get("upload_time")),
                bigquery.ScalarQueryParameter("status", "STRING", bq_report.get("status", "processing")),
                bigquery.ScalarQueryParameter("file_path", "STRING", bq_report.get("file_path")),
                bigquery.ScalarQueryParameter("raw_text", "STRING", bq_report.get("raw_text")),
                bigquery.ScalarQueryParameter("structured_data", "STRING", bq_report.get("structured_data")),
                bigquery.ScalarQueryParameter("user_verified", "INT64", bq_report.get("user_verified", 0)),
            ]
        )
        bq_client.query(query, job_config=job_config).result()
    else:
        conn = sqlite3.connect(str(DB_PATH))
        cursor = conn.cursor()
        cursor.execute("INSERT INTO reports (id, filename, upload_time, status, file_path, raw_text, structured_data) VALUES (?, ?, ?, ?, ?, ?, ?)",
                       (report["id"], report["filename"], report["upload_time"], report["status"], 
                        report.get("file_path"), report.get("raw_text"), json.dumps(report.get("structured_data"))))
        conn.commit()
        conn.close()

async def update_report_in_db(report_id: str, update_dict: dict):
    if STORAGE_ENGINE == "mongodb" and db is not None:
        await db.reports.update_one(
            {"id": report_id},
            {"$set": {"structured_data": update_dict.get("structured_data", {})}}
        )
    elif STORAGE_ENGINE == "bigquery" and bq_client:
        structured_data_str = json.dumps(update_dict.get("structured_data", {}))
        query = f"""
            UPDATE `{get_bq_table_id()}`
            SET structured_data = @structured_data
            WHERE id = @report_id
        """
        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("structured_data", "STRING", structured_data_str),
                bigquery.ScalarQueryParameter("report_id", "STRING", report_id),
            ]
        )
        bq_client.query(query, job_config=job_config).result()
    else:
        conn = sqlite3.connect(str(DB_PATH))
        cursor = conn.cursor()
        cursor.execute("UPDATE reports SET structured_data = ? WHERE id = ?",
                       (json.dumps(update_dict.get("structured_data", {})), report_id))
        conn.commit()
        conn.close()

async def mark_report_sent(report_id: str):
    """Mark a report as verified and sent."""
    if STORAGE_ENGINE == "mongodb" and db is not None:
        await db.reports.update_one(
            {"id": report_id},
            {"$set": {"user_verified": 1, "status": "sent"}}
        )
    elif STORAGE_ENGINE == "bigquery" and bq_client:
        query = f"""
            UPDATE `{get_bq_table_id()}`
            SET user_verified = 1, status = 'sent'
            WHERE id = @report_id
        """
        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("report_id", "STRING", report_id),
            ]
        )
        bq_client.query(query, job_config=job_config).result()
    else:
        conn = sqlite3.connect(str(DB_PATH))
        cursor = conn.cursor()
        cursor.execute("UPDATE reports SET user_verified = 1, status = 'sent' WHERE id = ?", (report_id,))
        conn.commit()
        conn.close()

async def get_report_by_id(report_id: str):
    if STORAGE_ENGINE == "mongodb" and db is not None:
        report = await db.reports.find_one({"id": report_id})
        if report and "_id" in report:
            report["_id"] = str(report["_id"])
        return report
    elif STORAGE_ENGINE == "bigquery" and bq_client:
        query = f"SELECT * FROM `{get_bq_table_id()}` WHERE id = @report_id"
        job_config = bigquery.QueryJobConfig(
            query_parameters=[bigquery.ScalarQueryParameter("report_id", "STRING", report_id)]
        )
        results = bq_client.query(query, job_config=job_config).result()
        row = next(iter(results), None)
        if not row: return None
        report = dict(row)
        report["structured_data"] = json.loads(report["structured_data"]) if report["structured_data"] else None
        return report
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
        return report

# ─── API Endpoints ──────────────────────────────────────────────────────────

@app.get("/")
async def root():
    return {
        "status": "ok", 
        "version": "2.0.0",
        "ocr_engine": OCR_ENGINE, 
        "storage": STORAGE_ENGINE,
        "llm_model": OPENAI_MODEL,
        "gcp_support": HAS_GCP
    }

@app.post("/api/upload")
async def upload_report(file: UploadFile = File(...)):
    """Upload an image, run OCR + LLM parsing, return structured data."""
    report_id = str(uuid.uuid4())
    file_ext = Path(file.filename).suffix or ".jpg"
    file_path = UPLOAD_DIR / f"{report_id}{file_ext}"

    async with aiofiles.open(file_path, "wb") as f:
        content = await file.read()
        await f.write(content)

    report_metadata = {
        "id": report_id,
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
        if STORAGE_ENGINE == "mongodb" and db is not None:
            await db.reports.update_one(
                {"id": report_id},
                {"$set": {"status": "completed", "raw_text": raw_text, "structured_data": structured_data}}
            )
        elif STORAGE_ENGINE == "bigquery" and bq_client:
            query = f"UPDATE `{get_bq_table_id()}` SET status='completed', raw_text=@text, structured_data=@data WHERE id=@id"
            job_config = bigquery.QueryJobConfig(
                query_parameters=[
                    bigquery.ScalarQueryParameter("text", "STRING", raw_text),
                    bigquery.ScalarQueryParameter("data", "STRING", json.dumps(structured_data)),
                    bigquery.ScalarQueryParameter("id", "STRING", report_id),
                ]
            )
            bq_client.query(query, job_config=job_config).result()
        else:
            conn = sqlite3.connect(str(DB_PATH))
            cursor = conn.cursor()
            cursor.execute("UPDATE reports SET status = ?, raw_text = ?, structured_data = ? WHERE id = ?",
                           ("completed", raw_text, json.dumps(structured_data), report_id))
            conn.commit()
            conn.close()

        return {"id": report_id, "status": "completed", "structured_data": structured_data}
    except Exception as e:
        if STORAGE_ENGINE == "mongodb" and db is not None:
            await db.reports.update_one({"id": report_id}, {"$set": {"status": "failed"}})
        elif STORAGE_ENGINE == "bigquery" and bq_client:
            bq_client.query(f"UPDATE `{get_bq_table_id()}` SET status='failed' WHERE id='{report_id}'").result()
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
