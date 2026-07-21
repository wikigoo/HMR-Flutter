import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_strings.dart';
import 'providers/auth_provider.dart';
import 'providers/conversations_provider.dart';
import 'repositories/chat_repository.dart';
import 'screens/home_shell.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  // SentryFlutter.init calls WidgetsFlutterBinding.ensureInitialized() internally.
  await SentryFlutter.init(
    (SentryFlutterOptions options) {
      // DSN injected at build time: --dart-define=SENTRY_DSN=<dsn>
      // Empty string → Sentry is a no-op (safe for debug builds without the define).
      options.dsn = const String.fromEnvironment('SENTRY_DSN');
      options.environment = kReleaseMode ? 'production' : 'development';
    },
    appRunner: () {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppTheme.navy950,
        systemNavigationBarIconBrightness: Brightness.light,
      ));

      if (kReleaseMode) {
        // Forward uncaught platform/async errors to Sentry.
        PlatformDispatcher.instance.onError =
            (Object error, StackTrace stack) {
          Sentry.captureException(error, stackTrace: stack);
          return true;
        };
        // Replace Flutter's red crash widget with a friendly Persian screen.
        ErrorWidget.builder =
            (FlutterErrorDetails _) => const _FriendlyErrorScreen();
      }

      runApp(const HmrApp());
    },
  );
}

class HmrApp extends StatelessWidget {
  const HmrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // App-scoped data-access seam. Shared by ChatProvider and
        // ConversationsProvider; owns the pooled HTTP client, closed on dispose.
        Provider<ChatRepository>(
          create: (_) => ChatRepository(),
          dispose: (_, ChatRepository repo) => repo.dispose(),
        ),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<ConversationsProvider>(
          create: (BuildContext context) =>
              ConversationsProvider(context.read<ChatRepository>()),
        ),
      ],
      child: MaterialApp(
        title: AppStrings.appTitle,
        debugShowCheckedModeBanner: false,
        theme: _theme,
        // Persian-only product (CLAUDE.md invariant #1); the app is not
        // actually translated into English, so only fa-IR is declared.
        locale: const Locale('fa', 'IR'),
        supportedLocales: const <Locale>[
          Locale('fa', 'IR'),
        ],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (BuildContext context, Widget? child) {
          // Full-bleed: the app fills the viewport width on web/desktop.
          // Each screen's own padding and max bubble widths keep content
          // readable; HmrBackground now spans the full width.
          return Directionality(
            textDirection: TextDirection.rtl,
            child: ColoredBox(
              color: AppTheme.navy950,
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        // Still no mandatory auth gate. [_FirstRun] shows the welcome panel
        // once, then hands over to HomeShell, which picks the mobile (list +
        // drawer) or desktop (persistent sidebar) layout by width; silent
        // sign-in + history load happen on first frame.
        home: const _FirstRun(),
      ),
    );
  }

  static final ThemeData _theme = ThemeData(
    useMaterial3: true,
    fontFamily: AppTheme.fontFa,
    fontFamilyFallback: AppTheme.faFallback,
    scaffoldBackgroundColor: AppTheme.navy950,
    colorScheme: const ColorScheme.dark(
      surface: AppTheme.navy950,
      primary: AppTheme.cyan,
      secondary: AppTheme.blue,
      onPrimary: AppTheme.navy950,
      onSurface: AppTheme.textPrimary,
    ),
    splashFactory: InkRipple.splashFactory,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppTheme.cyan,
      selectionColor: Color(0x4000D4FF),
      selectionHandleColor: AppTheme.cyan,
    ),
  );
}

/// Shown in release builds instead of Flutter's red crash widget.
/// Intentionally avoids Theme.of(context) and external packages so it
/// cannot itself crash.
class _FriendlyErrorScreen extends StatelessWidget {
  const _FriendlyErrorScreen();

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.rtl,
      child: ColoredBox(
        color: AppTheme.navy950,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFFF8597),
                  size: 48,
                ),
                SizedBox(height: 20),
                Text(
                  AppStrings.errorScreenTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFa,
    fontFamilyFallback: AppTheme.faFallback,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  AppStrings.errorScreenBody,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFa,
    fontFamilyFallback: AppTheme.faFallback,
                    fontSize: 14,
                    height: 1.7,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows [WelcomeScreen] on the very first launch, [HomeShell] every time after.
///
/// The flag lives in SharedPreferences next to the conversation index. While it
/// is being read the app renders nothing but the background, so the welcome
/// panel never flashes on top of an already-onboarded user's history.
class _FirstRun extends StatefulWidget {
  const _FirstRun();

  @override
  State<_FirstRun> createState() => _FirstRunState();
}

class _FirstRunState extends State<_FirstRun> {
  static const String _kSeenWelcome = 'seen_welcome';

  bool? _showWelcome;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _showWelcome = !(prefs.getBool(_kSeenWelcome) ?? false));
  }

  Future<void> _dismiss() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSeenWelcome, true);
    if (!mounted) return;
    setState(() => _showWelcome = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showWelcome == null) {
      return const ColoredBox(color: AppTheme.navy950, child: SizedBox.expand());
    }
    return _showWelcome! ? WelcomeScreen(onDone: _dismiss) : const HomeShell();
  }
}
