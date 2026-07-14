import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class AuthProvider extends ChangeNotifier {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  GoogleSignInAccount? _user;
  bool _isLoading = false;
  bool _initialized = false;
  // `_initialized` only flips at the END of init(), but init() awaits in the
  // middle. Both ConversationsScreen and HomeShell call `if (!initialized)
  // init()`, so without this re-entrancy guard a second caller can slip into
  // that async gap and run init() twice — subscribing twice to the stream below.
  bool _initializing = false;
  StreamSubscription<GoogleSignInAccount?>? _userChanges;
  String? _error;

  bool get isSignedIn => _user != null;
  bool get isGuest => !isSignedIn;
  bool get isLoading => _isLoading;
  bool get initialized => _initialized;
  GoogleSignInAccount? get user => _user;
  String? get error => _error;

  String get userId => _user?.id ?? 'guest';

  String get displayName => _user?.displayName ?? 'کاربر';
  String get email => _user?.email ?? '';
  String? get photoUrl => _user?.photoUrl;

  String get photoInitial {
    final String name = displayName.trim();
    return name.isEmpty ? '؟' : name[0];
  }

  Future<void> init() async {
    if (_initialized || _initializing) return;
    _initializing = true;
    _isLoading = true;
    notifyListeners();

    if (kIsWeb) {
      // On web, a successful sign-in through the GIS `renderButton` widget
      // (see lib/widgets/google_signin_web_button_web.dart) never returns
      // through a method call of ours — the plugin only reports it via this
      // stream. Subscribe once so the drawer reflects it. This is additive
      // and web-only: it does not change how Android resolves `_user` from
      // the direct signIn()/signInSilently() return values below.
      _userChanges ??= _googleSignIn.onCurrentUserChanged
          .listen((GoogleSignInAccount? account) {
        _user = account;
        notifyListeners();
      });
    }

    try {
      // signInSilently() defaults to `suppressErrors: true`, so any GIS/
      // FedCM failure (e.g. the browser rejecting the One Tap prompt with a
      // NetworkError because third-party sign-in prompts are blocked)
      // resolves to `null` instead of throwing. This call is a one-shot,
      // terminal attempt to restore a previous session — its result is never
      // retried and never triggers another init()/render cycle, so a
      // failing FedCM prompt cannot loop; the user just stays signed out
      // until they use the sign-in button again.
      _user = await _googleSignIn.signInSilently();
    } catch (e, st) {
      // Defensive only: suppressErrors already swallows the realistic
      // failure modes above. If something still slips through, fail
      // silently and terminally — never surface it to the user, never retry.
      _user = null;
      debugPrint('AuthProvider.init: signInSilently failed: $e');
      unawaited(Sentry.captureException(e, stackTrace: st));
    }
    _isLoading = false;
    _initialized = true;
    _initializing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _userChanges?.cancel();
    super.dispose();
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      // Note: on web this is deprecated by the plugin (it can only
      // synthesize a profile via the People API, with no idToken) — the web
      // UI uses the GIS renderButton widget instead and should not reach
      // this method. It remains the sign-in path for Android.
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      _user = account;
      // `signIn()` already converts a user-cancelled flow into a `null`
      // result (it catches PlatformException(kSignInCanceledError)
      // internally), so this branch is the correct place for that message.
      _error = account == null ? 'ورود لغو شد.' : null;
      _isLoading = false;
      notifyListeners();
      return account != null;
    } catch (e, st) {
      _isLoading = false;
      // Do not blame "the internet" for every failure — that masked the
      // real cause (a disabled People API) for a long time. Show a truthful
      // generic message and keep the real exception visible for debugging.
      _error = 'ورود با گوگل ناموفق بود. لطفاً دوباره تلاش کنید.';
      final String code = e is PlatformException ? e.code : e.runtimeType.toString();
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
