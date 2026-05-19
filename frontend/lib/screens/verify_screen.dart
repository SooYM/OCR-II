import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import '../widgets/glass_card.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/report_model.dart';
import '../utils/formatters.dart';
import '../utils/date_utils.dart';
import '../utils/biomarker_dictionary.dart';
import '../utils/unit_converter.dart';
import 'package:intl/intl.dart';
import 'main_screen.dart';

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
  final Set<int> _convertedIndices = {};
  final Map<int, BiomarkerEntry> _matchedEntries = {};
  final Map<int, UniqueKey> _valueFieldKeys = {};

  @override
  void initState() {
    super.initState();
    // Copy structured data so we can edit it
    _data = widget.report.structuredData ??
        StructuredData(
          patientName: '',
          patientId: '',
          date: '',
          time: '',
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
    
    // Normalize date format if possible
    if (_data.date != null && _data.date!.isNotEmpty) {
      final dt = DateParser.parse(_data.date!);
      if (dt != null) {
        final d = dt.day.toString().padLeft(2, '0');
        final m = dt.month.toString().padLeft(2, '0');
        _data.date = '$d / $m / ${dt.year}';
      }
    }
  }

  /// Run each test result through the biomarker dictionary matcher.
  void _normalizeResults() {
    for (int i = 0; i < _data.results.length; i++) {
      final result = _data.results[i];
      BiomarkerEntry? match;
      
      // 1. Try to match by key (crucial for saved reports where backend changed testItem)
      if (result.key != null && result.key!.isNotEmpty) {
        match = BiomarkerDictionary.getEntryByKey(result.key!);
      }
      
      // 2. Fallback to name matching
      match ??= BiomarkerDictionary.match(result.testItem, unit: result.unit);

      if (match != null) {
        _matchedIndices.add(i);
        _matchedEntries[i] = match;
        // Set key if missing
        result.key ??= match.key;

        // Always set unit from dictionary (clears wrong OCR units for qualitative items like urine glucose/bilirubin)
        if (match.allowedUnits.isNotEmpty) {
          // Has allowed units — normalize OCR casing or default to standard
          final normalized = (result.unit != null && result.unit!.isNotEmpty)
              ? _matchUnitCasing(result.unit!, match.allowedUnits)
              : null;
          result.unit = normalized ?? match.unit;
        } else {
          // No allowed units (qualitative/unitless) — always use dictionary unit (usually empty)
          result.unit = match.unit;
        }

        // Set reference range if empty, respecting the extracted unit
        if (result.referenceRange == null || result.referenceRange!.isEmpty) {
          final normUnit = result.unit?.toLowerCase().replaceAll(' ', '');
          final normStdUnit = match.unit.toLowerCase().replaceAll(' ', '');
          
          if (normUnit != null && normUnit != normStdUnit && match.referenceRangeSI != null && match.referenceRangeSI!.isNotEmpty && match.referenceRangeSI != 'N/A') {
            result.referenceRange = match.referenceRangeSI;
          } else if (match.referenceRange != null) {
            result.referenceRange = match.referenceRange;
          }
        }
      }
    }
  }

  /// Match an OCR-extracted unit string to the correct casing from allowedUnits.
  /// Returns the correctly-cased unit if found, null otherwise.
  String? _matchUnitCasing(String ocrUnit, List<String> allowedUnits) {
    final lower = ocrUnit.toLowerCase().replaceAll(' ', '');
    for (final allowed in allowedUnits) {
      if (allowed.toLowerCase().replaceAll(' ', '') == lower) {
        return allowed;
      }
    }
    return null;
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

    // Validate time if entered
    if (_data.time != null && _data.time!.trim().isNotEmpty) {
      final timeStr = _data.time!.trim();
      final timeRegExp = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)?$', caseSensitive: false);
      if (!timeRegExp.hasMatch(timeStr)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            content: const Text('Invalid time format. Please use HH:MM or HH:MM AM/PM'),
          ),
        );
        return;
      }
    }

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
                'Your medical data has been successfully verified and added to your history.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 32),
              GradientButton(
                label: 'Back to Dashboard',
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const MainScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
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
                _buildSectionHeader(
                  'Patient Information',
                  Icons.person_outline,
                  Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                GlassCard(
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
                      const Divider(),
                      _buildField(
                        label: 'Time',
                        value: _data.time ?? '',
                        icon: Icons.access_time_outlined,
                        hintText: 'e.g., 07:01:00 or 10:00 AM',
                        onChanged: (v) {
                          _data.time = v;
                          _hasChanges = true;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Report Context Section
                _buildSectionHeader(
                  'Report Details',
                  Icons.medical_services_outlined,
                  Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(height: 12),
                GlassCard(
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

                const SizedBox(height: 24),

                _buildSectionHeader(
                  'Test Results',
                  Icons.analytics_outlined,
                  Theme.of(context).colorScheme.tertiary,
                ),
                const SizedBox(height: 12),

                ..._buildGroupedTestResults(),

                const SizedBox(height: 24),

                // Notes Section
                _buildSectionHeader(
                  'Notes',
                  Icons.note_outlined,
                  Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(height: 12),
                GlassCard(
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
    String? hintText,
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
                hintText: hintText,
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _exceedsReferenceRange(String valueStr, String rangeStr) {
    if (valueStr.isEmpty || rangeStr.isEmpty) return false;

    final valStrClean = valueStr.replaceAll(',', '').trim();
    if (valStrClean.startsWith('<') || valStrClean.startsWith('>')) {
      if (valStrClean.replaceAll(' ', '') == rangeStr.replaceAll(' ', '')) {
        return false;
      }
      return false;
    }

    final val = double.tryParse(valStrClean);
    if (val == null) return false;

    final rangeClean = rangeStr.replaceAll(',', '').trim();

    double? combinedMin;
    double? combinedMax;
    bool hasRange = false;

    // 1. Extract all "X - Y" ranges (handles "13.8 - 17.2" or "Male: 13.8-17.2 | Female: 12.1-15.1")
    final rangeMatches = RegExp(r'(\d*\.?\d+)\s*-\s*(\d*\.?\d+)').allMatches(rangeClean);
    for (final match in rangeMatches) {
      final minVal = double.tryParse(match.group(1)!);
      final maxVal = double.tryParse(match.group(2)!);
      if (minVal != null && maxVal != null) {
        combinedMin = (combinedMin == null) ? minVal : (minVal < combinedMin ? minVal : combinedMin);
        combinedMax = (combinedMax == null) ? maxVal : (maxVal > combinedMax ? maxVal : combinedMax);
        hasRange = true;
      }
    }

    // 2. Extract all "< X" limits (handles "< 200")
    final lessMatches = RegExp(r'<\s*(\d*\.?\d+)').allMatches(rangeClean);
    for (final match in lessMatches) {
      final maxVal = double.tryParse(match.group(1)!);
      if (maxVal != null) {
        combinedMax = (combinedMax == null) ? maxVal : (maxVal > combinedMax ? maxVal : combinedMax);
        hasRange = true;
      }
    }

    // 3. Extract all "> X" limits (handles "> 40")
    final greaterMatches = RegExp(r'>\s*(\d*\.?\d+)').allMatches(rangeClean);
    for (final match in greaterMatches) {
      final minVal = double.tryParse(match.group(1)!);
      if (minVal != null) {
        combinedMin = (combinedMin == null) ? minVal : (minVal < combinedMin ? minVal : combinedMin);
        hasRange = true;
      }
    }

    if (!hasRange) return false;

    if (combinedMin != null && val < combinedMin) return true;
    if (combinedMax != null && val > combinedMax) return true;

    return false;
  }

  List<Widget> _buildGroupedTestResults() {
    if (_data.results.isEmpty) {
      return [
        GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 36, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5)),
              const SizedBox(height: 12),
              Text(
                'No test results extracted',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
              ),
            ],
          ),
        )
      ];
    }

    final Map<String, List<int>> grouped = {};
    for (var category in BiomarkerDictionary.medicalCategories.keys) {
      grouped[category] = [];
    }
    grouped['Other Metrics'] = [];

    for (int i = 0; i < _data.results.length; i++) {
      final match = _matchedEntries[i];
      String category = 'Other Metrics';
      
      if (match != null) {
        for (var entry in BiomarkerDictionary.medicalCategories.entries) {
          if (entry.value.contains(match.key)) {
            category = entry.key;
            break;
          }
        }
      }
      grouped[category]!.add(i);
    }

    grouped.removeWhere((key, value) => value.isEmpty);

    final List<Widget> widgets = [];
    for (var entry in grouped.entries) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
          child: Text(
            entry.key.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );
      for (int index in entry.value) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildResultCard(index, _data.results[index]),
          ),
        );
      }
    }
    
    return widgets;
  }

  Widget _buildResultCard(int index, TestResult result) {
    final isMatched = _matchedIndices.contains(index);
    final matchEntry = _matchedEntries[index];
    final String currentRefRange = result.referenceRange ?? (matchEntry?.referenceRange ?? '');
    final bool isExceeding = _exceedsReferenceRange(result.value, currentRefRange);

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
                    if (isMatched)
                      Text(
                        result.testItem,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      )
                    else
                      TextFormField(
                        initialValue: result.testItem,
                        onChanged: (v) {
                          result.testItem = v;
                          _hasChanges = true;
                          final newMatch = BiomarkerDictionary.match(v, unit: result.unit);
                          setState(() {
                            if (newMatch != null) {
                              _matchedIndices.add(index);
                              _matchedEntries[index] = newMatch;
                              result.key = newMatch.key;

                              if (newMatch.unit.isNotEmpty && (result.unit == null || result.unit!.isEmpty)) {
                                result.unit = newMatch.unit;
                              }
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
                    if (!isMatched && result.testItem.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 13, color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Text(
                              'Not in standard dictionary',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7)),
                            ),
                          ],
                        ),
                      ),
                  ],
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
                  key: _valueFieldKeys[index],
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
                child: (isMatched && matchEntry!.allowedUnits.length > 1)
                    // Multiple units available — show dropdown for conversion
                    ? _buildUnitDropdown(
                        label: 'Unit',
                        value: result.unit ?? matchEntry.unit,
                        biomarkerValue: result.value,
                        allowedUnits: matchEntry.allowedUnits,
                        onChanged: (v) {
                          if (v != null && v != result.unit) {
                            final oldUnit = result.unit ?? matchEntry.unit;
                            // Convert reference range
                            if (result.referenceRange != null && result.referenceRange!.isNotEmpty) {
                              final newRange = UnitConverter.convertRange(matchEntry.key, result.referenceRange!, oldUnit, v);
                              result.referenceRange = newRange;
                            }
                            // Convert value
                            if (result.value.isNotEmpty) {
                              final conversion = UnitConverter.convert(matchEntry.key, result.value, oldUnit, v);
                              if (conversion.wasConverted) {
                                result.value = conversion.convertedValue;
                                _valueFieldKeys[index] = UniqueKey();
                                if (!_convertedIndices.contains(index)) {
                                  _convertedIndices.add(index);
                                }
                              }
                            }
                            setState(() {
                              result.unit = v;
                              _hasChanges = true;
                            });
                          }
                        },
                      )
                    // Single or no unit — show as static text
                    : _buildStaticField(
                        label: 'Unit',
                        value: isMatched
                            ? (result.unit ?? matchEntry!.unit)
                            : (result.unit ?? ''),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Reference range
          isMatched
              ? _buildStaticField(
                  label: 'Reference Range',
                  value: result.referenceRange ?? '')
              : _buildMiniField(
                  label: 'Reference Range',
                  value: result.referenceRange ?? '',
                  onChanged: (v) {
                    result.referenceRange = v;
                    _hasChanges = true;
                  },
                ),
          if (isExceeding)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 14, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 6),
                  Text(
                    'Value exceeds reference range',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStaticField({required String label, required String value}) {
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value.isEmpty ? '—' : value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniField({
    Key? key,
    required String label,
    required String value,
    required Function(String) onChanged,
  }) {
    return Column(
      key: key,
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

  Widget _buildUnitDropdown({required String label, required String value, required String? biomarkerValue, required List<String> allowedUnits, required Function(String?) onChanged}) {
    List<String> units = List.from(allowedUnits);

    // Case-insensitive: match current value to an item in allowedUnits
    String effectiveValue = value;
    if (effectiveValue.isNotEmpty) {
      final lowerValue = effectiveValue.toLowerCase();
      final match = units.cast<String?>().firstWhere(
        (u) => u!.toLowerCase() == lowerValue,
        orElse: () => null,
      );
      if (match != null) {
        effectiveValue = match;
      } else {
        // OCR unit not in allowedUnits — insert it so dropdown doesn't crash
        units.insert(0, effectiveValue);
      }
    }

    final dropdownValue = effectiveValue.isEmpty ? (units.isNotEmpty ? units[0] : null) : effectiveValue;

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
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: dropdownValue,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              dropdownColor: Theme.of(context).colorScheme.surface,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              onChanged: onChanged,
              items: units.map<DropdownMenuItem<String>>((String val) {
                return DropdownMenuItem<String>(
                  value: val,
                  child: Text(val),
                );
              }).toList(),
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
