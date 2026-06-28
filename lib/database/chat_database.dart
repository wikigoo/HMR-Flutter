import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/message_model.dart';

/// Singleton SQLite helper for chat message persistence.
///
/// Schema: one `messages` table keyed by (conv_id, ts).
/// Each conversation's rows are fetched/deleted in O(log n) via the index.
class ChatDatabase {
  ChatDatabase._();
  static final ChatDatabase instance = ChatDatabase._();

  Database? _db;

  Future<Database> get _database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final String path = join(await getDatabasesPath(), 'hmr_chat.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int _) async {
        await db.execute('''
          CREATE TABLE messages (
            id      TEXT NOT NULL,
            conv_id TEXT NOT NULL,
            role    TEXT NOT NULL,
            text    TEXT NOT NULL,
            ts      INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_conv_ts ON messages (conv_id, ts)',
        );
      },
    );
  }

  Future<List<MessageModel>> fetchMessages(String conversationId) async {
    final Database db = await _database;
    final List<Map<String, dynamic>> rows = await db.query(
      'messages',
      where: 'conv_id = ?',
      whereArgs: <Object>[conversationId],
      orderBy: 'ts ASC',
    );
    return rows.map(_rowToModel).toList();
  }

  Future<void> insertMessage(String conversationId, MessageModel msg) async {
    final Database db = await _database;
    await db.insert('messages', _modelToRow(conversationId, msg));
  }

  Future<void> deleteMessages(String conversationId) async {
    final Database db = await _database;
    await db.delete(
      'messages',
      where: 'conv_id = ?',
      whereArgs: <Object>[conversationId],
    );
  }

  Future<void> deleteAllMessages() async {
    final Database db = await _database;
    await db.delete('messages');
  }

  static MessageModel _rowToModel(Map<String, dynamic> row) {
    return MessageModel(
      id: row['id'] as String,
      text: row['text'] as String,
      role: (row['role'] as String) == 'user'
          ? MessageRole.user
          : MessageRole.ai,
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['ts'] as int),
    );
  }

  static Map<String, Object> _modelToRow(
    String convId,
    MessageModel msg,
  ) {
    return <String, Object>{
      'id': msg.id,
      'conv_id': convId,
      'role': msg.isUser ? 'user' : 'ai',
      'text': msg.text,
      'ts': msg.timestamp.millisecondsSinceEpoch,
    };
  }
}
