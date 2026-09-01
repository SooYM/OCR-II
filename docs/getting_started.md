# 🚀 MedScan — Getting Started Guide

## 1. System Requirements & Prerequisites

Before setting up MedScan, ensure the development environment meets the following specifications:

* **Operating System**: macOS (ARM64 / x86_64), Linux (Ubuntu 20.04+), or Windows 11 with WSL2.
* **Python**: `Python 3.10` or higher.
* **Flutter SDK**: `Flutter 3.10.0` or higher (Channel `stable`).
* **C++ Compiler & CMake**: Required to build OpenCV Python bindings.
  - *macOS*: `xcode-select --install`, `brew install cmake`
  - *Ubuntu/Debian*: `sudo apt-get install build-essential cmake libgl1-mesa-glx`
* **OpenAI API Key**: Access to GPT-4o (`gpt-4o`).
* **Supabase Project (Optional for cloud storage)**: Supabase PostgreSQL database URL and service role key.

---

## 2. Backend Service Setup (FastAPI)

### 2.1 Clone & Environment Initialization
```bash
# Navigate to backend directory
cd backend

# Create a clean Python virtual environment
python3 -m venv venv

# Activate the virtual environment
# On macOS / Linux:
source venv/bin/activate
# On Windows (PowerShell):
.\venv\Scripts\Activate.ps1

# Upgrade pip and install dependencies
pip install --upgrade pip
pip install -r requirements.txt
```

### 2.2 Configure Environment Variables
Copy `.env.template` to `.env` in `backend/`:
```bash
cp .env.template .env
```

Edit `backend/.env` with your credentials:
```ini
PORT=8000
STORAGE_ENGINE=supabase  # or 'sqlite' for zero-config offline mode
OPENAI_API_KEY=sk-proj-your-openai-api-key
OPENAI_MODEL=gpt-4o

# Required if STORAGE_ENGINE=supabase
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_KEY=your-supabase-service-role-key

# Security
JWT_SECRET=super-secure-random-jwt-secret-string
```

### 2.3 Initialize the Database
* **If using Supabase**:
  1. Open your Supabase Project Dashboard -> **SQL Editor**.
  2. Copy and execute the contents of `backend/supabase_auth_setup.sql`.
* **If using SQLite (`STORAGE_ENGINE=sqlite`)**:
  - The SQLite database file (`medical_reports.db`) and tables are initialized automatically on startup.

### 2.4 Start the Backend Server
```bash
# Run with live auto-reload
python3 -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```
The interactive Swagger API documentation will be available at: `http://localhost:8000/docs`.

---

## 3. Frontend Client Setup (Flutter)

### 3.1 Install Flutter Dependencies
```bash
# Navigate to the frontend directory
cd ../frontend

# Fetch Dart package dependencies
flutter pub get
```

### 3.2 Configure API Base URL
MedScan allows configuring the API server endpoint dynamically at runtime without recompiling:
1. Launch the app.
2. Navigate to **Settings** (Gear icon on bottom bar or top right).
3. Tap **Server Base URL**.
4. Enter your backend host address:
   - *Localhost iOS Simulator*: `http://127.0.0.1:8000`
   - *Android Emulator*: `http://10.0.2.2:8000`
   - *Physical Mobile Device (via localtunnel or ngrok)*: `https://your-tunnel-subdomain.loca.lt`
   - *Production Server*: `https://your-domain.com/backend`

### 3.3 Run on Simulator or Physical Device
```bash
# Run on connected device / simulator
flutter run

# Run on macOS desktop (if enabled)
flutter run -d macos

# Run on Chrome for Web testing
flutter run -d chrome
```
