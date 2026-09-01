# 🚢 MedScan — Release & Deployment Manual

## 1. Overview

MedScan supports multiple deployment models:
* **Backend**: Docker containers, standalone Linux systemd services, Cloud Run, or cPanel / WSGI hosting.
* **Frontend**: Cross-platform Flutter builds for Android (APK / AAB), iOS (IPA / TestFlight), and Web.

---

## 2. Backend Deployment

### 2.1 Docker Containerization

The repository includes a production-ready `Dockerfile` in `backend/`:

```dockerfile
FROM python:3.10-slim

WORKDIR /app

# Install system C++ dependencies for OpenCV
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

#### Build & Run Commands:
```bash
# Build image
docker build -t medscan-backend:latest ./backend

# Run container with environment configuration
docker run -d \
  --name medscan-api \
  -p 8000:8000 \
  --env-file backend/.env \
  -v $(pwd)/backend/uploads:/app/uploads \
  medscan-backend:latest
```

---

### 2.2 WSGI & cPanel Passenger Deployment

For shared or cPanel hosting with Phusion Passenger:
1. `backend/passenger_wsgi.py` adapts ASGI (FastAPI) to WSGI using `a2wsgi`:
   ```python
   import sys, os
   sys.path.insert(0, os.path.dirname(__file__))
   from a2wsgi import ASGIMiddleware
   from main import app
   application = ASGIMiddleware(app)
   ```
2. Set Python version in cPanel Python App Manager to `3.10+`.
3. Point entry point to `passenger_wsgi.py`.

---

## 3. Frontend Client Release Builds

### 3.1 Android Build

#### 1. Generate Keystore (For Production Signed Builds)
```bash
keytool -genkey -v -keystore ~/medscan-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias medscan
```

#### 2. Build Release APK
```bash
cd frontend
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

#### 3. Build Google Play App Bundle (AAB)
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

---

### 3.2 iOS Release Build

```bash
cd frontend
flutter build ipa --release
```
Open `frontend/ios/Runner.xcworkspace` in Xcode, select the **Archive** scheme, and distribute to TestFlight or the App Store.

---

### 3.3 Web Build

```bash
cd frontend
flutter build web --release --web-renderer canvaskit
# Output: build/web/ (Deployable to Firebase Hosting, Cloudflare Pages, Vercel, or Nginx)
```
