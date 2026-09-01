"""
Content-Aware Horizontal Projection Row-Splitter.

Slices tall, high-resolution medical laboratory documents into top and bottom segments
along genuine whitespace gaps between table rows. Prevents OCR line-skipping, token bloat,
and character splitting.

Example:
    >>> from pathlib import Path
    >>> from services.scanner.splitter import split_image_at_gap
    >>> split_paths = split_image_at_gap(Path('uploads/dense_report.jpg'))
    >>> print("Produced segments:", [p.name for p in split_paths])
"""

import os
from pathlib import Path
from typing import List, Tuple, Optional
import cv2
import numpy as np


def compute_horizontal_projection(image: np.ndarray) -> np.ndarray:
    """
    Computes the horizontal projection profile of a document image.

    Binarizes the image using Otsu's inverted thresholding (dark text becomes 255,
    white paper becomes 0) and sums foreground pixel intensity horizontally for each row.

    Args:
        image: Source BGR or grayscale image array.

    Returns:
        1D numpy array of length equal to image height, representing row text density.
    """
    if len(image.shape) == 3:
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    else:
        gray = image.copy()
    
    # Binarize: dark text pixels become 255, white backdrop becomes 0 via Otsu threshold
    _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
    
    # Sum along axis=1 to compute horizontal projection
    projection = np.sum(binary, axis=1).astype(np.float64)
    return projection


def find_row_gaps(
    image: np.ndarray,
    min_gap_height: int = 5,
    threshold_ratio: float = 0.02
) -> List[Tuple[int, int]]:
    """
    Identifies horizontal whitespace gap bands between printed text lines.

    Args:
        image: Source image array.
        min_gap_height: Minimum vertical pixel thickness required for a valid gap.
        threshold_ratio: Fraction of maximum projection below which a row is considered empty.

    Returns:
        List of (start_y, end_y) tuples marking vertical gap spans.
    """
    projection = compute_horizontal_projection(image)
    
    if len(projection) == 0:
        return []
    
    max_val = np.max(projection)
    if max_val == 0:
        return [(0, len(projection) - 1)]
    
    threshold = max_val * threshold_ratio
    is_gap = projection < threshold
    gaps = []
    in_gap = False
    gap_start = 0
    
    for y in range(len(is_gap)):
        if is_gap[y] and not in_gap:
            in_gap = True
            gap_start = y
        elif not is_gap[y] and in_gap:
            in_gap = False
            gap_end = y - 1
            gap_height = gap_end - gap_start + 1
            if gap_height >= min_gap_height:
                gaps.append((gap_start, gap_end))
    
    if in_gap:
        gap_end = len(is_gap) - 1
        gap_height = gap_end - gap_start + 1
        if gap_height >= min_gap_height:
            gaps.append((gap_start, gap_end))
    
    return gaps


def find_best_split_y(
    image: np.ndarray,
    target_y: Optional[int] = None,
    min_gap_height: int = 5,
    threshold_ratio: float = 0.02,
    search_zone_ratio: float = 0.35
) -> int:
    """
    Determines the optimal vertical split line by finding the center of the whitespace
    gap closest to the mathematical midpoint.

    Args:
        image: Source image array.
        target_y: Preferred target y-coordinate (defaults to image height // 2).
        min_gap_height: Minimum gap height in pixels.
        threshold_ratio: Projection threshold ratio for empty rows.
        search_zone_ratio: Fraction of image height above and below target to search.

    Returns:
        The y-coordinate of the chosen split line.
    """
    height = image.shape[0]
    
    if target_y is None:
        target_y = height // 2
    
    search_min = int(height * (0.5 - search_zone_ratio))
    search_max = int(height * (0.5 + search_zone_ratio))
    
    gaps = find_row_gaps(image, min_gap_height=min_gap_height, threshold_ratio=threshold_ratio)
    
    if not gaps:
        return target_y
    
    # Filter gaps within search bounds
    valid_gaps = []
    for (start, end) in gaps:
        center = (start + end) // 2
        if search_min <= center <= search_max:
            valid_gaps.append((start, end, center))
    
    if not valid_gaps:
        return target_y
    
    # Select gap closest to target midpoint
    best_gap = min(valid_gaps, key=lambda g: abs(g[2] - target_y))
    return best_gap[2]


def split_image_at_gap(
    image_path: Path,
    output_dir: Optional[Path] = None,
    overlap_ratio: float = 0.03,
    min_gap_height: int = 5,
    threshold_ratio: float = 0.02
) -> List[Path]:
    """
    Splits a single document image into top and bottom halves at a content-aware whitespace gap.

    Main public entry point for page segmenting. Includes a safety overlap margin on both
    segments to ensure character integrity near boundary boundaries.

    Args:
        image_path: Filesystem path to source image.
        output_dir: Destination directory for generated image segments.
        overlap_ratio: Overlap percentage added to each half (default 3%).
        min_gap_height: Minimum whitespace thickness in pixels.
        threshold_ratio: Projection threshold ratio for gap identification.

    Returns:
        List of Path objects for the generated image segments, or [image_path] on failure.
    """
    image_path = Path(image_path)
    
    try:
        img = cv2.imread(str(image_path))
        if img is None:
            return [image_path]
        
        height, width = img.shape[:2]
        
        # Skip splitting if image is already small (< 200px)
        if height < 200:
            return [image_path]
        
        split_y = find_best_split_y(
            img, 
            min_gap_height=min_gap_height,
            threshold_ratio=threshold_ratio
        )
        
        # Calculate overlap margins
        overlap_px = int(height * overlap_ratio)
        
        top_end = min(split_y + overlap_px, height)
        bottom_start = max(split_y - overlap_px, 0)
        
        top_half = img[0:top_end, 0:width]
        bottom_half = img[bottom_start:height, 0:width]
        
        if output_dir is None:
            output_dir = image_path.parent
        output_dir = Path(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
        
        stem = image_path.stem
        suffix = image_path.suffix or ".png"
        top_path = output_dir / f"split_top_{stem}{suffix}"
        bottom_path = output_dir / f"split_bottom_{stem}{suffix}"
        
        cv2.imwrite(str(top_path), top_half)
        cv2.imwrite(str(bottom_path), bottom_half)
        
        return [top_path, bottom_path]
        
    except Exception as e:
        print(f"[SPLITTER] Error splitting image: {e}. Returning original.")
        return [image_path]
