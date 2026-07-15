import 'package:flutter/foundation.dart';

import '../database/chat_database.dart';
import '../models/message_model.dart';
import '../services/api_service.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required this.conversationId,
    this.userId,
    this.onUpdate,
  });

  final String conversationId;

  // Phase 4: the signed-in user's stable Google id (`sub`), or null for guests.
  // Used as the Flowise sessionId so a signed-in user's chat context follows
  // them across devices; guests fall back to the local per-conversation id.
  final String? userId;

  final void Function(String title, String lastMessage)? onUpdate;

  final ApiService _api = ApiService();
  final ChatDatabase _db = ChatDatabase.instance;

  List<MessageModel> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  bool _metaUpdated = false;
  String? _lastFailedText;

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

    await _callApi(text.trim());
  }

  Future<void> retryLastMessage() async {
    final String? text = _lastFailedText;
    if (text == null || _isSending) return;
    _isSending = true;
    if (_messages.isNotEmpty && _messages.last.isError) _messages.removeLast();
    _isLoading = true;
    notifyListeners();
    await _callApi(text);
  }

  Future<void> _callApi(String text) async {
    try {
      final String aiText = await _api.sendMessage(
        text,
        // Phase 4: signed-in -> stable Google `sub` (cross-device continuity);
        // guest -> local per-conversation id (unchanged behaviour).
        sessionId: userId ?? conversationId,
      );
      _lastFailedText = null;
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
        final String preview =
            aiText.length > 60 ? '${aiText.substring(0, 60)}...' : aiText;
        onUpdate!(title, preview);
      }
    } on ApiException catch (e) {
      _lastFailedText = text;
      _messages.add(MessageModel.aiMessage(e.message, isError: true));
    } catch (_) {
      _lastFailedText = text;
      _messages.add(MessageModel.aiMessage(
        'خطای غیرمنتظره‌ای رخ داد. لطفاً دوباره تلاش کنید.',
        isError: true,
      ));
    } finally {
      _isLoading = false;
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> clearHistory() async {
    _messages.clear();
    _metaUpdated = false;
    _lastFailedText = null;
    notifyListeners();
    try {
      await _db.deleteMessages(conversationId);
    } catch (e) {
      debugPrint('HMR: clear error — $e');
    }
  }
}
