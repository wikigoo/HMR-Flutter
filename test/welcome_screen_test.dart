import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:hmr_chatbot/l10n/app_strings.dart';
import 'package:hmr_chatbot/providers/auth_provider.dart';
import 'package:hmr_chatbot/screens/welcome_screen.dart';

/// The welcome panel is the app's first frame, so a layout error here is a
/// launch-blocking crash. These pump it at a small phone size to catch overflow.
void main() {
  Widget host(VoidCallback onDone) => ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: MaterialApp(home: WelcomeScreen(onDone: onDone)),
        ),
      );

  testWidgets('renders both paths without layout errors', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(() {}));
    await tester.pump();

    expect(find.text(AppStrings.signInWithGoogle), findsOneWidget);
    expect(find.text(AppStrings.continueAsGuest), findsOneWidget);
    expect(find.text(AppStrings.welcomeTerms), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest button calls onDone — login is never a dead end',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    int done = 0;
    await tester.pumpWidget(host(() => done++));
    await tester.pump();

    await tester.tap(find.text(AppStrings.continueAsGuest));
    await tester.pump();

    expect(done, 1);
  });
}
