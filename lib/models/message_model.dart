import 'dart:convert';

import 'package:uuid/uuid.dart';

enum MessageRole { user, ai }

const _uuid = Uuid();

class MessageModel {
  const MessageModel({
    required this.id,
    required this.text,
    required this.role,
    required this.timestamp,
    this.isError = false,
  });

  final String id;
  final String text;
  final MessageRole role;
  final DateTime timestamp;
  final bool isError;

  bool get isUser => role == MessageRole.user;
  bool get isAi => role == MessageRole.ai;

  /// Localized HH:mm label with Persian digits (e.g. ۱۴:۳۱).
  String get timeLabel {
    final String hh = timestamp.hour.toString().padLeft(2, '0');
    final String mm = timestamp.minute.toString().padLeft(2, '0');
    return _toFa('$hh:$mm');
  }

  static String _toFa(String input) {
    const List<String> fa = <String>[
      '۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'
    ];
    final StringBuffer out = StringBuffer();
    for (final int code in input.runes) {
      if (code >= 48 && code <= 57) {
        out.write(fa[code - 48]);
      } else {
        out.writeCharCode(code);
      }
    }
    return out.toString();
  }

  factory MessageModel.userMessage(String text) {
    return MessageModel(
      id: _uuid.v4(),
      text: text,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );
  }

  factory MessageModel.aiMessage(String text, {bool isError = false}) {
    return MessageModel(
      id: _uuid.v4(),
      text: text,
      role: MessageRole.ai,
      timestamp: DateTime.now(),
      isError: isError,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'role': role == MessageRole.user ? 'user' : 'ai',
      'timestamp': timestamp.toIso8601String(),
      'isError': isError,
    };
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      text: json['text'] as String,
      role: json['role'] == 'user' ? MessageRole.user : MessageRole.ai,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isError: json['isError'] as bool? ?? false,
    );
  }

  static String encodeList(List<MessageModel> messages) {
    return jsonEncode(messages.map((m) => m.toJson()).toList());
  }

  static List<MessageModel> decodeList(String jsonString) {
    final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
    return jsonList
        .map((item) => MessageModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
