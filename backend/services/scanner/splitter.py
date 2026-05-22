import os
import cv2
import numpy as np
from pathlib import Path
from typing import List, Tuple, Optional


def compute_horizontal_projection(image: np.ndarray) -> np.ndarray:
    """
    Computes the horizontal projection profile of an image.
    For each row, sums the number of dark (foreground) pixels.
    
    Returns:
        1D numpy array of length = image height, where each value is the
        sum of dark pixels in that row.
    """
    # Convert to grayscale if needed
    if len(image.shape) == 3:
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    else:
        gray = image.copy()
    
    # Binarize: dark pixels (text) become 255, light pixels (background) become 0
    # Use Otsu's method for automatic thresholding — works better across different
    # lighting conditions than a fixed threshold
    _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
    
    # Sum across each row (axis=1) to get horizontal projection
    projection = np.sum(binary, axis=1).astype(np.float64)
    
    return projection


def find_row_gaps(image: np.ndarray, min_gap_height: int = 5, 
                  threshold_ratio: float = 0.02) -> List[Tuple[int, int]]:
    """
    Finds whitespace gaps between text rows using horizontal projection analysis.
    
    Args:
        image: Input BGR or grayscale image.
        min_gap_height: Minimum height in pixels for a gap to be considered valid.
                       Filters out noise and thin lines.
        threshold_ratio: Rows with projection below (max_projection * threshold_ratio)
                        are considered "empty" / gap rows. Default 2%.
    
    Returns:
        List of (start_y, end_y) tuples representing whitespace gap bands,
        sorted by start_y. Each tuple marks the vertical span of a gap.
    """
    projection = compute_horizontal_projection(image)
    
    if len(projection) == 0:
        return []
    
    max_val = np.max(projection)
    if max_val == 0:
        # Entire image is blank
        return [(0, len(projection) - 1)]
    
    # Threshold: rows below this value are considered "gap" rows
    threshold = max_val * threshold_ratio
    
    # Find contiguous gap bands
    is_gap = projection < threshold
    gaps = []
    in_gap = False
    gap_start = 0
    
    for y in range(len(is_gap)):
        if is_gap[y] and not in_gap:
            # Entering a gap
            in_gap = True
            gap_start = y
        elif not is_gap[y] and in_gap:
            # Exiting a gap
            in_gap = False
            gap_end = y - 1
            gap_height = gap_end - gap_start + 1
            if gap_height >= min_gap_height:
                gaps.append((gap_start, gap_end))
    
    # Handle gap that extends to the bottom of the image
    if in_gap:
        gap_end = len(is_gap) - 1
        gap_height = gap_end - gap_start + 1
        if gap_height >= min_gap_height:
            gaps.append((gap_start, gap_end))
    
    return gaps


def find_best_split_y(image: np.ndarray, target_y: Optional[int] = None,
                      min_gap_height: int = 5, 
                      threshold_ratio: float = 0.02,
                      search_zone_ratio: float = 0.35) -> int:
    """
    Finds the best vertical position to split the image, choosing the center
    of the whitespace gap closest to the target position (default: image midpoint).
    
    Args:
        image: Input BGR or grayscale image.
        target_y: Target y-coordinate to split near. Defaults to image midpoint.
        min_gap_height: Minimum gap height for valid gaps (pixels).
        threshold_ratio: Projection threshold ratio for gap detection.
        search_zone_ratio: Only consider gaps within this fraction of the image
                          height from the target. Default 0.35 means we search
                          the middle 70% of the image (35% above and below midpoint).
    
    Returns:
        The y-coordinate of the best split point (center of the chosen gap).
        Falls back to target_y (or midpoint) if no suitable gap is found.
    """
    height = image.shape[0]
    
    if target_y is None:
        target_y = height // 2
    
    # Define the search zone: only consider gaps within a reasonable distance
    # from the target to avoid extreme splits (e.g., splitting at 90/10)
    search_min = int(height * (0.5 - search_zone_ratio))
    search_max = int(height * (0.5 + search_zone_ratio))
    
    gaps = find_row_gaps(image, min_gap_height=min_gap_height, 
                         threshold_ratio=threshold_ratio)
    
    if not gaps:
        print(f"[SPLITTER] No row gaps found. Falling back to midpoint y={target_y}")
        return target_y
    
    # Filter gaps to only those within the search zone
    valid_gaps = []
    for (start, end) in gaps:
        center = (start + end) // 2
        if search_min <= center <= search_max:
            valid_gaps.append((start, end, center))
    
    if not valid_gaps:
        print(f"[SPLITTER] No gaps found in search zone [{search_min}, {search_max}]. "
              f"Total gaps found: {len(gaps)}. Falling back to midpoint y={target_y}")
        return target_y
    
    # Pick the gap whose center is closest to target_y
    best_gap = min(valid_gaps, key=lambda g: abs(g[2] - target_y))
    best_y = best_gap[2]
    gap_height = best_gap[1] - best_gap[0] + 1
    
    print(f"[SPLITTER] Found best split at y={best_y} (gap: y={best_gap[0]}-{best_gap[1]}, "
          f"height={gap_height}px). Target was y={target_y}. "
          f"Deviation: {abs(best_y - target_y)}px ({abs(best_y - target_y) * 100 / height:.1f}%)")
    
    return best_y


