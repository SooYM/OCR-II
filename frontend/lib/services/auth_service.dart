import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Manages JWT-based authentication: login, register, token persistence.
class AuthService {
  static const _tokenKey = 'medscan_auth_token';
  static const _userKey = 'medscan_user';

  static String? _token;
  static Map<String, dynamic>? _currentUser;

  // ─── Token Access ──────────────────────────────────────────────────────────

  static String? get token => _token;
  static Map<String, dynamic>? get currentUser => _currentUser;
  static bool get isLoggedIn => _token != null;

  /// Attach auth header to requests.
  static Map<String, String> get authHeaders => {
    'Content-Type': 'application/json',
    'bypass-tunnel-reminder': 'true',
    'ngrok-skip-browser-warning': 'true',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ─── Init (load from disk) ─────────────────────────────────────────────────

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      _currentUser = jsonDecode(userJson);
    }
  }

  // ─── Register ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> register(String email, String name, String password, String gender, int age, String dob) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/api/auth/register'),
      headers: {'Content-Type': 'application/json', 'bypass-tunnel-reminder': 'true'},
      body: jsonEncode({
        'email': email,
        'name': name,
        'password': password,
        'gender': gender,
        'age': age,
        'dob': dob,
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
        return true;
      }
      await logout();
      return false;
    } catch (_) {
      // Network error — still consider logged in (offline-friendly)
      return _token != null;
    }
  }

  // ─── Logout ────────────────────────────────────────────────────────────────

  static Future<void> logout() async {
    _token = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  /// Update user name and email.
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

  /// Deactivate account (mark as inactive).
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

  /// Change user password.
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

  static Future<void> _saveAuth(String token, Map<String, dynamic> user) async {
    _token = token;
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  static String _parseError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      return body['detail'] ?? 'Unknown error';
    } catch (_) {
      return 'Request failed (${response.statusCode})';
    }
  }
}

class AuthException implements Exception {
  final String message;
  final int statusCode;
  AuthException(this.message, this.statusCode);

  @override
  String toString() => message;
}
