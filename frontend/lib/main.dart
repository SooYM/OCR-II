import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/theme_service.dart';
import 'screens/auth_screen.dart';
import 'screens/main_screen.dart';

import 'dart:io';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  // Load saved auth token from disk
  await AuthService.init();
  await ApiService.init();
  await ThemeService.instance.init();
  runApp(const MedScanApp());
}

class MedScanApp extends StatelessWidget {
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
          scrollBehavior: NoScrollGlowBehavior(), // Completely removes all scroll overscroll effects globally
          home: AuthService.isLoggedIn ? const MainScreen() : const AuthScreen(),
        );
      },
    );
  }
}

/// A global scroll behavior that removes the Android glowing/stretching overscroll effect.
class NoScrollGlowBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child; // Returns the list directly without the stretch/glow wrapper
  }
}
