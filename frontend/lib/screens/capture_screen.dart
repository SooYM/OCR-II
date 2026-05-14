import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:animate_do/animate_do.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import '../widgets/glass_card.dart';
import '../services/api_service.dart';
import 'verify_screen.dart';

/// Screen 1: Capture or pick medical report images (supports multi-page).
/// After processing, navigates to VerifyScreen with extracted data.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];
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
      if (source == ImageSource.gallery) {
        // Allow picking multiple images from gallery
        final List<XFile> images = await _picker.pickMultiImage(
          imageQuality: 90,
        );
        if (images.isNotEmpty) {
          setState(() {
            _selectedImages.addAll(images);
          });
        }
      } else {
        // Camera: pick one at a time, add to list
        final XFile? image = await _picker.pickImage(
          source: source,
          imageQuality: 90,
        );
        if (image != null) {
          setState(() {
            _selectedImages.add(image);
          });
        }
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

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _clearAllImages() {
    setState(() {
      _selectedImages.clear();
    });
  }

  Future<void> _processImages() async {
    if (_selectedImages.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Uploading ${_selectedImages.length} page(s)...';
      _progress = 0.15;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() {
        _statusMessage = _selectedImages.length > 1
            ? 'Analyzing ${_selectedImages.length} pages...'
            : 'Running OCR extraction...';
        _progress = 0.4;
      });

      // Actual API call — uploads all pages, runs LLM parsing
      final report = await ApiService.uploadMultipleReports(_selectedImages);

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
        _selectedImages.clear();
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Server URL',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
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
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(context)),
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
                              gradient: AppTheme.primaryGradient(context),
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
                                Text(
                                  'MedScan',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context).colorScheme.onSurface,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  _selectedImages.isEmpty
                                      ? 'Snap a medical report to begin'
                                      : '${_selectedImages.length} page(s) captured',
                                  style: TextStyle(
                                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? AppTheme.textSecondary,
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
                      child: _selectedImages.isEmpty
                          ? _buildUploadArea()
                          : _buildMultiImagePreview(),
                    ),

                    const SizedBox(height: 24),

                    // Action buttons
                    if (_selectedImages.isEmpty && !_isProcessing) ...[
                      FadeInUp(
                        delay: const Duration(milliseconds: 200),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildActionCard(
                                icon: Icons.camera_alt_rounded,
                                label: 'Camera',
                                subtitle: 'Take a photo',
                                gradient: AppTheme.primaryGradient(context),
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
                                gradient: AppTheme.accentGradient(context),
                                onTap: () =>
                                    _pickImage(ImageSource.gallery),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_selectedImages.isNotEmpty && !_isProcessing) ...[
                      FadeInUp(
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: GradientButton(
                                label: _selectedImages.length == 1
                                    ? 'Process Report'
                                    : 'Process ${_selectedImages.length} Pages',
                                icon: Icons.auto_awesome,
                                onPressed: _processImages,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Add more pages
                                TextButton.icon(
                                  onPressed: () => _showAddMoreOptions(),
                                  icon: Icon(Icons.add_photo_alternate,
                                      color: Theme.of(context).colorScheme.primary, size: 18),
                                  label: Text(
                                    'Add pages',
                                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Clear all
                                TextButton.icon(
                                  onPressed: _clearAllImages,
                                  icon: const Icon(Icons.refresh,
                                      color: AppTheme.textSecondary, size: 18),
                                  label: const Text(
                                    'Start over',
                                    style:
                                        TextStyle(color: AppTheme.textSecondary),
                                  ),
                                ),
                              ],
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

  void _showAddMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textTertiary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Add More Pages',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_selectedImages.length} page(s) already added',
              style: const TextStyle(color: AppTheme.textTertiary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 22),
              ),
              title: Text('Camera',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
              subtitle: const Text('Take another photo',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library_rounded,
                    color: Colors.white, size: 22),
              ),
              title: Text('Gallery',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
              subtitle: const Text('Pick from library',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
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
            color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
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
              Text(
                'Tap to scan a report',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Supports multi-page reports',
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

  Widget _buildMultiImagePreview() {
    return FadeIn(
      child: Column(
        children: [
          // Page count header
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.collections, size: 14, color: AppTheme.primaryLight),
                      const SizedBox(width: 6),
                      Text(
                        '${_selectedImages.length} page(s)',
                        style: const TextStyle(
                          color: AppTheme.primaryLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Text(
                  'Swipe to browse • Tap ✕ to remove',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ),
          // Scrollable page thumbnails
          Expanded(
            child: _selectedImages.length == 1
                ? _buildSingleImagePreview(0)
                : PageView.builder(
                    itemCount: _selectedImages.length,
                    controller: PageController(viewportFraction: 0.85),
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: _buildPageCard(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleImagePreview(int index) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(_selectedImages[index].path),
            fit: BoxFit.cover,
          ),
          // Gradient overlay at top
          Positioned(
            top: 0, left: 0, right: 0, height: 80,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                ),
              ),
            ),
          ),
          // Page badge
          Positioned(
            top: 12, left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description, color: Colors.white70, size: 14),
                  SizedBox(width: 6),
                  Text('Page 1',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          // Remove button
          Positioned(
            top: 12, right: 12,
            child: GestureDetector(
              onTap: () => _removeImage(index),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.85),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageCard(int index) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(_selectedImages[index].path),
            fit: BoxFit.cover,
          ),
          // Gradient overlay
          Positioned(
            top: 0, left: 0, right: 0, height: 60,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
            ),
          ),
          // Bottom gradient
          Positioned(
            bottom: 0, left: 0, right: 0, height: 60,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                ),
              ),
            ),
          ),
          // Page number badge
          Positioned(
            top: 12, left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Page ${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          // Remove button
          Positioned(
            top: 12, right: 12,
            child: GestureDetector(
              onTap: () => _removeImage(index),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.85),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
          // Page indicator at bottom
          Positioned(
            bottom: 12, left: 0, right: 0,
            child: Center(
              child: Text(
                '${index + 1} of ${_selectedImages.length}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
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
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? AppTheme.textTertiary,
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
      color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.92),
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
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
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
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? AppTheme.textTertiary,
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
