import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import '../widgets/glass_card.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/report_model.dart';
import '../utils/formatters.dart';
import '../utils/date_utils.dart';
import '../utils/biomarker_dictionary.dart';
import 'package:intl/intl.dart';

/// Screen 2: Verify and correct extracted data, then send.
/// Receives the MedicalReport directly from CaptureScreen (no API fetch needed).
class VerifyScreen extends StatefulWidget {
  final MedicalReport report;

  const VerifyScreen({super.key, required this.report});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  late StructuredData _data;
  bool _isSending = false;
  bool _hasChanges = false;
  final Set<int> _matchedIndices = {};
  final Map<int, BiomarkerEntry> _matchedEntries = {};

  @override
  void initState() {
    super.initState();
    // Copy structured data so we can edit it
    _data = widget.report.structuredData ??
        StructuredData(
          patientName: '',
          patientId: '',
          date: '',
          testName: '',
          doctorName: '',
          hospitalName: '',
          results: [],
          notes: '',
        );
        
    // Auto-fill username in the patient name section if empty
    if ((_data.patientName == null || _data.patientName!.isEmpty) &&
        AuthService.currentUser != null) {
      _data.patientName = AuthService.currentUser!['name'] as String?;
    }

    // Auto-normalize results against the standard dictionary
    _normalizeResults();
  }

  /// Run each test result through the biomarker dictionary matcher.
  void _normalizeResults() {
    for (int i = 0; i < _data.results.length; i++) {
      final result = _data.results[i];
      final match = BiomarkerDictionary.match(result.testItem);
      if (match != null) {
        _matchedIndices.add(i);
        _matchedEntries[i] = match;
        // Set key if missing
        result.key ??= match.key;
        // Set unit if empty or non-standard
        if ((result.unit == null || result.unit!.isEmpty) && match.unit.isNotEmpty) {
          result.unit = match.unit;
        }
        // Set reference range if empty
        if ((result.referenceRange == null || result.referenceRange!.isEmpty) && match.referenceRange != null) {
          result.referenceRange = match.referenceRange;
        }
      }
    }
  }

