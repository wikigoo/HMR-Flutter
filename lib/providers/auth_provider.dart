import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../l10n/app_strings.dart';

class AuthProvider extends ChangeNotifier {
  /// The **web** OAuth client (project `hmrbot-app` / 326113602877). This is the
  /// only client id the app hard-codes: the Android client is never named here —
  /// it is matched by Google from `com.hmrbot` + the signing SHA-1, and shipped
  /// in `android/app/google-services.json` (gitignored).
  static const String _webClientId =
      '326113602877-emaibubf14sht9oij805s31m3eecoifu.apps.googleusercontent.com';

  // google_sign_in v7+ is a singleton: `initialize()` must be awaited exactly
  // once before any other member is used. `init()` below guards that via
  // `_initialized`/`_initializing`, relying on AuthProvider itself being a
  // singleton (see the single ChangeNotifierProvider<AuthProvider> in main.dart).
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  GoogleSignInAccount? _user;
  bool _isLoading = false;
  bool _initialized = false;
  bool _initializing = false;
  String? _error;

  bool get isSignedIn => _user != null;
  bool get isGuest => !isSignedIn;
  bool get isLoading => _isLoading;
  bool get initialized => _initialized;
  GoogleSignInAccount? get user => _user;
  String? get error => _error;

  String? get uid => _user?.id;
  String get userId => uid ?? 'guest';
  String get displayName => _user?.displayName ?? AppStrings.defaultUserName;
  String get email => _user?.email ?? '';
  String? get photoUrl => _user?.photoUrl;

  String get photoInitial {
    final String name = displayName.trim();
    return name.isEmpty ? AppStrings.unknownInitial : name[0];
  }

  Future<void> init() async {
    if (_initialized || _initializing) return;
    _initializing = true;
    _isLoading = true;
    notifyListeners();

    try {
      // Web must be given the *web* OAuth client id explicitly. Android must
      // NOT be given a clientId at all — the plugin resolves the Android
      // OAuth client from the package name (`com.hmrbot`) + the signing
      // SHA-1 registered in Google Cloud, and passing one here makes sign-in
      // fail with ApiException 10 (DEVELOPER_ERROR). `serverClientId` is the
      // *web* client on Android; it is what an ID token would be minted for,
      // and is unsupported on web.
      await _googleSignIn.initialize(
        clientId: kIsWeb ? _webClientId : null,
        serverClientId: kIsWeb ? null : _webClientId,
      );
      _user = await _googleSignIn.attemptLightweightAuthentication();
    } catch (e, st) {
      _user = null;
      debugPrint('AuthProvider.init: sign-in restore failed: $e');
      unawaited(Sentry.captureException(e, stackTrace: st));
    }
    _isLoading = false;
    _initialized = true;
    _initializing = false;
    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final GoogleSignInAccount account = await _googleSignIn.authenticate();
      _user = account;
      _isLoading = false;
      notifyListeners();
      return true;
    } on GoogleSignInException catch (e, st) {
      _isLoading = false;
      if (e.code == GoogleSignInExceptionCode.canceled) {
        _error = AppStrings.signInCancelled;
      } else {
        _error = AppStrings.signInFailed;
        unawaited(Sentry.captureException(e, stackTrace: st));
      }
      debugPrint('AuthProvider.signInWithGoogle failed (${e.code}): $e');
      notifyListeners();
      return false;
    } catch (e, st) {
      _isLoading = false;
      _error = AppStrings.signInFailed;
      debugPrint('AuthProvider.signInWithGoogle failed: $e');
      unawaited(Sentry.captureException(e, stackTrace: st));
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    _user = null;
    _error = null;
    notifyListeners();
  }
}
