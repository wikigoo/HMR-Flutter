import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'app_colors.g.dart';

/// HMR design tokens — dark neon-blue glassmorphism.
/// Every color is expressed as `Color(0xAARRGGBB)` (no `withOpacity`)
/// to stay Dart 3.x / lint compliant.
class AppTheme {
  AppTheme._();

  // ── Neon ramp (the brand's "light") — from HMR-Design tokens ──────
  static const Color cyan = HmrTokens.cyan;
  static const Color blue = HmrTokens.blue;
  static const Color indigo = HmrTokens.indigo;

  // ── Navy base / surfaces ─────────────────────────────────────────
  static const Color navy950 = HmrTokens.navy950;
  static const Color screenTop = Color(0xFF0C1733);
  static const Color screenMid = Color(0xFF080F24);
  static const Color screenBottom = Color(0xFF04060F);
  static const Color avatarTop = Color(0xFF142340);
  static const Color avatarBottom = Color(0xFF08101F);

  // ── Text ─────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textBody = Color(0xFFE2E8F0); // AI prose
  static const Color textSecondary = HmrTokens.muted; // subtitle / muted
  static const Color timeMuted = Color(0xFF7E8AA8); // AI timestamp
  static const Color timeOnUser = Color(0xFFBCD5F5); // user timestamp
  static const Color chipText = Color(0xFFDCEEFE);

  // ── Status ───────────────────────────────────────────────────────
  static const Color online = HmrTokens.success;
  static const Color amber = HmrTokens.amber;
  static const Color amberText = Color(0xFFE7CF9B);

  // ── Glass surfaces (backdrop-blur intended) ──────────────────────
  static const Color glassFill = Color(0x0FFFFFFF); // white @ ~6%
  static const Color glassBorder = Color(0x21FFFFFF); // white @ ~13%

  // ── Optimised bubble surfaces (NO backdrop-blur — solid fill) ────
  // A semi-transparent dark slate reads as glass over the ambient glow
  // without the per-frame BackdropFilter cost inside a scrolling ListView.
  static const Color bubbleAiFill = Color(0x8A1E293B); // slate @ ~54%
  static const Color bubbleAiBorder = Color(0x1FFFFFFF); // white @ ~12%
  static const Color avatarCore = Color(0xFF102030); // solid disc behind logo
  static const Color inputFill = Color(0x0DFFFFFF); // white @ ~5%
  static const Color inputBorder = Color(0x24FFFFFF); // white @ ~14%
  static const Color ghostBorder = Color(0x24FFFFFF);

  // ── Neon-tinted surfaces ─────────────────────────────────────────
  static const Color userBubbleStart = Color(0x472F6BFF); // blue @ 28%
  static const Color userBubbleEnd = Color(0x2100D4FF); // cyan @ 13%
  static const Color userBubbleBorder = Color(0x7300D4FF); // cyan @ 45%
  static const Color chipBorder = Color(0x5200D4FF); // cyan @ 32%
  static const Color chipFill = Color(0x1400D4FF); // cyan @ 8%
  static const Color disclaimerFill = Color(0x1AF6B73C); // amber @ 10%
  static const Color disclaimerBorder = Color(0x47F6B73C); // amber @ 28%

  // ── Auth / list screens ──────────────────────────────────────────
  static const Color googleFill = Color(0xFFFFFFFF);
  static const Color googleText = Color(0xFF1F2330);
  static const Color sidebarFill = Color(0xF20A1124); // near-opaque drawer
  static const Color rowDivider = Color(0x12FFFFFF);

  // ── Glow colors (for BoxShadow) ──────────────────────────────────
  static const Color glow = Color(0x6600D4FF); // cyan @ 40%
  static const Color glowFocus = Color(0x4D00D4FF); // cyan @ 30%
  static const Color glowRing = Color(0x7300D4FF); // cyan @ 45%

