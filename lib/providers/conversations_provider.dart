import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../l10n/app_strings.dart';
import '../models/conversation_model.dart';
import '../repositories/chat_repository.dart';

class ConversationsProvider extends ChangeNotifier {
  ConversationsProvider(this._repo);

  final ChatRepository _repo;

  static const String _indexKey = 'conversations_index';
  static const _uuid = Uuid();

  List<ConversationModel> _all = [];
  String _query = '';

  List<ConversationModel> get filtered {
    if (_query.isEmpty) return List.unmodifiable(_all);
    final String q = _query.toLowerCase();
    return _all
        .where((c) =>
            c.title.toLowerCase().contains(q) ||
            c.lastMessage.toLowerCase().contains(q))
        .toList();
  }

  bool get isEmpty => _all.isEmpty;

  Future<void> loadConversations() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_indexKey);
    if (raw != null && raw.isNotEmpty) {
      _all = ConversationModel.decodeList(raw);
      _all.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    notifyListeners();
  }

  void search(String query) {
    _query = query;
    notifyListeners();
  }

  Future<ConversationModel> createConversation() async {
    final DateTime now = DateTime.now();
    final ConversationModel conv = ConversationModel(
      id: _uuid.v4(),
      title: AppStrings.newChat,
      createdAt: now,
      updatedAt: now,
    );
    _all.insert(0, conv);
    await _saveIndex();
    notifyListeners();
    return conv;
  }

  /// Insert-or-update in one call. Used by the desktop shell, where a "new
  /// chat" starts with a client-side id that is only committed to the index
  /// once the user actually sends the first message (no ghost rows).
  Future<void> upsertConversation(
    String id, {
    required String title,
    required String lastMessage,
  }) async {
    final int idx = _all.indexWhere((c) => c.id == id);
    if (idx == -1) {
      final DateTime now = DateTime.now();
      _all.insert(
        0,
        ConversationModel(
          id: id,
          title: title,
          createdAt: now,
          updatedAt: now,
          lastMessage: lastMessage,
        ),
      );
    } else {
      _all[idx].title = title;
      _all[idx].lastMessage = lastMessage;
      _all[idx].updatedAt = DateTime.now();
    }
    _all.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _saveIndex();
    notifyListeners();
  }

  Future<void> updateConversation(
    String id, {
    String? title,
    String? lastMessage,
  }) async {
    final int idx = _all.indexWhere((c) => c.id == id);
    if (idx == -1) return;
    if (title != null) _all[idx].title = title;
    if (lastMessage != null) _all[idx].lastMessage = lastMessage;
    _all[idx].updatedAt = DateTime.now();
    _all.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _saveIndex();
    notifyListeners();
  }

  Future<void> deleteConversation(String id) async {
    _all.removeWhere((c) => c.id == id);
    await _repo.deleteMessages(id);
    await _saveIndex();
    notifyListeners();
  }

  Future<void> deleteAllConversations() async {
    await _repo.deleteAllMessages();
    _all.clear();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_indexKey);
    notifyListeners();
  }

  Future<void> _saveIndex() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_indexKey, ConversationModel.encodeList(_all));
  }
}
