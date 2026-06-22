import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'https://srv.hmrbot.com';
  static const String _chatflowId = '843b252b-6ed0-4064-96cd-cb78367bd7b3';

  // Injected at compile time: flutter build apk --dart-define=HMR_API_TOKEN=<token>
  static const String _apiToken = String.fromEnvironment('HMR_API_TOKEN');

  /// Maximum duration to wait for a server response.
  static const Duration _timeout = Duration(seconds: 30);

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Sends the user's [question] to the Flowise prediction endpoint and
  /// returns the AI's answer text extracted from the `text` field of the
  /// JSON response.
  ///
  /// Throws an [ApiException] with a Persian user-facing error message on
  /// any failure (timeout, network error, non-200 status, malformed response).
  Future<String> sendMessage(String question) async {
    final Uri url = Uri.parse(
      '$_baseUrl/api/v1/prediction/$_chatflowId',
    );

    final Map<String, String> headers = {
      'Authorization': 'Bearer $_apiToken',
      'Content-Type': 'application/json',
    };

    final Map<String, dynamic> body = {
      'question': question,
    };

    try {
      final http.Response response = await http
          .post(
            url,
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;

        // Flowise returns the AI answer in the 'text' field.
        final String? answer = data['text'] as String?;

        if (answer != null && answer.trim().isNotEmpty) {
          return answer.trim();
        } else {
          throw const ApiException(
            'متأسفانه پاسخی از سرور دریافت نشد. لطفاً دوباره تلاش کنید.',
          );
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw const ApiException(
          'خطای احراز هویت. لطفاً با پشتیبانی تماس بگیرید.',
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
      throw const ApiException(
        'زمان اتصال به پایان رسید. لطفاً اتصال اینترنت خود را بررسی کنید.',
      );
    } on http.ClientException {
      throw const ApiException(
        'خطا در برقراری ارتباط با سرور. لطفاً اتصال اینترنت خود را بررسی کنید.',
      );
    } on FormatException {
      throw const ApiException(
        'پاسخ دریافتی از سرور نامعتبر است. لطفاً دوباره تلاش کنید.',
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw const ApiException(
        'خطای غیرمنتظره‌ای رخ داد. لطفاً دوباره تلاش کنید.',
      );
    }
  }
}

/// Custom exception for API-related errors carrying a user-friendly Persian
/// message suitable for direct display in the chat UI.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}