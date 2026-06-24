import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/message_model.dart';
import '../theme/app_theme.dart';
import 'hmr_avatar.dart';

/// One message row. AI bubbles sit on the leading edge with a glowing
/// HMR avatar and render Markdown; user bubbles sit on the trailing edge
/// with a neon-tinted glass fill. Long-press copies the text.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.onCopy,
    this.onRetry,
  });

  final MessageModel message;
  final VoidCallback onCopy;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return message.isAi ? _buildAi(context) : _buildUser(context);
  }

  Widget _buildAi(BuildContext context) {
    final double maxWidth = MediaQuery.of(context).size.width * 0.76;
    // Force LTR so the avatar stays physically on the left of the bubble,
    // regardless of the app's global RTL direction.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          const HmrAvatar(size: 30),
          const SizedBox(width: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: _GlassBubble(
                onCopy: onCopy,
                copyPayload: message.text,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                  bottomLeft: Radius.zero,
                ),
                fill: message.isError
                    ? const Color(0x33FF5470)
                    : AppTheme.bubbleAiFill,
                border: message.isError
                    ? const Color(0x66FF5470)
                    : AppTheme.bubbleAiBorder,
                child: _aiContent(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiContent(BuildContext context) {
    if (message.isError) return _errorContent();
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
        Align(
          alignment: Alignment.centerLeft,
          child: Text(message.timeLabel, style: AppTheme.timestampAi),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'تلاش مجدد',
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
    final double maxWidth = MediaQuery.of(context).size.width * 0.78;
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
              BoxShadow(color: AppTheme.glow, blurRadius: 20, offset: Offset(0, 4)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(message.text, textAlign: TextAlign.right, style: AppTheme.bodyUser),
        const SizedBox(height: 5),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(message.timeLabel, style: AppTheme.timestampUser),
        ),
      ],
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
