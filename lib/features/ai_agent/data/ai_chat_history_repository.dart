import 'dart:convert';
import '../../../core/localization/noesis_l10n.dart';
import '../../quizzes/data/saved_exams_store_stub.dart'
    if (dart.library.io) '../../quizzes/data/saved_exams_store_io.dart'
    if (dart.library.js_interop) '../../quizzes/data/saved_exams_store_web.dart' as local_store;

class AiChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Map<String, dynamic>> messages;

  const AiChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  String get previewText {
    for (int i = messages.length - 1; i >= 0; i--) {
      final role = messages[i]['role']?.toString();
      if (role == 'ai' || role == 'user') {
        final txt = (messages[i]['text'] ?? '').toString().trim();
        if (txt.isNotEmpty) return txt;
      }
    }
    return NoesisL10n.tr('Conversa salva');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'messages': messages.map(_sanitizeMessageForStorage).toList(),
      };

  factory AiChatSession.fromJson(Map<String, dynamic> json) {
    final rawMsgs = (json['messages'] as List?) ?? const [];
    return AiChatSession(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? NoesisL10n.tr('Conversa Noesis AI')).toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ?? DateTime.now(),
      messages: rawMsgs
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList(),
    );
  }

  static Map<String, dynamic> _sanitizeMessageForStorage(Map<String, dynamic> msg) {
    final out = <String, dynamic>{
      'role': (msg['role'] ?? 'ai').toString(),
      'text': (msg['text'] ?? '').toString(),
    };
    if (msg['isError'] == true) out['isError'] = true;
    if (msg['status'] != null) out['status'] = msg['status'].toString();
    if (msg['actionName'] != null) out['actionName'] = msg['actionName'].toString();
    if (msg['time'] != null) out['time'] = msg['time'].toString();
    return out;
  }
}

class AiChatHistoryRepository {
  static const String storageKey = 'noesis_ai_chat_history_v1';
  static const int maxSessions = 50;

  static Future<List<AiChatSession>> loadAll() async {
    try {
      final raw = await local_store.readSavedExamsRaw(storageKey);
      if (raw == null || raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final list = decoded
          .whereType<Map>()
          .map((e) => AiChatSession.fromJson(Map<String, dynamic>.from(e)))
          .where((s) => s.id.isNotEmpty)
          .toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _saveList(List<AiChatSession> sessions) async {
    final sorted = List<AiChatSession>.from(sessions)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final trimmed = sorted.take(maxSessions).toList();
    await local_store.writeSavedExamsRaw(
      storageKey,
      jsonEncode(trimmed.map((s) => s.toJson()).toList()),
    );
  }

  static Future<void> upsertSession(AiChatSession session) async {
    final all = List<AiChatSession>.from(await loadAll());
    final idx = all.indexWhere((s) => s.id == session.id);
    if (idx >= 0) {
      all[idx] = session;
    } else {
      all.insert(0, session);
    }
    await _saveList(all);
  }

  static Future<void> deleteSession(String id) async {
    final all = List<AiChatSession>.from(await loadAll())
      ..removeWhere((s) => s.id == id);
    await _saveList(all);
  }

  static Future<void> clearAll() async {
    await local_store.writeSavedExamsRaw(storageKey, '[]');
  }
}
