# OCR II System Thresholds Configuration Reference

This document highlights all configurable and hardcoded decision thresholds, scanning parameters, mathematical ratios, and matching limits found in the frontend and backend codebases.

---

## 1. Frontend Biomarker Matching Threshold

### Fuzzy Match Confidence Threshold
* **Value**: `0.45`
* **Defined In**: [biomarker_dictionary.dart](file:///Users/sooyauming/Desktop/Intern/OCR%20II/frontend/lib/utils/biomarker_dictionary.dart#L1164-L1166)
* **Context**:
  ```dart
  // Return the match only if it meets our confidence threshold of 0.45
  // (Reduced slightly from 0.5 to account for longer user inputs, but compensated by unit boosts)
  return bestScore >= 0.45 ? bestMatch : null;
  ```
* **Purpose**: During OCR extraction, raw test names (e.g. "Tot. Chol", "Hb", "ANC") are matched against the standard dictionary. The matching score combines Jaccard similarity, word overlap, starting-word boost, unit compatibility boost, and short-word penalties. A candidate must meet this minimum score of `0.45` to be mapped to a standard database field.

---

## 2. Document Corner Detection (OpenCV Geometry Search)

These thresholds are used in the first phase of document processing to identify the document borders in an uploaded image.

* **Defined In**: [detector.py](file:///Users/sooyauming/Desktop/Intern/OCR%20II/backend/services/scanner/detector.py)

### A. Processing Height
* **Value**: `500` pixels (Line 36)
* **Purpose**: Resizes the input image to a height of 500px while maintaining the aspect ratio. This ensures consistent speed and edge response thresholding during contour analysis.

### B. Canny Edge Detection Thresholds
* **Low Threshold**: `75` (Line 46)
* **High Threshold**: `200` (Line 46)
* **Context**:
  ```python
  edged = cv2.Canny(blurred, 75, 200)
  ```
* **Purpose**: Threshold values used by the Canny algorithm to identify structural gradients (document borders).

### C. Minimum Document Area Ratio
* **Value**: `0.15` (15% of the total image area) (Line 57)
* **Context**:
  ```python
  min_area_ratio = 0.15  # At least 15% of the image area
  ```
* **Purpose**: Prevents the detector from choosing small noise contours. Only contours spanning at least 15% of the image are analyzed.

### D. Contour Approximation Precision (`approxPolyDP`)
* **Value**: `0.02 * perimeter` (Line 66)
* **Context**:
  ```python
  approx = cv2.approxPolyDP(c, 0.02 * peri, True)
  ```
* **Purpose**: Simplifies candidate contours. If a contour can be approximated to exactly 4 points under this limit, it is classified as a valid document page shape.

---

## 3. Image Enhancers & Binarization

These settings are used to remove shadows, increase text contrast, and produce clean scanner-like images for the OCR model.

* **Defined In**: [enhancer.py](file:///Users/sooyauming/Desktop/Intern/OCR%20II/backend/services/scanner/enhancer.py) and [main.py](file:///Users/sooyauming/Desktop/Intern/OCR%20II/backend/main.py)

### A. Contrast Limited Adaptive Histogram Equalization (CLAHE)
* **Clip Limit**: `2.0`
* **Tile Grid Size**: `(8, 8)`
* **Defined In**: [main.py](file:///Users/sooyauming/Desktop/Intern/OCR%20II/backend/main.py#L483)
* **Context**:
  ```python
  clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8,8))
  ```
* **Purpose**: Evens out lighting and boosts text/background contrast locally before encoding the image.

### B. Adaptive Gaussian Thresholding (Black & White Scanner Effect)
* **Block Size**: `11`
* **Constant (C)**: `2`
* **Defined In**: [enhancer.py](file:///Users/sooyauming/Desktop/Intern/OCR%20II/backend/services/scanner/enhancer.py#L52-L55)
* **Context**:
  ```python
  thresh = cv2.adaptiveThreshold(
      gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
      cv2.THRESH_BINARY, 11, 2
  )
  ```
* **Purpose**: Converts the grayscale document page to high-contrast binary black & white. A pixel is binarized based on the Gaussian-weighted average of an `11x11` neighborhood, subtracting `2`.

### C. Color Enhancer Background Map Dilation & Median Blur
* **Dilation Kernel**: `(7, 7)` (Line 16)
* **Median Blur Kernel Size**: `21` (Line 19)
* **Purpose**: Generates a smooth illumination background map (ignoring small text elements). Dividing the original channels by this background map removes shadows while preserving color labels/marks.

### D. B&W Noise Filtering Median Blur
* **Kernel Size**: `3` (Line 58)
* **Purpose**: Removes salt-and-pepper noise dots on the binarized image.

### E. Upscaling Target Height
* **Value**: `800` pixels (Line 63)
* **Purpose**: If a split page half is too short (height < 800px), it is upscaled proportionally using high-quality bicubic interpolation (`cv2.INTER_CUBIC`) so the OCR model can accurately read standard/small font sizes.

---

## 4. Content-Aware Page Splitter

The page splitter splits high-resolution tall documents into top and bottom halves at horizontal empty gaps to make them easier for the Vision API to digitize.

* **Defined In**: [splitter.py](file:///Users/sooyauming/Desktop/Intern/OCR%20II/backend/services/scanner/splitter.py)

### A. Horizontal Projection Binarization Threshold (Otsu's Method)
* **Value**: Automatic / Dynamic Otsu threshold
* **Context**:
  ```python
  _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
  ```
* **Purpose**: Binarizes the page row-by-row before calculating the projection profile to distinguish text rows from white space gaps.

### B. Row Gap Detection Threshold Ratio
* **Value**: `0.02` (2% of the maximum projection) (Line 35)
* **Context**:
  ```python
  threshold_ratio: float = 0.02
  ```
* **Purpose**: Rows where the horizontal sum of text pixels is less than 2% of the maximum row density are considered potential whitespace gaps.

### C. Minimum Gap Height
* **Value**: `5` pixels (Line 34)
* **Purpose**: Gaps must be at least 5 pixels tall to be considered valid split boundaries, filtering out small empty lines between normal letters.

### D. Midpoint Split Search Zone Ratio
* **Value**: `0.35` (35%) (Line 95)
* **Purpose**: Limits gap search to the middle 70% of the image (35% above and below the center) to avoid highly uneven splits.

### E. Safety Overlap Margin
* **Value**: `0.03` (3% of total image height) (Line 155)
* **Purpose**: Adds a 3% overlap region to both the top and bottom split halves to ensure text lines precisely on the boundary are not cut off.

### F. Minimum Split Height
* **Value**: `200` pixels (Line 189)
* **Purpose**: Prevents attempting to split images that are already extremely small.