  Future<void> _handleSend() async {
    if (_data.date == null || _data.date!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: const Text('Please enter the collected date before sending.'),
        ),
      );
      return;
    }

    final parsedDate = DateParser.parse(_data.date!);
    if (parsedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: const Text('Invalid date format. Please use DD / MM / YYYY'),
        ),
      );
      return;
    }
    
    // Normalize format before saving
    _data.date = DateFormat('dd / MM / yyyy').format(parsedDate);

    setState(() => _isSending = true);

    try {
      // Step 1: Save corrected data
      await ApiService.updateReport(widget.report.id, _data);

      // Step 2: Mark as sent
      await ApiService.sendReport(widget.report.id);

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            content: Text('Failed to send: $e'),
          ),
        );
      }
    }
  }


  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: FadeInUp(
          child: GlassCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Report Sent!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Data has been verified and submitted successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    label: 'Scan Next Report',
                    icon: Icons.camera_alt_rounded,
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Back to CaptureScreen
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addTestResult() {
    setState(() {
      _data.results.add(TestResult(testItem: '', value: ''));
      _hasChanges = true;
    });
  }

  void _removeTestResult(int index) {
    setState(() {
      _data.results.removeAt(index);
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            if (_hasChanges) {
              _showDiscardDialog();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verify Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              'Review and correct extracted fields',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Scrollable form
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Patient Info Section
                FadeInUp(
                  duration: const Duration(milliseconds: 400),
                  child: _buildSectionHeader(
                    'Patient Information',
                    Icons.person_outline,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                FadeInUp(
                  delay: const Duration(milliseconds: 100),
                  child: GlassCard(
                    child: Column(
                      children: [
                        _buildField(
                          label: 'Patient Name',
                          value: _data.patientName ?? '',
                          icon: Icons.badge_outlined,
                          onChanged: (v) {
                            _data.patientName = v;
                            _hasChanges = true;
                          },
                        ),
                        const Divider(),
                        _buildField(
                          label: 'Patient ID',
                          value: _data.patientId ?? '',
                          icon: Icons.numbers,
                          onChanged: (v) {
                            _data.patientId = v;
                            _hasChanges = true;
                          },
                        ),
                        const Divider(),
                        _buildField(
                          label: 'Date',
                          value: _data.date ?? '',
                          icon: Icons.calendar_today_outlined,
                          keyboardType: TextInputType.number,
                          inputFormatters: [DateInputFormatter()],
                          onChanged: (v) {
                            _data.date = v;
                            _hasChanges = true;
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Report Context Section
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: _buildSectionHeader(
                    'Report Details',
                    Icons.medical_services_outlined,
                    Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 12),
                FadeInUp(
                  delay: const Duration(milliseconds: 300),
                  child: GlassCard(
                    child: Column(
                      children: [
                        _buildField(
                          label: 'Test Name',
                          value: _data.testName ?? '',
                          icon: Icons.science_outlined,
                          onChanged: (v) {
                            _data.testName = v;
                            _hasChanges = true;
                          },
                        ),
                        const Divider(),
                        _buildField(
                          label: 'Doctor',
                          value: _data.doctorName ?? '',
                          icon: Icons.medical_information_outlined,
                          onChanged: (v) {
                            _data.doctorName = v;
                            _hasChanges = true;
                          },
                        ),
                        const Divider(),
                        _buildField(
                          label: 'Hospital',
                          value: _data.hospitalName ?? '',
                          icon: Icons.local_hospital_outlined,
                          onChanged: (v) {
                            _data.hospitalName = v;
                            _hasChanges = true;
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Test Results Section
                FadeInUp(
                  delay: const Duration(milliseconds: 400),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader(
                        'Test Results',
                        Icons.analytics_outlined,
                        Theme.of(context).colorScheme.tertiary,
                      ),
                      GestureDetector(
                        onTap: _addTestResult,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 16, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                'Add Row',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                if (_data.results.isEmpty)
                  FadeInUp(
                    delay: const Duration(milliseconds: 500),
                    child: GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 36,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5)),
                          const SizedBox(height: 12),
                          Text(
                            'No test results extracted',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _addTestResult,
                            child: Text(
                              'Tap + Add Row to add manually',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...List.generate(_data.results.length, (index) {
                    return FadeInUp(
                      delay: Duration(milliseconds: 500 + (index * 60)),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildResultCard(index, _data.results[index]),
                      ),
                    );
                  }),

                const SizedBox(height: 24),

                // Notes Section
                FadeInUp(
                  delay: const Duration(milliseconds: 600),
                  child: _buildSectionHeader(
                    'Notes',
                    Icons.note_outlined,
                    Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 12),
                FadeInUp(
                  delay: const Duration(milliseconds: 700),
                  child: GlassCard(
                    child: TextFormField(
                      initialValue: _data.notes ?? '',
                      maxLines: 4,
                      onChanged: (v) {
                        _data.notes = v;
                        _hasChanges = true;
                      },
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        height: 1.5,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Any additional notes...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),

                // Bottom padding for the sticky button
                const SizedBox(height: 100),
              ],
            ),
          ),

          // Sticky Send button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerTheme.color ?? Theme.of(context).colorScheme.outline),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: _buildSendButton(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00D9A6), Color(0xFF00B4D8)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSending ? null : _handleSend,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSending)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                else ...[
                  const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'Send Report',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required String value,
    required IconData icon,
    required Function(String) onChanged,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              initialValue: value,
              onChanged: onChanged,
              inputFormatters: inputFormatters,
              keyboardType: keyboardType,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                  ),
                ),
                fillColor: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(int index, TestResult result) {
    final isMatched = _matchedIndices.contains(index);
    final matchEntry = _matchedEntries[index];

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header with index, match indicator, and delete
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isMatched
                      ? const Color(0xFF4CAF50).withOpacity(0.15)
                      : Theme.of(context).colorScheme.tertiary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: isMatched
                    ? const Icon(Icons.check_rounded, size: 16, color: Color(0xFF4CAF50))
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.tertiary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      initialValue: result.testItem,
                      onChanged: (v) {
                        result.testItem = v;
                        _hasChanges = true;
                        // Re-run matching for this item
                        final newMatch = BiomarkerDictionary.match(v);
                        setState(() {
                          if (newMatch != null) {
                            _matchedIndices.add(index);
                            _matchedEntries[index] = newMatch;
                            result.key = newMatch.key;
                            if (newMatch.unit.isNotEmpty) result.unit = newMatch.unit;
                            if (newMatch.referenceRange != null && (result.referenceRange == null || result.referenceRange!.isEmpty)) {
                              result.referenceRange = newMatch.referenceRange;
                            }
                          } else {
                            _matchedIndices.remove(index);
                            _matchedEntries.remove(index);
                          }
                        });
                      },
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Test item name',
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                      ),
                    ),
                    // Show matched standard name chip
                    if (isMatched && matchEntry != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '→ ${matchEntry.standardName}  •  ${matchEntry.unit}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4CAF50)),
                          ),
                        ),
                      ),
                    if (!isMatched && result.testItem.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 13, color: Theme.of(context).colorScheme.error.withOpacity(0.7)),
                            const SizedBox(width: 4),
                            Text(
                              'Not in standard dictionary',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.error.withOpacity(0.7)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _removeTestResult(index),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.close,
                      size: 14, color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Value + Unit row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildMiniField(
                  label: 'Value',
                  value: result.value,
                  onChanged: (v) {
                    result.value = v;
                    _hasChanges = true;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: _buildMiniField(
                  label: 'Unit',
                  value: result.unit ?? '',
                  onChanged: (v) {
                    result.unit = v;
                    _hasChanges = true;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Reference range
          _buildMiniField(
            label: 'Reference Range',
            value: result.referenceRange ?? '',
            onChanged: (v) {
              result.referenceRange = v;
              _hasChanges = true;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMiniField({
    required String label,
    required String value,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: value,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.secondary,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved corrections. Going back will discard them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back
            },
            child: Text('Discard', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}
