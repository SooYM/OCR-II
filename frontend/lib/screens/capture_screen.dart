import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dotted_border/dotted_border.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import '../widgets/glass_card.dart';
import '../services/api_service.dart';
import '../models/report_model.dart';
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
  bool _enhanceScan = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final List<XFile> images = await _picker.pickMultiImage(imageQuality: 90);
        if (images.isNotEmpty) {
          setState(() => _selectedImages.addAll(images));
        }
      } else {
        final XFile? image = await _picker.pickImage(source: source, imageQuality: 90);
        if (image != null) {
          setState(() => _selectedImages.add(image));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Theme.of(context).colorScheme.error, content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  void _clearAllImages() {
    setState(() => _selectedImages.clear());
  }

  Future<void> _processImages() async {
    if (_selectedImages.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = _enhanceScan ? 'Initializing scanner...' : 'Uploading ${_selectedImages.length} page(s)...';
      _progress = 0.10;
    });

    try {
      MedicalReport report;

      if (_enhanceScan) {
        final List<String> filepaths = [];
        final List<String> filenames = [];
        bool preprocessFailed = false;

        for (int i = 0; i < _selectedImages.length; i++) {
          final img = _selectedImages[i];
          setState(() {
            _statusMessage = 'Enhancing scan: Page ${i + 1} of ${_selectedImages.length}...';
            _progress = 0.15 + (0.45 * (i / _selectedImages.length));
          });

          try {
            final res = await ApiService.preprocessImage(img);
            if (res['success'] == true && res['filepath'] != null) {
              filepaths.add(res['filepath'] as String);
              filenames.add(img.name);
            } else {
              preprocessFailed = true;
              break;
            }
          } catch (e) {
            print('Preprocessing page ${i + 1} failed: $e. Falling back to original.');
            preprocessFailed = true;
            break;
          }
        }

        if (preprocessFailed || filepaths.length != _selectedImages.length) {
          // Fallback to raw upload
          setState(() {
            _statusMessage = 'Extracting medical data (fallback to raw)...';
            _progress = 0.65;
          });
          report = await ApiService.uploadMultipleReports(_selectedImages);
        } else {
          setState(() {
            _statusMessage = 'Extracting medical data...';
            _progress = 0.70;
          });
          report = await ApiService.uploadPreprocessedReports(filepaths, filenames);
        }
      } else {
        // Direct OCR on raw upload
        setState(() {
          _statusMessage = 'Extracting medical data...';
          _progress = 0.40;
        });
        report = await ApiService.uploadMultipleReports(_selectedImages);
      }

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
        if (report.isDuplicate) {
          _showDuplicateDialog(report);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => VerifyScreen(report: report)),
          );
        }
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Theme.of(context).colorScheme.error, content: Text('Processing failed: $e')),
        );
      }
    }
  }

  void _showDuplicateDialog(MedicalReport report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Duplicate Report'),
          ],
        ),
        content: const Text('This report has already been scanned. Duplicate reports are not stored to maintain data integrity.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => VerifyScreen(report: report)));
            },
            child: const Text('View Existing'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isWide = width > 600;

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(context)),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _selectedImages.isEmpty
                      ? _buildLandingUI(isWide)
                      : _buildPreviewUI(isWide),
                ),
              ],
            ),
            if (_isProcessing) _buildProcessingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outline, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Capture Report',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface, letterSpacing: -0.3)),
                Text(
                  _selectedImages.isEmpty ? 'Ready to scan' : '${_selectedImages.length} page(s) ready',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (_selectedImages.isNotEmpty)
            IconButton(
              onPressed: _clearAllImages,
              icon: Icon(Icons.delete_sweep_rounded, color: Theme.of(context).colorScheme.error),
              tooltip: 'Clear all',
            ),
        ],
      ),
    );
  }

  Widget _buildLandingUI(bool isWide) {
    if (isWide) {
      return _buildWideLandingUI();
    } else {
      return _buildNarrowLandingUI();
    }
  }

  Widget _buildNarrowLandingUI() {
    final double screenHeight = MediaQuery.of(context).size.height;
    final bool isShort = screenHeight < 700;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: isShort ? 12 : 24),
      child: Column(
        children: [
          const Spacer(),
          GestureDetector(
            onTap: () => _pickImage(ImageSource.camera),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final double scaleFactor = 1.0 + (_pulseController.value * 0.05);
                return Transform.scale(
                  scale: scaleFactor,
                  child: Container(
                    padding: EdgeInsets.all(isShort ? 24 : 32),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient(context),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3 * _pulseController.value),
                          blurRadius: isShort ? 24 : 32,
                          spreadRadius: isShort ? 6 : 8,
                        ),
                      ],
                    ),
                    child: Icon(Icons.qr_code_scanner_rounded, size: isShort ? 56 : 72, color: Colors.white),
                  ),
                );
              },
            ),
          ),
          Spacer(flex: isShort ? 1 : 2),
          Text(
            'Scan Medical Report',
            style: TextStyle(
              fontSize: isShort ? 20 : 24,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Snap photos of your report pages. Our AI will extract and analyze the biomarkers for you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isShort ? 12 : 14,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Spacer(flex: isShort ? 1 : 2),
          Container(
            padding: EdgeInsets.all(isShort ? 12 : 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tips_and_updates_rounded, color: Theme.of(context).colorScheme.primary, size: isShort ? 16 : 18),
                    const SizedBox(width: 8),
                    Text(
                      'Tips for High Accuracy:',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: isShort ? 12 : 13,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isShort ? 8 : 12),
                _buildTipRow(Icons.light_mode_rounded, 'Ensure the room is well-lit', isShort),
                _buildTipRow(Icons.crop_free_rounded, 'Keep the camera parallel to the paper', isShort),
                _buildTipRow(Icons.center_focus_strong_rounded, 'Make sure text is sharp and in focus', isShort),
              ],
            ),
          ),
          Spacer(flex: isShort ? 1 : 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: _buildModeCard(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: Theme.of(context).colorScheme.primary,
                  onTap: () => _pickImage(ImageSource.camera),
                  isShort: isShort,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildModeCard(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: Theme.of(context).colorScheme.secondary,
                  onTap: () => _pickImage(ImageSource.gallery),
                  isShort: isShort,
                ),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildWideLandingUI() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _pickImage(ImageSource.camera),
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final double scaleFactor = 1.0 + (_pulseController.value * 0.05);
                      return Transform.scale(
                        scale: scaleFactor,
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.primaryGradient(context),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.3 * _pulseController.value),
                                blurRadius: 32,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.qr_code_scanner_rounded, size: 72, color: Colors.white),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Scan Medical Report',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Snap photos of your report pages. Our AI will extract and analyze the biomarkers for you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tips_and_updates_rounded, color: Theme.of(context).colorScheme.primary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Tips for High Accuracy:',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTipRow(Icons.light_mode_rounded, 'Ensure the room is well-lit', false),
                      _buildTipRow(Icons.crop_free_rounded, 'Keep the camera parallel to the paper', false),
                      _buildTipRow(Icons.center_focus_strong_rounded, 'Make sure text is sharp and in focus', false),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: _buildModeCard(
                        icon: Icons.camera_alt_rounded,
                        label: 'Camera',
                        color: Theme.of(context).colorScheme.primary,
                        onTap: () => _pickImage(ImageSource.camera),
                        isShort: false,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildModeCard(
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        color: Theme.of(context).colorScheme.secondary,
                        onTap: () => _pickImage(ImageSource.gallery),
                        isShort: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipRow(IconData icon, String text, bool isShort) {
    return Padding(
      padding: EdgeInsets.only(bottom: isShort ? 6 : 8),
      child: Row(
        children: [
          Icon(icon, size: isShort ? 14 : 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: isShort ? 11 : 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9))),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({required IconData icon, required String label, required Color color, required VoidCallback onTap, required bool isShort}) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: isShort ? 12 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: isShort ? 24 : 32),
            SizedBox(height: isShort ? 6 : 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: isShort ? 11 : 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewUI(bool isWide) {
    return Column(
      children: [
        Expanded(
          child: isWide
              ? GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: _selectedImages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _selectedImages.length) {
                      return _buildAddMoreCard(isGrid: true);
                    }
                    return _buildImageItem(index, isGrid: true);
                  },
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _selectedImages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _selectedImages.length) {
                      return _buildAddMoreCard(isGrid: false);
                    }
                    return _buildImageItem(index, isGrid: false);
                  },
                ),
        ),
        _buildBottomActions(),
      ],
    );
  }

  Widget _buildImageItem(int index, {required bool isGrid}) {
    return Container(
      margin: EdgeInsets.only(bottom: isGrid ? 0 : 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: AspectRatio(
          aspectRatio: isGrid ? 1.4 : 16 / 9,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.file(
                  File(_selectedImages[index].path),
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _removeImage(index),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        style: IconButton.styleFrom(backgroundColor: Colors.black26),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddMoreCard({required bool isGrid}) {
    return GestureDetector(
      onTap: () => _pickImage(ImageSource.camera),
      child: DottedBorder(
        options: RoundedRectDottedBorderOptions(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
          strokeWidth: 2,
          dashPattern: const [8, 4],
          radius: const Radius.circular(AppTheme.radiusLg),
        ),
        child: AspectRatio(
          aspectRatio: isGrid ? 1.4 : 16 / 9,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_rounded, size: isGrid ? 32 : 40, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                const Text('Add another page', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outline, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.document_scanner_rounded,
                    color: _enhanceScan
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Enhance Document Scan',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
              Switch(
                value: _enhanceScan,
                onChanged: (val) {
                  setState(() => _enhanceScan = val);
                },
                activeColor: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          GradientButton(
            label: 'Analyze ${_selectedImages.length} Page(s)',
            icon: Icons.auto_awesome_rounded,
            onPressed: _processImages,
          ),
          const SizedBox(height: 12),
          Text('Ensure text is clear and readable',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black54,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: GlassCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(_statusMessage, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(value: _progress, borderRadius: BorderRadius.circular(10)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
