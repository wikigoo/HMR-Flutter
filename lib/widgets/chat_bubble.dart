import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../models/message_model.dart';
import '../theme/app_theme.dart';

/// One message row.
///
/// AI answers render as **plain prose** — no card, border, or avatar — so a
/// reply reads like a direct answer rather than a boxed chat message (mirrors
/// the hmrbot.com/ai design). Below the prose sit a left-aligned timestamp and,
/// on the opposite side, copy + report actions (no thumbs up/down). User
/// messages keep the neon-tinted glass bubble on the trailing edge.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.onCopy,
    this.onRetry,
    this.onReport,
  });

  final MessageModel message;
  final VoidCallback onCopy;
  final VoidCallback? onRetry;

  /// Report an AI answer (e.g. a wrong/inappropriate response). Non-null only
  /// for normal AI messages; required by Google Play's GenAI policy so users
  /// can flag hallucinations.
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    return message.isAi ? _buildAi(context) : _buildUser(context);
  }

  Widget _buildAi(BuildContext context) {
    final double maxWidth = (MediaQuery.of(context).size.width * 0.82)
        .clamp(240.0, 560.0)
        .toDouble();

    // Error answers keep a red-tinted container for distinction; normal answers
    // are plain text. Both sit on the leading (RTL → right) edge, no avatar.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: message.isError
            ? _GlassBubble(
                onCopy: onCopy,
                copyPayload: message.text,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                  bottomLeft: Radius.zero,
                ),
                fill: const Color(0x33FF5470),
                border: const Color(0x66FF5470),
                child: _errorContent(),
              )
            : _aiContent(context),
      ),
    );
  }

  Widget _aiContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Directionality(
          textDirection: TextDirection.rtl,
          child: MarkdownBody(
            data: message.text,
            selectable: false,
            styleSheet: AppTheme.markdown(context),
            onTapLink: (String text, String? href, String title) {
              if (href == null) return;
              final Uri? uri = Uri.tryParse(href);
              if (uri != null) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ),
        const SizedBox(height: 6),
        _AiActions(
          timeLabel: message.timeLabel,
          copyText: message.text,
          onReport: onReport,
        ),
      ],
    );
  }

  Widget _errorContent() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            message.text,
            style: const TextStyle(
              fontFamily: AppTheme.fontFa,
              fontSize: 14,
              height: 1.7,
              color: Color(0xFFFF8597),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0x1AFF5470),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0x66FF5470), width: 0.8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              AppStrings.retry,
              style: TextStyle(
                fontFamily: AppTheme.fontFa,
                fontSize: 13,
                color: Color(0xFFFF8597),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUser(BuildContext context) {
    final double maxWidth = (MediaQuery.of(context).size.width * 0.78)
        .clamp(240.0, 600.0)
        .toDouble();
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: _GlassBubble(
            onCopy: onCopy,
            copyPayload: message.text,
            gradient: AppTheme.userBubble,
            border: AppTheme.userBubbleBorder,
            glow: const <BoxShadow>[
              BoxShadow(
                color: AppTheme.glow,
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
              bottomRight: Radius.zero, // sharp tail points at the user
              bottomLeft: Radius.circular(22),
            ),
            child: _userContent(),
          ),
        ),
      ],
    );
  }

  Widget _userContent() {
    // start (RTL -> right) + min size so the bubble hugs its text instead of
    // stretching to the full max width (which turned short messages into bars).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          message.text,
          textAlign: TextAlign.right,
          style: AppTheme.bodyUser,
        ),
        const SizedBox(height: 5),
        Text(message.timeLabel, style: AppTheme.timestampUser),
      ],
    );
  }
}

// ── AI action row (timestamp + copy/report, with inline "کپی شد") ─────────

/// Timestamp on the leading side, copy + report on the trailing side. Copying
/// flashes an inline green "کپی شد" for ~1.5 s (local state + timer — not a
/// toast/portal), matching the web design.
class _AiActions extends StatefulWidget {
  const _AiActions({
    required this.timeLabel,
    required this.copyText,
    this.onReport,
  });

  final String timeLabel;
  final String copyText;
  final VoidCallback? onReport;

  @override
  State<_AiActions> createState() => _AiActionsState();
}

class _AiActionsState extends State<_AiActions> {
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _handleCopy() {
    Clipboard.setData(ClipboardData(text: widget.copyText));
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(widget.timeLabel, style: AppTheme.timestampAi),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedOpacity(
              opacity: _copied ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(
<<<<<<< HEAD
                  'کپی شد',
=======
                  AppStrings.copiedInline,
>>>>>>> main
                  style: TextStyle(
                    fontFamily: AppTheme.fontFa,
                    fontSize: 10,
                    color: Color(0xFF34E0A1),
                  ),
                ),
              ),
            ),
            _iconButton(
              icon: Icons.copy_rounded,
<<<<<<< HEAD
              label: 'کپی',
=======
              label: AppStrings.copy,
>>>>>>> main
              onTap: _handleCopy,
            ),
            if (widget.onReport != null) ...<Widget>[
              const SizedBox(width: 2),
              _iconButton(
                icon: Icons.outlined_flag,
<<<<<<< HEAD
                label: 'گزارش پاسخ نامناسب',
=======
                label: AppStrings.reportLabel,
>>>>>>> main
                onTap: widget.onReport,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _iconButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          child: Icon(icon, size: 15, color: const Color(0x80FFFFFF)),
        ),
      ),
    );
  }
}

// ── Frosted-glass bubble container ───────────────────────────────────────

/// Optimised message container. No BackdropFilter — a real blur per bubble
/// tanks the frame rate while the list scrolls on mid-range Android. Instead
/// a semi-transparent solid fill + soft border gives the glass read at a
/// fraction of the cost. The heavy blur stays only on the static composer
/// and app-bar chrome.
class _GlassBubble extends StatelessWidget {
  const _GlassBubble({
    required this.child,
    required this.borderRadius,
    required this.border,
    required this.onCopy,
    required this.copyPayload,
    this.fill,
    this.gradient,
    this.glow,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Color border;
  final Color? fill;
  final Gradient? gradient;
  final List<BoxShadow>? glow;
  final VoidCallback onCopy;
  final String copyPayload;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onCopy,
      child: Container(
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 9),
        decoration: BoxDecoration(
          color: gradient == null ? fill : null,
          gradient: gradient,
          borderRadius: borderRadius,
          border: Border.all(color: border, width: 0.8),
          boxShadow: glow,
        ),
        child: child,
      ),
    );
  }
}
