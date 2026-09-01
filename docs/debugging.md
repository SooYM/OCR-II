# 🔍 MedScan — Debugging & Troubleshooting Guide

## 1. Computer Vision & OpenCV Issues

### 1.1 `ModuleNotFoundError: No module named 'cv2'`
* **Root Cause**: OpenCV binary wheel is missing from the active Python virtual environment.
* **Resolution**:
  ```bash
  source venv/bin/activate
  pip install opencv-python-headless numpy imutils
  ```
  *(Note: `opencv-python-headless` is recommended for server and Docker environments to avoid GUI library dependencies like libGL / X11).*

### 1.2 Document Corners Not Detected
* **Root Cause**: High background contrast or complex background clutter obscures page boundaries.
* **Diagnostic Output**: `DEBUG [scanner] No document corners detected. Skipping perspective warp.`
* **Resolution**: The pipeline automatically falls back to the original image dimensions without crashing. To optimize detection, capture reports against a solid, dark background with all four paper corners visible.

### 1.3 Splitter Falling Back to Midpoint
* **Root Cause**: Document text is unusually dense, or horizontal lines span continuously across the page without zero-pixel whitespace gaps.
* **Diagnostic Output**: `[SPLITTER] No row gaps found in search zone. Falling back to midpoint y=...`
* **Resolution**: The splitter adds a $3\%$ safety overlap margin on both halves, ensuring characters near the midpoint cut are still fully readable in at least one image segment.

---

## 2. Supabase & Database Issues

### 2.1 Supabase HTTP/2 `ConnectionTerminated` Errors
* **Root Cause**: Supabase edge gateways terminate multiplexed HTTP/2 streams when handling large multipart vision uploads or prolonged database queries.
* **Resolution**: In `backend/main.py`, HTTP/2 is explicitly disabled in the underlying HTTP client:
  ```python
  httpx_client = httpx.Client(http2=False, timeout=httpx.Timeout(30.0, read=60.0))
  options = ClientOptions(httpx_client=httpx_client, postgrest_client_timeout=60.0)
  supabase = create_client(SUPABASE_URL, SUPABASE_KEY, options=options)
  ```

### 2.2 PostgREST Type Mismatch (`PGRST204` or `22P02`)
* **Root Cause**: An extracted qualitative or formatted string (e.g. `"< 0.5"`, `"Negative"`) was submitted to a strict numeric column (`DOUBLE PRECISION` or `BIGINT`).
* **Resolution**: The backend `mark_report_sent` function contains a schema retry routine:
  1. Catches PostgREST error responses containing the failing column name.
  2. Strips non-numeric prefixes/symbols via regex (`re.sub(r'[^0-9.]', '', val)`).
  3. Re-attempts the database insert. If non-numeric, casts to `None` to prevent transaction failure.

### 2.3 Supabase Table Access Denied (May 2026 API Standards)
* **Root Cause**: New tables created in the public schema are not exposed to API roles by default.
* **Resolution**: Re-run the explicit grant queries in Supabase SQL Editor:
  ```sql
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE users TO anon, authenticated, service_role;
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE reports TO anon, authenticated, service_role;
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE staging_medical_records TO anon, authenticated, service_role;
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE chat_sessions TO anon, authenticated, service_role;
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE chat_messages TO anon, authenticated, service_role;
  ```

---

## 3. Network & Mobile Client Debugging

### 3.1 Mobile Connection Refused (`SocketException`)
* **Root Cause**: Mobile client is attempting to connect to `127.0.0.1`, which points to the device's internal loopback rather than the host machine.
* **Resolution**:
  - For **Android Emulator**: Use `http://10.0.2.2:8000`.
  - For **iOS Simulator**: Use `http://127.0.0.1:8000`.
  - For **Physical Devices**: Ensure device and computer are on the same Wi-Fi network, and use your computer's local IP (e.g. `http://192.168.1.50:8000`), or launch a tunnel:
    ```bash
    npx localtunnel --port 8000
    ```

### 3.2 Tunnel Reminder Bypass Headers
* **Root Cause**: Free tunneling services (like localtunnel or ngrok) return an interstitial HTML warning page that breaks JSON parsing on mobile.
* **Resolution**: `ApiService` and `AuthService` include bypass headers on all requests:
  ```dart
  'bypass-tunnel-reminder': 'true',
  'ngrok-skip-browser-warning': 'true',
  ```
