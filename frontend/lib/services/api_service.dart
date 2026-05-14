import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/report_model.dart';
import 'auth_service.dart';

/// API service with JWT auth.
/// Base URL is configurable at runtime for localtunnel changes.
class ApiService {
  static const _urlKey = 'medscan_base_url';

  // Default URL — update this or change at runtime via the settings icon
  static String _baseUrl = 'https://preacher-dreadful-jarring.ngrok-free.dev';

  /// Get the current base URL.
  static String get baseUrl => _baseUrl;

  /// Load the base URL from storage
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_urlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl;
    }
  }

  /// Update the base URL at runtime (no rebuild needed).
  static Future<void> setBaseUrl(String url) async {
    // Strip trailing slash
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, _baseUrl);
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'bypass-tunnel-reminder': 'true',
    'ngrok-skip-browser-warning': 'true',
    if (AuthService.token != null) 'Authorization': 'Bearer ${AuthService.token}',
  };

  // ─── Health Check ─────────────────────────────────────────────────────────

  /// Ping the server to check connectivity.
  static Future<bool> checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/'),
        headers: {'bypass-tunnel-reminder': 'true'},
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Upload & Process ──────────────────────────────────────────────────────

  /// Upload an image to the backend for OCR + LLM processing.
  /// Returns a MedicalReport with structured data.
  static Future<MedicalReport> uploadReport(XFile imageFile) async {
    final uri = Uri.parse('$_baseUrl/api/upload');
    final request = http.MultipartRequest('POST', uri);

    request.headers['bypass-tunnel-reminder'] = 'true';
    request.headers['ngrok-skip-browser-warning'] = 'true';
    if (AuthService.token != null) {
      request.headers['Authorization'] = 'Bearer ${AuthService.token}';
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        filename: imageFile.name,
      ),
    );

    final streamedResponse = await request.send().timeout(const Duration(seconds: 180));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return MedicalReport.fromJson(jsonDecode(response.body));
    } else {
      final detail = _parseError(response);
      throw ApiException(detail, response.statusCode);
    }
  }

  // ─── Upload Multiple Pages ─────────────────────────────────────────────────

  /// Upload multiple page images for a single report.
  /// The backend merges all pages via LLM into one unified report.
  static Future<MedicalReport> uploadMultipleReports(List<XFile> imageFiles) async {
    if (imageFiles.isEmpty) throw ApiException('No images provided', 400);

    // If only 1 image, use the original single-upload endpoint
    if (imageFiles.length == 1) return uploadReport(imageFiles.first);

    final uri = Uri.parse('$_baseUrl/api/upload-multi');
    final request = http.MultipartRequest('POST', uri);

    request.headers['bypass-tunnel-reminder'] = 'true';
    request.headers['ngrok-skip-browser-warning'] = 'true';
    if (AuthService.token != null) {
      request.headers['Authorization'] = 'Bearer ${AuthService.token}';
    }

    for (final file in imageFiles) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'files',
          file.path,
          filename: file.name,
        ),
      );
    }

    final streamedResponse = await request.send().timeout(const Duration(seconds: 300));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return MedicalReport.fromJson(jsonDecode(response.body));
    } else {
      final detail = _parseError(response);
      throw ApiException(detail, response.statusCode);
    }
  }

  // ─── Update Report ─────────────────────────────────────────────────────────

  /// Update structured data for a report (tester corrections).
  static Future<void> updateReport(String id, StructuredData data) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/api/reports/$id'),
      headers: _headers,
      body: jsonEncode({'structured_data': data.toJson()}),
    );
    if (response.statusCode != 200) {
      throw ApiException('Update failed', response.statusCode);
    }
  }

  // ─── Send Report ──────────────────────────────────────────────────────────

  /// Mark report as verified and sent — the final step.
  static Future<void> sendReport(String id) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/reports/$id/send'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw ApiException('Send failed', response.statusCode);
    }
  }

  // ─── My Reports ─────────────────────────────────────────────────────────────

  /// Fetch all reports for the current logged-in user.
  static Future<List<MedicalReport>> fetchMyReports() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/reports/my'),
      headers: _headers,
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((j) => MedicalReport.fromJson(j as Map<String, dynamic>)).toList();
    } else {
      final detail = _parseError(response);
      throw ApiException(detail, response.statusCode);
    }
  }

  // ─── Health Analysis ──────────────────────────────────────────────────────

  /// Fetch AI analysis of health trends using LLM, optionally with a specific user query.
  static Future<String> analyzeHealthTrends({String? query, String? startDate, String? endDate}) async {
    final Map<String, String> params = {};
    if (query != null && query.isNotEmpty) params['query'] = query;
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;

    final uri = Uri.parse('$_baseUrl/api/reports/analyze').replace(
      queryParameters: params.isNotEmpty ? params : null,
    );
    final response = await http.get(
      uri,
      headers: _headers,
    ).timeout(const Duration(seconds: 45)); // LLM can be slow

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['analysis'] as String? ?? 'No analysis returned.';
    } else {
      final detail = _parseError(response);
      throw ApiException(detail, response.statusCode);
    }
  }

  /// Stream AI analysis token-by-token via SSE.
  static Stream<String> analyzeHealthTrendsStream({String? query, String? startDate, String? endDate}) async* {
    final Map<String, String> params = {};
    if (query != null && query.isNotEmpty) params['query'] = query;
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;

    final uri = Uri.parse('$_baseUrl/api/reports/analyze/stream').replace(
      queryParameters: params.isNotEmpty ? params : null,
    );

    final client = http.Client();
    try {
      final request = http.Request('GET', uri);
      request.headers.addAll(_headers);
      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 120));

      if (streamedResponse.statusCode != 200) {
        throw ApiException('Stream request failed', streamedResponse.statusCode);
      }

      final lineStream = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lineStream) {
        if (line.startsWith('data: ')) {
          final payload = line.substring(6).trim();
          if (payload == '[DONE]') break;
          try {
            final data = jsonDecode(payload);
            if (data is Map && data.containsKey('token')) {
              yield data['token'] as String;
            } else if (data is Map && data.containsKey('error')) {
              throw ApiException(data['error'] as String, 500);
            }
          } catch (e) {
            if (e is ApiException) rethrow;
            // Plain text fallback (for simple error messages)
            yield payload;
          }
        }
      }
    } finally {
      client.close();
    }
  }

  /// Delete a report by ID
  static Future<void> deleteReport(String reportId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/reports/$reportId'),
      headers: _headers,
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      final detail = _parseError(response);
      throw ApiException(detail, response.statusCode);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static String _parseError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      return body['detail'] ?? 'Unknown error';
    } catch (_) {
      return 'Request failed (${response.statusCode})';
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
