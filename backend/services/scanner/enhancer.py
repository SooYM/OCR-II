"""
Computer Vision Document Enhancement & Illumination Module.

Provides illumination normalization via morphological background division,
adaptive Gaussian thresholding for high-contrast scan effects, and cubic
interpolation upscaling for high-fidelity OCR ingestion.

Example:
    >>> from services.scanner.enhancer import enhance_color, upscale_if_small
    >>> clean_doc = enhance_color(warped_image)
    >>> ready_doc = upscale_if_small(clean_doc, min_height=800)
"""

import cv2
import numpy as np


def enhance_color(image: np.ndarray) -> np.ndarray:
    """
    Normalizes uneven lighting and shadow gradients across color documents.

    Applies morphological dilation with a 7x7 structuring element and a 21x21 median
    filter to compute the background illumination map per channel. Dividing each channel
    by its background map eliminates shadows while preserving color ink and stamps.

    Args:
        image: Source BGR image array.

    Returns:
        Illumination-corrected and sharpened BGR image.
    """
    channels = cv2.split(image)
    result_channels = []
    
    # Process each color channel separately to normalize lighting
    for channel in channels:
        # 1. Dilate to bridge foreground text and isolate background illumination
        dilated = cv2.dilate(channel, np.ones((7, 7), np.uint8))
        
        # 2. Apply a large median blur to smooth out the background map
        bg_map = cv2.medianBlur(dilated, 21)
        
        # 3. Divide channel by estimated background map to normalize lighting to 255
        diff = cv2.divide(channel, bg_map, scale=255)
        
        # 4. Normalize contrast to span the full 0-255 dynamic range
        norm = cv2.normalize(diff, None, alpha=0, beta=255, norm_type=cv2.NORM_MINMAX, dtype=cv2.CV_8U)
        result_channels.append(norm)
        
    merged = cv2.merge(result_channels)
    
    # 5. Apply subtle Laplacian sharpening to crispen text edges
    sharpen_kernel = np.array([
        [0, -1, 0],
        [-1, 5, -1],
        [0, -1, 0]
    ], dtype="float32")
    sharpened = cv2.filter2D(merged, -1, sharpen_kernel)
    
    return sharpened


def enhance_bw(image: np.ndarray) -> np.ndarray:
    """
    Applies adaptive Gaussian thresholding to produce a high-contrast black & white scan.

    Args:
        image: Source BGR image.

    Returns:
        High-contrast BGR image containing pure black text on white background.
    """
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    
    # Adaptive Gaussian thresholding (neighborhood=11, C=2)
    thresh = cv2.adaptiveThreshold(
        gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
        cv2.THRESH_BINARY, 11, 2
    )
    
    # Median filter to eliminate salt-and-pepper noise dots
    denoised = cv2.medianBlur(thresh, 3)
    
    return cv2.cvtColor(denoised, cv2.COLOR_GRAY2BGR)


def upscale_if_small(image: np.ndarray, min_height: int = 800) -> np.ndarray:
    """
    Upscales an image proportionally if its vertical resolution is below min_height.

    Ensures that sliced page segments retain sufficient pixel density for small font
    character recognition by the Vision API.

    Args:
        image: Input BGR image array.
        min_height: Minimum target height threshold in pixels.

    Returns:
        The original image if height >= min_height, or the bicubic upscaled array.
    """
    h, w = image.shape[:2]
    if h >= min_height:
        return image
    
    scale = min_height / h
    new_w = int(w * scale)
    new_h = min_height
    
    # Use high-quality bicubic interpolation for sharp character strokes
    upscaled = cv2.resize(image, (new_w, new_h), interpolation=cv2.INTER_CUBIC)
    return upscaled
