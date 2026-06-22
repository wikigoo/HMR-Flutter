import 'dart:convert';

class ConversationModel {
  ConversationModel({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage = '',
  });

  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  String lastMessage;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'lastMessage': lastMessage,
      };

  factory ConversationModel.fromJson(Map<String, dynamic> json) =>
      ConversationModel(
        id: json['id'] as String,
        title: json['title'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        lastMessage: json['lastMessage'] as String? ?? '',
      );

  static String encodeList(List<ConversationModel> list) =>
      jsonEncode(list.map((c) => c.toJson()).toList());

  static List<ConversationModel> decodeList(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
