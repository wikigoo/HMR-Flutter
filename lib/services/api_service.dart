import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../l10n/app_strings.dart';

class ApiService {
  static const String _baseUrl = 'https://srv.hmrbot.com';
  static const String _chatflowId = '463b566b-f0f1-44d8-b498-3827c188783a';

  static const Duration _timeout = Duration(seconds: 30);
  static const Duration _preflightTimeout = Duration(seconds: 3);
  static const int _maxRetries = 2;
  static const List<Duration> _backoffs = [
    Duration(seconds: 1),
    Duration(seconds: 2),
  ];

  // Single reused client: pools the TCP/TLS connection across preflight probes,
  // the prediction call, and its retries, instead of opening a fresh socket per
  // request (the static http.get/http.post helpers do the latter). Closed via
  // dispose() when the owning provider is torn down.
  final http.Client _client = http.Client();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  Future<String> sendMessage(
    String question, {
    required String sessionId,
  }) async {
    if (_baseUrl.trim().isEmpty) {
      throw const ApiException(AppStrings.apiConfigError);
    }

    // Pre-flight: fast network check before the real request.
    // connectivity_plus alone misses captive portals and DNS failures;
    // a real HTTP probe to the server is the only reliable signal.
    final List<ConnectivityResult> connectivity =
        await Connectivity().checkConnectivity();
    if (connectivity.every(
        (ConnectivityResult r) => r == ConnectivityResult.none)) {
      throw const ApiException(AppStrings.apiNoInternet);
    }
    await _preflight();

    final Uri url = Uri.parse('$_baseUrl/api/v1/prediction/$_chatflowId');
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    final Map<String, dynamic> body = {
      'question': question,
      'streaming': false,
      'overrideConfig': {'sessionId': sessionId},
    };

    _TransientError? lastTransient;
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      if (attempt > 0) await Future<void>.delayed(_backoffs[attempt - 1]);
      try {
        return await _attempt(url, headers, body);
      } on _TransientError catch (e) {
        lastTransient = e;
        // Retry on next iteration; terminal ApiExceptions propagate immediately.
      }
    }
    throw ApiException(lastTransient!.message);
  }

  /// Releases the pooled HTTP connection. Call when the owning provider is
  /// disposed; the instance must not be reused afterwards.
  void dispose() => _client.close();

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  /// Light probe to /api/v1/version (no auth, ~100 bytes response).
  /// Catches captive portals, DNS failures, and server-down before the
  /// real 30-second request is sent.
  Future<void> _preflight() async {
    try {
      final res = await _client
          .get(Uri.parse('$_baseUrl/api/v1/version'))
          .timeout(_preflightTimeout);
      if (res.statusCode >= 500) {
        throw _TransientError(AppStrings.apiServerUnavailable(res.statusCode));
      }
    } on TimeoutException {
      throw const _TransientError(AppStrings.apiServerNotResponding);
    } on http.ClientException {
      throw const _TransientError(AppStrings.apiConnectFailed);
    } catch (_) {
      // Non-network errors (e.g. unexpected response format) — let the real
      // request surface its own error rather than blocking here.
    }
  }

  Future<String> _attempt(
    Uri url,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) async {
    try {
      final http.Response response = await _client
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        final String? answer = data['text'] as String?;
        if (answer != null && answer.trim().isNotEmpty) return answer.trim();
        throw const ApiException(AppStrings.apiEmptyResponse);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw const ApiException(AppStrings.apiAuthError);
      } else if (response.statusCode == 502 ||
          response.statusCode == 503 ||
          response.statusCode == 504) {
        // Gateway / service-unavailable — transient, worth retrying.
        throw _TransientError(AppStrings.apiServerError(response.statusCode));
      } else if (response.statusCode == 500) {
        throw const ApiException(AppStrings.apiInternalError);
      } else {
        throw ApiException(AppStrings.apiServerError(response.statusCode));
      }
    } on TimeoutException {
      throw const _TransientError(AppStrings.apiTimeout);
    } on http.ClientException {
      throw const _TransientError(AppStrings.apiConnectionError);
    } on FormatException {
      throw const ApiException(AppStrings.apiInvalidResponse);
    } on ApiException {
      rethrow;
    } on _TransientError {
      rethrow;
    } catch (_) {
      throw const ApiException(AppStrings.unexpectedError);
    }
  }
}

// Marker for retriable failures (timeout, network blip, 502/503/504).
// Converted to ApiException only after all retries are exhausted.
class _TransientError {
  final String message;
  const _TransientError(this.message);
}

/// Custom exception for API-related errors carrying a user-friendly Persian
/// message suitable for direct display in the chat UI.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
