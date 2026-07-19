import 'package:flutter_test/flutter_test.dart';
import 'package:hmr_chatbot/models/message_model.dart';
import 'package:hmr_chatbot/providers/chat_provider.dart';
import 'package:hmr_chatbot/repositories/chat_repository.dart';
import 'package:hmr_chatbot/services/api_service.dart';

/// In-memory fake repository. Its existence is the point of the refactor:
/// [ChatProvider] can now be exercised end-to-end without a live Flowise
/// server or an on-device SQLite database. Every method the provider calls is
/// overridden here, so the real ApiService/ChatDatabase are never touched.
class _FakeChatRepository extends ChatRepository {
  final List<MessageModel> saved = <MessageModel>[];
  String reply = 'پاسخ آزمایشی';
  bool throwApi = false;
  String? lastSessionId;

  @override
  Future<List<MessageModel>> loadMessages(String conversationId) async =>
      List<MessageModel>.from(saved);

  @override
  Future<void> saveMessage(String conversationId, MessageModel message) async {
    saved.add(message);
  }

  @override
  Future<String> fetchAiResponse(String text, {required String sessionId}) async {
    lastSessionId = sessionId;
    if (throwApi) throw const ApiException('boom');
    return reply;
  }

  @override
  Future<void> deleteMessages(String conversationId) async => saved.clear();
}

void main() {
  group('ChatProvider with an injected repository', () {
    test('stores both sides of the exchange through the repository', () async {
      final _FakeChatRepository repo = _FakeChatRepository();
      final ChatProvider chat =
          ChatProvider(conversationId: 'c1', repository: repo);

      await chat.sendMessage('سلام');

      expect(chat.messages.length, 2);
      expect(chat.messages.first.isUser, isTrue);
      expect(chat.messages.last.isAi, isTrue);
      expect(chat.messages.last.text, 'پاسخ آزمایشی');
      // User message + AI answer both persisted.
      expect(repo.saved.length, 2);
    });

    test('uses the signed-in user id as the Flowise sessionId', () async {
      final _FakeChatRepository repo = _FakeChatRepository();
      final ChatProvider chat = ChatProvider(
        conversationId: 'c1',
        userId: 'google-sub-123',
        repository: repo,
      );

      await chat.sendMessage('سلام');

      expect(repo.lastSessionId, 'google-sub-123');
    });

    test('guest falls back to the conversation id as the sessionId', () async {
      final _FakeChatRepository repo = _FakeChatRepository();
      final ChatProvider chat =
          ChatProvider(conversationId: 'c1', repository: repo);

      await chat.sendMessage('سلام');

      expect(repo.lastSessionId, 'c1');
    });

    test('surfaces an error bubble when the API throws', () async {
      final _FakeChatRepository repo = _FakeChatRepository()..throwApi = true;
      final ChatProvider chat =
          ChatProvider(conversationId: 'c1', repository: repo);

      await chat.sendMessage('سلام');

      expect(chat.messages.last.isError, isTrue);
      // Only the user message is persisted; error bubbles are ephemeral.
      expect(repo.saved.length, 1);
    });
  });
}
