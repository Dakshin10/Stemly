import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/scan_history.dart';

/// Production Multi-Tenant Offline Storage Manager with Schema Versioning & User Isolation.
/// Caches Scan History and Last Viewed Notes per authenticated user (or guest) for robust offline learning.
class OfflineStorage {
  OfflineStorage._();

  static const int currentSchemaVersion = 3;
  static const String _versionKey = 'stemly_schema_version';
  static const String _legacyHistoryKey = 'stemly_history_v1';
  static const String _historyKeyV2 = 'stemly_history_v2';
  static const String _lastNotesKeyV2 = 'stemly_last_notes_v2';

  static SharedPreferences? _prefs;
  static String _activeScope = 'guest';
  static List<ScanHistory> _cachedHistory = [];
  static Map<String, dynamic>? _cachedLastNotes;

  static String get activeScope => _activeScope;

  static String _historyKeyFor(String scope) => 'stemly_history_v3_$scope';
  static String _notesKeyFor(String scope) => 'stemly_last_notes_v3_$scope';

  /// Initializes the local storage and runs migrations if needed.
  static Future<void> init({String? userUid}) async {
    _prefs ??= await SharedPreferences.getInstance();
    if (userUid != null && userUid.isNotEmpty) {
      _activeScope = userUid;
    }
    await _migrateIfNeeded();
    await _loadFromDisk();
  }

  /// Switches active user context, purging in-memory state and rehydrating user-isolated storage.
  /// If upgrading from guest with items and the user has no history yet, seamlessly migrates guest records.
  static Future<void> switchUser(String? newUid) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;

    final targetScope = (newUid != null && newUid.isNotEmpty) ? newUid : 'guest';
    if (_activeScope == targetScope && _cachedHistory.isNotEmpty) {
      return;
    }

    final oldScope = _activeScope;
    final hadGuestItems = oldScope == 'guest' && _cachedHistory.isNotEmpty;
    final guestItemsToMigrate = hadGuestItems ? List<ScanHistory>.from(_cachedHistory) : <ScanHistory>[];

    // Wipe memory immediately to avoid data bleed between user sessions
    _cachedHistory = [];
    _cachedLastNotes = null;
    _activeScope = targetScope;

    // Check if target user has existing data
    final userKey = _historyKeyFor(targetScope);
    final existingUserJson = prefs.getString(userKey);

