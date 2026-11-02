import '../data/storage/offline_storage.dart';
import '../models/scan_history.dart';

/// Legacy facade wrapping OfflineStorage for backward compatibility.
class HistoryStore {
  HistoryStore._();

  static Future<void> init() async {
    await OfflineStorage.init();
  }

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
