import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

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
      throw const ApiException(
        'خطای پیکربندی برنامه. لطفاً با پشتیبانی تماس بگیرید.',
      );
    }

    // Pre-flight: fast network check before the real request.
    // connectivity_plus alone misses captive portals and DNS failures;
    // a real HTTP probe to the server is the only reliable signal.
    final List<ConnectivityResult> connectivity =
        await Connectivity().checkConnectivity();
    if (connectivity.every(
        (ConnectivityResult r) => r == ConnectivityResult.none)) {
      throw const ApiException(
        'اتصال اینترنت برقرار نیست. لطفاً اتصال خود را بررسی کنید.',
      );
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
        throw _TransientError(
          'سرور همر در دسترس نیست (${res.statusCode}). لطفاً لحظاتی دیگر تلاش کنید.',
        );
      }
    } on TimeoutException {
      throw const _TransientError(
        'سرور همر پاسخ نمی‌دهد. اتصال اینترنت یا فیلترینگ را بررسی کنید.',
      );
    } on http.ClientException {
      throw const _TransientError(
        'اتصال به سرور برقرار نشد. لطفاً اتصال اینترنت خود را بررسی کنید.',
      );
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
        throw const ApiException(
          'متأسفانه پاسخی از سرور دریافت نشد. لطفاً دوباره تلاش کنید.',
        );
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw const ApiException(
          'خطای احراز هویت. لطفاً با پشتیبانی تماس بگیرید.',
        );
      } else if (response.statusCode == 502 ||
          response.statusCode == 503 ||
          response.statusCode == 504) {
        // Gateway / service-unavailable — transient, worth retrying.
        throw _TransientError(
          'خطای سرور (${response.statusCode}). لطفاً لحظاتی دیگر تلاش کنید.',
        );
      } else if (response.statusCode == 500) {
        throw const ApiException(
          'خطای داخلی سرور. لطفاً لحظاتی دیگر تلاش کنید.',
        );
      } else {
        throw ApiException(
          'خطای سرور (${response.statusCode}). لطفاً لحظاتی دیگر تلاش کنید.',
        );
      }
    } on TimeoutException {
      throw const _TransientError(
        'زمان اتصال به پایان رسید. لطفاً اتصال اینترنت خود را بررسی کنید.',
      );
    } on http.ClientException {
      throw const _TransientError(
        'خطا در برقراری ارتباط با سرور. لطفاً اتصال اینترنت خود را بررسی کنید.',
      );
    } on FormatException {
      throw const ApiException(
        'پاسخ دریافتی از سرور نامعتبر است. لطفاً دوباره تلاش کنید.',
      );
    } on ApiException {
      rethrow;
    } on _TransientError {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'خطای غیرمنتظره‌ای رخ داد. لطفاً دوباره تلاش کنید.',
      );
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
