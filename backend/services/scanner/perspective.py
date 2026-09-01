"""
Four-Point Perspective Warping Module.

Flattens angled, trapezoidal document captures into rectangular planar images
via homographic perspective transformations.

Example:
    >>> from services.scanner.perspective import warp_perspective
    >>> warped_doc = warp_perspective(image_bgr, corner_points_4x2)
"""

import cv2
import numpy as np


def warp_perspective(image: np.ndarray, pts: np.ndarray) -> np.ndarray:
    """
    Transforms a quadrilateral document contour into a top-down rectangular image.

    Calculates the maximum Euclidean width and height across opposite edges, constructs
    the target destination coordinate plane, and applies `cv2.warpPerspective`.

    Args:
        image: Original input image in BGR format.
        pts: 4x2 numpy array of sorted corners [top-left, top-right, bottom-right, bottom-left].

    Returns:
        The rectified, planar rectangular document image.
    """
    (tl, tr, br, bl) = pts
    
    # Compute output width as the maximum distance between horizontal edges
    width_a = np.sqrt(((br[0] - bl[0]) ** 2) + ((br[1] - bl[1]) ** 2))
    width_b = np.sqrt(((tr[0] - tl[0]) ** 2) + ((tr[1] - tl[1]) ** 2))
    max_width = max(int(width_a), int(width_b))
    
    # Compute output height as the maximum distance between vertical edges
    height_a = np.sqrt(((tr[0] - br[0]) ** 2) + ((tr[1] - br[1]) ** 2))
    height_b = np.sqrt(((tl[0] - bl[0]) ** 2) + ((tl[1] - bl[1]) ** 2))
    max_height = max(int(height_a), int(height_b))
    
    # Define destination coordinates for standard top-down planar grid
    dst = np.array([
        [0, 0],
        [max_width - 1, 0],
        [max_width - 1, max_height - 1],
        [0, max_height - 1]
    ], dtype="float32")
    
    # Compute perspective transform matrix and warp
    M = cv2.getPerspectiveTransform(pts, dst)
    warped = cv2.warpPerspective(image, M, (max_width, max_height))
    
    return warped
