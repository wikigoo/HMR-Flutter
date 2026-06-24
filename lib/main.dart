import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'providers/auth_provider.dart';
import 'providers/conversations_provider.dart';
import 'screens/conversations_screen.dart';
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
      providers: <ChangeNotifierProvider<dynamic>>[
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<ConversationsProvider>(
            create: (_) => ConversationsProvider()),
      ],
      child: MaterialApp(
        title: 'همر | HMR',
        debugShowCheckedModeBanner: false,
        theme: _theme,
        supportedLocales: const <Locale>[
          Locale('fa', 'IR'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (BuildContext context, Widget? child) {
          // On desktop/web wide screens, constrain the UI to a max-width
          // column centered on a solid navy background. The glow blobs
          // (HmrBackground) are inside each screen's Stack, so they are
          // naturally clipped to the 900 px column along with the content.
          return Directionality(
            textDirection: TextDirection.rtl,
            child: ColoredBox(
              color: AppTheme.navy950,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          );
        },
        // Launch directly — no mandatory auth gate.
        // Silent sign-in happens inside ConversationsScreen.initState().
        home: const ConversationsScreen(),
      ),
    );
  }

  static final ThemeData _theme = ThemeData(
    useMaterial3: true,
    fontFamily: AppTheme.fontFa,
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
                  'خطایی رخ داد',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFa,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'لطفاً برنامه را مجدداً باز کنید.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFa,
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