    if ((existingUserJson == null || existingUserJson.isEmpty) &&
        targetScope != 'guest' &&
        guestItemsToMigrate.isNotEmpty) {
      // Migrate guest scans to the newly logged-in user account
      _cachedHistory = guestItemsToMigrate;
      await _saveHistoryToDisk();
      await prefs.remove(_historyKeyFor('guest'));
      debugPrint("OfflineStorage: Migrated ${guestItemsToMigrate.length} guest scans to user $targetScope");
    } else {
      await _loadFromDisk();
    }
  }

  /// Immediately purges in-memory state and resets to guest scope (used on sign-out).
  static void flushMemory() {
    _cachedHistory = [];
    _cachedLastNotes = null;
    _activeScope = 'guest';
  }

  /// Migrates older storage schemas to currentSchemaVersion.
  static Future<void> _migrateIfNeeded() async {
    final prefs = _prefs!;
    final installedVersion = prefs.getInt(_versionKey) ?? 1;

    if (installedVersion < currentSchemaVersion) {
      debugPrint(
        "OfflineStorage: Migrating storage from schema v$installedVersion to v$currentSchemaVersion...",
      );

      // Step 1: Migrate v1 to v2 if needed
      if (installedVersion == 1) {
        final legacyJson = prefs.getString(_legacyHistoryKey);
        if (legacyJson != null && legacyJson.isNotEmpty) {
          try {
            final List<dynamic> raw = jsonDecode(legacyJson);
            final items = raw
                .map((e) => ScanHistory.fromJson(e as Map<String, dynamic>))
                .toList();
            final v2Json = jsonEncode(items.map((e) => e.toJson()).toList());
            await prefs.setString(_historyKeyV2, v2Json);
          } catch (e) {
            debugPrint("OfflineStorage: Warning migrating legacy history: $e");
          }
        }
      }

      // Step 2: Migrate v2 unscoped to v3 guest / active scope
      if (installedVersion < 3) {
        final v2Json = prefs.getString(_historyKeyV2);
        if (v2Json != null && v2Json.isNotEmpty) {
          try {
            final targetKey = _historyKeyFor(_activeScope);
            if (!prefs.containsKey(targetKey)) {
              await prefs.setString(targetKey, v2Json);
            }
          } catch (e) {
            debugPrint("OfflineStorage: Warning migrating v2 to v3: $e");
          }
        }

        final v2Notes = prefs.getString(_lastNotesKeyV2);
        if (v2Notes != null && v2Notes.isNotEmpty) {
          try {
            final targetNotesKey = _notesKeyFor(_activeScope);
            if (!prefs.containsKey(targetNotesKey)) {
              await prefs.setString(targetNotesKey, v2Notes);
            }
          } catch (e) {
            debugPrint("OfflineStorage: Warning migrating v2 notes: $e");
          }
        }
      }

      await prefs.setInt(_versionKey, currentSchemaVersion);
      debugPrint(
        "OfflineStorage: Migration complete. Schema version is now $currentSchemaVersion.",
      );
    }
  }

  /// Loads cached data from SharedPreferences into memory for the active user scope.
  static Future<void> _loadFromDisk() async {
    final prefs = _prefs!;

    // 1. Load History for active scope
    final historyKey = _historyKeyFor(_activeScope);
    final historyJson = prefs.getString(historyKey) ??
        // Fallback check on unscoped v2 for backwards compatibility
        (_activeScope == 'guest' ? prefs.getString(_historyKeyV2) : null);

    if (historyJson != null && historyJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(historyJson);
        _cachedHistory = decoded
            .map((e) => ScanHistory.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint("OfflineStorage: Error decoding history for scope $_activeScope: $e");
        _cachedHistory = [];
      }
    } else {
      _cachedHistory = [];
    }

    // 2. Load Last Notes for active scope
    final notesKey = _notesKeyFor(_activeScope);
    final lastNotesJson = prefs.getString(notesKey) ??
        (_activeScope == 'guest' ? prefs.getString(_lastNotesKeyV2) : null);

    if (lastNotesJson != null && lastNotesJson.isNotEmpty) {
      try {
        _cachedLastNotes = jsonDecode(lastNotesJson) as Map<String, dynamic>;
      } catch (e) {
        debugPrint("OfflineStorage: Error decoding last notes for scope $_activeScope: $e");
        _cachedLastNotes = null;
      }
    } else {
      _cachedLastNotes = null;
    }
  }

  // ---------------------------------------------------------------------------
  // History Operations (Scoped to Active User)
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
    final jsonString = jsonEncode(
      _cachedHistory.map((e) => e.toJson()).toList(),
    );
    await prefs.setString(_historyKeyFor(_activeScope), jsonString);
  }

  // ---------------------------------------------------------------------------
  // Last Notes Operations (Scoped to Active User)
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
    await prefs.setString(_notesKeyFor(_activeScope), jsonEncode(payload));
  }

  // ---------------------------------------------------------------------------
  // Clear Data (Delete-My-Data / Sign Out)
  // ---------------------------------------------------------------------------

  /// Clears data for a specific user ID or guest scope.
  static Future<void> clearUserData(String scope) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.remove(_historyKeyFor(scope));
    await prefs.remove(_notesKeyFor(scope));

    if (_activeScope == scope) {
      _cachedHistory.clear();
      _cachedLastNotes = null;
    }
  }

  /// Clears active user's local records from memory and disk.
  static Future<void> clearActiveUser() async {
    await clearUserData(_activeScope);
  }

  /// Wipes all cached histories, notes, and legacy data across all users on this device.
  static Future<void> clearAll() async {
    _cachedHistory.clear();
    _cachedLastNotes = null;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.remove(_historyKeyFor(_activeScope));
    await prefs.remove(_notesKeyFor(_activeScope));
    await prefs.remove(_historyKeyFor('guest'));
    await prefs.remove(_notesKeyFor('guest'));
    await prefs.remove(_historyKeyV2);
    await prefs.remove(_lastNotesKeyV2);
    await prefs.remove(_legacyHistoryKey);
  }
}
