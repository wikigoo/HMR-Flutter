import 'package:flutter/foundation.dart';

import '../models/message_model.dart';
import '../repositories/chat_repository.dart';
// ApiException (thrown by the repository's network call) is caught below.
import '../services/api_service.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required this.conversationId,
    required ChatRepository repository,
    this.userId,
    this.onUpdate,
  }) : _repo = repository;

  final String conversationId;

  // Phase 4: the signed-in user's stable Google id (`sub`), or null for guests.
  // Used as the Flowise sessionId so a signed-in user's chat context follows
  // them across devices; guests fall back to the local per-conversation id.
  final String? userId;

  final void Function(String title, String lastMessage)? onUpdate;

  // Injected data-access seam; the app-scoped repository owns (and disposes)
  // the underlying ApiService / ChatDatabase.
  final ChatRepository _repo;

  List<MessageModel> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  bool _metaUpdated = false;
  bool _disposed = false;
  String? _lastFailedText;

  List<MessageModel> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;

  // Async methods below mutate state and notify after `await`. If the user
  // leaves the chat mid-request the provider is disposed before the await
  // resolves, and a bare notifyListeners() would throw "used after being
  // disposed". Route every notification through this guard.
  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    // The repository (and its pooled HTTP client) is app-scoped and shared
    // across conversations — it is NOT disposed here, only the disposed guard
    // is flipped so late async callbacks skip notifyListeners().
    _disposed = true;
    super.dispose();
  }

  Future<void> loadHistory() async {
    try {
      _messages = await _repo.loadMessages(conversationId);
      _metaUpdated = _messages.isNotEmpty;
      _safeNotify();
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
      _safeNotify();
      return;
    }
    _isSending = true;

    final MessageModel userMsg = MessageModel.userMessage(text.trim());
    _messages.add(userMsg);
    _isLoading = true;
    _safeNotify();

    try {
      await _repo.saveMessage(conversationId, userMsg);
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
    _safeNotify();
    await _callApi(text);
  }

  Future<void> _callApi(String text) async {
    try {
      final String aiText = await _repo.fetchAiResponse(
        text,
        // Phase 4: signed-in -> stable Google `sub` (cross-device continuity);
        // guest -> local per-conversation id (unchanged behaviour).
        sessionId: userId ?? conversationId,
      );
      _lastFailedText = null;
      final MessageModel aiMsg = MessageModel.aiMessage(aiText);
      _messages.add(aiMsg);
      try {
        await _repo.saveMessage(conversationId, aiMsg);
      } catch (e) {
        debugPrint('HMR: insert ai msg — $e');
      }
      if (!_disposed && onUpdate != null) {
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
      _safeNotify();
    }
  }

  Future<void> clearHistory() async {
    _messages.clear();
    _metaUpdated = false;
    _lastFailedText = null;
    _safeNotify();
    try {
      await _repo.deleteMessages(conversationId);
    } catch (e) {
      debugPrint('HMR: clear error — $e');
    }
  }
}
