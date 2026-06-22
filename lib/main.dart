import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/conversations_provider.dart';
import 'screens/conversations_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppTheme.navy950,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const HmrApp());
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
