import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/report_model.dart';
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

  static const Map<String, List<String>> _medicalCategories = {
    'Lipid Profile': ['total_cholesterol_mg_dl', 'hdl_mg_dl', 'ldl_mg_dl', 'vldl_mg_dl', 'triglycerides_mg_dl', 'non_hdl_mg_dl', 'total_hdl_ratio', 'ldl_hdl_ratio'],
    'Liver Function': ['alt_sgpt_u_l', 'ast_sgot_u_l', 'alp_u_l', 'ggt_u_l', 'bilirubin_total_mg_dl', 'bilirubin_direct_mg_dl', 'bilirubin_indirect_mg_dl', 'protein_total_g_dl', 'albumin_g_dl', 'globulin_g_dl', 'a_g_ratio'],
    'Kidney Function': ['creatinine_mg_dl', 'urea_mg_dl', 'bun_mg_dl', 'uric_acid_mg_dl', 'egfr_ml_min_173m2', 'sodium_mmol_l', 'potassium_mmol_l', 'chloride_mmol_l'],
    'Blood Sugar (Diabetes)': ['glucose', 'hba1c_pct', 'fasting_glucose_mg_dl', 'postprandial_glucose_mg_dl', 'fbs_mg_dl', 'plbs_mg_dl', 'estimated_avg_glucose_mg_dl'],
    'Complete Blood Count (CBC)': ['hemoglobin_g_dl', 'wbc_cells_ul', 'rbc_count_mil_ul', 'platelet_count_x10_3_ul', 'hematocrit_pct', 'mcv_fl', 'mch_pg', 'mchc_g_dl', 'rdw_cv_pct', 'neutrophils_pct', 'lymphocytes_pct', 'eosinophils_pct', 'monocytes_pct', 'basophils_pct'],
    'Thyroid Function': ['tt3_ng_dl', 'tt4_ug_dl', 'tsh_uiu_ml'],
    'Iron Studies': ['iron_ug_dl', 'uibc_ug_dl', 'tibc_ug_dl', 'transferrin_saturation_pct'],
    'Urine Analysis': ['ph', 'specific_gravity', 'proteins', 'glucose', 'bilirubin', 'ketones', 'blood', 'urobilinogen', 'nitrites'],
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
            SnackBar(content: Text('AI Analysis failed: $e'), backgroundColor: AppTheme.error),
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
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: const Text('Log Out?'),
        content: const Text('You will need to sign in again.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
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
            child: const Text('Log Out', style: TextStyle(color: AppTheme.error)),
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
          border: Border(bottom: BorderSide(color: Theme.of(context).dividerTheme.color ?? AppTheme.surfaceBorder, width: 1)),
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
                      style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? AppTheme.textTertiary, fontSize: 12, fontWeight: FontWeight.w500)),
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
                  color: ThemeService.instance.isDarkMode ? Colors.orangeAccent : AppTheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _handleLogout,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_rounded, size: 18, color: AppTheme.primaryLight),
                    if (AuthService.currentUser != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        (AuthService.currentUser!['name'] as String? ?? '').split(' ').first,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _fetchDashboardData,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.refresh_rounded, size: 20, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
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
                decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.cloud_off_rounded, size: 48, color: AppTheme.error),
              ),
              const SizedBox(height: 24),
              const Text('Unable to Load Dashboard',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Text(_dashboardError ?? 'An unknown error occurred.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textTertiary, fontSize: 14, height: 1.5)),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: _fetchDashboardData,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient(context),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    boxShadow: Theme.of(context).brightness == Brightness.dark ? AppTheme.primaryShadow : AppTheme.primaryShadowLight,
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
                decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.auto_awesome, color: AppTheme.accent, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('AI Health Analysis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),

          // Analysis result or placeholder
          if (_aiAnalysis != null)
            MarkdownBody(
              data: _aiAnalysis!,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.6),
                strong: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700, height: 1.6),
                em: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontStyle: FontStyle.italic, height: 1.6),
                h1: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800, height: 1.5),
                h2: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, height: 1.5),
                h3: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 15, fontWeight: FontWeight.w700, height: 1.5),
                listBullet: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                blockSpacing: 10,
              ),
            )
          else if (_isAnalyzing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2)),
            )
          else
            Text('Generate a detailed AI analysis based on the exact values from your reports.', 
                style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? AppTheme.textTertiary, fontSize: 13, height: 1.5)),
          
          // Query input — always visible when not loading
          if (!_isAnalyzing) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _queryCtrl,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              maxLines: null,
              decoration: InputDecoration(
                hintText: _aiAnalysis != null ? 'Ask a follow-up question...' : 'Any specific question? (Optional)',
                hintStyle: const TextStyle(color: AppTheme.textTertiary),
                prefixIcon: Icon(_aiAnalysis != null ? Icons.chat_bubble_outline : Icons.help_outline, color: AppTheme.textTertiary, size: 18),
                filled: true,
                fillColor: AppTheme.surfaceVariant.withValues(alpha: 0.5),
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
                  backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.15),
                  foregroundColor: AppTheme.primaryLight,
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
                  Icon(Icons.fullscreen_rounded, size: 18, color: AppTheme.textTertiary.withValues(alpha: 0.5)),
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
                      getDrawingHorizontalLine: (value) => FlLine(color: Theme.of(context).dividerTheme.color ?? AppTheme.surfaceBorder, strokeWidth: 1),
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
                                child: Text(DateFormat('MMM d, yy').format(date), style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? AppTheme.textTertiary, fontSize: 10)),
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
                            return Text(value.toStringAsFixed(1), style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10));
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: AppTheme.primaryLight,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 4, color: AppTheme.primaryLight, strokeWidth: 2, strokeColor: AppTheme.surface,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [AppTheme.primaryLight.withValues(alpha: 0.3), AppTheme.primaryLight.withValues(alpha: 0.0)],
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
                                color: AppTheme.surfaceVariant,
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
                                Text('Trend Analysis', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? AppTheme.textTertiary, fontSize: 12, fontWeight: FontWeight.w500)),
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
                              getDrawingHorizontalLine: (value) => const FlLine(color: AppTheme.surfaceBorder, strokeWidth: 0.8),
                              getDrawingVerticalLine: (value) => const FlLine(color: AppTheme.surfaceBorder, strokeWidth: 0.5),
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
                                        child: Text(DateFormat('MMM d, yyyy').format(date), style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
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
                                    return Text(value.toStringAsFixed(1), style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11));
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (touchedSpot) => AppTheme.surface,
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
                                color: AppTheme.primaryLight,
                                barWidth: 3.5,
                                isStrokeCapRound: true,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                    radius: 6, color: AppTheme.primaryLight, strokeWidth: 3, strokeColor: Theme.of(context).colorScheme.surface,
                                  ),
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    colors: [AppTheme.primaryLight.withValues(alpha: 0.25), AppTheme.primaryLight.withValues(alpha: 0.0)],
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
                            Container(width: 1, height: 30, color: AppTheme.surfaceBorder),
                            _buildStatItem('Max', maxY.toStringAsFixed(1)),
                            Container(width: 1, height: 30, color: AppTheme.surfaceBorder),
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
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary, fontWeight: FontWeight.w500)),
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
                  child: Text('🩸 $category', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                child: Text('🔬 Other Biomarkers', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text('Biomarker Trends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        ),
        ...categoryWidgets,
      ],
    );
  }

  Widget _buildDashboardContent() {
    // Only use reports that are 'completed' or 'sent' and have structured data results
    final validReports = _reports.where((r) => 
        (r.status == 'completed' || r.status == 'sent') && 
        r.structuredData != null && 
        r.structuredData!.results.isNotEmpty
    ).toList();

    if (validReports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: AppTheme.textTertiary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('No Data Available', style: TextStyle(fontSize: 18, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Scan a medical report to see your analytics.', style: TextStyle(color: AppTheme.textTertiary, fontSize: 14)),
          ],
        ),
      );
    }

    // Sort reports chronologically by collected date (fallback to uploadTime)
    validReports.sort((a, b) => _parseDate(a.structuredData?.date, a.uploadTime).compareTo(_parseDate(b.structuredData?.date, b.uploadTime)));

    // Aggregate unique test keys and map them to readable names
    Set<String> uniqueTestKeys = {};
    Map<String, String> testKeyToName = {};

    for (var report in validReports) {
      for (var result in report.structuredData!.results) {
        final key = result.key ?? result.testItem;
        uniqueTestKeys.add(key);
        testKeyToName[key] = result.testItem;
      }
    }

    final sortedTestKeys = uniqueTestKeys.toList()..sort((a, b) => (testKeyToName[a] ?? a).compareTo(testKeyToName[b] ?? b));

    return FadeInUp(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Analysis
            _buildAiAnalysis(),
            const SizedBox(height: 20),

            // Trend Graphs Categorized
            _buildCategorizedGraphs(validReports, uniqueTestKeys, testKeyToName),
            const SizedBox(height: 20),

            // Data Table
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text('Biomarker Analytics Table', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ),
            const SizedBox(height: 8),
            GlassCard(
              padding: EdgeInsets.zero,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: AppTheme.surfaceBorder),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AppTheme.surfaceVariant.withValues(alpha: 0.5)),
                    columnSpacing: 24,
                    horizontalMargin: 16,
                    dividerThickness: 1,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 48,
                    columns: [
                      const DataColumn(
                        label: Text('Biomarker', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      ),
                      ...validReports.map((r) {
                        final date = _parseDate(r.structuredData?.date, r.uploadTime);
                        final dateStr = DateFormat('MMM d, yyyy').format(date);
                        return DataColumn(
                          label: Text(dateStr, style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
                        );
                      }),
                    ],
                    rows: sortedTestKeys.map((testKey) {
                      return DataRow(
                        cells: [
                          DataCell(Text(testKeyToName[testKey] ?? testKey, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary))),
                          ...validReports.map((report) {
                            final result = report.structuredData!.results.firstWhere(
                              (res) => (res.key ?? res.testItem) == testKey,
                              orElse: () => TestResult(testItem: '', value: '-'),
                            );
                            final valueText = result.value == '-' ? '-' : '${result.value} ${result.unit ?? ''}'.trim();
                            return DataCell(
                              Text(valueText, style: TextStyle(
                                color: result.value == '-' ? AppTheme.textTertiary : AppTheme.textPrimary,
                                fontWeight: result.value == '-' ? FontWeight.w400 : FontWeight.w500,
                              )),
                            );
                          }),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 100), // padding for bottom nav
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: const Border(top: BorderSide(color: AppTheme.surfaceBorder, width: 1)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, -4))],
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
            color: isActive ? AppTheme.surfaceVariant.withValues(alpha: 0.6) : Colors.transparent,
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
                  return const LinearGradient(colors: [AppTheme.textTertiary, AppTheme.textTertiary]).createShader(bounds);
                },
                child: Icon(isActive ? activeIcon : icon, size: 24, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(fontSize: 10, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? AppTheme.textPrimary : AppTheme.textTertiary, letterSpacing: 0.2)),
            ],
          ),
        ),
      ),
    );
  }
}
