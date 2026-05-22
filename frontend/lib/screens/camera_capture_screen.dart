
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

/// A premium, custom camera screen that displays a visual framing guide
/// in the center of the screen to help the user align medical reports.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isPermissionDenied = false;
  String _errorMessage = '';
  FlashMode _currentFlashMode = FlashMode.auto;
  bool _isTakingPicture = false;

  // Flash animation controller
  late AnimationController _flashAnimationController;
  late Animation<double> _flashAnimation;

  // Focus tap details
  Offset? _focusPosition;
  late AnimationController _focusAnimationController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _flashAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _flashAnimation = Tween<double>(begin: 0.0, end: 0.8).animate(
      CurvedAnimation(parent: _flashAnimationController, curve: Curves.easeIn),
    );

    _focusAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _flashAnimationController.dispose();
    _focusAnimationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    // App state changed before we are initialized or if controller is null
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = 'No camera devices found.';
          });
        }
        return;
      }

      // Target the rear camera
      final backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _controller = controller;

      await controller.initialize();

      // Set default flash mode
      await controller.setFlashMode(_currentFlashMode);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPermissionDenied = false;
        });
      }
    } on CameraException catch (e) {
      if (mounted) {
        setState(() {
          if (e.code == 'CameraAccessDenied') {
            _isPermissionDenied = true;
          } else {
            _errorMessage = 'Camera initialization failed: ${e.description}';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred: $e';
        });
      }
    }
  }

  Future<void> _cycleFlashMode() async {
    if (_controller == null || !_isInitialized) return;

    FlashMode nextMode;
    switch (_currentFlashMode) {
      case FlashMode.off:
        nextMode = FlashMode.always;
        break;
      case FlashMode.always:
        nextMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        nextMode = FlashMode.off;
        break;
      default:
        nextMode = FlashMode.auto;
    }

    try {
      await _controller!.setFlashMode(nextMode);
      setState(() {
        _currentFlashMode = nextMode;
      });
    } catch (e) {
      debugPrint('Error setting flash mode: $e');
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_isInitialized || _isTakingPicture) return;

    try {
      setState(() {
        _isTakingPicture = true;
      });

      // Trigger shutter flash animation
      _flashAnimationController.forward().then((_) {
        _flashAnimationController.reverse();
      });

      final XFile file = await _controller!.takePicture();

      if (mounted) {
        Navigator.pop(context, file);
      }
    } catch (e) {
      setState(() {
        _isTakingPicture = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            content: Text('Failed to capture photo: $e'),
          ),
        );
      }
    }
  }

  Future<void> _handleTapToFocus(TapDownDetails details) async {
    if (_controller == null || !_isInitialized) return;

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final Offset localPosition = box.globalToLocal(details.globalPosition);
    final double dx = localPosition.dx / box.size.width;
    final double dy = localPosition.dy / box.size.height;

    // Normalizing coordinates to [0.0, 1.0] range
    final Offset focusPoint = Offset(
      dx.clamp(0.0, 1.0),
      dy.clamp(0.0, 1.0),
    );

    try {
      if (_controller!.value.exposurePointSupported) {
        await _controller!.setExposurePoint(focusPoint);
      }
      if (_controller!.value.focusPointSupported) {
        await _controller!.setFocusPoint(focusPoint);
        await _controller!.setFocusMode(FocusMode.auto);
      }

      setState(() {
        _focusPosition = localPosition;
      });
      _focusAnimationController.forward(from: 0.0);
    } catch (e) {
      debugPrint('Error setting focus/exposure point: $e');
    }
  }

  Widget _buildFlashIcon() {
    switch (_currentFlashMode) {
      case FlashMode.off:
        return const Icon(Icons.flash_off_rounded, color: Colors.white70);
      case FlashMode.always:
        return const Icon(Icons.flash_on_rounded, color: Colors.amber);
      case FlashMode.auto:
        return const Icon(Icons.flash_auto_rounded, color: Colors.cyanAccent);
      default:
        return const Icon(Icons.flash_off_rounded, color: Colors.white70);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        top: false,
        bottom: false,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isPermissionDenied) {
      return _buildPermissionDeniedUI();
    }

    if (_errorMessage.isNotEmpty) {
      return _buildErrorUI();
    }

    if (!_isInitialized || _controller == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Camera Viewfinder (Fullscreen Fitted)
        Positioned.fill(
          child: GestureDetector(
            onTapDown: _handleTapToFocus,
            behavior: HitTestBehavior.opaque,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxWidth * _controller!.value.aspectRatio,
                        child: CameraPreview(_controller!),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Framing Overlay Guide (Custom Painter)
        Positioned.fill(
          child: CustomPaint(
            painter: DocumentScannerOverlayPainter(
              borderColor: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ),

        // Shutter flash effect
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _flashAnimation,
            builder: (context, child) {
              return Container(
                color: Colors.white.withValues(alpha: _flashAnimation.value),
              );
            },
          ),
        ),

        // Focus indicator ring
        if (_focusPosition != null)
          AnimatedBuilder(
            animation: _focusAnimationController,
            builder: (context, child) {
              final double value = _focusAnimationController.value;
              final double scale = 1.4 - (0.4 * value); // 1.4 down to 1.0
              final double opacity = 1.0 - value; // 1.0 down to 0.0

              if (opacity <= 0.0) return const SizedBox.shrink();

              return Positioned(
                left: _focusPosition!.dx - 36,
                top: _focusPosition!.dy - 36,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.amberAccent,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.center_focus_weak_rounded,
                            color: Colors.amberAccent,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

        // UI Controls and Overlays
        Positioned.fill(
          child: Column(
            children: [
              // Top Bar
              _buildTopBar(),

              // Middle Spacer containing the Instruction Card
              _buildInstructionOverlay(),

              const Spacer(),

              // Bottom Control Panel
              _buildBottomControlPanel(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 12,
        left: 16,
        right: 16,
      ),
      color: Colors.black.withValues(alpha: 0.4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Exit button
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black26,
              padding: const EdgeInsets.all(12),
            ),
          ),
          // Screen Title
          const Text(
            'Scan Report',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          // Flash Toggle Button
          IconButton(
            onPressed: _cycleFlashMode,
            icon: _buildFlashIcon(),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black26,
              padding: const EdgeInsets.all(12),
            ),
            tooltip: 'Toggle Flash',
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionOverlay() {
    return Container(
      margin: const EdgeInsets.only(top: 24, left: 32, right: 32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: GlassCard(
            showBorder: false,
            backgroundColor: Colors.black.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.crop_free_rounded, color: Theme.of(context).colorScheme.secondary, size: 20),
                const SizedBox(width: 10),
                const Flexible(
                  child: Text(
                    'Align the medical report inside the frame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControlPanel() {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      padding: EdgeInsets.only(
        top: 24,
        bottom: MediaQuery.of(context).padding.bottom + 24,
        left: 24,
        right: 24,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Center Shutter Button
          GestureDetector(
            onTap: _capturePhoto,
            child: Container(
              height: 84,
              width: 84,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white24,
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  height: _isTakingPicture ? 62 : 68,
                  width: _isTakingPicture ? 62 : 68,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.no_photography_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Camera Permission Required',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'We need camera permission to take photos of your medical reports. Please enable camera access in your system settings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Camera Error',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _initializeCamera,
              child: const Text('Try Again'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter that draws a dark semi-transparent mask with a centered
/// clear rectangular viewport matching the aspect ratio of a medical document.
class DocumentScannerOverlayPainter extends CustomPainter {
  final Color borderColor;

  DocumentScannerOverlayPainter({required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    // Define the scanning rectangle dimensions
    // Aspect ratio of typical document is ~1.35 (close to A4 1.41)
    double width = size.width * 0.82;
    double height = width * 1.35;

    // Limit maximum height so it doesn't overlap the top bar or bottom panel
    final double maxAllowedHeight = size.height * 0.62;
    if (height > maxAllowedHeight) {
      height = maxAllowedHeight;
      width = height / 1.35;
    }

    final double left = (size.width - width) / 2;
    final double top = (size.height - height) / 2;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, width, height),
      const Radius.circular(AppTheme.radiusMd),
    );

    // Draw dark mask around the cutout using even-odd fill path
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rect);

    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    // Draw a subtle border outline
    final borderPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(rect, borderPaint);

    // Draw glowing corner indicators/bracket marks in the app's Accent color
    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5;

    final double cornerLength = 28.0;

    // Top-Left corner
    canvas.drawPath(
      Path()
        ..moveTo(left, top + cornerLength)
        ..lineTo(left, top)
        ..lineTo(left + cornerLength, top),
      cornerPaint,
    );

    // Top-Right corner
    canvas.drawPath(
      Path()
        ..moveTo(left + width - cornerLength, top)
        ..lineTo(left + width, top)
        ..lineTo(left + width, top + cornerLength),
      cornerPaint,
    );

    // Bottom-Left corner
    canvas.drawPath(
      Path()
        ..moveTo(left, top + height - cornerLength)
        ..lineTo(left, top + height)
        ..lineTo(left + cornerLength, top + height),
      cornerPaint,
    );

    // Bottom-Right corner
    canvas.drawPath(
      Path()
        ..moveTo(left + width - cornerLength, top + height)
        ..lineTo(left + width, top + height)
        ..lineTo(left + width, top + height - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
