import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../models/message_model.dart';
import '../providers/chat_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/hmr_avatar.dart';
import '../widgets/hmr_background.dart';
import '../widgets/price_disclaimer.dart';

/// HMR Assistant — the single chat surface.
///
/// [embedded] is set when the chat is hosted inside the desktop [HomeShell]
/// (persistent sidebar + chat pane). In that mode it renders just its content
/// column — the shell already paints the background and provides the Scaffold —
/// and drops the mobile-only back button.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    this.embedded = false,
  });

  final String conversationId;
  final bool embedded;

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
        AppStrings.messageCopied,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTheme.fontFa, fontFamilyFallback: AppTheme.faFallback,
          color: AppTheme.textBody,
          fontSize: 12.5,
        ),
      ),
    );
  }

  static const String _supportEmail = 'wikigoo58@gmail.com';

  /// Report an AI answer (hallucination / inappropriate / wrong). Opens the
  /// user's email app pre-filled with the flagged response. Falls back to
  /// copying the support address if no mail client is available.
  Future<void> _report(String text) async {
    final String excerpt = text.length > 1000
        ? '${text.substring(0, 1000)}…'
        : text;
    const String subject = AppStrings.reportEmailSubject;
    final String body = '${AppStrings.reportEmailBody}«$excerpt»\n\n'
        '${AppStrings.reportEmailReasonPrompt}';
    final Uri mailto = Uri.parse(
      'mailto:$_supportEmail'
      '?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}',
    );

    bool opened = false;
    try {
      opened = await launchUrl(mailto, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      await Clipboard.setData(const ClipboardData(text: _supportEmail));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          _snack(AppStrings.noEmailApp(_supportEmail)),
        );
    }
  }

  SnackBar _snack(String message) {
    return SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xE00A1020),
      elevation: 0,
      duration: const Duration(milliseconds: 2600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppTheme.glowRing, width: 0.8),
      ),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: AppTheme.fontFa, fontFamilyFallback: AppTheme.faFallback,
          color: AppTheme.textBody,
          fontSize: 12.5,
        ),
      ),
    );
  }

  Future<void> _confirmClear() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => const ConfirmDialog(
        title: AppStrings.clearChatTitle,
        body: AppStrings.clearChatBody,
        confirmLabel: AppStrings.clearChatConfirm,
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
    final Widget content = Consumer<ChatProvider>(
      builder: (BuildContext context, ChatProvider chat, _) {
        final bool empty = chat.messages.isEmpty && !chat.isLoading;
        return Column(
          children: <Widget>[
            // In the desktop shell the sidebar already carries the brand, so the
            // empty/hero state stays chrome-free (matches the reference design);
            // the slim bar returns once a conversation is in progress.
            if (!widget.embedded || !empty)
              _AppBar(onClear: _confirmClear, showBack: !widget.embedded),
            if (empty)
              Expanded(
                child: widget.embedded
                    // Desktop: hero centred, footer links pinned to the bottom.
                    ? Column(
                        children: <Widget>[
                          Expanded(
                            child: _HeroLanding(
                              controller: _input,
                              focus: _focus,
                              onSend: () => _send(),
                              bottomInset: 0,
                              showFooter: false,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(bottom: 18 + safe.bottom),
                            child: const _FooterLinks(),
                          ),
                        ],
                      )
                    : _HeroLanding(
                        controller: _input,
                        focus: _focus,
                        onSend: () => _send(),
                        bottomInset: safe.bottom,
                      ),
              )
            else ...<Widget>[
              Expanded(child: _centered(_messageList())),
              _centered(
                _Composer(
                  controller: _input,
                  focus: _focus,
                  onSend: () => _send(),
                  bottomInset: safe.bottom,
                ),
              ),
            ],
          ],
        );
      },
    );

    // Embedded in the desktop shell: the shell owns the background + Scaffold.
    if (widget.embedded) {
      return SafeArea(bottom: false, child: content);
    }

    return Scaffold(
      backgroundColor: AppTheme.navy950,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: <Widget>[
          const HmrBackground(),
          SafeArea(bottom: false, child: content),
        ],
      ),
    );
  }

  static const double _kContentMaxWidth = 760;

  // Constrains chat content to a readable, centered column on wide screens
  // (desktop / web) while staying full-width on phones -- ChatGPT-style.
  Widget _centered(Widget child) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _kContentMaxWidth),
      child: child,
    ),
  );

  Widget _messageList() {
    return Consumer<ChatProvider>(
      builder: (BuildContext context, ChatProvider chat, _) {
        if (chat.messages.isEmpty && !chat.isLoading) {
          return _EmptyState(onPrompt: _send);
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
              onReport: m.isAi && !m.isError ? () => _report(m.text) : null,
            );
          },
        );
      },
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────

