/// MedScan Authentication & Session Management Service.
///
/// Handles user registration, credentials authentication, stateless JWT bearer token
/// caching, and offline profile synchronization.
///
/// ### Simple Example:
/// ```dart
/// // Logging in a user
/// final user = await AuthService.login('jane.doe@example.com', 'SecurePassword123!');
/// print('Welcome back, ${user['name']}!');
/// ```
///
/// ### Advanced Example:
/// ```dart
/// // Validating token on startup with offline fallback
/// final isValid = await AuthService.validateToken();
/// if (!isValid && !AuthService.isLoggedIn) {
///   Navigator.pushReplacementNamed(context, '/auth');
/// }
/// ```
library auth_service;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Singleton manager for authentication state, credentials, and token persistence.
class AuthService {
  static const _tokenKey = 'medscan_auth_token';
  static const _userKey = 'medscan_user';

  static String? _token;
  static Map<String, dynamic>? _currentUser;

  // ─── Token Access ──────────────────────────────────────────────────────────

  /// The active JWT bearer token, or `null` if unauthenticated.
  static String? get token => _token;

  /// The active user demographic profile dictionary.
  static Map<String, dynamic>? get currentUser => _currentUser;

  /// Whether a user is currently authenticated with a cached token.
  static bool get isLoggedIn => _token != null;

  /// Default HTTP headers containing the active JWT bearer token.
  static Map<String, String> get authHeaders => {
    'Content-Type': 'application/json',
    'bypass-tunnel-reminder': 'true',
    'ngrok-skip-browser-warning': 'true',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ─── Init (load from disk) ─────────────────────────────────────────────────

  /// Initializes authentication state by loading cached JWT token and profile data.
  ///
  /// Must be invoked at app bootstrap prior to building routes.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      _currentUser = jsonDecode(userJson);
    }
  }

  // ─── Register ──────────────────────────────────────────────────────────────

  /// Registers a new user account with demographic baseline parameters.
  ///
  /// * [email]: User email address.
  /// * [name]: Full name (used for OCR patient matching).
  /// * [password]: Account password (hashed via bcrypt on backend).
  /// * [gender]: Biological sex (`'Male'` or `'Female'`).
  /// * [dob]: Date of birth (`YYYY-MM-DD`).
  /// * [icNumber]: National identity card or passport number.
  /// * Returns: The registered user profile map.
  /// * Throws: [AuthException] on validation failure or duplicate email.
  static Future<Map<String, dynamic>> register(
    String email,
    String name,
    String password,
    String gender,
    String dob,
    String icNumber,
  ) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/api/auth/register'),
      headers: {'Content-Type': 'application/json', 'bypass-tunnel-reminder': 'true'},
      body: jsonEncode({
        'email': email,
        'name': name,
        'password': password,
        'gender': gender,
        'dob': dob,
        'ic_number': icNumber,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _saveAuth(data['token'], data['user']);
      return data['user'];
    } else {
      final detail = _parseError(response);
      throw AuthException(detail, response.statusCode);
    }
  }

  // ─── Login ─────────────────────────────────────────────────────────────────

  /// Authenticates user credentials with the backend API.
  ///
  /// * [email]: Registered email address.
  /// * [password]: Plaintext password string.
  /// * Returns: User demographic profile dictionary.
  /// * Throws: [AuthException] on invalid credentials.
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/api/auth/login'),
      headers: {'Content-Type': 'application/json', 'bypass-tunnel-reminder': 'true'},
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _saveAuth(data['token'], data['user']);
      return data['user'];
    } else {
      final detail = _parseError(response);
      throw AuthException(detail, response.statusCode);
    }
  }

  // ─── Validate Token ────────────────────────────────────────────────────────

  /// Validates the active JWT token against the backend `/api/auth/me` endpoint.
  ///
  /// Refreshes cached user demographics (DOB, NRIC, gender) if the token is valid.
  /// Automatically logs out the user locally if rejected (e.g. expired or deactivated).
  ///
  /// * Returns: `true` if valid or offline-resilient, `false` if rejected.
  static Future<bool> validateToken() async {
    if (_token == null) return false;
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/auth/me'),
        headers: authHeaders,
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final user = jsonDecode(response.body);
        _currentUser = user;
        // Persist refreshed user data so cached fields stay up-to-date
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(user));
        return true;
      }
      await logout();
      return false;
    } catch (_) {
      // Network error — preserve session to support offline usage
      return _token != null;
    }
  }

  // ─── Logout ────────────────────────────────────────────────────────────────

  /// Clears active credentials from memory and wipes persisted tokens from disk.
  static Future<void> logout() async {
    _token = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  /// Updates user profile name and email on the server.
  ///
  /// * [name]: New display name.
  /// * [email]: New contact email.
  /// * Returns: Updated user profile map.
  static Future<Map<String, dynamic>> updateProfile(String name, String email) async {
    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/api/auth/profile'),
      headers: authHeaders,
      body: jsonEncode({'name': name, 'email': email}),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _currentUser = data['user'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(_currentUser));
      return _currentUser!;
    } else {
      final detail = _parseError(response);
      throw AuthException(detail, response.statusCode);
    }
  }

  /// Deactivates the user account on the backend and triggers local logout.
  static Future<void> deactivateAccount() async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/api/auth/deactivate'),
      headers: authHeaders,
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      await logout();
    } else {
      final detail = _parseError(response);
      throw AuthException(detail, response.statusCode);
    }
  }

  /// Updates user account password.
  ///
  /// * [currentPassword]: Existing password for verification.
  /// * [newPassword]: New replacement password.
  static Future<void> changePassword(String currentPassword, String newPassword) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/api/auth/password'),
      headers: authHeaders,
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      final detail = _parseError(response);
      throw AuthException(detail, response.statusCode);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Persists authentication state to local device storage.
  static Future<void> _saveAuth(String token, Map<String, dynamic> user) async {
    _token = token;
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  /// Parses error responses into clean user-facing error strings.
  static String _parseError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      return body['detail'] ?? 'Unknown error';
    } catch (_) {
      return 'Request failed (${response.statusCode})';
    }
  }
}

/// Custom exception thrown on authentication failures.
class AuthException implements Exception {
  /// User-facing error message.
  final String message;

  /// HTTP status code.
  final int statusCode;

  /// Constructs an [AuthException].
  AuthException(this.message, this.statusCode);

  @override
  String toString() => message;
}
