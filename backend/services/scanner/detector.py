"""
Four-Point Document Corner Detection Module.

Identifies the rectangular bounding polygon of a physical medical document
within a mobile camera capture using bilateral noise suppression, Canny edge detection,
and contour polygon approximation.

Example:
    >>> from services.scanner.detector import detect_document_corners
    >>> corners = detect_document_corners(image_bgr)
    >>> if corners is not None:
    ...     print("Top-left corner:", corners[0])
"""

from typing import Optional
import cv2
import numpy as np
import imutils


def order_points(pts: np.ndarray) -> np.ndarray:
    """
    Orders a list of 4 (x, y) coordinates into standard geometric order:
    [top-left, top-right, bottom-right, bottom-left].

    Mathematical Logic:
    - Top-left coordinate has the smallest (x + y) sum.
    - Bottom-right coordinate has the largest (x + y) sum.
    - Top-right coordinate has the largest (x - y) difference.
    - Bottom-left coordinate has the smallest (or most negative) (x - y) difference.

    Args:
        pts: A 4x2 numpy array of (x, y) coordinates.

    Returns:
        A sorted 4x2 numpy array with shape (4, 2) in float32.
    """
    rect = np.zeros((4, 2), dtype="float32")
    
    # top-left has the smallest sum, bottom-right has the largest sum
    s = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]
    rect[2] = pts[np.argmax(s)]
    
    # top-right has the largest difference (x - y), bottom-left has the smallest difference
    diff = pts[:, 0] - pts[:, 1]
    rect[1] = pts[np.argmax(diff)]
    rect[3] = pts[np.argmin(diff)]
    
    return rect


def detect_document_corners(image: np.ndarray) -> Optional[np.ndarray]:
    """
    Detects the 4 physical corners of a document page in an image.

    Args:
        image: Source image array in BGR format.

    Returns:
        A sorted 4x2 numpy array containing document corner coordinates scaled to the
        original image dimensions, or None if detection fails.
    """
    # Resize image to a constant height of 500px for speed and predictable Canny thresholds
    ratio = image.shape[0] / 500.0
    image_resized = imutils.resize(image, height=500)
    
    # 1. Convert to single-channel grayscale
    gray = cv2.cvtColor(image_resized, cv2.COLOR_BGR2GRAY)
    
    # 2. Bilateral filter removes screen moiré and paper texture while preserving sharp edges
    blurred = cv2.bilateralFilter(gray, 9, 75, 75)
    
    # 3. Canny gradient edge detector
    edged = cv2.Canny(blurred, 75, 200)
    
    # 4. Extract external contours and sort by surface area descending
    cnts = cv2.findContours(edged.copy(), cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    cnts = imutils.grab_contours(cnts)
    cnts = sorted(cnts, key=cv2.contourArea, reverse=True)[:5]
    
    resized_h, resized_w = image_resized.shape[:2]
    resized_area = resized_h * resized_w
    min_area_ratio = 0.15  # Document must span at least 15% of the total frame
    
    for c in cnts:
        area = cv2.contourArea(c)
        if area < resized_area * min_area_ratio:
            continue
            
        # Simplify contour to a polygon
        peri = cv2.arcLength(c, True)
        approx = cv2.approxPolyDP(c, 0.02 * peri, True)
        
        # If the polygon has exactly four vertices, we have isolated the document boundary
        if len(approx) == 4:
            # Rescale the corner coordinates back to original image resolution
            screen_cnt = approx.reshape(4, 2) * ratio
            return order_points(screen_cnt)
            
    # Return None if no valid quadrilateral was identified
    return None
