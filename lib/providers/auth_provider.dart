import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider extends ChangeNotifier {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  GoogleSignInAccount? _user;
  bool _isLoading = false;
  bool _initialized = false;
  String? _error;

  bool get isSignedIn => _user != null;
  bool get isGuest => !isSignedIn;
  bool get isLoading => _isLoading;
  bool get initialized => _initialized;
  GoogleSignInAccount? get user => _user;
  String? get error => _error;

  String get displayName => _user?.displayName ?? 'کاربر';
  String get email => _user?.email ?? '';
  String? get photoUrl => _user?.photoUrl;

  String get photoInitial {
    final String name = displayName.trim();
    return name.isEmpty ? '؟' : name[0];
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _googleSignIn.signInSilently();
    } catch (_) {
      _user = null;
    }
    _isLoading = false;
    _initialized = true;
    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      _user = account;
      _error = account == null ? 'ورود لغو شد.' : null;
      _isLoading = false;
      notifyListeners();
      return account != null;
    } catch (e) {
      _isLoading = false;
      _error = 'ورود ناموفق بود. مطمئن شوید Firebase تنظیم شده است.';
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
