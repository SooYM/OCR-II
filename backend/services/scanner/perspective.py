import cv2
import numpy as np

def warp_perspective(image, pts):
    """
    Applies perspective transform to obtain a top-down, bird's eye view of the document.
    Args:
        image: Original input image.
        pts: 4x2 numpy array of sorted corners (top-left, top-right, bottom-right, bottom-left).
    Returns:
        Warped top-down image.
    """
    (tl, tr, br, bl) = pts
    
    # Compute the width of the new image
    # Maximum distance between bottom-right and bottom-left x-coords, or top-right and top-left x-coords
    width_a = np.sqrt(((br[0] - bl[0]) ** 2) + ((br[1] - bl[1]) ** 2))
    width_b = np.sqrt(((tr[0] - tl[0]) ** 2) + ((tr[1] - tl[1]) ** 2))
    max_width = max(int(width_a), int(width_b))
    
    # Compute the height of the new image
    # Maximum distance between top-right and bottom-right y-coords, or top-left and bottom-left y-coords
    height_a = np.sqrt(((tr[0] - br[0]) ** 2) + ((tr[1] - br[1]) ** 2))
    height_b = np.sqrt(((tl[0] - bl[0]) ** 2) + ((tl[1] - bl[1]) ** 2))
    max_height = max(int(height_a), int(height_b))
    
    # Define destination coordinates for top-down view
    dst = np.array([
        [0, 0],
        [max_width - 1, 0],
        [max_width - 1, max_height - 1],
        [0, max_height - 1]
    ], dtype="float32")
    
    # Compute perspective transform matrix and warp the image
    M = cv2.getPerspectiveTransform(pts, dst)
    warped = cv2.warpPerspective(image, M, (max_width, max_height))
    
    return warped