def split_image_at_gap(image_path: Path, output_dir: Optional[Path] = None,
                       overlap_ratio: float = 0.03,
                       min_gap_height: int = 5,
                       threshold_ratio: float = 0.02) -> List[Path]:
    """
    Splits a single page image into top and bottom halves at a content-aware
    row gap position, with a small overlap margin for safety.
    
    This is the main public API for the splitter module.
    
    Args:
        image_path: Path to the input image file.
        output_dir: Directory for output files. Defaults to same directory as input.
        overlap_ratio: Fraction of image height to overlap on each side of the split.
                      Default 3% per side (6% total overlap). Smaller than the old 5%
                      per side because we're splitting at gaps, not blindly.
        min_gap_height: Minimum gap height in pixels for gap detection.
        threshold_ratio: Projection threshold ratio for gap detection.
    
    Returns:
        List of Path objects for the split image files.
        Returns [image_path] (original) if splitting fails.
    """
    image_path = Path(image_path)
    
    try:
        img = cv2.imread(str(image_path))
        if img is None:
            print(f"[SPLITTER] Warning: Could not read image at {image_path}. "
                  f"Returning original.")
            return [image_path]
        
        height, width = img.shape[:2]
        
        # Don't split very small images
        if height < 200:
            print(f"[SPLITTER] Image too small to split (height={height}). "
                  f"Returning original.")
            return [image_path]
        
        # Find the best content-aware split point
        split_y = find_best_split_y(
            img, 
            min_gap_height=min_gap_height,
            threshold_ratio=threshold_ratio
        )
        
        # Calculate overlap margins
        overlap_px = int(height * overlap_ratio)
        
        # Calculate split boundaries with overlap
        top_end = min(split_y + overlap_px, height)
        bottom_start = max(split_y - overlap_px, 0)
        
        # Create the halves
        top_half = img[0:top_end, 0:width]
        bottom_half = img[bottom_start:height, 0:width]
        
        # Determine output directory
        if output_dir is None:
            output_dir = image_path.parent
        output_dir = Path(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
        
        # Generate output filenames
        stem = image_path.stem
        suffix = image_path.suffix or ".png"
        top_path = output_dir / f"split_top_{stem}{suffix}"
        bottom_path = output_dir / f"split_bottom_{stem}{suffix}"
        
        cv2.imwrite(str(top_path), top_half)
        cv2.imwrite(str(bottom_path), bottom_half)
        
        print(f"[SPLITTER] Successfully split {image_path.name} "
              f"(H={height}, W={width}) at y={split_y}:")
        print(f"  - Top:    {top_path.name} (H={top_half.shape[0]}, "
              f"rows 0-{top_end})")
        print(f"  - Bottom: {bottom_path.name} (H={bottom_half.shape[0]}, "
              f"rows {bottom_start}-{height})")
        
        return [top_path, bottom_path]
        
    except Exception as e:
        print(f"[SPLITTER] Error splitting image: {e}. Returning original.")
        return [image_path]
