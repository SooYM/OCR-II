import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/report_model.dart';

/// Simplified API service — no auth, tester-focused.
/// Base URL is configurable at runtime for localtunnel changes.
class ApiService {
  // Default URL — update this or change at runtime via the settings icon
  static String _baseUrl = 'https://medscan-soo.loca.lt';

  /// Get the current base URL.
  static String get baseUrl => _baseUrl;

  /// Update the base URL at runtime (no rebuild needed).
  static void setBaseUrl(String url) {
    // Strip trailing slash
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
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

    // Bypass localtunnel reminder page
    request.headers['bypass-tunnel-reminder'] = 'true';

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

    // Bypass localtunnel reminder page
    request.headers['bypass-tunnel-reminder'] = 'true';

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
      headers: {
        ..._headers,
        'bypass-tunnel-reminder': 'true',
      },
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
      headers: {
        ..._headers,
        'bypass-tunnel-reminder': 'true',
      },
    );
    if (response.statusCode != 200) {
      throw ApiException('Send failed', response.statusCode);
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
