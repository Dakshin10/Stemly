import 'package:flutter/foundation.dart';

/// @deprecated
/// All AI inference has been migrated to the hardened STEMLY Backend layer.
/// Direct client-side API keys and third-party LLM calls have been removed for production security.
@Deprecated(
  "Use StemlyApiService or ApiClient instead. Client-side LLM calls have been removed.",
)
class GroqService extends ChangeNotifier {
  bool get isConfigured => true;
  String get provider => "STEMLY Cloud AI";
  String? get apiKey => null;

  Future<void> loadApiKey() async {}
  Future<String?> setApiKey(String key) async => null;
  Future<void> removeApiKey() async {}
}
