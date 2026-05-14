import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/report_model.dart';
import '../utils/formatters.dart';
import 'capture_screen.dart';
import 'report_history_screen.dart';
import '../services/theme_service.dart';
import '../widgets/glass_card.dart';
import 'auth_screen.dart';

/// Main screen with bottom navigation: Dashboard, Scan, My Reports.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Dashboard state
  List<MedicalReport> _reports = [];
  bool _isLoadingDashboard = true;
  String? _dashboardError;

  // Graph and AI state
  String? _aiAnalysis;
  bool _isAnalyzing = false;
  final TextEditingController _queryCtrl = TextEditingController();
  
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

  static const Map<String, List<String>> _medicalCategories = {
    'Urine': [
      'urine_colour', 'appearance', 'specific_gravity', 'ph', 'proteins', 'glucose', 
      'bilirubin', 'ketones', 'blood', 'urobilinogen', 'nitrites', 'wbc_pus_cells_hpf', 
      'rbc', 'epithelial_cells_hpf', 'casts', 'crystals', 'others'
    ],
    'CBC': [
      'hemoglobin_g_dl', 'rbc_count_mil_ul', 'hematocrit_pct', 'mcv_fl', 'mch_pg', 
      'mchc_g_dl', 'rdw_cv_pct', 'rdw_sd_fl', 'wbc_cells_ul', 'neutrophils_pct', 
      'lymphocytes_pct', 'eosinophils_pct', 'monocytes_pct', 'basophils_pct', 
      'abs_neutrophils', 'abs_lymphocytes', 'abs_monocytes', 'abs_eosinophils', 'abs_basophils'
    ],
    'Platelet Profile': [
      'platelet_count_x10_3_ul', 'mpv_fl', 'platelet_rdw_pct', 'pct_pct', 'p_lcr_pct', 
      'img_pct', 'imm_pct', 'iml_pct', 'lic_pct'
    ],
    'Lipid Profile': [
      'total_cholesterol_mg_dl', 'hdl_mg_dl', 'ldl_mg_dl', 'vldl_mg_dl', 'triglycerides_mg_dl', 
      'non_hdl_mg_dl', 'total_hdl_ratio', 'ldl_hdl_ratio', 'hdl_ldl_ratio'
    ],
    'Liver Function': [
      'bilirubin_total_mg_dl', 'bilirubin_direct_mg_dl', 'bilirubin_indirect_mg_dl', 'alp_u_l', 
      'alt_sgpt_u_l', 'ast_sgot_u_l', 'ggt_u_l', 'protein_total_g_dl', 'albumin_g_dl', 
      'globulin_g_dl', 'a_g_ratio'
    ],
    'Kidney Function': [
      'creatinine_mg_dl', 'urea_mg_dl', 'bun_mg_dl', 'bun_creatinine_ratio', 'sodium_mmol_l', 
      'potassium_mmol_l', 'chloride_mmol_l', 'uric_acid_mg_dl', 'egfr_ml_min_173m2'
    ],
    'Iron Profile': [
      'iron_ug_dl', 'uibc_ug_dl', 'tibc_ug_dl', 'transferrin_saturation_pct'
    ],
    'HbA1c': [
      'hba1c_pct', 'estimated_avg_glucose_mg_dl', 'hbf_pct'
    ],
    'Urine ACR': [
      'urine_albumin_mg_l', 'urine_creatinine_mg_dl', 'albumin_creatinine_ratio'
    ],
    'Calcium & Phos': [
      'calcium_mg_dl', 'phosphorus_mg_dl'
    ],
    'Thyroid Profile': [
      'tt3_ng_dl', 'tt4_ug_dl', 'tsh_uiu_ml'
    ],
    'Glucose - Fasting': [
      'fasting_glucose_mg_dl'
    ],
    'Glucose - PP': [
      'postprandial_glucose_mg_dl'
    ],
    'Glucose (Diagnopath)': [
      'fbs_mg_dl', 'plbs_mg_dl'
    ],
  };

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
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

  Future<void> _generateAnalysis() async {
    setState(() => _isAnalyzing = true);
    try {
      final analysis = await ApiService.analyzeHealthTrends(query: _queryCtrl.text);
      if (mounted) {
        setState(() {
          _aiAnalysis = analysis;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('AI Analysis failed: $e'), backgroundColor: Theme.of(context).colorScheme.error),
          );
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
    
    final dt = DateTime.tryParse(dateStr);
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
        return format.parse(dateStr.trim());
      } catch (_) {}
    }

    return DateTime.parse(uploadTime);
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: const Text('Log Out?'),
        content: const Text('You will need to sign in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.logout();
              if (mounted) {
                Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => AuthScreen()),
                );
              }
            },
            child: Text('Log Out', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboardTab(),
          const CaptureScreen(),
          const ReportHistoryScreen(),
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
    return FadeInDown(
      duration: const Duration(milliseconds: 500),
      child: Container(
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
              child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dashboard',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface, letterSpacing: -0.3)),
                  Text('Healthcare Biomarker Analytics',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => ThemeService.instance.toggleTheme(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  ThemeService.instance.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  size: 20,
                  color: ThemeService.instance.isDarkMode ? Colors.orangeAccent : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _handleLogout,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_rounded, size: 18),
                    if (AuthService.currentUser != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        (AuthService.currentUser!['name'] as String? ?? '').split(' ').first,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
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
          onApply: (range) => setState(() => _selectedDateRange = range),
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
    }
  }

  Widget _buildDashboardError() {
    return Center(
      child: FadeInUp(
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
      ),
    );
  }

  Widget _buildAiAnalysis() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.secondary, size: 18),
              ),
              const SizedBox(width: 12),
              Text('AI Health Analysis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 16),

          // Analysis result or placeholder
          if (_aiAnalysis != null)
            MarkdownBody(
              data: _aiAnalysis!,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14, height: 1.6),
                strong: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w700, height: 1.6),
                em: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14, fontStyle: FontStyle.italic, height: 1.6),
                h1: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.w800, height: 1.5),
                h2: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w700, height: 1.5),
                h3: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 15, fontWeight: FontWeight.w700, height: 1.5),
                listBullet: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
                blockSpacing: 10,
              ),
            )
          else if (_isAnalyzing)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.secondary, strokeWidth: 2)),
            )
          else
            Text('Generate a detailed AI analysis based on the exact values from your reports.', 
                style: const TextStyle(fontSize: 13, height: 1.5)),
          
          // Query input — always visible when not loading
          if (!_isAnalyzing) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _queryCtrl,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              maxLines: null,
              decoration: InputDecoration(
                hintText: _aiAnalysis != null ? 'Ask a follow-up question...' : 'Any specific question? (Optional)',
                hintStyle: const TextStyle(),
                prefixIcon: Icon(_aiAnalysis != null ? Icons.chat_bubble_outline : Icons.help_outline, size: 18),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _generateAnalysis(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generateAnalysis,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(_aiAnalysis != null ? Icons.refresh : Icons.analytics, size: 18),
                label: Text(_aiAnalysis != null ? 'Ask / Re-generate' : 'Generate AI Analysis', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]
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

    for (int i = 0; i < validReports.length; i++) {
      final report = validReports[i];
      final result = report.structuredData!.results.firstWhere(
        (res) => (res.key ?? res.testItem) == testKey,
        orElse: () => TestResult(testItem: '', value: '-'),
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

    if (spots.isEmpty) return null;

    if (minY == double.infinity) minY = 0;
    if (maxY == double.negativeInfinity) maxY = 10;
    double padding = (maxY - minY) * 0.2;
    if (padding == 0) padding = 1.0;

    return GestureDetector(
      onTap: () => _showFullScreenChart(displayName, spots, minX, maxX, minY, maxY, padding, validReports),
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
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
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

  void _showFullScreenChart(String displayName, List<FlSpot> spots, double minX, double maxX, double minY, double maxY, double padding, List<MedicalReport> validReports) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.97),
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
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.close_rounded, size: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(displayName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
                                Text('Trend Analysis', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
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

                    const SizedBox(height: 8),

                    // Full chart
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 16, 20, 16),
                        child: LineChart(
                          LineChartData(
                            minX: minX, maxX: maxX,
                            minY: minY - padding, maxY: maxY + padding,
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: true,
                              horizontalInterval: padding > 0 ? padding : null,
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
                                  interval: (validReports.length > 8) ? (validReports.length / 5).ceilToDouble() : 1,
                                  getTitlesWidget: (value, meta) {
                                    int index = value.toInt();
                                    if (index >= 0 && index < validReports.length) {
                                      final report = validReports[index];
                                      final date = _parseDate(report.structuredData?.date, report.uploadTime);
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 10.0),
                                        child: Text(DateFormat('MMM d, yyyy').format(date), style: const TextStyle(fontSize: 11)),
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
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (touchedSpot) => Theme.of(context).colorScheme.surface,
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    final index = spot.x.toInt();
                                    String dateLabel = '';
                                    if (index >= 0 && index < validReports.length) {
                                      final report = validReports[index];
                                      final date = _parseDate(report.structuredData?.date, report.uploadTime);
                                      dateLabel = DateFormat('MMM d, yyyy').format(date);
                                    }
                                    return LineTooltipItem(
                                      '${spot.y.toStringAsFixed(2)}\n$dateLabel',
                                      TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 13),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                color: Theme.of(context).colorScheme.primary,
                                barWidth: 3.5,
                                isStrokeCapRound: true,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                    radius: 6, color: Theme.of(context).colorScheme.primary, strokeWidth: 3, strokeColor: Theme.of(context).colorScheme.surface,
                                  ),
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    colors: [Theme.of(context).colorScheme.primary.withValues(alpha: 0.25), Theme.of(context).colorScheme.primary.withValues(alpha: 0.0)],
                                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Data points summary
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('Min', minY.toStringAsFixed(1)),
                            Container(width: 1, height: 30, color: Theme.of(context).colorScheme.outline),
                            _buildStatItem('Max', maxY.toStringAsFixed(1)),
                            Container(width: 1, height: 30, color: Theme.of(context).colorScheme.outline),
                            _buildStatItem('Points', spots.length.toString()),
                          ],
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

    for (var category in _medicalCategories.keys) {
      final categoryKeys = _medicalCategories[category]!;
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedDateRange != null) _buildFilterActiveIndicator(),
          _buildAiAnalysis(),
          const SizedBox(height: 32),
          
          // Multi-Attribute Comparison Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('Comparative Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
          ),
          _buildAttributeSelector(uniqueTestKeys, testKeyToName),
          const SizedBox(height: 12),
          _buildMultiAttributeChart(validReports, testKeyToName),
          const SizedBox(height: 40),
          
          _buildCategorizedGraphs(validReports, uniqueTestKeys, testKeyToName),
          const SizedBox(height: 32),
          _buildRecentResultsTable(validReports, uniqueTestKeys, testKeyToName),
          const SizedBox(height: 100), // padding for bottom nav
        ],
      ),
    );
  }

  Widget _buildMultiAttributeChart(List<MedicalReport> validReports, Map<String, String> testKeyToName) {
    if (_selectedMultiAttributes.isEmpty) {
      return FadeIn(
        child: GlassCard(
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

    return FadeInUp(
      child: GlassCard(
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
                      getTooltipColor: (touchedSpot) => Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final testKey = _selectedMultiAttributes.elementAt(spot.barIndex);
                          final report = validReports[spot.x.toInt()];
                          final date = _parseDate(report.structuredData?.date, report.uploadTime);
                          final dateStr = DateFormat('MMM d, yyyy').format(date);

                          // Add date to the first line of the tooltip
                          String text = (spot.barIndex == 0)
                              ? '$dateStr\n${testKeyToName[testKey]}: ${spot.y.toStringAsFixed(1)}'
                              : '${testKeyToName[testKey]}: ${spot.y.toStringAsFixed(1)}';

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
      ),
    );
  }

  void _showMultiFullScreenChart(List<MedicalReport> validReports, Map<String, String> testKeyToName, List<LineChartBarData> lines, double minX, double maxX, double minY, double maxY, double padding) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
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
                        padding: const EdgeInsets.fromLTRB(8, 16, 24, 16),
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
                                  interval: (validReports.length > 8) ? (validReports.length / 5).ceilToDouble() : 1,
                                  getTitlesWidget: (value, meta) {
                                    int index = value.toInt();
                                    if (index >= 0 && index < validReports.length) {
                                      final report = validReports[index];
                                      final date = _parseDate(report.structuredData?.date, report.uploadTime);
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 10.0),
                                        child: Text(DateFormat('MMM d, yyyy').format(date), style: const TextStyle(fontSize: 11)),
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
                                getTooltipColor: (touchedSpot) => Theme.of(context).colorScheme.surface,
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    final testKey = _selectedMultiAttributes.elementAt(spot.barIndex);
                                    final report = validReports[spot.x.toInt()];
                                    final date = _parseDate(report.structuredData?.date, report.uploadTime);
                                    final dateStr = DateFormat('MMM d, yyyy').format(date);

                                    // Add date to the first line of the tooltip
                                    String text = (spot.barIndex == 0)
                                        ? '$dateStr\n${testKeyToName[testKey]}: ${spot.y.toStringAsFixed(2)}'
                                        : '${testKeyToName[testKey]}: ${spot.y.toStringAsFixed(2)}';

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

    for (var entry in _medicalCategories.entries) {
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
                      Text(category, style: TextStyle(
                        fontSize: 13, 
                        fontWeight: selectedInCategory > 0 ? FontWeight.w700 : FontWeight.w500,
                        color: selectedInCategory > 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                      )),
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
    final categorizedKeys = _medicalCategories.values.expand((e) => e).toSet();
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
                    const Text('Other Metrics', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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
    return FadeInDown(
      duration: const Duration(milliseconds: 300),
      child: Padding(
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
      ),
    );
  }

  Widget _buildRecentResultsTable(List<MedicalReport> validReports, Set<String> uniqueTestKeys, Map<String, String> testKeyToName) {
    final List<DataRow> rows = [];

    for (var entry in _medicalCategories.entries) {
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
    final categorizedKeys = _medicalCategories.values.expand((e) => e).toSet();
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
              _buildNavItem(index: 2, icon: Icons.history_outlined, activeIcon: Icons.history_rounded,
                  label: 'My Reports', gradient: const LinearGradient(colors: [AppTheme.warning, Color(0xFFFF8A65)])),
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

  DateTime? _parseManualDate(String text) {
    try {
      final clean = text.replaceAll(' ', '');
      final parts = clean.split('/');
      if (parts.length != 3) return null;
      return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, -5)),
          ],
        ),
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                          final start = _parseManualDate(_startCtrl.text);
                          final end = _parseManualDate(_endCtrl.text);
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
