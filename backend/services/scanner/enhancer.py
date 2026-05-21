import cv2
import numpy as np

def enhance_color(image):
    """
    Applies a color scanner (CamScanner) effect by removing shadows and uneven lighting.
    Uses background division to normalize light across the document while keeping colors.
    """
    # Split the image into individual channels
    channels = cv2.split(image)
    result_channels = []
    
    # Process each color channel separately to normalize lighting
    for channel in channels:
        # 1. Dilate to find background elements (remove small foreground details like text)
        dilated = cv2.dilate(channel, np.ones((7, 7), np.uint8))
        
        # 2. Apply a large median blur to create a smooth illumination background map
        bg_map = cv2.medianBlur(dilated, 21)
        
        # 3. Divide the channel by the background map.
        # This divides original values by background, scaling to 255.
        # Result: Background becomes white (255), while foreground text remains dark.
        diff = cv2.divide(channel, bg_map, scale=255)
        
        # 4. Normalize the contrast to maximize dynamic range
        norm = cv2.normalize(diff, None, alpha=0, beta=255, norm_type=cv2.NORM_MINMAX, dtype=cv2.CV_8U)
        result_channels.append(norm)
        
    # Merge channels back
    merged = cv2.merge(result_channels)
    
    # 5. Apply a subtle sharpening filter to make text pop
    sharpen_kernel = np.array([
        [0, -1, 0],
        [-1, 5, -1],
        [0, -1, 0]
    ], dtype="float32")
    sharpened = cv2.filter2D(merged, -1, sharpen_kernel)
    
    return sharpened

def enhance_bw(image):
    """
    Applies a high-contrast black and white adaptive thresholding filter (Scan effect).
    """
    # 1. Convert to grayscale
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    
    # 2. Apply adaptive Gaussian thresholding
    # block size = 11, constant subtract = 2
    thresh = cv2.adaptiveThreshold(
        gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
        cv2.THRESH_BINARY, 11, 2
    )
    
    # 3. Optional: apply a bilateral filter or simple median filter to remove minor noise dots
    denoised = cv2.medianBlur(thresh, 3)
    
    # Convert back to BGR so it has the same channel count
    return cv2.cvtColor(denoised, cv2.COLOR_GRAY2BGR)
