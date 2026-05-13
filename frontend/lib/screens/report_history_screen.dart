import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../services/api_service.dart';
import '../models/report_model.dart';
import 'verify_screen.dart';

/// Displays the current user's scanned report history.
class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  List<MedicalReport>? _reports;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final reports = await ApiService.fetchMyReports();
      if (mounted) setState(() { _reports = reports; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (_) {
      return isoDate;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'sent': return AppTheme.success;
      case 'completed': return AppTheme.info;
      case 'processing': return AppTheme.warning;
      case 'failed': return AppTheme.error;
      default: return AppTheme.textTertiary;
    }
  }

  Future<void> _deleteReport(MedicalReport report) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: const Text('Delete Report?'),
        content: const Text('Are you sure you want to delete this report? This action cannot be undone.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await ApiService.deleteReport(report.id);
      _loadReports();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: AppTheme.success, content: Text('Report deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.error, content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            FadeInDown(
              duration: const Duration(milliseconds: 500),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withOpacity(0.85),
                  border: const Border(bottom: BorderSide(color: AppTheme.surfaceBorder, width: 1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: const Icon(Icons.history_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('My Reports',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary, letterSpacing: -0.3)),
                          Text(
                            _reports != null ? '${_reports!.length} report(s)' : 'Loading...',
                            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _loadReports,
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
            ),

            // Content
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: FadeInUp(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.cloud_off_rounded, size: 40, color: AppTheme.error),
                ),
                const SizedBox(height: 20),
                Text(_error!, textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textTertiary, fontSize: 14)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _loadReports,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_reports == null || _reports!.isEmpty) {
      return Center(
        child: FadeInUp(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.inbox_outlined, size: 48, color: AppTheme.textTertiary),
              ),
              const SizedBox(height: 20),
              const Text('No reports yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              const Text('Scan a medical report to get started',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReports,
      color: AppTheme.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()), // Removes Android stretch effect
        padding: const EdgeInsets.all(16),
        itemCount: _reports!.length,
        itemBuilder: (context, index) {
          final report = _reports![index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildReportCard(report),
          );
        },
      ),
    );
  }

  Widget _buildReportCard(MedicalReport report) {
    final patientName = report.structuredData?.patientName;
    final testName = report.structuredData?.testName;
    final resultCount = report.structuredData?.results.length ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VerifyScreen(report: report)),
        );
      },
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Status dot
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: _statusColor(report.status),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                // Patient name
                Expanded(
                  child: Text(
                    patientName?.isNotEmpty == true ? patientName! : 'Unknown Patient',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(report.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor(report.status).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    report.status.toUpperCase(),
                    style: TextStyle(
                      color: _statusColor(report.status),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _deleteReport(report),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline, size: 16, color: AppTheme.error),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Details row
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 13, color: AppTheme.textTertiary),
                const SizedBox(width: 6),
                Text(_formatDate(report.uploadTime),
                    style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                const Spacer(),
                if (testName?.isNotEmpty == true) ...[
                  const Icon(Icons.science_outlined, size: 13, color: AppTheme.textTertiary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(testName!,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ],
            ),
            if (resultCount > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.analytics_outlined, size: 13, color: AppTheme.accent),
                  const SizedBox(width: 6),
                  Text('$resultCount test result(s)',
                      style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
