import '../database/chat_database.dart';
import '../models/message_model.dart';
import '../services/api_service.dart';

/// Single data-access seam between the app's state layer (providers) and the
/// concrete network / persistence implementations.
///
/// Providers depend on this repository rather than instantiating [ApiService]
/// or [ChatDatabase] directly, so they can be unit-tested against a fake
/// repository (or a fake api/db injected here) without a live server or an
/// on-device SQLite file.
///
/// App-scoped: one instance is provided at the root (see `main.dart`), so the
/// pooled HTTP connection inside [ApiService] is shared across every
/// conversation and released once — via [dispose] — when the app shuts down.
class ChatRepository {
  ChatRepository({ApiService? apiService, ChatDatabase? database})
      : _api = apiService ?? ApiService(),
        _db = database ?? ChatDatabase.instance;

  final ApiService _api;
  final ChatDatabase _db;

  // ── Network ────────────────────────────────────────────────────────────

  /// Sends [text] to the assistant and returns its answer. [sessionId] is the
  /// Flowise session key (signed-in user's Google `sub`, or the local
  /// conversation id for guests).
  Future<String> fetchAiResponse(
    String text, {
    required String sessionId,
  }) {
    return _api.sendMessage(text, sessionId: sessionId);
  }

  // ── Persistence ────────────────────────────────────────────────────────

  Future<List<MessageModel>> loadMessages(String conversationId) {
    return _db.fetchMessages(conversationId);
  }

  Future<void> saveMessage(String conversationId, MessageModel message) {
    return _db.insertMessage(conversationId, message);
  }

  Future<void> deleteMessages(String conversationId) {
    return _db.deleteMessages(conversationId);
  }

  Future<void> deleteAllMessages() {
    return _db.deleteAllMessages();
  }

  /// Whether the conversation has at least one persisted message. Lets the UI
  /// run its ghost-conversation cleanup without reaching into the database.
  Future<bool> hasMessages(String conversationId) async {
    final List<MessageModel> messages = await _db.fetchMessages(conversationId);
    return messages.isNotEmpty;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────

  /// Releases the pooled HTTP connection. App-scoped: invoked by the root
  /// Provider's dispose callback, not per conversation.
  void dispose() => _api.dispose();
}