/// Five graphical category cards based on HMR's five product pillars.
/// Tapping a card sends a ready-made prompt to start the conversation.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPrompt});

  final void Function(String preset) onPrompt;

  static const List<_CategoryCard> _cards = <_CategoryCard>[
    _CategoryCard(
      icon: Icons.phone_android_rounded,
      gradient: <Color>[Color(0xFF00D4FF), Color(0xFF2F6BFF)],
      title: AppStrings.catNewPhoneTitle,
      prompt: AppStrings.catNewPhonePrompt,
    ),
    _CategoryCard(
      icon: Icons.recycling_rounded,
      gradient: <Color>[Color(0xFF34E0A1), Color(0xFF0EA5E9)],
      title: AppStrings.catUsedPhoneTitle,
      prompt: AppStrings.catUsedPhonePrompt,
    ),
    _CategoryCard(
      icon: Icons.build_rounded,
      gradient: <Color>[Color(0xFFF6B73C), Color(0xFFF97316)],
      title: AppStrings.catTroubleshootTitle,
      prompt: AppStrings.catTroubleshootPrompt,
    ),
    _CategoryCard(
      icon: Icons.school_rounded,
      gradient: <Color>[Color(0xFF6366F1), Color(0xFF8B5CF6)],
      title: AppStrings.catEducationTitle,
      prompt: AppStrings.catEducationPrompt,
    ),
    _CategoryCard(
      icon: Icons.headphones_rounded,
      gradient: <Color>[Color(0xFFEC4899), Color(0xFFF43F5E)],
      title: AppStrings.catAccessoriesTitle,
      prompt: AppStrings.catAccessoriesPrompt,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppTheme.glow,
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const HmrAvatar(size: 72),
            ),
            const SizedBox(height: 16),
            const Text('HMR', style: AppTheme.welcomeKicker),
            const SizedBox(height: 8),
            const Text(
              AppStrings.welcomeBody,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: AppTheme.welcomeBody,
            ),
            const SizedBox(height: 24),
            ..._cards.map(
              (_CategoryCard c) =>
                  _CategoryTile(card: c, onTap: () => onPrompt(c.prompt)),
            ),
            const SizedBox(height: 16),
            const PriceDisclaimer(compact: true),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard {
  const _CategoryCard({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.prompt,
  });

  final IconData icon;
  final List<Color> gradient;
  final String title;
  final String prompt;
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.card, required this.onTap});

  final _CategoryCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        label: card.title,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Color.fromARGB(
                  60,
                  (card.gradient[0].r * 255.0).round(),
                  (card.gradient[0].g * 255.0).round(),
                  (card.gradient[0].b * 255.0).round(),
                ),
                width: 0.8,
              ),
              color: Color.fromARGB(
                12,
                (card.gradient[0].r * 255.0).round(),
                (card.gradient[0].g * 255.0).round(),
                (card.gradient[0].b * 255.0).round(),
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: card.gradient,
                    ),
                  ),
                  child: Icon(card.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    card.title,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFa, fontFamilyFallback: AppTheme.faFallback,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_back_ios_new,
                  size: 14,
                  color: Color.fromARGB(
                    153,
                    (card.gradient[0].r * 255.0).round(),
                    (card.gradient[0].g * 255.0).round(),
                    (card.gradient[0].b * 255.0).round(),
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

// ── Private widgets ──────────────────────────────────────────────────────

/// Transparent top bar: back · brand identity · clear-history.
class _AppBar extends StatelessWidget {
  const _AppBar({required this.onClear, this.showBack = true});

  final VoidCallback onClear;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x12FFFFFF))),
      ),
      child: Row(
        children: <Widget>[
          if (showBack)
            _GhostIconButton(
              icon: Icons.arrow_back_ios_new,
              onTap: () => Navigator.maybePop(context),
              label: AppStrings.back,
            )
          else
            // Keep the brand visually centred against the clear button.
            const SizedBox(width: 40),
          const Expanded(child: _BrandIdentity()),
          _GhostIconButton(
            icon: Icons.delete_sweep_outlined,
            onTap: onClear,
            label: AppStrings.clearChatLabel,
          ),
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
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: AppTheme.online, blurRadius: 7),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                const Text(AppStrings.brandSubtitle, style: AppTheme.subtitle),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _GhostIconButton extends StatelessWidget {
  const _GhostIconButton({
    required this.icon,
    required this.onTap,
    required this.label,
  });

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

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

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
    this.hint = AppStrings.composerHint,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onSend;
  final double bottomInset;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final bool focused = focus.hasFocus;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 6, 16, 8 + bottomInset),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
            decoration: BoxDecoration(
              color: AppTheme.inputFill,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: focused ? AppTheme.cyan : AppTheme.inputBorder,
                width: focused ? 1.0 : 0.8,
              ),
              boxShadow: focused
                  ? const <BoxShadow>[
                      BoxShadow(
                        color: AppTheme.glowFocus,
                        blurRadius: 24,
                        spreadRadius: -2,
                      ),
                    ]
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
                    textAlign: TextAlign.start,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFa, fontFamilyFallback: AppTheme.faFallback,
                      fontSize: 14,
                      height: 1.6,
                      color: AppTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: InputBorder.none,
                      hintText: hint,
                      hintTextDirection: TextDirection.rtl,
                      hintStyle: const TextStyle(
                        fontFamily: AppTheme.fontFa, fontFamilyFallback: AppTheme.faFallback,
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
      label: AppStrings.sendMessage,
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.arrow_upward_rounded,
                  size: 24,
                  color: Colors.white,
                ),
        ),
      ),
    );
  }
}

