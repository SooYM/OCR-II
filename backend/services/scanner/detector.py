import cv2
import numpy as np
import imutils

def order_points(pts):
    """
    Orders a list of 4 coordinates:
    rect[0] = top-left
    rect[1] = top-right
    rect[2] = bottom-right
    rect[3] = bottom-left
    """
    rect = np.zeros((4, 2), dtype="float32")
    
    # top-left has the smallest sum, bottom-right has the largest sum
    s = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]
    rect[2] = pts[np.argmax(s)]
    
    # top-right has the largest difference (x - y), bottom-left has the smallest (or most negative) difference (x - y)
    diff = pts[:, 0] - pts[:, 1]
    rect[1] = pts[np.argmax(diff)]
    rect[3] = pts[np.argmin(diff)]
    
    return rect

def detect_document_corners(image):
    """
    Detects the 4 corners of a document in the image.
    Returns:
        A sorted 4x2 numpy array of coordinates if found, or None if detection fails.
    """
    # Resize image for faster and more reliable contour detection, keeping aspect ratio
    ratio = image.shape[0] / 500.0
    orig = image.copy()
    image_resized = imutils.resize(image, height=500)
    
    # 1. Convert to grayscale
    gray = cv2.cvtColor(image_resized, cv2.COLOR_BGR2GRAY)
    
    # 2. Denoise and blur
    # Bilateral filter is excellent for keeping sharp edges while removing noise (e.g. screen moire)
    blurred = cv2.bilateralFilter(gray, 9, 75, 75)
    
    # 3. Edge detection
    edged = cv2.Canny(blurred, 75, 200)
    
    # 4. Find contours
    cnts = cv2.findContours(edged.copy(), cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    cnts = imutils.grab_contours(cnts)
    
    # Sort contours by area, keeping only the largest ones
    cnts = sorted(cnts, key=cv2.contourArea, reverse=True)[:5]
    
    for c in cnts:
        # Approximate the contour
        peri = cv2.arcLength(c, True)
        approx = cv2.approxPolyDP(c, 0.02 * peri, True)
        
        # If the approximated contour has four points, we can assume we've found our document
        if len(approx) == 4:
            # Rescale the corner points back to the original image size
            screen_cnt = approx.reshape(4, 2) * ratio
            return order_points(screen_cnt)
            
    # Failed to find a 4-point contour
    return None
