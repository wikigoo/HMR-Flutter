import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'https://srv.hmrbot.com';
  static const String _chatflowId = '463b566b-f0f1-44d8-b498-3827c188783a';

  // Injected at compile time: flutter build apk --dart-define=HMR_API_TOKEN=<token>
  static const String _apiToken = String.fromEnvironment('HMR_API_TOKEN');

  static const Duration _timeout = Duration(seconds: 30);
  static const int _maxRetries = 2;
  static const List<Duration> _backoffs = [
    Duration(seconds: 1),
    Duration(seconds: 2),
  ];

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

    // Fail immediately when there is no network — avoids a 30 s timeout wait.
    final List<ConnectivityResult> connectivity =
        await Connectivity().checkConnectivity();
    if (connectivity.every(
        (ConnectivityResult r) => r == ConnectivityResult.none)) {
      throw const ApiException(
        'اتصال اینترنت برقرار نیست. لطفاً اتصال خود را بررسی کنید.',
      );
    }

    final Uri url = Uri.parse('$_baseUrl/api/v1/prediction/$_chatflowId');
    final Map<String, String> headers = {
      'Authorization': 'Bearer $_apiToken',
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

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  Future<String> _attempt(
    Uri url,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) async {
    try {
      final http.Response response = await http
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
