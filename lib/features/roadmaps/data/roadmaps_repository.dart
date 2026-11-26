import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/supabase_service.dart';
import '../../quizzes/data/saved_exams_store_stub.dart'
    if (dart.library.io) '../../quizzes/data/saved_exams_store_io.dart'
    if (dart.library.js_interop) '../../quizzes/data/saved_exams_store_web.dart' as store;
import '../models/roadmap_model.dart';

/// Repositório local + sincronização Supabase para trilhas de estudos (`public.noesis_roadmaps`).
class RoadmapsRepository {
  RoadmapsRepository._();

  static const String _storageKey = 'noesis_roadmaps_v1';
  static List<StudyRoadmap>? _cache;

  static Future<List<StudyRoadmap>> loadAll({bool forceRemote = false}) async {
    List<StudyRoadmap> localList;
    if (_cache != null && !forceRemote) {
      localList = List<StudyRoadmap>.from(_cache!);
    } else {
      localList = [];
      try {
        final raw = await store.readSavedExamsRaw(_storageKey);
        if (raw != null && raw.trim().isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            localList = decoded
                .whereType<Map>()
                .map((e) => StudyRoadmap.fromJson(Map<String, dynamic>.from(e)))
                .toList();
          }
        }
      } catch (e) {
        debugPrint('Erro ao carregar trilhas locais: $e');
      }
    }

    if (SupabaseService.isAuthenticated && (_cache == null || forceRemote)) {
      try {
        final remoteRows = await SupabaseService.getRoadmaps();
        final remoteIds = <String>{};
        final merged = <String, StudyRoadmap>{
          for (final r in localList) r.id: r,
        };
        for (final row in remoteRows) {
          final parsed = StudyRoadmap.fromJson(row);
          remoteIds.add(parsed.id);
          final existing = merged[parsed.id];
          if (existing == null || parsed.updatedAt.isAfter(existing.updatedAt)) {
            merged[parsed.id] = parsed;
          }
        }
        // Sobe eventuais trilhas criadas localmente antes da autenticação para o Supabase
        for (final local in localList) {
          if (!remoteIds.contains(local.id)) {
            await SupabaseService.upsertRoadmap(local.toJson());
          }
        }
        localList = merged.values.toList();
        await _persist(localList);
      } catch (e) {
        debugPrint('Erro ao sincronizar trilhas do Supabase: $e');
      }
    }

    localList.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _cache = localList;
    return List<StudyRoadmap>.unmodifiable(localList);
  }

  static Future<List<StudyRoadmap>> saveRoadmap(
    StudyRoadmap roadmap, {
    bool syncRemote = true,
  }) async {
    final list = List<StudyRoadmap>.from(await loadAll());
    final updated = roadmap.copyWith(updatedAt: DateTime.now());
    final idx = list.indexWhere((r) => r.id == updated.id);
    if (idx != -1) {
      list[idx] = updated;
    } else {
      list.insert(0, updated);
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _cache = list;
    await _persist(list);
    SupabaseService.recordConsistencyActivity(date: updated.updatedAt);

    if (syncRemote) {
      await SupabaseService.upsertRoadmap(updated.toJson());
    }
    return List<StudyRoadmap>.unmodifiable(list);
  }

  static Future<List<StudyRoadmap>> deleteRoadmap(String roadmapId) async {
    final list = List<StudyRoadmap>.from(await loadAll());
    list.removeWhere((r) => r.id == roadmapId);
    _cache = list;
    await _persist(list);
    await SupabaseService.deleteRoadmap(roadmapId);
    return List<StudyRoadmap>.unmodifiable(list);
  }

  @visibleForTesting
  static Future<void> clearForTest() async {
    _cache = [];
    await store.writeSavedExamsRaw(_storageKey, '[]');
  }

  static Future<void> _persist(List<StudyRoadmap> list) async {
    try {
      await store.writeSavedExamsRaw(
        _storageKey,
        jsonEncode(list.map((r) => r.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('Erro ao salvar trilhas locais: $e');
    }
  }
}
