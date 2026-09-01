/// MedScan Mobile Application Entrypoint.
///
/// This module bootstraps the Flutter application lifecycle:
/// 1. Configures global HTTP security overrides to allow custom local development tunnels.
/// 2. Initializes persistent service singletons ([AuthService], [ApiService], [ThemeService]).
/// 3. Configures transparent status bar system overlays.
/// 4. Boots the root widget [MedScanApp] with dynamic theme switching and authentication gating.
///
/// ### Example Usage:
/// ```dart
/// // Standard Flutter execution entrypoint
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   runApp(const MedScanApp());
/// }
/// ```
library main;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/theme_service.dart';
import 'screens/auth_screen.dart';
import 'screens/main_screen.dart';

/// Global HTTP security overrides for testing environments.
///
/// Allows self-signed SSL certificates and local development tunneling proxies
/// (such as ngrok and localtunnel) to communicate without certificate validation rejection.
class MyHttpOverrides extends HttpOverrides {
  /// Creates a custom HTTP client that accepts self-signed or developmental SSL certificates.
  ///
  /// * [context]: Optional security context.
  /// * Returns: An [HttpClient] with a permissive [badCertificateCallback].
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      // Allow self-signed certificates during development testing and localtunnel proxying
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

/// Application entrypoint initializing bindings, services, and UI theme.
void main() async {
  // Install custom HTTP override globally before any network request is triggered
  HttpOverrides.global = MyHttpOverrides();
  
  // Ensure framework services are initialized prior to async storage reads
  WidgetsFlutterBinding.ensureInitialized();
  
  // Render clean edge-to-edge transparent system status bars
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialize service singletons from persistent local storage (SharedPreferences)
  await AuthService.init();
  await ApiService.init();
  await ThemeService.instance.init();

  runApp(const MedScanApp());
}

/// The root application widget for MedScan.
///
/// Manages top-level theme state via [ThemeService] and conditionally routes the user
/// to [MainScreen] if logged in, or [AuthScreen] if unauthenticated.
class MedScanApp extends StatelessWidget {
  /// Constructs a new [MedScanApp] instance.
  const MedScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'MedScan',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeService.instance.themeMode,
          // Remove default Android stretch/glow scroll indicators across all screens
          scrollBehavior: NoScrollGlowBehavior(),
          // Route immediately based on cached JWT authentication status
          home: AuthService.isLoggedIn ? const MainScreen() : const AuthScreen(),
        );
      },
    );
  }
}

/// A global [ScrollBehavior] that removes the Android glowing/stretching overscroll animation.
///
/// This provides a consistent iOS-like bounce or clean edge-stop across all lists and grids.
class NoScrollGlowBehavior extends ScrollBehavior {
  /// Builds the overscroll indicator widget.
  ///
  /// * [context]: The build context.
  /// * [child]: The scrollable child widget.
  /// * [details]: Scrollable metadata.
  /// * Returns: The raw [child] without overscroll glow decorations.
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    // Return child directly without wrapping in GlowingOverscrollIndicator or StretchingOverscrollIndicator
    return child;
  }
}
