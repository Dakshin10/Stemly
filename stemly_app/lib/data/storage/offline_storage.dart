import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/scan_history.dart';

/// Production Offline Storage Manager with Schema Versioning & Automatic Migration.
/// Caches Scan History and Last Viewed Notes for robust offline learning.
class OfflineStorage {
  OfflineStorage._();

  static const int currentSchemaVersion = 2;
  static const String _versionKey = 'stemly_schema_version';
  static const String _legacyHistoryKey = 'stemly_history_v1';
  static const String _historyKeyV2 = 'stemly_history_v2';
  static const String _lastNotesKeyV2 = 'stemly_last_notes_v2';

  static SharedPreferences? _prefs;
  static List<ScanHistory> _cachedHistory = [];
  static Map<String, dynamic>? _cachedLastNotes;

  /// Initializes the local storage and runs migrations if needed.
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _migrateIfNeeded();
    await _loadFromDisk();
  }

  /// Migrates older storage schemas to currentSchemaVersion.
  static Future<void> _migrateIfNeeded() async {
    final prefs = _prefs!;
    final installedVersion = prefs.getInt(_versionKey) ?? 1;

    if (installedVersion < currentSchemaVersion) {
      debugPrint("OfflineStorage: Migrating storage from schema v$installedVersion to v$currentSchemaVersion...");

      if (installedVersion == 1) {
        // Migrate legacy v1 history to v2
        final legacyJson = prefs.getString(_legacyHistoryKey);
        if (legacyJson != null && legacyJson.isNotEmpty) {
          try {
            final List<dynamic> raw = jsonDecode(legacyJson);
            final items = raw
                .map((e) => ScanHistory.fromJson(e as Map<String, dynamic>))
                .toList();

            // Save under v2 format
            final v2Json = jsonEncode(items.map((e) => e.toJson()).toList());
            await prefs.setString(_historyKeyV2, v2Json);
            debugPrint("OfflineStorage: Successfully migrated ${items.length} history records to v2.");
          } catch (e) {
            debugPrint("OfflineStorage: Warning migrating legacy history: $e");
          }
        }
      }

      await prefs.setInt(_versionKey, currentSchemaVersion);
      debugPrint("OfflineStorage: Migration complete. Schema version is now $currentSchemaVersion.");
    }
  }

  /// Loads cached data from SharedPreferences into memory.
  static Future<void> _loadFromDisk() async {
    final prefs = _prefs!;

    // 1. Load History
    final historyJson = prefs.getString(_historyKeyV2);
    if (historyJson != null && historyJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(historyJson);
        _cachedHistory = decoded
            .map((e) => ScanHistory.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint("OfflineStorage: Error decoding history v2: $e");
        _cachedHistory = [];
      }
    }

    // 2. Load Last Notes
    final lastNotesJson = prefs.getString(_lastNotesKeyV2);
    if (lastNotesJson != null && lastNotesJson.isNotEmpty) {
      try {
        _cachedLastNotes = jsonDecode(lastNotesJson) as Map<String, dynamic>;
      } catch (e) {
        debugPrint("OfflineStorage: Error decoding last notes: $e");
        _cachedLastNotes = null;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // History Operations
  // ---------------------------------------------------------------------------

  static List<ScanHistory> get history => List.unmodifiable(_cachedHistory);

  static Future<void> addHistory(ScanHistory scan) async {
    _cachedHistory.insert(0, scan);
    await _saveHistoryToDisk();
  }

  static Future<void> removeHistory(ScanHistory scan) async {
    _cachedHistory.remove(scan);
    await _saveHistoryToDisk();
  }

  static Future<void> updateHistory() async {
    await _saveHistoryToDisk();
  }

  static Future<void> setHistory(List<ScanHistory> list) async {
    _cachedHistory = List.from(list);
    await _saveHistoryToDisk();
  }

  static Future<void> _saveHistoryToDisk() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_cachedHistory.map((e) => e.toJson()).toList());
    await prefs.setString(_historyKeyV2, jsonString);
  }

  // ---------------------------------------------------------------------------
  // Last Notes Operations (Offline Reading)
  // ---------------------------------------------------------------------------

  /// Returns cached last notes: { "topic": String, "notes": Map, "variables": List, "savedAt": String }
  static Map<String, dynamic>? get lastNotes => _cachedLastNotes;

  static Future<void> saveLastNotes({
    required String topic,
    required Map<String, dynamic> notes,
    List<String>? variables,
  }) async {
    final payload = {
      "topic": topic,
      "notes": notes,
      "variables": variables ?? [],
      "savedAt": DateTime.now().toIso8601String(),
    };
    _cachedLastNotes = payload;

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_lastNotesKeyV2, jsonEncode(payload));
  }

  // ---------------------------------------------------------------------------
  // Clear Data (Delete-My-Data / Sign Out)
  // ---------------------------------------------------------------------------

  static Future<void> clearAll() async {
    _cachedHistory.clear();
    _cachedLastNotes = null;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.remove(_historyKeyV2);
    await prefs.remove(_lastNotesKeyV2);
    await prefs.remove(_legacyHistoryKey);
  }
}
