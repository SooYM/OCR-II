/// MedScan REST API Communication Gateway.
///
/// This service coordinates all network communication between the Flutter client
/// and the FastAPI backend:
/// 1. Multipart image and multi-page document uploads with OCR ingestion.
/// 2. Computer vision scanner preprocessing (CamScanner shadow removal).
/// 3. Human-in-the-loop report verification updates and finalization.
/// 4. Server-Sent Events (SSE) token-by-token streaming for conversational AI health analytics.
///
/// ### Simple Example:
/// ```dart
/// // Fetch all digitized reports for the authenticated user
/// final reports = await ApiService.fetchMyReports();
/// for (final r in reports) {
///   print('Report: ${r.filename}, Date: ${r.structuredData?.date}');
/// }
/// ```
///
/// ### Advanced Example:
/// ```dart
/// // Streaming AI health analysis response token-by-token
/// ApiService.analyzeHealthTrendsStream(query: 'Summarize my liver markers')
///   .listen(
///     (token) => stdout.write(token),
///     onError: (e) => print('Stream failed: $e'),
///   );
/// ```
library api_service;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/report_model.dart';
import '../models/chat_models.dart';
import 'auth_service.dart';

/// Centralized API service with JWT authentication and dynamic host routing.
///
/// The base URL can be altered at runtime via the settings screen to accommodate
/// development tunnels (localtunnel, ngrok) without requiring application rebuilds.
class ApiService {
  static const _urlKey = 'medscan_base_url';

  // Default production or testing backend URL
  static String _baseUrl = 'https://aihubdev.qiu.edu.my/backend';

  /// Returns the current backend base URL string.
  static String get baseUrl => _baseUrl;

