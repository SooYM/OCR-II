import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:animate_do/animate_do.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import '../widgets/glass_card.dart';
import '../services/api_service.dart';
import 'verify_screen.dart';

/// Screen 1: Capture or pick a medical report image.
/// After processing, navigates to VerifyScreen with extracted data.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  bool _isProcessing = false;
  String _statusMessage = '';
  double _progress = 0.0;
  late AnimationController _pulseController;
  bool? _serverConnected;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _checkServer();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkServer() async {
    final ok = await ApiService.checkConnection();
    if (mounted) setState(() => _serverConnected = ok);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.error,
            content: Text('Error picking image: $e'),
          ),
        );
      }
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Uploading report...';
      _progress = 0.15;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() {
        _statusMessage = 'Running OCR extraction...';
        _progress = 0.4;
      });

      // Actual API call — uploads, runs OCR, runs LLM parsing
      final report = await ApiService.uploadReport(_selectedImage!);

      setState(() {
        _statusMessage = 'Parsing data fields...';
        _progress = 0.8;
      });

      await Future.delayed(const Duration(milliseconds: 300));

      setState(() {
        _statusMessage = 'Done!';
        _progress = 1.0;
      });

      await Future.delayed(const Duration(milliseconds: 400));

      setState(() {
        _isProcessing = false;
        _selectedImage = null;
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyScreen(report: report),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.error,
            content: Text('Processing failed: $e'),
          ),
        );
      }
    }
  }

  void _showServerSettings() {
    final controller = TextEditingController(text: ApiService.baseUrl);
    bool testing = false;
    bool? testResult;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Server URL',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Paste your localtunnel URL here',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'https://your-tunnel.loca.lt',
                  prefixIcon: const Icon(Icons.link, color: AppTheme.textTertiary),
                  suffixIcon: testResult != null
                      ? Icon(
                          testResult! ? Icons.check_circle : Icons.error,
                          color: testResult! ? AppTheme.success : AppTheme.error,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: testing
                          ? null
                          : () async {
                              setSheetState(() {
                                testing = true;
                                testResult = null;
                              });
                              ApiService.setBaseUrl(controller.text.trim());
                              final ok = await ApiService.checkConnection();
                              setSheetState(() {
                                testing = false;
                                testResult = ok;
                              });
                            },
                      icon: testing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_find, size: 18),
                      label: Text(testing ? 'Testing...' : 'Test'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ApiService.setBaseUrl(controller.text.trim());
                        _checkServer();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppTheme.success,
                            content: Text('Server URL updated'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    // Header
                    FadeInDown(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                            ),
                            child: const Icon(Icons.document_scanner_outlined,
                                color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'MedScan',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const Text(
                                  'Snap a medical report to begin',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Server status + settings
                          GestureDetector(
                            onTap: _showServerSettings,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _serverConnected == null
                                          ? AppTheme.warning
                                          : _serverConnected!
                                              ? AppTheme.success
                                              : AppTheme.error,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.settings,
                                      size: 18, color: AppTheme.textSecondary),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Image preview or upload area
                    Expanded(
                      child: _selectedImage == null
                          ? _buildUploadArea()
                          : _buildImagePreview(),
                    ),

                    const SizedBox(height: 24),

                    // Action buttons
                    if (_selectedImage == null && !_isProcessing) ...[
                      FadeInUp(
                        delay: const Duration(milliseconds: 200),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildActionCard(
                                icon: Icons.camera_alt_rounded,
                                label: 'Camera',
                                subtitle: 'Take a photo',
                                gradient: AppTheme.primaryGradient,
                                onTap: () =>
                                    _pickImage(ImageSource.camera),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildActionCard(
                                icon: Icons.photo_library_rounded,
                                label: 'Gallery',
                                subtitle: 'Choose existing',
                                gradient: AppTheme.accentGradient,
                                onTap: () =>
                                    _pickImage(ImageSource.gallery),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_selectedImage != null && !_isProcessing) ...[
                      FadeInUp(
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: GradientButton(
                                label: 'Process Report',
                                icon: Icons.auto_awesome,
                                onPressed: _processImage,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => _selectedImage = null),
                              icon: const Icon(Icons.refresh,
                                  color: AppTheme.textSecondary, size: 18),
                              label: const Text(
                                'Choose different image',
                                style:
                                    TextStyle(color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),
                  ],
                ),
              ),

              // Processing overlay
              if (_isProcessing) _buildProcessingOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadArea() {
    return FadeIn(
      child: GestureDetector(
        onTap: () => _pickImage(ImageSource.camera),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(
              color: AppTheme.primary.withOpacity(0.2),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.08),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primary.withOpacity(0.15),
                            AppTheme.primary.withOpacity(0.05),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary
                                .withOpacity(0.15 * _pulseController.value),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.document_scanner_outlined,
                        size: 56,
                        color: AppTheme.primaryLight,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              const Text(
                'Tap to scan a report',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Use camera or pick from gallery',
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return FadeIn(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(_selectedImage!.path),
              fit: BoxFit.cover,
            ),
            // Gradient overlay at top
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 80,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // File info badge
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.image, color: Colors.white70, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      _selectedImage!.name.length > 20
                          ? '${_selectedImage!.name.substring(0, 20)}...'
                          : _selectedImage!.name,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.surfaceBorder),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: AppTheme.background.withOpacity(0.92),
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: FadeInUp(
          child: GlassCard(
            width: 300,
            padding: const EdgeInsets.all(36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    strokeWidth: 5,
                    value: _progress > 0 ? _progress : null,
                    backgroundColor: AppTheme.surfaceBorder,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 6,
                    backgroundColor: AppTheme.surfaceBorder,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${(_progress * 100).toInt()}%',
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
