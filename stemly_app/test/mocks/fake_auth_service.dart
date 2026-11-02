import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:stemly_app/services/firebase_auth_service.dart';

class FakeAuthService extends ChangeNotifier implements FirebaseAuthService {
  final String _testToken = "fake-jwt-token";

  @override
  User? get currentUser => null;

  @override
  bool get isAuthenticated => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async => _testToken;

  @override
  Future<Map<String, String>> authenticatedHeaders({Map<String, String>? base}) async {
    final map = <String, String>{};
    if (base != null) map.addAll(base);
    map["Authorization"] = "Bearer $_testToken";
    return map;
  }

  @override
  Future<http.Response> getWithAuth(String path) async {
    return http.Response('{"status": "ok"}', 200);
  }

  @override
  Future<void> warmUpBackend() async {}

  @override
  Map<String, dynamic>? readCachedProfile() => {"name": "Test Student"};

  @override
  Future<UserCredential?> signInWithGoogle() async => null;

  @override
  Future<void> signOut() async {}
}
