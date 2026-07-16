import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';

// Web-only, first-party mirror of a signed-in Google profile, restored from
// the `hmr_session` cookie via GET /api/auth/session (see _restoredProfile
// below). Google's own signInSilently()/FedCM restore is unreliable — it can
// fail for reasons outside this app's control (browser "third-party sign-in"
// setting, network/filtering, no active Google browser session) — so it
// cannot be the only way a returning user's sign-in survives a page reload.
class _RestoredProfile {
  _RestoredProfile({required this.sub, required this.email, required this.name, this.picture});
  final String sub;
  final String email;
  final String name;
  final String? picture;
}

class AuthProvider extends ChangeNotifier {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  GoogleSignInAccount? _user;
  _RestoredProfile? _restoredProfile;
  bool _isLoading = false;
  bool _initialized = false;
  // `_initialized` only flips at the END of init(), but init() awaits in the
  // middle. Both ConversationsScreen and HomeShell call `if (!initialized)
  // init()`, so without this re-entrancy guard a second caller can slip into
  // that async gap and run init() twice — subscribing twice to the stream below.
  bool _initializing = false;
  StreamSubscription<GoogleSignInAccount?>? _userChanges;
  String? _error;

  bool get isSignedIn => _user != null || _restoredProfile != null;
  bool get isGuest => !isSignedIn;
  bool get isLoading => _isLoading;
  bool get initialized => _initialized;
  GoogleSignInAccount? get user => _user;
  String? get error => _error;

  // Google `sub` used as the Flowise sessionId (null for guests) — the
  // sessionId-bearing counterpart of `userId` below, which is display-only.
  String? get uid => _user?.id ?? _restoredProfile?.sub;

  String get userId => uid ?? 'guest';

  String get displayName => _user?.displayName ?? _restoredProfile?.name ?? 'کاربر';
  String get email => _user?.email ?? _restoredProfile?.email ?? '';
  String? get photoUrl => _user?.photoUrl ?? _restoredProfile?.picture;

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
        if (account != null) {
          // A live GIS account is authoritative over a cookie-restored one,
          // and is the trigger to (re)establish our own first-party session.
          _restoredProfile = null;
          unawaited(_establishServerSession(account));
        }
        notifyListeners();
      });

      // Fast, reliable restore for a returning signed-in user: read our own
      // `hmr_session` cookie (minted by /api/auth/login on a prior sign-in)
      // via the same-origin hmrbot.com backend, instead of depending on
      // Google's signInSilently()/FedCM restore below — which can fail for
      // reasons entirely outside this app's control (a browser's "third-party
      // sign-in" setting, network/filtering, no active Google browser
      // session) and was the actual cause of users appearing signed-out on
      // every reload even after the FedCM-loop fix.
      await _restoreSessionFromCookie();
    }

    try {
      // signInSilently() defaults to `suppressErrors: true`, so any GIS/
      // FedCM failure (e.g. the browser rejecting the One Tap prompt with a
      // NetworkError because third-party sign-in prompts are blocked)
      // resolves to `null` instead of throwing. This call is a one-shot,
      // terminal attempt to restore a previous session — its result is never
      // retried and never triggers another init()/render cycle, so a
      // failing FedCM prompt cannot loop; the user just stays signed out
      // until they use the sign-in button again. On web this is now purely
      // opportunistic — `_restoredProfile` above already carries the
      // authoritative signed-in state when it succeeded.
      _user = await _googleSignIn.signInSilently();
      if (_user != null) _restoredProfile = null; // live account supersedes
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

  // GET /api/auth/session: resolves the `hmr_session` cookie server-side
  // (see HMR-Astro src/middleware.ts) and returns the profile it carries, if
  // any. Same-origin (the Flutter web build is served at hmrbot.com/ai), so
  // the cookie goes along automatically — no token handling here.
  Future<void> _restoreSessionFromCookie() async {
    try {
      final http.Response res =
          await http.get(Uri.base.resolve('/api/auth/session'));
      if (res.statusCode != 200) return;
      final Map<String, dynamic> body =
          jsonDecode(res.body) as Map<String, dynamic>;
      final Map<String, dynamic>? user = body['user'] as Map<String, dynamic>?;
      final String sub = (user?['sub'] as String?) ?? '';
      if (user == null || sub.isEmpty) return;
      _restoredProfile = _RestoredProfile(
        sub: sub,
        email: (user['email'] as String?) ?? '',
        name: (user['name'] as String?) ?? '',
        picture: user['picture'] as String?,
      );
    } catch (e, st) {
      // Never block startup on this — guest/live-GIS restore still apply.
      debugPrint('AuthProvider._restoreSessionFromCookie failed: $e');
      unawaited(Sentry.captureException(e, stackTrace: st));
    }
  }

  // POST /api/auth/login: exchanges the GIS ID token for our own first-party
  // `hmr_session` cookie, so the next page load can restore via
  // _restoreSessionFromCookie() above without needing Google's cooperation.
  Future<void> _establishServerSession(GoogleSignInAccount account) async {
    try {
      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;
      if (idToken == null) return;
      await http.post(
        Uri.base.resolve('/api/auth/login'),
        headers: <String, String>{'content-type': 'application/json'},
        body: jsonEncode(<String, String>{'credential': idToken}),
      );
    } catch (e, st) {
      // Non-fatal: the user is still signed in for this tab via the live
      // GIS account; only cross-reload persistence is affected.
      debugPrint('AuthProvider._establishServerSession failed: $e');
      unawaited(Sentry.captureException(e, stackTrace: st));
    }
  }

  Future<void> _clearServerSession() async {
    try {
      await http.post(Uri.base.resolve('/api/auth/logout'));
    } catch (_) {
      // Best-effort; the cookie will simply expire on its own (30-day TTL).
    }
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
    if (kIsWeb) await _clearServerSession();
    _user = null;
    _restoredProfile = null;
    _error = null;
    notifyListeners();
  }
}
