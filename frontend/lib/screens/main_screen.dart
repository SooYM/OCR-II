import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:animate_do/animate_do.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'capture_screen.dart';
import 'report_history_screen.dart';
import 'auth_screen.dart';

/// Main screen with bottom navigation: Dashboard, Scan, My Reports.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final WebViewController _webViewController;
  bool _isWebViewLoading = true;
  final ValueNotifier<double> _loadingProgressNotifier = ValueNotifier(0.0);
  String? _webViewError;

  @override
  void dispose() {
    _loadingProgressNotifier.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _isWebViewLoading = true;
                _webViewError = null;
              });
              _loadingProgressNotifier.value = 0.0;
            }
          },
          onProgress: (progress) {
            if (mounted) {
              _loadingProgressNotifier.value = progress / 100.0;
            }
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _isWebViewLoading = false;
              });
              _loadingProgressNotifier.value = 1.0;
            }
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _isWebViewLoading = false;
                _webViewError = 'Failed to load dashboard.\n${error.description}';
              });
            }
          },
        ),
      )
      ..setBackgroundColor(AppTheme.background)
      ..loadRequest(Uri.parse('https://aihubdev.qiu.edu.my'));
  }

  void _refreshDashboard() {
    setState(() { _webViewError = null; _isWebViewLoading = true; });
    _loadingProgressNotifier.value = 0.0;
    _webViewController.reload();
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
                  context, MaterialPageRoute(builder: (_) => const AuthScreen()),
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
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Dashboard Header ──
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
                        gradient: AppTheme.accentGradient,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dashboard',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary, letterSpacing: -0.3)),
                          Text('Healthcare Biomarker Analytics',
                              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    // User/Logout button
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
                      onTap: _refreshDashboard,
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

            // ── Loading Progress Bar ──
            if (_isWebViewLoading)
              ValueListenableBuilder<double>(
                valueListenable: _loadingProgressNotifier,
                builder: (context, progressValue, _) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progressValue),
                    duration: const Duration(milliseconds: 300),
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        value: value > 0 ? value : null,
                        minHeight: 3,
                        backgroundColor: AppTheme.surfaceBorder,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                      );
                    },
                  );
                },
              ),

            // ── WebView Content ──
            Expanded(
              child: _webViewError != null
                  ? _buildErrorState()
                  : Stack(
                      children: [
                        WebViewWidget(controller: _webViewController),
                        if (_isWebViewLoading)
                          Container(
                            color: AppTheme.background.withOpacity(0.7),
                            child: Center(
                              child: FadeIn(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 48, height: 48,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 4,
                                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                                        backgroundColor: AppTheme.surfaceBorder,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    const Text('Loading Dashboard…',
                                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: FadeInUp(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.cloud_off_rounded, size: 48, color: AppTheme.error),
              ),
              const SizedBox(height: 24),
              const Text('Unable to Load Dashboard',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Text(_webViewError ?? 'An unknown error occurred.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textTertiary, fontSize: 14, height: 1.5)),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: _refreshDashboard,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    boxShadow: AppTheme.primaryShadow,
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

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: const Border(top: BorderSide(color: AppTheme.surfaceBorder, width: 1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _buildNavItem(index: 0, icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded,
                  label: 'Dashboard', gradient: AppTheme.accentGradient),
              _buildNavItem(index: 1, icon: Icons.document_scanner_outlined, activeIcon: Icons.document_scanner_rounded,
                  label: 'Scan', gradient: AppTheme.primaryGradient),
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
            color: isActive ? AppTheme.surfaceVariant.withOpacity(0.6) : Colors.transparent,
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