/// Landing hero on an empty conversation: robot avatar, title, a large centered
/// ask box, and footer links — mirrors the hmrbot.com/ai landing design.
class _HeroLanding extends StatelessWidget {
  const _HeroLanding({
    required this.controller,
    required this.focus,
    required this.onSend,
    required this.bottomInset,
    this.showFooter = true,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onSend;
  final double bottomInset;

  /// On desktop the footer is pinned to the bottom of the pane instead, so the
  /// hero renders without its inline footer.
  final bool showFooter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 48, 20, 24 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const HmrAvatar(size: 100, glow: true),
              const SizedBox(height: 28),
              const Text(
                AppStrings.heroTitle,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: AppTheme.fontFa, fontFamilyFallback: AppTheme.faFallback,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  height: 1.6,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 32),
              _Composer(
                controller: controller,
                focus: focus,
                onSend: onSend,
                bottomInset: 0,
                hint: AppStrings.heroComposerHint,
              ),
              if (showFooter) ...<Widget>[
                const SizedBox(height: 24),
                const _FooterLinks(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Privacy / about / disclaimer footer links -> hmrbot.com pages.
class _FooterLinks extends StatelessWidget {
  const _FooterLinks();

  Future<void> _open(String path) async {
    await launchUrl(
      Uri.parse('https://hmrbot.com$path'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget link(String label, String path) =>
        _HoverLink(label: label, onTap: () => _open(path));
    const Widget sep = Text('  |  ', style: AppTheme.subtitle);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      textDirection: TextDirection.rtl,
      children: <Widget>[
        link(AppStrings.downloadApp, '/download'),
        sep,
        link(AppStrings.privacy, '/privacy'),
        sep,
        link(AppStrings.about, '/about'),
        sep,
        link(AppStrings.disclaimer, '/disclaimer'),
      ],
    );
  }
}

/// A footer link that brightens to the brand cyan and underlines on hover
/// (web/desktop), with a pointer cursor.
class _HoverLink extends StatefulWidget {
  const _HoverLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_HoverLink> createState() => _HoverLinkState();
}

class _HoverLinkState extends State<_HoverLink> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.label,
          style: AppTheme.subtitle.copyWith(
            color: _hovering ? AppTheme.cyan : null,
            decoration:
                _hovering ? TextDecoration.underline : TextDecoration.none,
            decorationColor: AppTheme.cyan,
          ),
        ),
      ),
    );
  }
}
