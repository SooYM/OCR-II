import os
import cv2
import numpy as np
from .detector import detect_document_corners
from .perspective import warp_perspective
from .enhancer import enhance_color, enhance_bw

class DocumentScanner:
    @staticmethod
    def process_image(input_source, output_path=None, mode="color"):
        """
        Runs the full document scanning pipeline.
        Args:
            input_source: Can be a filepath (str) or a numpy BGR image array.
            output_path: Path to save the processed image. If None, won't write to disk.
            mode: "color" for CamScanner shadow division, "bw" for adaptive thresholding.
        Returns:
            A tuple of (processed_image, metadata)
            metadata includes:
                "success": bool,
                "corners_detected": bool,
                "detected_corners": list of lists of floats (or None),
                "original_size": [width, height],
                "processed_size": [width, height]
        """
        # 1. Load image if path is given
        if isinstance(input_source, str):
            if not os.path.exists(input_source):
                raise FileNotFoundError(f"Input image not found: {input_source}")
            image = cv2.imread(input_source)
            if image is None:
                raise ValueError(f"Could not load image: {input_source}")
        else:
            image = input_source
            
        h, w = image.shape[:2]
        metadata = {
            "success": True,
            "corners_detected": False,
            "detected_corners": None,
            "original_size": [w, h],
            "processed_size": [w, h]
        }
        
        # 2. Detect corners
        try:
            corners = detect_document_corners(image)
        except Exception as e:
            print(f"DEBUG [scanner] Corner detection crashed: {e}")
            corners = None
            
        # 3. Warp perspective if corners found
        if corners is not None:
            metadata["corners_detected"] = True
            # Convert np.float32 coordinates to nested lists for JSON serializability
            metadata["detected_corners"] = corners.tolist()
            try:
                warped = warp_perspective(image, corners)
            except Exception as e:
                print(f"DEBUG [scanner] Perspective warp failed: {e}. Falling back to original.")
                warped = image.copy()
        else:
            print("DEBUG [scanner] No document corners detected. Skipping perspective warp.")
            warped = image.copy()
            
        # 4. Enhance
        try:
            if mode == "bw":
                enhanced = enhance_bw(warped)
            else:
                enhanced = enhance_color(warped)
        except Exception as e:
            print(f"DEBUG [scanner] Enhancement failed: {e}. Falling back to warped/original image.")
            enhanced = warped
            
        eh, ew = enhanced.shape[:2]
        metadata["processed_size"] = [ew, eh]
        
        # 5. Save output if path is specified
        if output_path:
            # Ensure output directory exists
            os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
            cv2.imwrite(output_path, enhanced)
            
        return enhanced, metadata
