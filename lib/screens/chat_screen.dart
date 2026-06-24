import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/message_model.dart';
import '../providers/chat_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/hmr_avatar.dart';
import '../widgets/hmr_background.dart';
import '../widgets/price_disclaimer.dart';

/// HMR Assistant — the single chat surface.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final ChatProvider chat = context.read<ChatProvider>();
    final String text = preset ?? _input.text;
    if (text.trim().isEmpty || chat.isLoading) return;
    chat.sendMessage(text);
    _input.clear();
    _scrollToEnd();
  }

  void _scrollToEnd() {
    // List is `reverse: true`, so the newest message lives at offset 0.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    });
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(_copySnackBar());
  }

  SnackBar _copySnackBar() {
    return SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xE00A1020),
      elevation: 0,
      duration: const Duration(milliseconds: 1600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: AppTheme.glowRing, width: 0.8),
      ),
      content: const Text(
        'پیام کپی شد',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: AppTheme.fontFa, color: AppTheme.textBody, fontSize: 12.5),
      ),
    );
  }

  Future<void> _confirmClear() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => const ConfirmDialog(
        title: 'پاک‌کردن گفت‌وگو',
        body: 'همهٔ پیام‌های این گفت‌وگو حذف می‌شوند. این کار قابل بازگشت نیست.',
        confirmLabel: 'پاک کن',
      ),
    );
    if (ok ?? false) {
      if (!mounted) return;
      context.read<ChatProvider>().clearHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.of(context).padding;
    return Scaffold(
      backgroundColor: AppTheme.navy950,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: <Widget>[
          const HmrBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: <Widget>[
                _AppBar(onClear: _confirmClear),
                Expanded(child: _messageList()),
                const PriceDisclaimer(),
                _Composer(
                  controller: _input,
                  focus: _focus,
                  onSend: () => _send(),
                  bottomInset: safe.bottom,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageList() {
    return Consumer<ChatProvider>(
      builder: (BuildContext context, ChatProvider chat, _) {
        if (chat.messages.isEmpty && !chat.isLoading) {
          return const _EmptyState();
        }
        final List<MessageModel> messages = chat.messages;
        final int typing = chat.isLoading ? 1 : 0;
        // `reverse: true` keeps the newest message pinned to the bottom and
        // makes the keyboard push the conversation up naturally.
        return ListView.separated(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          itemCount: messages.length + typing,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (BuildContext context, int i) {
            if (typing == 1 && i == 0) return const _TypingDots();
            final MessageModel m = messages[messages.length - 1 - (i - typing)];
            return ChatBubble(
              message: m,
              onCopy: () => _copy(m.text),
              onRetry: m.isError
                  ? () => context.read<ChatProvider>().retryLastMessage()
                  : null,
            );
          },
        );
      },
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────

/// Centered welcome shown when there are no messages.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(color: AppTheme.glow, blurRadius: 36, spreadRadius: 2),
                ],
              ),
              child: const HmrAvatar(size: 76),
            ),
            const SizedBox(height: 20),
            const Text('HMR', style: AppTheme.welcomeKicker),
            const SizedBox(height: 12),
            const Text(
              'من همر هستم، مشاور هوشمند سخت‌افزار شما. چه کمکی از دستم برمی‌آید؟',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: AppTheme.welcomeBody,
            ),
            const SizedBox(height: 24),
            const PriceDisclaimer(),
          ],
        ),
      ),
    );
  }
}

// ── Private widgets ──────────────────────────────────────────────────────

/// Transparent top bar: back · brand identity · clear-history.
class _AppBar extends StatelessWidget {
  const _AppBar({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x12FFFFFF))),
      ),
      child: Row(
        children: <Widget>[
          _GhostIconButton(
            icon: Icons.arrow_back_ios_new,
            onTap: () => Navigator.maybePop(context),
            label: 'بازگشت',
          ),
          const Expanded(child: _BrandIdentity()),
          _GhostIconButton(icon: Icons.delete_sweep_outlined, onTap: onClear, label: 'پاک کردن گفتگو'),
        ],
      ),
    );
  }
}

class _BrandIdentity extends StatelessWidget {
  const _BrandIdentity();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const HmrAvatar(size: 38),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('HMR', style: AppTheme.appTitle),
            const SizedBox(height: 2),
            Row(
              children: <Widget>[
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.online,
                    boxShadow: <BoxShadow>[BoxShadow(color: AppTheme.online, blurRadius: 7)],
                  ),
                ),
                const SizedBox(width: 5),
                const Text('مشاور هوشمند موبایل', style: AppTheme.subtitle),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _GhostIconButton extends StatelessWidget {
  const _GhostIconButton({required this.icon, required this.onTap, required this.label});

  final IconData icon;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.inputFill,
                border: Border.all(color: AppTheme.ghostBorder, width: 0.8),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFFD6D6F2)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three pulsing neon dots inside a glass bubble (assistant is thinking).
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // LTR so the avatar is always on the physical left, matching AI bubbles.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          const HmrAvatar(size: 30),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.bubbleAiFill,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
                bottomRight: Radius.circular(22),
                bottomLeft: Radius.zero,
              ),
              border: Border.all(color: AppTheme.bubbleAiBorder, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List<Widget>.generate(3, (int i) => _dot(i)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(int index) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, _) {
        final double t = (_c.value - index * 0.18) % 1.0;
        final double lift = t < 0.5 ? (1 - (t * 4 - 1).abs()) : 0;
        return Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 5),
          child: Transform.translate(
            offset: Offset(0, -4 * lift),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(const Color(0x7300D4FF), AppTheme.cyan, lift),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bottom glass input bar with neon-on-focus border + glowing send button.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focus,
    required this.onSend,
    required this.bottomInset,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onSend;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final bool focused = focus.hasFocus;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 6, 16, 8 + bottomInset),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.fromLTRB(7, 7, 8, 7),
            decoration: BoxDecoration(
              color: AppTheme.inputFill,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: focused ? AppTheme.cyan : AppTheme.inputBorder,
                width: focused ? 1.2 : 0.8,
              ),
              boxShadow: focused
                  ? const <BoxShadow>[BoxShadow(color: AppTheme.glowFocus, blurRadius: 18)]
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focus,
                    minLines: 1,
                    maxLines: 4,
                    textDirection: TextDirection.rtl,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFa,
                      fontSize: 14,
                      height: 1.6,
                      color: AppTheme.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: InputBorder.none,
                      hintText: 'پیام خود را بنویسید…',
                      hintTextDirection: TextDirection.rtl,
                      hintStyle: TextStyle(
                        fontFamily: AppTheme.fontFa,
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _SendButton(onSend: onSend),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onSend});

  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final bool loading = context.watch<ChatProvider>().isLoading;
    return Semantics(
      button: true,
      label: 'ارسال پیام',
      enabled: !loading,
      child: GestureDetector(
        onTap: loading ? null : onSend,
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.neon,
            boxShadow: AppTheme.sendGlow,
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                )
              : const Icon(Icons.arrow_upward_rounded, size: 24, color: Colors.white),
        ),
      ),
    );
  }
}