  /// Loads the persisted base URL from local storage.
  ///
  /// Must be called during application startup prior to executing API calls.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_urlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl;
    }
  }

  /// Updates the active base URL at runtime and persists it across app restarts.
  ///
  /// * [url]: New backend URL string. Trailing slashes are automatically stripped.
  static Future<void> setBaseUrl(String url) async {
    // Strip trailing slash to maintain clean endpoint URI concatenation
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, _baseUrl);
  }

  /// Default HTTP headers injected into requests, including tunnel bypasses and JWT token.
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    // Bypass interstitial reminder warning pages served by free tunneling proxies
    'bypass-tunnel-reminder': 'true',
    'ngrok-skip-browser-warning': 'true',
    if (AuthService.token != null) 'Authorization': 'Bearer ${AuthService.token}',
  };

  // ─── Health Check ─────────────────────────────────────────────────────────

  /// Pings the backend root endpoint to verify network reachability.
  ///
  /// * Returns: `true` if server responds with HTTP 200 within 5 seconds, `false` otherwise.
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

  /// Uploads a single image report to the backend for OCR and LLM extraction.
  ///
  /// * [imageFile]: The local image file to upload.
  /// * [force]: Optional flag to bypass identity verification mismatch warnings.
  /// * Returns: A [MedicalReport] containing extracted structured medical parameters.
  /// * Throws: [ApiException] if the server rejects the upload or extraction fails.
  static Future<MedicalReport> uploadReport(XFile imageFile, {bool force = false}) async {
    final uri = Uri.parse('$_baseUrl/api/upload${force ? "?force=true" : ""}');
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

    // High timeout (180s) to allow for OpenCV preprocessing + multi-segment GPT-4o Vision OCR
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

  /// Uploads multiple page images belonging to a single multi-page medical report.
  ///
  /// The backend preprocesses every page, performs content-aware splitting, merges
  /// extracted parameters across pages, and returns a unified [MedicalReport].
  ///
  /// * [imageFiles]: List of [XFile] images in page sequence order.
  /// * [force]: Set true to bypass demographic mismatch warnings.
  /// * Returns: A unified [MedicalReport].
  /// * Throws: [ApiException] on network or processing failure.
  static Future<MedicalReport> uploadMultipleReports(List<XFile> imageFiles, {bool force = false}) async {
    if (imageFiles.isEmpty) throw ApiException('No images provided', 400);

    // Optimization: Route 1-page reports through the simpler single-upload endpoint
    if (imageFiles.length == 1) return uploadReport(imageFiles.first, force: force);

    final uri = Uri.parse('$_baseUrl/api/upload-multi${force ? "?force=true" : ""}');
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

  // ─── Scanner Preprocessing ──────────────────────────────────────────────────

  /// Runs the backend CamScanner-like edge detection and shadow-removal pipeline.
  ///
  /// * [imageFile]: Input raw camera photo.
  /// * [mode]: Enhancement mode (`'color'` for illumination division, `'bw'` for adaptive thresholding).
  /// * Returns: Map containing `processed_image_url`, `server_filepath`, and corner metadata.
  /// * Throws: [ApiException] if processing fails.
  static Future<Map<String, dynamic>> preprocessImage(XFile imageFile, {String mode = 'color'}) async {
    final uri = Uri.parse('$_baseUrl/api/scanner/preprocess?mode=$mode');
    final request = http.MultipartRequest('POST', uri);

    request.headers['bypass-tunnel-reminder'] = 'true';
    request.headers['ngrok-skip-browser-warning'] = 'true';
    if (AuthService.token != null) {
      request.headers['Authorization'] = 'Bearer ${AuthService.token}';
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        filename: imageFile.name,
      ),
    );

    final streamedResponse = await request.send().timeout(const Duration(seconds: 180));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final detail = _parseError(response);
      throw ApiException(detail, response.statusCode);
    }
  }

  /// Dispatches OCR extraction for files already preprocessed and saved on the server.
  ///
  /// * [filepaths]: Absolute file paths on the server filesystem.
  /// * [filenames]: Display filenames.
  /// * [force]: Bypass identity mismatch flags.
  /// * Returns: Extracted [MedicalReport].
  static Future<MedicalReport> uploadPreprocessedReports(List<String> filepaths, List<String> filenames, {bool force = false}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/upload-multi/preprocessed${force ? "?force=true" : ""}'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'filepaths': filepaths,
        'filenames': filenames,
      }),
    ).timeout(const Duration(seconds: 300));

    if (response.statusCode == 200) {
      return MedicalReport.fromJson(jsonDecode(response.body));
    } else {
      final detail = _parseError(response);
      throw ApiException(detail, response.statusCode);
    }
  }

  // ─── Manual Report (No OCR) ────────────────────────────────────────────────

  /// Creates a blank report structure for direct manual laboratory entry.
  ///
  /// * Returns: A [MedicalReport] with empty [StructuredData] containers.
  static Future<MedicalReport> createManualReport() async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/reports/manual'),
      headers: _headers,
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return MedicalReport.fromJson(jsonDecode(response.body));
    } else {
      final detail = _parseError(response);
      throw ApiException(detail, response.statusCode);
    }
  }

  // ─── Update Report ─────────────────────────────────────────────────────────

  /// Updates corrected structured clinical data for an existing report.
  ///
  /// * [id]: The report UUID.
  /// * [data]: The modified [StructuredData] payload from the verification screen.
  /// * [force]: Bypass mismatch warnings.
  /// * Throws: [ApiException] if update fails.
  static Future<void> updateReport(String id, StructuredData data, {bool force = false}) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/api/reports/$id${force ? "?force=true" : ""}'),
      headers: _headers,
      body: jsonEncode({'structured_data': data.toJson()}),
    );
    if (response.statusCode != 200) {
      throw ApiException('Update failed', response.statusCode);
    }
  }

  // ─── Send Report ──────────────────────────────────────────────────────────

  /// Finalizes and commits the verified report.
  ///
  /// Triggers backend duplicate analysis, toggles `user_verified = 1`, and persists
  /// the 92 standardized biomarkers into `staging_medical_records`.
  ///
  /// * [id]: Report UUID to finalize.
  /// * Throws: [ApiException] if database commit fails.
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

  /// Fetches all reports belonging to the current authenticated user.
  ///
  /// * Returns: List of [MedicalReport] records.
  /// * Throws: [ApiException] if retrieval fails.
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

  /// Fetches a high-level layman AI health summary of the patient's latest records.
  ///
  /// * Returns: Markdown summary string.
  static Future<String> fetchHealthSummary() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/reports/health-summary'),
      headers: _headers,
    ).timeout(const Duration(seconds: 45));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['summary'] as String? ?? 'No summary returned.';
    } else {
      final detail = _parseError(response);
      throw ApiException(detail, response.statusCode);
    }
  }

  /// Fetches an AI analysis of health trends using LLM completions.
  ///
  /// * [query]: Optional specific clinical question.
  /// * [startDate]: Optional start date filter (`YYYY-MM-DD`).
  /// * [endDate]: Optional end date filter (`YYYY-MM-DD`).
  /// * Returns: AI generated analysis string.
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
    ).timeout(const Duration(seconds: 45));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['analysis'] as String? ?? 'No analysis returned.';
    } else {
      final detail = _parseError(response);
      throw ApiException(detail, response.statusCode);
    }
  }

  /// Streams an AI health analysis response token-by-token via Server-Sent Events (SSE).
  ///
  /// * [query]: The user query to analyze.
  /// * [startDate]: Optional beginning of date window.
  /// * [endDate]: Optional end of date window.
  /// * [messages]: Conversational history array for multi-turn context.
  /// * [sessionId]: Persistent chat thread ID.
  /// * Returns: A [Stream] yielding individual token strings as they arrive.
  static Stream<String> analyzeHealthTrendsStream({
    String? query,
    String? startDate,
    String? endDate,
    List<Map<String, String>>? messages,
    String? sessionId,
  }) async* {
    final uri = Uri.parse('$_baseUrl/api/reports/analyze/stream');

    final client = http.Client();
    try {
      final request = http.Request('POST', uri);
      final headers = Map<String, String>.from(_headers);
      headers['Content-Type'] = 'application/json';
      request.headers.addAll(headers);

      final body = {
        if (query != null && query.isNotEmpty) 'query': query,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        if (messages != null && messages.isNotEmpty) 'messages': messages,
        if (sessionId != null) 'session_id': sessionId,
      };
      request.body = jsonEncode(body);
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

  // ─── Chat Sessions ────────────────────────────────────────────────────────

  /// Creates a new conversational chat session.
  ///
  /// * [title]: Topic summary title.
  /// * Returns: The newly created [ChatSession].
  static Future<ChatSession> createChatSession(String title) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/chat/sessions'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'title': title}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ChatSession(
        id: data['id'] as String,
        title: data['title'] as String,
        createdAt: DateTime.now(),
      );
    } else {
      final detail = _parseError(response);
      throw ApiException(detail, response.statusCode);
    }
  }

  /// Fetches all chat sessions for the authenticated user.
  ///
  /// * Returns: List of [ChatSession] items.
  static Future<List<ChatSession>> getChatSessions() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/chat/sessions'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => ChatSession.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      final detail = _parseError(response);
      throw ApiException(detail, response.statusCode);
    }
  }

  /// Fetches all historical messages belonging to a chat session.
  ///
  /// * [sessionId]: Session UUID.
  /// * Returns: List of [ChatMessage] items ordered chronologically.
  static Future<List<ChatMessage>> getChatMessages(String sessionId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/chat/sessions/$sessionId/messages'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      final detail = _parseError(response);
      throw ApiException(detail, response.statusCode);
    }
  }

  /// Deletes a chat session and all its child messages.
  ///
  /// * [sessionId]: Target session UUID.
  static Future<void> deleteChatSession(String sessionId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/chat/sessions/$sessionId'),
      headers: _headers,
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      final detail = _parseError(response);
      throw ApiException(detail, response.statusCode);
    }
  }

  /// Deletes a medical report and its staging database rows.
  ///
  /// * [reportId]: Target report UUID.
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

  /// Extracts error message from response JSON bodies or falls back to status code.
  static String _parseError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      return body['detail'] ?? 'Unknown error';
    } catch (_) {
      return 'Request failed (${response.statusCode})';
    }
  }
}

/// Custom exception thrown on MedScan REST API network failures.
class ApiException implements Exception {
  /// User-facing or technical error description.
  final String message;

  /// HTTP status code returned by the server.
  final int statusCode;

  /// Constructs an [ApiException].
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