  // ── Gradients ────────────────────────────────────────────────────
  static const LinearGradient neon = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[cyan, blue],
  );

  static const RadialGradient background = RadialGradient(
    center: Alignment(0, -1),
    radius: 1.3,
    colors: <Color>[screenTop, screenMid, screenBottom],
    stops: <double>[0.0, 0.42, 1.0],
  );

  static const LinearGradient userBubble = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: <Color>[userBubbleStart, userBubbleEnd],
  );

  // ── Typography ───────────────────────────────────────────────────
  static const String fontFa = 'Vazirmatn';
  static const String fontLatin = 'SpaceGrotesk';

  static const TextStyle appTitle = TextStyle(
    fontFamily: fontLatin,
    fontWeight: FontWeight.w700,
    fontSize: 16.5,
    letterSpacing: 0.4,
    color: textPrimary,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: fontFa,
    fontSize: 11.5,
    color: textSecondary,
  );

  static const TextStyle bodyAi = TextStyle(
    fontFamily: fontFa,
    fontSize: 14,
    height: 1.8, // relaxed leading for long Persian responses
    color: textBody,
  );

  static const TextStyle bodyUser = TextStyle(
    fontFamily: fontFa,
    fontSize: 14,
    height: 1.7,
    color: textPrimary,
  );

  static const TextStyle chip = TextStyle(
    fontFamily: fontFa,
    fontSize: 12.5,
    color: chipText,
  );

  static const TextStyle timestampAi = TextStyle(
    fontFamily: fontFa,
    fontSize: 10,
    color: timeMuted,
  );

  static const TextStyle timestampUser = TextStyle(
    fontFamily: fontFa,
    fontSize: 10,
    color: timeOnUser,
  );

  static const TextStyle disclaimer = TextStyle(
    fontFamily: fontFa,
    fontSize: 11,
    height: 1.5,
    color: amberText,
  );

  // ── Empty-state / welcome ────────────────────────────────────────
  static const TextStyle welcomeBody = TextStyle(
    fontFamily: fontFa,
    fontSize: 15,
    height: 1.9,
    color: textBody,
  );

  static const TextStyle welcomeKicker = TextStyle(
    fontFamily: fontLatin,
    fontWeight: FontWeight.w700,
    fontSize: 19,
    letterSpacing: 0.4,
    color: textPrimary,
  );

  // ── Auth / login screen ──────────────────────────────────────────
  static const TextStyle display = TextStyle(
    fontFamily: fontLatin,
    fontWeight: FontWeight.w700,
    fontSize: 30,
    letterSpacing: 0.6,
    color: textPrimary,
  );

  static const TextStyle tagline = TextStyle(
    fontFamily: fontFa,
    fontSize: 14,
    height: 1.9,
    color: textBody,
  );

  // ── Conversations list ───────────────────────────────────────────
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: fontFa,
    fontSize: 12,
    letterSpacing: 0.3,
    fontWeight: FontWeight.w600,
    color: textSecondary,
  );

  static const TextStyle tileTitle = TextStyle(
    fontFamily: fontFa,
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle tilePreview = TextStyle(
    fontFamily: fontFa,
    fontSize: 12.5,
    height: 1.6,
    color: textSecondary,
  );

  static const TextStyle tileMeta = TextStyle(
    fontFamily: fontFa,
    fontSize: 10.5,
    color: timeMuted,
  );

  static const TextStyle ctaLabel = TextStyle(
    fontFamily: fontFa,
    fontSize: 14.5,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  // ── Reusable glow shadows ────────────────────────────────────────
  static const List<BoxShadow> ringGlow = <BoxShadow>[
    BoxShadow(color: glow, blurRadius: 14, spreadRadius: 0),
  ];

  static const List<BoxShadow> sendGlow = <BoxShadow>[
    BoxShadow(color: glow, blurRadius: 20, spreadRadius: 2, offset: Offset(0, 6)),
  ];

  /// flutter_markdown stylesheet tuned for the dark glass AI bubble.
  static MarkdownStyleSheet markdown(BuildContext context) {
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: bodyAi,
      strong: bodyAi.copyWith(color: textPrimary, fontWeight: FontWeight.w700),
      listBullet: bodyAi.copyWith(color: cyan),
      a: bodyAi.copyWith(color: cyan, decoration: TextDecoration.underline),
      code: bodyAi.copyWith(
        fontFamily: 'monospace',
        backgroundColor: glassFill,
        color: cyan,
      ),
      codeblockDecoration: BoxDecoration(
        color: glassFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: glassBorder, width: 0.8),
      ),
      blockquoteDecoration: const BoxDecoration(
        border: Border(left: BorderSide(color: cyan, width: 2)),
      ),
      textAlign: WrapAlignment.end,
      listBulletPadding: const EdgeInsets.only(right: 6),
    );
  }
}
