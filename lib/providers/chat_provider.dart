import 'package:flutter/foundation.dart';

import '../database/chat_database.dart';
import '../models/message_model.dart';
import '../services/api_service.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required this.conversationId,
    this.onUpdate,
  });

  final String conversationId;
  final void Function(String title, String lastMessage)? onUpdate;

  final ApiService _api = ApiService();
  final ChatDatabase _db = ChatDatabase.instance;

  List<MessageModel> _messages = [];
  bool _isLoading = false;
  bool _isSending = false; // strict concurrency lock
  bool _metaUpdated = false;

  List<MessageModel> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;

  Future<void> loadHistory() async {
    try {
      _messages = await _db.fetchMessages(conversationId);
      _metaUpdated = _messages.isNotEmpty;
      notifyListeners();
    } catch (e) {
      debugPrint('HMR: load error — $e');
    }
  }

  static const int _maxInputLength = 1000;

  Future<void> sendMessage(String text) async {
    // Lock acquired synchronously before any await — prevents spam-tap races.
    if (text.trim().isEmpty || _isSending) return;
    if (text.trim().length > _maxInputLength) {
      _messages.add(MessageModel.aiMessage(
        'پیام شما بیش از $_maxInputLength کاراکتر است. لطفاً آن را کوتاه‌تر کنید.',
      ));
      notifyListeners();
      return;
    }
    _isSending = true;

    final MessageModel userMsg = MessageModel.userMessage(text.trim());
    _messages.add(userMsg);
    _isLoading = true;
    notifyListeners();

    // Persist user message immediately so it survives if the app is killed.
    try {
      await _db.insertMessage(conversationId, userMsg);
    } catch (e) {
      debugPrint('HMR: insert user msg — $e');
    }

    if (!_metaUpdated && onUpdate != null) {
      _metaUpdated = true;
      final String title = text.trim().length > 45
          ? '${text.trim().substring(0, 45)}...'
          : text.trim();
      onUpdate!(title, text.trim());
    }

    try {
      final String aiText = await _api.sendMessage(
        text.trim(),
        sessionId: conversationId,
      );
      final MessageModel aiMsg = MessageModel.aiMessage(aiText);
      _messages.add(aiMsg);
      try {
        await _db.insertMessage(conversationId, aiMsg);
      } catch (e) {
        debugPrint('HMR: insert ai msg — $e');
      }
      if (onUpdate != null) {
        final String title = _messages.first.text.length > 45
            ? '${_messages.first.text.substring(0, 45)}...'
            : _messages.first.text;
        final String preview = aiText.length > 60
            ? '${aiText.substring(0, 60)}...'
            : aiText;
        onUpdate!(title, preview);
      }
    } on ApiException catch (e) {
      _messages.add(MessageModel.aiMessage(e.message));
    } catch (_) {
      _messages.add(MessageModel.aiMessage('خطای غیرمنتظره‌ای رخ داد.'));
    } finally {
      _isLoading = false;
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> clearHistory() async {
    _messages.clear();
    _metaUpdated = false;
    notifyListeners();
    try {
      await _db.deleteMessages(conversationId);
    } catch (e) {
      debugPrint('HMR: clear error — $e');
    }
  }
}
