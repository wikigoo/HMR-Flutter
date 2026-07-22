import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hmr_chatbot/l10n/app_strings.dart';
import 'package:hmr_chatbot/models/message_model.dart';
import 'package:hmr_chatbot/widgets/chat_bubble.dart';

/// The in-bubble controls (copy, report, retry) are small by design, so it is
/// easy to shrink their hit area below the point where they can be tapped
/// reliably. These pin the interactive size, not the glyph size — the icons are
/// deliberately still 15dp.
///
/// Regression guard: copy/report previously rendered a ~25x19dp target
/// (InkWell + symmetric(5, 2) padding, and InkWell enforces no minimum of its
/// own), and retry collapsed to ~30dp via Size.zero + shrinkWrap.
void main() {
  const double minTarget = 44;

  Widget host(Widget child) => Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(
          home: Scaffold(body: Center(child: child)),
        ),
      );

  testWidgets('AI copy and report targets are at least 44dp',
      (WidgetTester tester) async {
    await tester.pumpWidget(host(
      ChatBubble(
        message: MessageModel.aiMessage('پاسخ آزمایشی'),
        onCopy: () {},
        onReport: () {},
      ),
    ));
    await tester.pump();

    // Two icon controls: copy and report. Both are Semantics-labelled.
    for (final String label in <String>[AppStrings.copy, AppStrings.reportLabel]) {
      final Finder target = find.descendant(
        of: find.bySemanticsLabel(label),
        matching: find.byType(InkWell),
      );
      expect(target, findsOneWidget, reason: 'no InkWell for "$label"');

      final Size size = tester.getSize(target);
      expect(size.width, greaterThanOrEqualTo(minTarget),
          reason: '"$label" is only ${size.width}dp wide');
      expect(size.height, greaterThanOrEqualTo(minTarget),
          reason: '"$label" is only ${size.height}dp tall');
    }
  });

  testWidgets('retry target on a failed message is at least 44dp tall',
      (WidgetTester tester) async {
    await tester.pumpWidget(host(
      ChatBubble(
        message: MessageModel.aiMessage('خطا', isError: true),
        onCopy: () {},
        onRetry: () {},
      ),
    ));
    await tester.pump();

    final Finder retry = find.widgetWithText(TextButton, AppStrings.retry);
    expect(retry, findsOneWidget);
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(minTarget));
  });

  testWidgets('retry still fires its callback', (WidgetTester tester) async {
    int retried = 0;
    await tester.pumpWidget(host(
      ChatBubble(
        message: MessageModel.aiMessage('خطا', isError: true),
        onCopy: () {},
        onRetry: () => retried++,
      ),
    ));
    await tester.pump();

    await tester.tap(find.text(AppStrings.retry));
    await tester.pump();

    expect(retried, 1);
  });
}
