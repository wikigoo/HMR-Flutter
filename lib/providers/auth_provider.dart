import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../l10n/app_strings.dart';

class AuthProvider extends ChangeNotifier {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  GoogleSignInAccount? _user;
  bool _isLoading = false;
  bool _initialized = false;
  // `_initialized` only flips at the END of init(), but init() awaits in the
  // middle. Both ConversationsScreen and HomeShell call `if (!initialized)
  // init()`, so without this re-entrancy guard a second caller can slip into
  // that async gap and run init() twice.
  bool _initializing = false;
  String? _error;

  bool get isSignedIn => _user != null;
  bool get isGuest => !isSignedIn;
  bool get isLoading => _isLoading;
  bool get initialized => _initialized;
  GoogleSignInAccount? get user => _user;
  String? get error => _error;

  // Google `sub` used as the Flowise sessionId (null for guests) — the
  // sessionId-bearing counterpart of `userId` below, which is display-only.
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
      // 7.2.0: Singleton instance must be initialized once before any other calls.
      await _googleSignIn.initialize();

      // attemptLightweightAuthentication() replaces signInSilently() in 7.2.0.
      // It handles FedCM/One Tap prompts with minimal interaction.
      _user = await _googleSignIn.attemptLightweightAuthentication();
    } catch (e, st) {
      // Defensive only: fail silently and terminally — never surface it to the user.
      _user = null;
      debugPrint('AuthProvider.init: initialization failed: $e');
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
      // authenticate() replaces signIn() in 7.2.0 for interactive flows.
      final GoogleSignInAccount account = await _googleSignIn.authenticate();
      _user = account;
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      _isLoading = false;
      // GIS 7.2.0 throws GoogleSignInException for cancellation or failures.
      final bool isCancel = e is GoogleSignInException &&
          e.code == GoogleSignInExceptionCode.canceled;
      _error = isCancel ? AppStrings.signInCancelled : AppStrings.signInFailed;
      
      final String code = e is GoogleSignInException ? e.code.name : e.runtimeType.toString();
      debugPrint('AuthProvider.signInWithGoogle failed ($code): $e');
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
