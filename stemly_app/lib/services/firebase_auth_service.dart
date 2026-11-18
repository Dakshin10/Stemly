import 'dart:async';
import 'dart:convert';

import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';

class FirebaseConfigurationException implements Exception {
  final String message;
  FirebaseConfigurationException(this.message);
  @override
  String toString() => message;
}

const String _tokenStorageKey = "stemly_id_token";
const String _profileStorageKey = "stemly_user_profile";
String get _apiBaseUrl => AppConfig.baseUrl;

class FirebaseAuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Google OAuth client ID for desktop/web authentication
  static const String _googleClientId =
      "75140432972-ua4tbeh27rbejd55q03htq91dt2ig1bd.apps.googleusercontent.com";

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ["email"],
    // Windows and Web require a specific clientId
    clientId: kIsWeb || Platform.isWindows ? _googleClientId : null,
  );
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  StreamSubscription<User?>? _authSubscription;
  SharedPreferences? _prefs;
  User? _user;
  String? _cachedIdToken;

  User? get currentUser => _user;

  bool get isAuthenticated => _user != null;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _user = _auth.currentUser;

    if (_user != null) {
      try {
        await _cacheAuthState(_user!);
      } catch (e) {
        debugPrint("Warning caching initial auth state: $e");
      }
    } else {
      _cachedIdToken = await _secureStorage.read(key: _tokenStorageKey);
    }

    _authSubscription = _auth.idTokenChanges().listen((user) async {
      _user = user;
      if (user != null) {
        try {
          await _cacheAuthState(user);
        } catch (e) {
          debugPrint("Warning caching auth state in listener: $e");
        }
      } else {
        _cachedIdToken = null;
        await _secureStorage.delete(key: _tokenStorageKey);
        await _prefs?.remove(_profileStorageKey);
      }
      notifyListeners();
    });
  }

  // ---------------------------------------------------------------------------
  // 🔵 GOOGLE SIGN-IN
  // ---------------------------------------------------------------------------
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw Exception(
          "Missing Google ID token.\n\n"
          "Fix this by checking:\n"
          "1. Firebase Android app package: com.example.stemly_app\n"
          "2. SHA-1 & SHA-256 added in Firebase Console\n"
          "3. google-services.json exists in android/app/\n"
          "4. Run: cd android && ./gradlew signingReport\n",
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      await _cacheAuthState(userCredential.user);
      await warmUpBackend();
      notifyListeners();

      return userCredential;
    } on FirebaseException catch (e) {
      debugPrint("Firebase Error: ${e.code} - ${e.message}");

      String msg = "Authentication failed. ";

      if (e.code == 'auth/network-request-failed') {
        msg += "Check your internet connection.";
      } else if (e.code.contains('developer') || e.code == '10') {
        msg +=
            "Google Sign-In configuration issue.\n\nFix:\n"
            "1. Run: flutterfire configure\n"
            "2. Add SHA-1 & SHA-256 in Firebase Console\n"
            "3. Download google-services.json\n"
            "4. flutter clean && flutter run";
      } else {
        msg += e.message ?? "Unknown error occurred.";
      }

      throw Exception(msg);
    } catch (error, stackTrace) {
      debugPrint("Google sign-in failed: $error");
      debugPrintStack(stackTrace: stackTrace);

      final err = error.toString();

      if (err.contains('ApiException: 10') || err.contains('DEVELOPER_ERROR')) {
        throw Exception(
          "Google Sign-In failed with ApiException: 10.\n\n"
          "This means Firebase is NOT configured properly.\n\n"
          "Fix steps:\n"
          "1. Firebase Console → Project Settings → Android App\n"
          "2. Ensure package: com.example.stemly_app\n"
          "3. Add SHA-1 & SHA-256\n"
          "4. Download google-services.json\n"
          "5. Run: flutterfire configure\n"
          "6. flutter clean && flutter run",
        );
      }

      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 🔵 EMAIL & PASSWORD AUTHENTICATION
  // ---------------------------------------------------------------------------
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _user = credential.user;
      await _cacheAuthState(credential.user);
      await warmUpBackend();
      notifyListeners();
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint("FirebaseAuthException signInWithEmail: ${e.code} - ${e.message}");
      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = "No account found with this email address.";
          break;
        case 'wrong-password':
        case 'invalid-credential':
          msg = "Incorrect password. Please verify and try again.";
          break;
        case 'invalid-email':
          msg = "Please enter a valid email address.";
          break;
        case 'user-disabled':
          msg = "This account has been disabled. Please contact support.";
          break;
        case 'too-many-requests':
          msg = "Too many failed attempts. Please try again later.";
          break;
        case 'network-request-failed':
          msg = "Network error. Please check your internet connection.";
          break;
        default:
          msg = e.message ?? "Authentication failed. Please try again.";
      }
      throw Exception(msg);
    } catch (error) {
      debugPrint("signInWithEmail unexpected error: $error");
      rethrow;
    }
  }

  Future<UserCredential> signUpWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user != null && displayName != null && displayName.trim().isNotEmpty) {
        await user.updateDisplayName(displayName.trim());
        await user.reload();
        _user = _auth.currentUser;
      } else {
        _user = user;
      }

      await _cacheAuthState(_user);
      await warmUpBackend();
      notifyListeners();
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint("FirebaseAuthException signUpWithEmail: ${e.code} - ${e.message}");
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = "An account already exists for this email address.";
          break;
        case 'invalid-email':
          msg = "Please enter a valid email address.";
          break;
        case 'weak-password':
          msg = "Password should be at least 6 characters.";
          break;
        case 'network-request-failed':
          msg = "Network error. Please check your internet connection.";
          break;
        default:
          msg = e.message ?? "Account creation failed. Please try again.";
      }
      throw Exception(msg);
    } catch (error) {
      debugPrint("signUpWithEmail unexpected error: $error");
      rethrow;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      debugPrint("FirebaseAuthException sendPasswordReset: ${e.code} - ${e.message}");
      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = "No account found with this email address.";
          break;
        case 'invalid-email':
          msg = "Please enter a valid email address.";
          break;
        default:
          msg = e.message ?? "Could not send password reset email.";
      }
      throw Exception(msg);
    }
  }

  // ---------------------------------------------------------------------------
  // 🔵 SIGN OUT
  // ---------------------------------------------------------------------------
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();

    await _secureStorage.delete(key: _tokenStorageKey);
    await _prefs?.remove(_profileStorageKey);

    _cachedIdToken = null;
    _user = null;

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // 🔵 BACKEND WARM-UP
  // ---------------------------------------------------------------------------
  Future<void> warmUpBackend() async {
    final token = await getIdToken();
    if (token == null) return;

    try {
      await http.get(
        Uri.parse("$_apiBaseUrl/auth/me"),
        headers: {"Authorization": "Bearer $token"},
      );
    } catch (e) {
      debugPrint("Backend warm-up failed: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // 🔵 AUTH HEADERS
  // ---------------------------------------------------------------------------
  Future<Map<String, String>> authenticatedHeaders({
    Map<String, String>? base,
  }) async {
    final token = await getIdToken();
    if (token == null) throw StateError("User is not authenticated.");

    final headers = <String, String>{};
    if (base != null) headers.addAll(base);

    headers["Authorization"] = "Bearer $token";
    headers["Content-Type"] = "application/json";

    return headers;
  }

  Future<http.Response> getWithAuth(String path) async {
    final headers = await authenticatedHeaders();
    return http.get(Uri.parse("$_apiBaseUrl$path"), headers: headers);
  }

  // ---------------------------------------------------------------------------
  // 🔵 TOKEN MANAGEMENT
  // ---------------------------------------------------------------------------
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (_user != null) {
      try {
        final token = await _user!.getIdToken(forceRefresh);
        if (token != null) {
          _cachedIdToken = token;
          await _secureStorage.write(key: _tokenStorageKey, value: token);
          return token;
        }
      } catch (e) {
        debugPrint("Warning retrieving fresh ID token: $e");
      }
    }

    _cachedIdToken ??= await _secureStorage.read(key: _tokenStorageKey);
    return _cachedIdToken;
  }

  // ---------------------------------------------------------------------------
  // 🔵 LOCAL PROFILE CACHING
  // ---------------------------------------------------------------------------
  Map<String, dynamic>? readCachedProfile() {
    final data = _prefs?.getString(_profileStorageKey);
    if (data == null) return null;

    return jsonDecode(data) as Map<String, dynamic>;
  }

  Future<void> _cacheAuthState(User? user) async {
    if (user == null) return;

    try {
      final token = await user.getIdToken();
      _cachedIdToken = token;

      if (token != null) {
        await _secureStorage.write(key: _tokenStorageKey, value: token);
      }
    } catch (e) {
      debugPrint("Warning fetching ID token during auth cache: $e");
      _cachedIdToken ??= await _secureStorage.read(key: _tokenStorageKey);
    }

    final payload = {
      "uid": user.uid,
      "name": user.displayName,
      "email": user.email,
      "photoUrl": user.photoURL,
    };

    await _prefs?.setString(_profileStorageKey, jsonEncode(payload));
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
