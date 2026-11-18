import '../data/storage/offline_storage.dart';
import '../models/scan_history.dart';

/// Legacy facade wrapping OfflineStorage for backward compatibility and multi-tenant scoping.
class HistoryStore {
  HistoryStore._();

  static Future<void> init({String? userUid}) async {
    await OfflineStorage.init(userUid: userUid);
  }

  static Future<void> switchUser(String? newUid) async {
    await OfflineStorage.switchUser(newUid);
  }

  static void flushMemory() {
    OfflineStorage.flushMemory();
  }

  static String get activeScope => OfflineStorage.activeScope;

  static Future<void> add(ScanHistory scan) async {
    await OfflineStorage.addHistory(scan);
  }

  static Future<void> remove(ScanHistory scan) async {
    await OfflineStorage.removeHistory(scan);
  }

  static Future<void> update() async {
    await OfflineStorage.updateHistory();
  }

  static void setHistory(List<ScanHistory> list) {
    OfflineStorage.setHistory(list);
  }

  static List<ScanHistory> get history => OfflineStorage.history;
}
