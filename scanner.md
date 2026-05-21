
# Document Scanner Preprocessing Module (CamScanner-like)

## Purpose

Improve OCR accuracy for medical report extraction by converting **phone-captured images** into **scan-quality images** before sending them to OpenAI Vision.

This module sits **between Flutter image capture and backend OCR extraction**.

---

# Architecture Overview

```text
Flutter App
   ↓
Capture medical report image
   ↓
Upload raw image to backend
   ↓
Document Scanner Module
   ├─ Edge detection
   ├─ Perspective correction
   ├─ Image enhancement
   ├─ Denoising
   ├─ Thresholding
   └─ Export scan-quality image
   ↓
OpenAI Vision extraction
   ↓
JSON parser
   ↓
Validation engine
   ↓
Return structured medical report
```

---

# Why This Module Is Needed

Current issue:

```text
Phone → Laptop screen capture → Vision OCR
```

Problems:

- Perspective distortion
- Screen glare
- Moiré pattern
- Blur
- Low contrast
- OCR row misalignment

Result:

- wrong numbers
- shifted rows
- incorrect mappings

This preprocessing module fixes image quality before OCR.

---

# Module Responsibilities

## 1. Document Boundary Detection

Detect report edges automatically.

### Input

Raw image from Flutter camera/gallery.

### Output

4 corner points:

```json
{
  "topLeft": [x, y],
  "topRight": [x, y],
  "bottomLeft": [x, y],
  "bottomRight": [x, y]
}
```

### Methods

Use OpenCV:

- Canny edge detection
- contour detection
- polygon approximation

---

## 2. Perspective Correction

Flatten angled document.

### Before

Trapezoid

### After

Rectangle

### Method

OpenCV:

```python
cv2.getPerspectiveTransform()
cv2.warpPerspective()
```

---

## 3. Image Denoising

Remove:

- camera noise
- laptop screen artifacts
- moiré patterns

### Method

```python
cv2.fastNlMeansDenoising()
cv2.bilateralFilter()
```

---

## 4. Contrast Enhancement

Increase text visibility.

### Method

```python
cv2.equalizeHist()
```

or

```python
CLAHE
```

---

## 5. Sharpening

Improve character edges.

### Method

Kernel sharpening:

```python
[[0,-1,0],
 [-1,5,-1],
 [0,-1,0]]
```

---

## 6. Thresholding (Scan Effect)

Convert image into scanner-style output.

### Method

Adaptive threshold:

```python
cv2.adaptiveThreshold()
```

Output:

- black text
- white background

---

# Backend Tech Stack

## Required Python Packages

Install:

```bash
pip install opencv-python
pip install numpy
pip install imutils
```

Optional:

```bash
pip install pillow
```

---

# Suggested Backend Structure

```text
backend/
 ├── app/
 │    ├── api/
 │    ├── services/
 │    │     ├── scanner/
 │    │     │     ├── detector.py
 │    │     │     ├── perspective.py
 │    │     │     ├── enhancer.py
 │    │     │     └── pipeline.py
 │    │     ├── ocr/
 │    │     └── validation/
 │    └── main.py
```

---

# Scanner Module API

## Endpoint

```http
POST /scanner/preprocess
```

---

## Request

Multipart image upload.

```json
{
  "image": "medical_report.jpg"
}
```

---

## Response

```json
{
  "success": true,
  "processed_image_url": "/tmp/scan_123.png",
  "metadata": {
    "width": 2480,
    "height": 3508
  }
}
```

---

# Flutter Integration

## Current Flutter Flow

```text
ImagePicker → Upload → OCR
```

---

## New Flow

```text
ImagePicker
   ↓
Preview
   ↓
Upload to scanner API
   ↓
Receive enhanced image
   ↓
Send enhanced image to OCR API
   ↓
Display extracted results
```

---

# Flutter Code Changes

## 1. Capture Image

Use:

```yaml
image_picker
```

---

## 2. Call Scanner Endpoint

Example:

```dart
final request = http.MultipartRequest(
  'POST',
  Uri.parse('$baseUrl/scanner/preprocess'),
);

request.files.add(
  await http.MultipartFile.fromPath(
    'image',
    imagePath,
  ),
);

final response = await request.send();
```

---

## 3. Use Returned Processed Image

Backend returns:

```json
{
  "processed_image_url": "..."
}
```

Pass this image to OCR endpoint:

```dart
POST /medical/extract
```

---

# Recommended UX Improvements

## Allow Crop Preview

Display detected document corners.

User can adjust manually if needed.

Flutter package:

```yaml
edge_detection
```

or

```yaml
flutter_document_scanner
```

---

## Show Processing Status

Example:

```text
Enhancing document...
Extracting medical data...
```

---

# Failure Handling

If edge detection fails:

Fallback:

```text
Use original image
```

If preprocessing confidence is low:

```text
Ask user to retake photo
```

---

# Quality Targets

Expected OCR improvement:

| Metric | Before | After |
|--------|--------|-------|
| Row accuracy | 70% | 95%+ |
| Number accuracy | 75% | 97% |
| Table alignment | Poor | Excellent |

---

# Recommended Pipeline

```text
Flutter capture
   ↓
Scanner preprocess API
   ↓
Enhanced image
   ↓
OpenAI Vision
   ↓
JSON extraction
   ↓
Validation
   ↓
Store report
```

---

# Future Improvements

Possible upgrades:

- PDF generation from processed image
- multiple-page stitching
- automatic glare removal
- confidence scoring
- human review fallback

---

# Summary

This scanner module is a **mandatory preprocessing layer** for reliable medical OCR from phone images.

Without it:

- OCR drift
- wrong lab values
- unstable extraction

With it:

- scan-quality input
- better OpenAI Vision performance
- production-grade reliability
