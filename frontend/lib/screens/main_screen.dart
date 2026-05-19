import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/report_model.dart';
import '../utils/formatters.dart';
import '../utils/date_utils.dart';
import '../utils/unit_converter.dart';
import 'capture_screen.dart';
import 'report_history_screen.dart';
import 'ai_chat_screen.dart';
import '../widgets/glass_card.dart';
import 'auth_screen.dart';
import 'settings_screen.dart';
import '../utils/biomarker_dictionary.dart';

/// Main screen with bottom navigation: Dashboard, Scan, My Reports.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final GlobalKey<AiChatScreenState> _chatKey = GlobalKey<AiChatScreenState>();

  // Dashboard state
  List<MedicalReport> _reports = [];
  bool _isLoadingDashboard = true;
  String? _dashboardError;
  
  // Multi-Attribute Chart state
  final Set<String> _selectedMultiAttributes = {};
  final Set<String> _expandedProfiles = {};
  DateTimeRange? _selectedDateRange;
  final List<Color> _lineColors = [
    const Color(0xFF6C63FF), // Primary
    const Color(0xFF00D9A6), // Accent
    const Color(0xFFFF6B6B), // Error/Red
    const Color(0xFFFFB347), // Warning/Orange
    const Color(0xFF4ECDC4), // Cyan
    const Color(0xFF74B9FF), // Info/Blue
    const Color(0xFFF06292), // Pink
    const Color(0xFFA1887F), // Brown
  ];

  bool _isMultiAttributeExpanded = false;

  // Categories moved to BiomarkerDictionary.medicalCategories

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoadingDashboard = true;
      _dashboardError = null;
    });

    try {
      final reports = await ApiService.fetchMyReports();
      if (mounted) {
        setState(() {
          _reports = reports;
          _isLoadingDashboard = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDashboard = false;
          _dashboardError = e.toString();
        });
      }
    }
  }


  double? _parseValue(String val) {
    final regex = RegExp(r'[+-]?([0-9]*[.])?[0-9]+');
    final match = regex.firstMatch(val);
    if (match != null) {
      return double.tryParse(match.group(0)!);
    }
    return null;
  }

  DateTime _parseDate(String? dateStr, String uploadTime) {
    if (dateStr == null || dateStr.trim().isEmpty) return DateTime.parse(uploadTime);
    
    // Normalize spaces around separators (e.g. "15 / 05 / 2026" → "15/05/2026")
    final normalized = dateStr.trim()
        .replaceAll(' / ', '/')
        .replaceAll(' - ', '-')
        .replaceAll(' . ', '.');
    
    final dt = DateTime.tryParse(normalized);
    if (dt != null) return dt;

    final formats = [
      DateFormat('dd MMM yyyy'),
      DateFormat('d MMM yyyy'),
      DateFormat('dd MMMM yyyy'),
      DateFormat('d MMMM yyyy'),
      DateFormat('MMM d, yyyy'),
      DateFormat('MMMM d, yyyy'),
      DateFormat('dd/MM/yyyy'),
      DateFormat('MM/dd/yyyy'),
      DateFormat('yyyy/MM/dd'),
      DateFormat('yyyy-MM-dd'),
      DateFormat('dd-MM-yyyy'),
    ];

    for (var format in formats) {
      try {
        return format.parse(normalized);
      } catch (_) {}
    }

    return DateTime.parse(uploadTime);
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboardTab(),
          const CaptureScreen(),
          AiChatScreen(key: _chatKey, dateRange: _selectedDateRange),
          const ReportHistoryScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildDashboardTab() {
    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(context)),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildDashboardHeader(),
            Expanded(
              child: _isLoadingDashboard
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.accent),
                    )
                  : _dashboardError != null
                      ? _buildDashboardError()
                      : _buildDashboardContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outline, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _getGreeting(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _showSimplifiedDatePicker,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _selectedDateRange != null 
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: _selectedDateRange != null ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5) : null,
              ),
              child: Icon(
                _selectedDateRange != null ? Icons.date_range_rounded : Icons.calendar_today_rounded, 
                size: 20,
                color: _selectedDateRange != null ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _fetchDashboardData,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.refresh_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _showSimplifiedDatePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _FilterBottomSheetContent(
          initialRange: _selectedDateRange,
          onApply: (range) {
            setState(() => _selectedDateRange = range);
            _chatKey.currentState?.updateDateRange(range);
          },
          onOpenCalendar: () {
            Navigator.pop(context);
            _showCalendarPicker();
          },
        );
      },
    );
  }

  Future<void> _showCalendarPicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _chatKey.currentState?.updateDateRange(picked);
    }
  }

  Widget _buildDashboardError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.cloud_off_rounded, size: 48, color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 24),
            Text('Unable to Load Dashboard',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text(_dashboardError ?? 'An unknown error occurred.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.5)),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: _fetchDashboardData,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient(context),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppTheme.primaryShadow(context),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    final name = AuthService.currentUser?['name'] ?? 'User';
    
    String greeting;
    if (hour >= 5 && hour < 12) {
      greeting = 'Good Morning';
    } else if (hour >= 12 && hour < 17) {
      greeting = 'Good Afternoon';
    } else if (hour >= 17 && hour < 21) {
      greeting = 'Good Evening';
    } else {
      greeting = 'Good Night';
    }
    
    return '$greeting, $name';
  }

  Widget _buildAiAnalysis() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      showBorder: false,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient(context),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_getGreeting(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface, letterSpacing: -0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget? _buildMiniChart(String testKey, List<MedicalReport> validReports, String displayName) {
    List<FlSpot> spots = [];
    double minX = 0;
    double maxX = (validReports.length - 1).toDouble();
    if (maxX < 1) maxX = 1;

    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    final entry = BiomarkerDictionary.getEntryByKey(testKey);
    final targetUnit = entry?.unit ?? '';

    for (int i = 0; i < validReports.length; i++) {
      final report = validReports[i];
      final result = report.structuredData!.results.firstWhere(
        (res) => (res.key ?? res.testItem) == testKey,
        orElse: () => TestResult(testItem: '', value: '-'),
      );
      if (result.value != '-') {
        double? val = _parseValue(result.value);
        if (val != null) {
          final srcUnit = (result.unit == null || result.unit!.isEmpty) ? targetUnit : result.unit!;
          if (srcUnit.isNotEmpty && targetUnit.isNotEmpty && srcUnit != targetUnit) {
            final conv = UnitConverter.convert(testKey, val.toString(), srcUnit, targetUnit);
            if (conv.wasConverted) {
              val = double.tryParse(conv.convertedValue) ?? val;
            }
          }

          spots.add(FlSpot(i.toDouble(), val));
          if (val < minY) minY = val;
          if (val > maxY) maxY = val;
        }
      }
    }

    if (spots.isEmpty) return null;

    if (minY == double.infinity) minY = 0;
    if (maxY == double.negativeInfinity) maxY = 10;
    double padding = (maxY - minY) * 0.2;
    if (padding == 0) padding = 1.0;

    return GestureDetector(
      onTap: () => _showFullScreenChart(testKey, displayName, validReports),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 260,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface))),
                  Icon(Icons.fullscreen_rounded, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 140,
                child: LineChart(
                  LineChartData(
                    minX: minX, maxX: maxX,
                    minY: minY - padding, maxY: maxY + padding,
                    gridData: FlGridData(
                      show: true, drawVerticalLine: false,
                      horizontalInterval: padding > 0 ? padding : null,
                      getDrawingHorizontalLine: (value) => FlLine(color: Theme.of(context).colorScheme.outline, strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true, reservedSize: 32, 
                          interval: (validReports.length > 5) ? (validReports.length / 4).ceilToDouble() : 1,
                          getTitlesWidget: (value, meta) {
                            int index = value.toInt();
                            if (index >= 0 && index < validReports.length) {
                              final report = validReports[index];
                              final date = _parseDate(report.structuredData?.date, report.uploadTime);
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(DateFormat('MMM d, yy').format(date), style: TextStyle(fontSize: 10)),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true, reservedSize: 36,
                          getTitlesWidget: (value, meta) {
                            return Text(value.toStringAsFixed(1), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10));
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (touchedSpot) => const Color(0xFF1F2937),
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final index = spot.x.toInt();
                            String dateLabel = '';
                            if (index >= 0 && index < validReports.length) {
                              final report = validReports[index];
                              final date = _parseDate(report.structuredData?.date, report.uploadTime);
                              dateLabel = DateFormat('MMM d, yyyy').format(date);
                            }
                            // Clean up trailing zeros up to 3 decimal places
                            final valStr = spot.y.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
                            return LineTooltipItem(
                              '$valStr\n$dateLabel',
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: false,
                        color: Theme.of(context).colorScheme.primary,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 4, color: Theme.of(context).colorScheme.primary, strokeWidth: 2, strokeColor: Theme.of(context).colorScheme.surface,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [Theme.of(context).colorScheme.primary.withValues(alpha: 0.3), Theme.of(context).colorScheme.primary.withValues(alpha: 0.0)],
                            begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          ),
                        ),
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

  void _showFullScreenChart(String testKey, String displayName, List<MedicalReport> validReports) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenChartPage(
          testKey: testKey,
          displayName: displayName,
          validReports: validReports,
          parseDate: _parseDate,
          parseValue: _parseValue,
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildCategorizedGraphs(List<MedicalReport> validReports, Set<String> uniqueTestKeys, Map<String, String> testKeyToName) {
    if (uniqueTestKeys.isEmpty) return const SizedBox();

    List<Widget> categoryWidgets = [];
    Set<String> processedKeys = {};

    for (var category in BiomarkerDictionary.medicalCategories.keys) {
      final categoryKeys = BiomarkerDictionary.medicalCategories[category]!;
      final presentKeys = uniqueTestKeys.where((k) => categoryKeys.contains(k)).toList();
      
      if (presentKeys.isNotEmpty) {
        List<Widget> chartWidgets = [];
        for (var testKey in presentKeys) {
          final chartWidget = _buildMiniChart(testKey, validReports, testKeyToName[testKey] ?? testKey);
          if (chartWidget != null) {
            chartWidgets.add(chartWidget);
            processedKeys.add(testKey);
          }
        }

        if (chartWidgets.isNotEmpty) {
          categoryWidgets.add(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                  child: Text('🩸 $category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  child: Row(
                    children: chartWidgets.map((w) => Padding(padding: const EdgeInsets.only(right: 16), child: w)).toList(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        }
      }
    }

    // Other Biomarkers
    final otherKeys = uniqueTestKeys.where((k) => !processedKeys.contains(k)).toList();
    if (otherKeys.isNotEmpty) {
      List<Widget> chartWidgets = [];
      for (var testKey in otherKeys) {
        final chartWidget = _buildMiniChart(testKey, validReports, testKeyToName[testKey] ?? testKey);
        if (chartWidget != null) {
          chartWidgets.add(chartWidget);
        }
      }

      if (chartWidgets.isNotEmpty) {
        categoryWidgets.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                child: Text('🔬 Other Biomarkers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.none,
                child: Row(
                  children: chartWidgets.map((w) => Padding(padding: const EdgeInsets.only(right: 16), child: w)).toList(),
                ),
              ),
            ],
          ),
        );
      }
    }

    if (categoryWidgets.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text('Biomarker Trends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
        ),
        ...categoryWidgets,
      ],
    );
  }

  Widget _buildMultiAttributeHeader() {
    return GestureDetector(
      onTap: () => setState(() => _isMultiAttributeExpanded = !_isMultiAttributeExpanded),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: _isMultiAttributeExpanded 
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
            : Theme.of(context).colorScheme.surface,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.stacked_line_chart_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Comparative Trends', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
                  Text(
                    _isMultiAttributeExpanded 
                        ? 'Select profiles below to drill across attributes' 
                        : 'Tap to expand and compare multiple attributes', 
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(
              _isMultiAttributeExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    // Filter reports based on the selected date range
    final filteredReports = _reports.where((r) {
      if (_selectedDateRange == null) return true;
      final date = _parseDate(r.structuredData?.date, r.uploadTime);
      // Include boundary dates
      return (date.isAfter(_selectedDateRange!.start) || date.isAtSameMomentAs(_selectedDateRange!.start)) && 
             (date.isBefore(_selectedDateRange!.end) || date.isAtSameMomentAs(_selectedDateRange!.end));
    }).toList();

    // Only use reports that are 'completed' or 'sent' and have structured data results
    final validReports = filteredReports.where((r) => 
        (r.status == 'completed' || r.status == 'sent') && 
        r.structuredData != null && 
        r.structuredData!.results.isNotEmpty
    ).toList()..sort((a, b) => _parseDate(a.structuredData?.date, a.uploadTime).compareTo(_parseDate(b.structuredData?.date, b.uploadTime)));

    if (validReports.isEmpty) {
      return Column(
        children: [
          if (_selectedDateRange != null) _buildFilterActiveIndicator(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),
                  Text(_selectedDateRange != null ? 'No Data in this Range' : 'No Data Available', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(_selectedDateRange != null ? 'Try selecting a wider date range.' : 'Scan a medical report to see your analytics.', style: const TextStyle(fontSize: 14)),
                  if (_selectedDateRange != null) ...[
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () => setState(() => _selectedDateRange = null),
                      icon: const Icon(Icons.filter_list_off_rounded),
                      label: const Text('Clear Date Filter'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Map of test keys to display names
    final Map<String, String> testKeyToName = {};
    final Set<String> numericTestKeys = {};
    
    for (var report in validReports) {
      for (var result in report.structuredData!.results) {
        final key = result.key ?? result.testItem;
        if (key != null) {
          if (!testKeyToName.containsKey(key)) {
            testKeyToName[key] = result.testItem;
          }
          if (_parseValue(result.value) != null) {
            numericTestKeys.add(key);
          }
        }
      }
    }

    final Set<String> uniqueTestKeys = testKeyToName.keys.toSet();

    final Set<String> nonNumericKeys = {
      'urine_colour', 'appearance', 'proteins', 'glucose', 'bilirubin',
      'ketones', 'blood', 'urobilinogen', 'nitrites', 'casts', 'crystals', 'others'
    };

    final Set<String> graphTestKeys = uniqueTestKeys.where((k) => !nonNumericKeys.contains(k)).toSet();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedDateRange != null) _buildFilterActiveIndicator(),
          
          // Multi-Attribute Comparison Section
          _buildMultiAttributeHeader(),
          if (_isMultiAttributeExpanded) ...[
            _buildAttributeSelector(graphTestKeys, testKeyToName),
            const SizedBox(height: 12),
            _buildMultiAttributeChart(validReports, testKeyToName),
          ],
          const SizedBox(height: 40),
          
          _buildCategorizedGraphs(validReports, graphTestKeys, testKeyToName),
          const SizedBox(height: 32),
          _buildRecentResultsTable(validReports, uniqueTestKeys, testKeyToName),
          const SizedBox(height: 100), // padding for bottom nav
        ],
      ),
    );
  }

  Widget _buildMultiAttributeChart(List<MedicalReport> validReports, Map<String, String> testKeyToName) {
    if (_selectedMultiAttributes.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.add_chart_rounded, size: 48, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
              const SizedBox(height: 16),
              Text('Select multiple metrics above to compare their trends in one view.', 
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    List<LineChartBarData> lines = [];
    double minX = 0;
    double maxX = (validReports.length - 1).toDouble();
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    int colorIndex = 0;
    for (final testKey in _selectedMultiAttributes) {
      final List<FlSpot> spots = [];
      for (int i = 0; i < validReports.length; i++) {
        final report = validReports[i];
        final result = report.structuredData!.results.firstWhere(
          (res) => (res.key ?? res.testItem) == testKey,
          orElse: () => TestResult(testItem: testKey, value: '-'),
        );
        if (result.value != '-') {
          final val = _parseValue(result.value);
          if (val != null) {
            spots.add(FlSpot(i.toDouble(), val));
            if (val < minY) minY = val;
            if (val > maxY) maxY = val;
          }
        }
      }

      if (spots.isNotEmpty) {
        final color = _lineColors[colorIndex % _lineColors.length];
        lines.add(LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 3.5,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
              radius: 4, color: color, strokeWidth: 2, strokeColor: Theme.of(context).colorScheme.surface,
            ),
          ),
          belowBarData: BarAreaData(show: false),
        ));
        colorIndex++;
      }
    }

    if (lines.isEmpty) return const SizedBox();

    double padding = (maxY - minY) * 0.2;
    if (padding <= 0) padding = 1.0;

    return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.stacked_line_chart_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Comparative Trends', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showMultiFullScreenChart(validReports, testKeyToName, lines, minX, maxX, minY, maxY, padding),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.fullscreen_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 280,
              child: LineChart(
                LineChartData(
                  minX: minX, maxX: maxX,
                  minY: minY - padding, maxY: maxY + padding,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(color: Theme.of(context).colorScheme.outline, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true, reservedSize: 32,
                        interval: (validReports.length > 5) ? (validReports.length / 4).ceilToDouble() : 1,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index >= 0 && index < validReports.length) {
                            final report = validReports[index];
                            final date = _parseDate(report.structuredData?.date, report.uploadTime);
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(DateFormat('MMM d').format(date), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true, reservedSize: 44,
                        getTitlesWidget: (value, meta) {
                          return Text(value.toStringAsFixed(1), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w500));
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: lines,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => const Color(0xFF1F2937),
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final testKey = _selectedMultiAttributes.elementAt(spot.barIndex);
                          final report = validReports[spot.x.toInt()];
                          final date = _parseDate(report.structuredData?.date, report.uploadTime);
                          final dateStr = DateFormat('MMM d, yyyy').format(date);
                          final valStr = spot.y.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');

                          // Add date to the first line of the tooltip
                          String text = (spot.barIndex == 0)
                              ? '$dateStr\n${testKeyToName[testKey]}: $valStr'
                              : '${testKeyToName[testKey]}: $valStr';

                          return LineTooltipItem(
                            text,
                            TextStyle(color: _lineColors[spot.barIndex % _lineColors.length], fontWeight: FontWeight.w800, fontSize: 12),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Legend
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: List.generate(_selectedMultiAttributes.length, (index) {
                final testKey = _selectedMultiAttributes.elementAt(index);
                final color = _lineColors[index % _lineColors.length];
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(testKeyToName[testKey] ?? testKey, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8))),
                  ],
                );
              }),
            ),
          ],
        ),
      );
  }

  void _showMultiFullScreenChart(List<MedicalReport> validReports, Map<String, String> testKeyToName, List<LineChartBarData> lines, double minX, double maxX, double minY, double maxY, double padding) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          // Dynamically adapt label counts based on the actual screen width to prevent overlap
          final screenWidth = MediaQuery.of(context).size.width;
          final maxLabels = (screenWidth / 95).floor().clamp(2, 8);
          final bottomInterval = (validReports.length / maxLabels).ceilToDouble();

          return FadeTransition(
            opacity: animation,
            child: Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.98),
              body: SafeArea(
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                              child: Icon(Icons.close_rounded, size: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Comparative Trends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
                                Text('${_selectedMultiAttributes.length} Attributes Overlay', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(gradient: AppTheme.accentGradient(context), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.stacked_line_chart_rounded, size: 20, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Large Chart
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 36, 16),
                        child: LineChart(
                          LineChartData(
                            minX: minX, maxX: maxX,
                            minY: minY - padding, maxY: maxY + padding,
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: true,
                              getDrawingHorizontalLine: (value) => FlLine(color: Theme.of(context).colorScheme.outline, strokeWidth: 0.8),
                              getDrawingVerticalLine: (value) => FlLine(color: Theme.of(context).colorScheme.outline, strokeWidth: 0.5),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true, reservedSize: 40,
                                  interval: bottomInterval > 0 ? bottomInterval : 1,
                                  getTitlesWidget: (value, meta) {
                                    int index = value.toInt();
                                    if (index >= 0 && index < validReports.length) {
                                      final report = validReports[index];
                                      final date = _parseDate(report.structuredData?.date, report.uploadTime);
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 10.0),
                                        child: Text(DateFormat('MMM d, yy').format(date), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                                      );
                                    }
                                    return const SizedBox();
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true, reservedSize: 48,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 11));
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: lines,
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (touchedSpot) => const Color(0xFF1F2937),
                                fitInsideHorizontally: true,
                                fitInsideVertically: true,
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    final testKey = _selectedMultiAttributes.elementAt(spot.barIndex);
                                    final report = validReports[spot.x.toInt()];
                                    final date = _parseDate(report.structuredData?.date, report.uploadTime);
                                    final dateStr = DateFormat('MMM d, yyyy').format(date);
                                    final valStr = spot.y.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');

                                    // Add date to the first line of the tooltip
                                    String text = (spot.barIndex == 0)
                                        ? '$dateStr\n${testKeyToName[testKey]}: $valStr'
                                        : '${testKeyToName[testKey]}: $valStr';

                                    return LineTooltipItem(
                                      text,
                                      TextStyle(color: _lineColors[spot.barIndex % _lineColors.length], fontWeight: FontWeight.w700, fontSize: 13),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Legend
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 20,
                          runSpacing: 12,
                          children: List.generate(_selectedMultiAttributes.length, (index) {
                            final testKey = _selectedMultiAttributes.elementAt(index);
                            final color = _lineColors[index % _lineColors.length];
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                const SizedBox(width: 8),
                                Text(testKeyToName[testKey] ?? testKey, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAttributeSelector(Set<String> uniqueTestKeys, Map<String, String> testKeyToName) {
    List<Widget> profileWidgets = [];

    for (var entry in BiomarkerDictionary.medicalCategories.entries) {
      final category = entry.key;
      final categoryKeys = entry.value;
      final availableKeys = uniqueTestKeys.where((k) => categoryKeys.contains(k)).toList();

      if (availableKeys.isNotEmpty) {
        int selectedInCategory = availableKeys.where((k) => _selectedMultiAttributes.contains(k)).length;
        
        profileWidgets.add(
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 8),
            child: MenuAnchor(
              builder: (context, controller, child) {
                return OutlinedButton(
                  onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    side: BorderSide(
                      color: selectedInCategory > 0 
                          ? Theme.of(context).colorScheme.primary 
                          : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                      width: selectedInCategory > 0 ? 1.5 : 1,
                    ),
                    backgroundColor: selectedInCategory > 0 
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05) 
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(category, 
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13, 
                            fontWeight: selectedInCategory > 0 ? FontWeight.w700 : FontWeight.w500,
                            color: selectedInCategory > 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (selectedInCategory > 0) ...[
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
                          child: Text(selectedInCategory.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Icon(Icons.arrow_drop_down, size: 18, color: selectedInCategory > 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
                    ],
                  ),
                );
              },
              menuChildren: availableKeys.map((testKey) {
                final isSelected = _selectedMultiAttributes.contains(testKey);
                final displayName = testKeyToName[testKey] ?? testKey;
                return MenuItemButton(
                  onPressed: () {
                    setState(() {
                      if (isSelected) {
                        _selectedMultiAttributes.remove(testKey);
                      } else {
                        _selectedMultiAttributes.add(testKey);
                      }
                    });
                  },
                  leadingIcon: Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                    color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  child: Text(displayName, style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                  )),
                );
              }).toList(),
            ),
          ),
        );
      }
    }

    // "Other" category for keys not in predefined categories
    final categorizedKeys = BiomarkerDictionary.medicalCategories.values.expand((e) => e).toSet();
    final otherKeys = uniqueTestKeys.where((k) => !categorizedKeys.contains(k)).toList();
    if (otherKeys.isNotEmpty) {
      int selectedInOther = otherKeys.where((k) => _selectedMultiAttributes.contains(k)).length;
      profileWidgets.add(
        Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 8),
          child: MenuAnchor(
            builder: (context, controller, child) {
              return OutlinedButton(
                onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  side: BorderSide(
                    color: selectedInOther > 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                    width: selectedInOther > 0 ? 1.5 : 1,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Flexible(child: Text('Other Metrics', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                    const SizedBox(width: 6),
                    if (selectedInOther > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, shape: BoxShape.circle),
                        child: Text(selectedInOther.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 4),
                    ],
                    const Icon(Icons.arrow_drop_down, size: 18),
                  ],
                ),
              );
            },
            menuChildren: otherKeys.map((testKey) {
              final isSelected = _selectedMultiAttributes.contains(testKey);
              final displayName = testKeyToName[testKey] ?? testKey;
              return MenuItemButton(
                onPressed: () {
                  setState(() {
                    if (isSelected) {
                      _selectedMultiAttributes.remove(testKey);
                    } else {
                      _selectedMultiAttributes.add(testKey);
                    }
                  });
                },
                leadingIcon: Icon(isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, color: isSelected ? Theme.of(context).colorScheme.primary : null, size: 20),
                child: Text(displayName, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400)),
              );
            }).toList(),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Wrap(
          children: profileWidgets,
        ),
        if (_selectedMultiAttributes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: () => setState(() => _selectedMultiAttributes.clear()),
              icon: const Icon(Icons.clear_all_rounded, size: 16),
              label: const Text('Clear All', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error, padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
            ),
          ),
      ],
      );
  }

  Widget _buildFilterActiveIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        child: Row(
          children: [
            Icon(Icons.filter_list_alt, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Filtering: ${DateFormat('MMM d, yyyy').format(_selectedDateRange!.start)} - ${DateFormat('MMM d, yyyy').format(_selectedDateRange!.end)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _selectedDateRange = null),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Icon(Icons.close_rounded, size: 14, color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentResultsTable(List<MedicalReport> validReports, Set<String> uniqueTestKeys, Map<String, String> testKeyToName) {
    final List<DataRow> rows = [];

    for (var entry in BiomarkerDictionary.medicalCategories.entries) {
      final category = entry.key;
      final categoryKeys = entry.value;
      final availableKeys = uniqueTestKeys.where((k) => categoryKeys.contains(k)).toList()..sort((a, b) => (testKeyToName[a] ?? a).compareTo(testKeyToName[b] ?? b));

      if (availableKeys.isNotEmpty) {
        final isExpanded = _expandedProfiles.contains(category);
        // Subheading Row
        rows.add(
          DataRow(
            color: WidgetStateProperty.all(Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)),
            onSelectChanged: (selected) {
              setState(() {
                if (isExpanded) {
                  _expandedProfiles.remove(category);
                } else {
                  _expandedProfiles.add(category);
                }
              });
            },
            cells: [
              DataCell(Row(
                children: [
                  Icon(isExpanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(category.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary, fontSize: 12, letterSpacing: 1.1)),
                ],
              )),
              ...List.generate(validReports.length, (_) => const DataCell(SizedBox())),
            ],
          ),
        );

        // Data Rows (Only if expanded)
        if (isExpanded) {
          for (final testKey in availableKeys) {
            rows.add(
              DataRow(
                cells: [
                  DataCell(Padding(
                    padding: const EdgeInsets.only(left: 28), // Indent to align with text after icon
                    child: Text(testKeyToName[testKey] ?? testKey, style: const TextStyle(fontWeight: FontWeight.w600)),
                  )),
                  ...validReports.map((report) {
                    final result = report.structuredData!.results.firstWhere(
                      (res) => (res.key ?? res.testItem) == testKey,
                      orElse: () => TestResult(testItem: testKey, value: '-'),
                    );
                    final valueText = result.value == '-' ? '-' : '${result.value} ${result.unit ?? ''}'.trim();
                    return DataCell(
                      Text(valueText, style: TextStyle(
                        color: result.value == '-' ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurface,
                        fontWeight: result.value == '-' ? FontWeight.w400 : FontWeight.w500,
                      )),
                    );
                  }),
                ],
              ),
            );
          }
        }
      }
    }

    // Other metrics not in categories
    final categorizedKeys = BiomarkerDictionary.medicalCategories.values.expand((e) => e).toSet();
    final otherKeys = uniqueTestKeys.where((k) => !categorizedKeys.contains(k)).toList()..sort((a, b) => (testKeyToName[a] ?? a).compareTo(testKeyToName[b] ?? b));
    
    if (otherKeys.isNotEmpty) {
      final isOtherExpanded = _expandedProfiles.contains('OTHER_METRICS');
      rows.add(
        DataRow(
          color: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)),
          onSelectChanged: (selected) {
            setState(() {
              if (isOtherExpanded) {
                _expandedProfiles.remove('OTHER_METRICS');
              } else {
                _expandedProfiles.add('OTHER_METRICS');
              }
            });
          },
          cells: [
            DataCell(Row(
              children: [
                Icon(isOtherExpanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded, size: 20),
                const SizedBox(width: 8),
                const Text('OTHER METRICS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.1)),
              ],
            )),
            ...List.generate(validReports.length, (_) => const DataCell(SizedBox())),
          ],
        ),
      );
      if (isOtherExpanded) {
        for (final testKey in otherKeys) {
          rows.add(
            DataRow(
              cells: [
                DataCell(Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Text(testKeyToName[testKey] ?? testKey, style: const TextStyle(fontWeight: FontWeight.w600)),
                )),
                ...validReports.map((report) {
                  final result = report.structuredData!.results.firstWhere(
                    (res) => (res.key ?? res.testItem) == testKey,
                    orElse: () => TestResult(testItem: testKey, value: '-'),
                  );
                  final valueText = result.value == '-' ? '-' : '${result.value} ${result.unit ?? ''}'.trim();
                  return DataCell(
                    Text(valueText, style: TextStyle(
                      color: result.value == '-' ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurface,
                      fontWeight: result.value == '-' ? FontWeight.w400 : FontWeight.w500,
                    )),
                  );
                }),
              ],
            ),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text('Biomarker Analytics Table', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
        ),
        const SizedBox(height: 8),
        GlassCard(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Theme.of(context).colorScheme.outline),
              child: DataTable(
                showCheckboxColumn: false,
                headingRowColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
                columnSpacing: 24,
                horizontalMargin: 16,
                dividerThickness: 1,
                dataRowMinHeight: 48,
                dataRowMaxHeight: 48,
                columns: [
                  DataColumn(
                    label: Text('Biomarker', style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                  ),
                  ...validReports.map((r) {
                    final date = _parseDate(r.structuredData?.date, r.uploadTime);
                    final dateStr = DateFormat('MMM d, yyyy').format(date);
                    return DataColumn(
                      label: Text(dateStr, style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
                    );
                  }),
                ],
                rows: rows,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outline, width: 1)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _buildNavItem(index: 0, icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded,
                  label: 'Dashboard', gradient: AppTheme.accentGradient(context)),
              _buildNavItem(index: 1, icon: Icons.document_scanner_outlined, activeIcon: Icons.document_scanner_rounded,
                  label: 'Scan', gradient: AppTheme.primaryGradient(context)),
              _buildNavItem(index: 2, icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome_rounded,
                  label: 'AI Chat', gradient: LinearGradient(colors: [Theme.of(context).colorScheme.secondary, const Color(0xFF7C4DFF)])),
              _buildNavItem(index: 3, icon: Icons.history_outlined, activeIcon: Icons.history_rounded,
                  label: 'My Reports', gradient: const LinearGradient(colors: [AppTheme.warning, Color(0xFFFF8A65)])),
              _buildNavItem(index: 4, icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded,
                  label: 'Settings', gradient: AppTheme.accentGradient(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index, required IconData icon, required IconData activeIcon,
    required String label, required LinearGradient gradient,
  }) {
    final isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isActive ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6) : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: isActive ? 20 : 0, height: 3,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(gradient: isActive ? gradient : null, borderRadius: BorderRadius.circular(2)),
              ),
              ShaderMask(
                shaderCallback: (bounds) {
                  if (isActive) return gradient.createShader(bounds);
                  return LinearGradient(colors: [Theme.of(context).colorScheme.onSurfaceVariant, Theme.of(context).colorScheme.onSurfaceVariant]).createShader(bounds);
                },
                child: Icon(isActive ? activeIcon : icon, size: 24, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(fontSize: 10, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6), letterSpacing: 0.2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterBottomSheetContent extends StatefulWidget {
  final DateTimeRange? initialRange;
  final Function(DateTimeRange?) onApply;
  final VoidCallback onOpenCalendar;

  const _FilterBottomSheetContent({
    required this.initialRange,
    required this.onApply,
    required this.onOpenCalendar,
  });

  @override
  State<_FilterBottomSheetContent> createState() => _FilterBottomSheetContentState();
}

class _FilterBottomSheetContentState extends State<_FilterBottomSheetContent> {
  late TextEditingController _startCtrl;
  late TextEditingController _endCtrl;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _startFocus = FocusNode();
  final FocusNode _endFocus = FocusNode();
  final GlobalKey _applyButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _startCtrl = TextEditingController(text: widget.initialRange != null ? DateFormat('dd / MM / yyyy').format(widget.initialRange!.start) : '');
    _endCtrl = TextEditingController(text: widget.initialRange != null ? DateFormat('dd / MM / yyyy').format(widget.initialRange!.end) : '');
    
    _startFocus.addListener(_onFocusChange);
    _endFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_startFocus.hasFocus || _endFocus.hasFocus) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _applyButtonKey.currentContext != null) {
          Scrollable.ensureVisible(
            _applyButtonKey.currentContext!,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            alignment: 1.0, // Scroll until the bottom of the button is visible
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    _scrollController.dispose();
    _startFocus.dispose();
    _endFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    // Push the entire sheet above the keyboard, and cap at 90% screen height
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -5)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle (fixed, not scrollable)
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text('Filter Reports', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
                    const Spacer(),
                    if (widget.initialRange != null)
                      TextButton.icon(
                        onPressed: () {
                          widget.onApply(null);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Clear'),
                        style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildRangeOption(Icons.today_rounded, 'Last 7 Days', () {
                        final end = DateTime.now();
                        final start = end.subtract(const Duration(days: 7));
                        widget.onApply(DateTimeRange(start: start, end: end));
                        Navigator.pop(context);
                      }),
                      _buildRangeOption(Icons.calendar_view_month_rounded, 'Last 30 Days', () {
                        final end = DateTime.now();
                        final start = end.subtract(const Duration(days: 30));
                        widget.onApply(DateTimeRange(start: start, end: end));
                        Navigator.pop(context);
                      }),
                      _buildRangeOption(Icons.history_rounded, 'Last 6 Months', () {
                        final end = DateTime.now();
                        final start = DateTime(end.year, end.month - 6, end.day);
                        widget.onApply(DateTimeRange(start: start, end: end));
                        Navigator.pop(context);
                      }),
                      _buildRangeOption(Icons.event_note_rounded, 'This Year', () {
                        final now = DateTime.now();
                        final start = DateTime(now.year, 1, 1);
                        widget.onApply(DateTimeRange(start: start, end: now));
                        Navigator.pop(context);
                      }),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Divider(),
                      ),
                      _buildRangeOption(Icons.date_range_rounded, 'Custom Calendar...', widget.onOpenCalendar, isCustom: true),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Divider(),
                      ),
                      // Manual Entry Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Manual Entry', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary, letterSpacing: 0.5)),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: _buildManualDateField(_startCtrl, 'Start Date', _startFocus)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildManualDateField(_endCtrl, 'End Date', _endFocus)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                key: _applyButtonKey,
                                onPressed: () {
                                  final start = DateParser.parse(_startCtrl.text);
                                  final end = DateParser.parse(_endCtrl.text);
                                  if (start != null && end != null) {
                                    widget.onApply(DateTimeRange(start: start, end: end));
                                    Navigator.pop(context);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Invalid date format. Use DD / MM / YYYY')),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: const Text('Apply Manual Range', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
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

  Widget _buildManualDateField(TextEditingController controller, String label, FocusNode focusNode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          inputFormatters: [DateInputFormatter()],
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'DD / MM / YYYY',
            hintStyle: TextStyle(color: Theme.of(context).colorScheme.outline, fontWeight: FontWeight.w400),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildRangeOption(IconData icon, String title, VoidCallback onTap, {bool isCustom = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isCustom ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: isCustom ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      title: Text(title, style: TextStyle(fontWeight: isCustom ? FontWeight.w700 : FontWeight.w600, fontSize: 15, color: isCustom ? Theme.of(context).colorScheme.primary : null)),
      trailing: Icon(Icons.chevron_right_rounded, size: 20, color: Theme.of(context).colorScheme.outline),
      onTap: onTap,
    );
  }
}

// ─── Full Screen Chart with Unit Switching ──────────────────────────────────

class _FullScreenChartPage extends StatefulWidget {
  final String testKey;
  final String displayName;
  final List<MedicalReport> validReports;
  final DateTime Function(String?, String) parseDate;
  final double? Function(String) parseValue;

  const _FullScreenChartPage({
    required this.testKey,
    required this.displayName,
    required this.validReports,
    required this.parseDate,
    required this.parseValue,
  });

  @override
  State<_FullScreenChartPage> createState() => _FullScreenChartPageState();
}

class _FullScreenChartPageState extends State<_FullScreenChartPage> {
  late BiomarkerEntry? _entry;
  late List<String> _availableUnits;
  late String _selectedUnit;
  late String _defaultUnit;
  bool _sortNewestFirst = true;

  @override
  void initState() {
    super.initState();
    _entry = BiomarkerDictionary.getEntryByKey(widget.testKey);
    _defaultUnit = _entry?.unit ?? '';
    _availableUnits = _entry != null && _entry!.allowedUnits.isNotEmpty
        ? List<String>.from(_entry!.allowedUnits)
        : [_defaultUnit];
    if (_availableUnits.isEmpty || (_availableUnits.length == 1 && _availableUnits.first.isEmpty)) {
      _availableUnits = [''];
    }
    _selectedUnit = _defaultUnit;
  }

  double? _convertValue(double original, String? sourceUnit) {
    final src = (sourceUnit == null || sourceUnit.isEmpty) ? _defaultUnit : sourceUnit;
    if (src.isEmpty || src == _selectedUnit) return original;
    
    final result = UnitConverter.convert(
      widget.testKey,
      original.toString(),
      src,
      _selectedUnit,
    );
    if (result.wasConverted) {
      return double.tryParse(result.convertedValue);
    }
    return original;
  }

  /// Parse reference range numbers from the dictionary entry
  (double?, double?) _parseRefRange() {
    if (_entry == null) return (null, null);
    final range = _selectedUnit == _defaultUnit
        ? _entry!.referenceRange
        : _entry!.referenceRangeSI;
    if (range == null || range.isEmpty || range == 'N/A') return (null, null);

    final nums = RegExp(r'[\d]+\.?[\d]*').allMatches(range).map((m) => double.tryParse(m.group(0)!)).whereType<double>().toList();
    if (nums.length >= 2) {
      return (nums[0], nums[1]);
    }
    // Single value with < or >
    if (nums.length == 1) {
      if (range.contains('<')) return (null, nums[0]);
      if (range.contains('>')) return (nums[0], null);
    }
    return (null, null);
  }

  String _getRefRangeText() {
    if (_entry == null) return '';
    if (_selectedUnit == _defaultUnit) {
      return _entry!.referenceRange ?? '';
    }
    return _entry!.referenceRangeSI ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Build spots with current unit
    List<_ChartDataPoint> dataPoints = [];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (int i = 0; i < widget.validReports.length; i++) {
      final report = widget.validReports[i];
      final result = report.structuredData!.results.firstWhere(
        (res) => (res.key ?? res.testItem) == widget.testKey,
        orElse: () => TestResult(testItem: '', value: '-'),
      );
      if (result.value != '-') {
        final rawVal = widget.parseValue(result.value);
        if (rawVal != null) {
          final val = _convertValue(rawVal, result.unit) ?? rawVal;
          final date = widget.parseDate(report.structuredData?.date, report.uploadTime);
          dataPoints.add(_ChartDataPoint(date, val, i.toDouble()));
          
          if (val < minY) minY = val;
          if (val > maxY) maxY = val;
        }
      }
    }

    final spots = dataPoints.map((dp) => FlSpot(dp.index, dp.value)).toList();

    if (minY == double.infinity) minY = 0;
    if (maxY == double.negativeInfinity) maxY = 10;
    double padding = (maxY - minY) * 0.25;
    if (padding == 0) padding = 1.0;

    final (refLow, refHigh) = _parseRefRange();

    // Adjust chart bounds to include reference range
    double chartMinY = minY - padding;
    double chartMaxY = maxY + padding;
    if (refLow != null && refLow < chartMinY) chartMinY = refLow - padding * 0.5;
    if (refHigh != null && refHigh > chartMaxY) chartMaxY = refHigh + padding * 0.5;

    final screenWidth = MediaQuery.of(context).size.width;
    final maxLabels = (screenWidth / 95).floor().clamp(2, 8);
    final bottomInterval = (widget.validReports.length / maxLabels).ceilToDouble();
    final refText = _getRefRangeText();
    final unitLabel = _selectedUnit.isNotEmpty ? ' ($_selectedUnit)' : '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.close_rounded, size: 20, color: cs.onSurface.withValues(alpha: 0.7)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.displayName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cs.onSurface)),
                              Text('Trend Analysis$unitLabel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        if (_availableUnits.length > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedUnit,
                                isDense: true,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.primary),
                                icon: Icon(Icons.swap_horiz_rounded, size: 16, color: cs.primary),
                                items: _availableUnits.map((u) => DropdownMenuItem(
                                  value: u,
                                  child: Text(u.isEmpty ? 'Default' : u),
                                )).toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _selectedUnit = v);
                                },
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: AppTheme.accentGradient(context),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.show_chart_rounded, size: 20, color: Colors.white),
                          ),
                      ],
                    ),
                  ),

                  // Reference range info
                  if (refText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: cs.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ref: $refText',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Chart
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 36, 16),
                    child: SizedBox(
                      height: 320,
                      child: spots.isEmpty
                          ? Center(child: Text('No numeric data available', style: TextStyle(color: cs.onSurfaceVariant)))
                          : LineChart(
                              LineChartData(
                                minX: 0,
                                maxX: (widget.validReports.length - 1).toDouble().clamp(1, double.infinity),
                                minY: chartMinY,
                                maxY: chartMaxY,
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: true,
                                  horizontalInterval: padding > 0 ? padding : null,
                                  getDrawingHorizontalLine: (value) => FlLine(color: cs.outline, strokeWidth: 0.8),
                                  getDrawingVerticalLine: (value) => FlLine(color: cs.outline, strokeWidth: 0.5),
                                ),
                                titlesData: FlTitlesData(
                                  show: true,
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true, reservedSize: 40,
                                      interval: bottomInterval > 0 ? bottomInterval : 1,
                                      getTitlesWidget: (value, meta) {
                                        int index = value.toInt();
                                        if (index >= 0 && index < widget.validReports.length) {
                                          final report = widget.validReports[index];
                                          final date = widget.parseDate(report.structuredData?.date, report.uploadTime);
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 10.0),
                                            child: Text(DateFormat('MMM d, yy').format(date), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                                          );
                                        }
                                        return const SizedBox();
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true, reservedSize: 48,
                                      getTitlesWidget: (value, meta) {
                                        return Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 11));
                                      },
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                // Reference range band
                                rangeAnnotations: (refLow != null || refHigh != null)
                                    ? RangeAnnotations(
                                        horizontalRangeAnnotations: [
                                          if (refLow != null && refHigh != null)
                                            HorizontalRangeAnnotation(
                                              y1: refLow,
                                              y2: refHigh,
                                              color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                                            ),
                                        ],
                                      )
                                    : RangeAnnotations(),
                                extraLinesData: ExtraLinesData(
                                  horizontalLines: [
                                    if (refLow != null)
                                      HorizontalLine(
                                        y: refLow,
                                        color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
                                        strokeWidth: 1.5,
                                        dashArray: [6, 4],
                                        label: HorizontalLineLabel(
                                          show: true,
                                          alignment: Alignment.topLeft,
                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFF4CAF50).withValues(alpha: 0.8)),
                                          labelResolver: (_) => 'Low: ${refLow.toStringAsFixed(1)}',
                                        ),
                                      ),
                                    if (refHigh != null)
                                      HorizontalLine(
                                        y: refHigh,
                                        color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
                                        strokeWidth: 1.5,
                                        dashArray: [6, 4],
                                        label: HorizontalLineLabel(
                                          show: true,
                                          alignment: Alignment.bottomLeft,
                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFF4CAF50).withValues(alpha: 0.8)),
                                          labelResolver: (_) => 'High: ${refHigh.toStringAsFixed(1)}',
                                        ),
                                      ),
                                  ],
                                ),
                                lineTouchData: LineTouchData(
                                  touchTooltipData: LineTouchTooltipData(
                                    getTooltipColor: (touchedSpot) => const Color(0xFF1F2937),
                                    fitInsideHorizontally: true,
                                    fitInsideVertically: true,
                                    getTooltipItems: (touchedSpots) {
                                      return touchedSpots.map((spot) {
                                        final index = spot.x.toInt();
                                        String dateLabel = '';
                                        if (index >= 0 && index < widget.validReports.length) {
                                          final report = widget.validReports[index];
                                          final date = widget.parseDate(report.structuredData?.date, report.uploadTime);
                                          dateLabel = DateFormat('MMM d, yyyy').format(date);
                                        }
                                        final valStr = spot.y.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
                                        final unitSuffix = _selectedUnit.isNotEmpty ? ' $_selectedUnit' : '';
                                        return LineTooltipItem(
                                          '$valStr$unitSuffix\n$dateLabel',
                                          const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                                        );
                                      }).toList();
                                    },
                                  ),
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: spots,
                                    isCurved: false,
                                    color: cs.primary,
                                    barWidth: 3.5,
                                    isStrokeCapRound: true,
                                    dotData: FlDotData(
                                      show: true,
                                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                        radius: 6, color: cs.primary, strokeWidth: 3, strokeColor: cs.surface,
                                      ),
                                    ),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      gradient: LinearGradient(
                                        colors: [cs.primary.withValues(alpha: 0.25), cs.primary.withValues(alpha: 0.0)],
                                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),

                  // Stats bar
                  if (spots.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _stat('Min', minY.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''), cs),
                            Container(width: 1, height: 30, color: cs.outline),
                            _stat('Max', maxY.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''), cs),
                            Container(width: 1, height: 30, color: cs.outline),
                            _stat('Points', spots.length.toString(), cs),
                          ],
                        ),
                      ),
                    ),
                  
                  if (spots.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Data Points', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _sortNewestFirst = !_sortNewestFirst;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _sortNewestFirst ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                    size: 14,
                                    color: cs.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _sortNewestFirst ? 'Newest First' : 'Oldest First',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Data Points List
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final dp = _sortNewestFirst 
                        ? dataPoints[dataPoints.length - 1 - index]
                        : dataPoints[index];
                    final valStr = dp.value.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
                    final isAbnormal = (refLow != null && dp.value < refLow) || (refHigh != null && dp.value > refHigh);
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isAbnormal ? cs.error.withValues(alpha: 0.3) : cs.outline.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isAbnormal ? cs.error.withValues(alpha: 0.1) : cs.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isAbnormal ? Icons.warning_amber_rounded : Icons.calendar_today_rounded, 
                              size: 16, 
                              color: isAbnormal ? cs.error : cs.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(DateFormat('MMM d, yyyy').format(dp.date), style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
                                if (isAbnormal)
                                  Text('Out of reference range', style: TextStyle(fontSize: 11, color: cs.error))
                              ],
                            ),
                          ),
                          Text(
                            valStr,
                            style: TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.w800, 
                              color: isAbnormal ? cs.error : cs.onSurface,
                            ),
                          ),
                          if (_selectedUnit.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text(_selectedUnit, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                          ],
                        ],
                      ),
                    );
                  },
                  childCount: dataPoints.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, ColorScheme cs) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cs.primary)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _ChartDataPoint {
  final DateTime date;
  final double value;
  final double index;
  _ChartDataPoint(this.date, this.value, this.index);
}
