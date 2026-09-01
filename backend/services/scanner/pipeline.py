"""
Document Scanner Pipeline Orchestrator.

Combines four-point document edge detection, perspective warping, morphological
illumination division, and adaptive contrast enhancement into an automated end-to-end
CamScanner-like preprocessing workflow.

Example:
    >>> from services.scanner.pipeline import DocumentScanner
    >>> enhanced_img, meta = DocumentScanner.process_image('uploads/sample.jpg', mode='color')
    >>> print('Success:', meta['success'], 'Corners detected:', meta['corners_detected'])
"""

import os
from typing import Union, Tuple, Dict, Any, Optional
import cv2
import numpy as np

from .detector import detect_document_corners
from .perspective import warp_perspective
from .enhancer import enhance_color, enhance_bw


class DocumentScanner:
    """
    Automated document computer vision processor.
    
    Transforms distorted mobile camera captures into flat, scan-quality documents
    prior to submission to optical character recognition engines.
    """

    @staticmethod
    def process_image(
        input_source: Union[str, np.ndarray],
        output_path: Optional[str] = None,
        mode: str = "color"
    ) -> Tuple[np.ndarray, Dict[str, Any]]:
        """
        Executes the full document scanning and enhancement pipeline.

        Processing Steps:
        1. Ingests image from filesystem path or existing BGR numpy matrix.
        2. Detects document corners via bilateral filtering, Canny edges, and contour approximation.
        3. Applies perspective transformation matrix to rectify skew if 4 corners are found.
        4. Cancels shadow gradients via morphological illumination background division.
        5. Optionally writes the resulting image to disk.

        Args:
            input_source: Absolute/relative file path string, or raw BGR image array.
            output_path: Optional destination file path to save the processed image.
            mode: Preprocessing style ('color' for illumination division, 'bw' for adaptive thresholding).

        Returns:
            A tuple of (processed_image_array, metadata_dictionary).
            Metadata dictionary schema:
                - success (bool): Whether execution completed.
                - corners_detected (bool): Whether 4 document corners were found.
                - detected_corners (list | None): Coordinates of detected quadrilateral.
                - original_size (list[int]): [width, height] before processing.
                - processed_size (list[int]): [width, height] after transformation.

        Raises:
            FileNotFoundError: If string input_source points to a non-existent file.
            ValueError: If the file cannot be decoded by OpenCV.
        """
        # 1. Load image if file path string is provided
        if isinstance(input_source, str):
            if not os.path.exists(input_source):
                raise FileNotFoundError(f"Input image not found: {input_source}")
            image = cv2.imread(input_source)
            if image is None:
                raise ValueError(f"Could not decode image at path: {input_source}")
        else:
            image = input_source
            
        h, w = image.shape[:2]
        metadata: Dict[str, Any] = {
            "success": True,
            "corners_detected": False,
            "detected_corners": None,
            "original_size": [w, h],
            "processed_size": [w, h]
        }
        
        # 2. Detect 4 document corners
        try:
            corners = detect_document_corners(image)
        except Exception as e:
            print(f"DEBUG [scanner] Corner detection failed: {e}")
            corners = None
            
        # 3. Warp perspective if 4 corners are successfully identified
        if corners is not None:
            metadata["corners_detected"] = True
            # Convert np.float32 coordinates to nested lists for JSON serializability
            metadata["detected_corners"] = corners.tolist()
            try:
                warped = warp_perspective(image, corners)
            except Exception as e:
                print(f"DEBUG [scanner] Perspective warp failed: {e}. Falling back to unwarped image.")
                warped = image.copy()
        else:
            # Fall back gracefully to original bounding box without crashing
            warped = image.copy()
            
        # 4. Enhance contrast and remove illumination gradients
        try:
            if mode == "bw":
                enhanced = enhance_bw(warped)
            else:
                enhanced = enhance_color(warped)
        except Exception as e:
            print(f"DEBUG [scanner] Enhancement failed: {e}. Falling back to warped image.")
            enhanced = warped
            
        eh, ew = enhanced.shape[:2]
        metadata["processed_size"] = [ew, eh]
        
        # 5. Persist to disk if output path was requested
        if output_path:
            os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
            cv2.imwrite(output_path, enhanced)
            
        return enhanced, metadata
