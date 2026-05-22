import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../services/api_service.dart';
import '../models/report_model.dart';
import '../utils/date_utils.dart';
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
  bool _isCreatingManual = false;
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
      return DateFormat('dd-MMM-yyyy').format(dt);
    } catch (_) {
      return isoDate;
    }
  }

  String _formatReportDate(String? collectedDate, String uploadTime) {
    if (collectedDate == null || collectedDate.trim().isEmpty) {
      return 'Not specified';
    }
    final parsed = DateParser.parse(collectedDate);
    if (parsed != null) {
      return DateFormat('dd-MMM-yyyy').format(parsed);
    }
    // Fallback: Try parsing uploadTime
    try {
      final parsedUpload = DateTime.parse(uploadTime);
      return DateFormat('dd-MMM-yyyy').format(parsedUpload);
    } catch (_) {
      return collectedDate;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'sent': return Theme.of(context).colorScheme.primary;
      case 'completed': return Theme.of(context).colorScheme.secondary;
      case 'processing': return Theme.of(context).colorScheme.tertiary;
      case 'failed': return Theme.of(context).colorScheme.error;
      default: return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  Future<void> _deleteReport(MedicalReport report) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: const Text('Delete Report?'),
        content: const Text('Are you sure you want to delete this report? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
          SnackBar(backgroundColor: Theme.of(context).colorScheme.primary, content: const Text('Report deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Theme.of(context).colorScheme.error, content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Future<void> _createManualReport() async {
    setState(() => _isCreatingManual = true);
    try {
      final report = await ApiService.createManualReport();
      if (mounted) {
        setState(() => _isCreatingManual = false);
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VerifyScreen(report: report)),
        );
        // Refresh the list when returning from VerifyScreen
        _loadReports();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreatingManual = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            content: Text('Failed to create report: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(context)),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Container(
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
                      gradient: AppTheme.primaryGradient(context),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: const Icon(Icons.history_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Reports',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface, letterSpacing: -0.3)),
                        Text(
                          _reports != null ? '${_reports!.length} report(s)' : 'Loading...',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _isCreatingManual ? null : _createManualReport,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _isCreatingManual
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )
                          : Icon(Icons.add_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _loadReports,
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

            // Content
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.error.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.cloud_off_rounded, size: 40, color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 20),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadReports,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_reports == null || _reports!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inbox_outlined, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Text('No reports yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 8),
            const Text('Scan a medical report to get started',
                style: TextStyle(fontSize: 14)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReports,
      color: Theme.of(context).colorScheme.primary,
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

    final reportRef = report.structuredData?.reportReference;
    final hasReportRef = reportRef != null && reportRef.trim().isNotEmpty;

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
                // Title: Report Reference if available, otherwise Scan date
                Expanded(
                  child: Text(
                    hasReportRef ? 'Ref: $reportRef' : 'Scan: ${_formatDate(report.uploadTime)}',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (resultCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$resultCount',
                      style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _deleteReport(report),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.delete_outline, size: 16, color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Date & Test Info
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 13, color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Report Date: ${_formatReportDate(report.structuredData?.date, report.uploadTime)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.science_outlined, size: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(testName?.isNotEmpty == true ? '$testName' : 'Medical Report',
                          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
