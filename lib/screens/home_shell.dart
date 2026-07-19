import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../l10n/app_strings.dart';
import '../models/conversation_model.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/conversations_provider.dart';
import '../repositories/chat_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/hmr_avatar.dart';
import '../widgets/hmr_background.dart';
import 'chat_screen.dart';
import 'conversations_screen.dart';

/// Responsive entry point.
///
/// - Narrow (phones): the original mobile flow — a conversations list with a
///   slide-in drawer, pushing [ChatScreen] as a route. Untouched.
/// - Wide (web / desktop, ≥ [_kWideBreakpoint]px): a ChatGPT-style two-pane
///   layout — a persistent right sidebar (brand · new chat · history · account)
///   next to the chat pane — matching the HMR-AI-Chat reference design.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const double _kWideBreakpoint = 900;
  static const Uuid _uuid = Uuid();

  /// The conversation currently shown in the desktop chat pane. Starts as a
  /// fresh client-side id (a pending "new chat"); it is only written to the
  /// conversations index once the user sends the first message.
  late String _activeId = _uuid.v4();

  /// Desktop sidebar visibility, toggled by the hamburger button.
  bool _sidebarOpen = true;

  void _toggleSidebar() => setState(() => _sidebarOpen = !_sidebarOpen);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final AuthProvider auth = context.read<AuthProvider>();
      if (!auth.initialized) auth.init();
      context.read<ConversationsProvider>().loadConversations();
    });
  }

  void _startNewChat() {
    setState(() => _activeId = _uuid.v4());
  }

  void _selectConversation(String id) {
    if (id == _activeId) return;
    setState(() => _activeId = id);
  }

  Future<void> _deleteConversation(String id) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (_) => const ConfirmDialog(
        title: AppStrings.deleteConversationTitle,
        body: AppStrings.deleteConversationBody,
        confirmLabel: AppStrings.delete,
      ),
    );
    if (!(ok ?? false) || !mounted) return;
    await context.read<ConversationsProvider>().deleteConversation(id);
    if (id == _activeId) _startNewChat();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;

    // Phones keep the original, battle-tested mobile experience.
    if (width < _kWideBreakpoint) {
      return const ConversationsScreen();
    }

    final double topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppTheme.navy950,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: <Widget>[
          const HmrBackground(),
          SafeArea(
            bottom: false,
            child: Row(
              // Stretch so the fixed-width sidebar (whose inner Column uses an
              // Expanded history list) gets a bounded full height.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // RTL: first child sits on the right — the sidebar.
                if (_sidebarOpen)
                  _DesktopSidebar(
                    activeId: _activeId,
                    onNewChat: _startNewChat,
                    onSelect: _selectConversation,
                    onDelete: _deleteConversation,
                    onToggle: _toggleSidebar,
                  ),
                Expanded(
                  child: ChangeNotifierProvider<ChatProvider>(
                    // Recreate the chat state whenever the active conversation
                    // changes so history + input reset cleanly.
                    key: ValueKey<String>(_activeId),
                    create: (_) {
                      final String id = _activeId;
                      final ConversationsProvider convs =
                          context.read<ConversationsProvider>();
                      // Phase 4: signed-in user's Google `sub` (null for guests)
                      // -> Flowise sessionId for cross-device chat continuity.
                      final String? uid = context.read<AuthProvider>().uid;
                      final ChatProvider p = ChatProvider(
                        conversationId: id,
                        userId: uid,
                        repository: context.read<ChatRepository>(),
                        onUpdate: (String title, String last) =>
                            convs.upsertConversation(
                          id,
                          title: title,
                          lastMessage: last,
                        ),
                      );
                      p.loadHistory();
                      return p;
                    },
                    child: ChatScreen(conversationId: _activeId, embedded: true),
                  ),
                ),
              ],
            ),
          ),
          // Floating hamburger to reopen the sidebar once it is collapsed.
          if (!_sidebarOpen)
            Positioned(
              top: topInset + 12,
              right: 16,
              child: _GlassHamburger(onTap: _toggleSidebar),
            ),
        ],
      ),
    );
  }
}

// ── Sidebar ─────────────────────────────────────────────────────────────────

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.activeId,
    required this.onNewChat,
    required this.onSelect,
    required this.onDelete,
    required this.onToggle,
  });

  final String activeId;
  final VoidCallback onNewChat;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDelete;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: AppTheme.sidebarFill,
        border: Border(left: BorderSide(color: AppTheme.rowDivider)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Brand + collapse (hamburger) button.
            Row(
              children: <Widget>[
                const HmrAvatar(size: 40),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('HMR', style: AppTheme.appTitle),
                      SizedBox(height: 2),
                      Text(AppStrings.brandSubtitle, style: AppTheme.subtitle),
                    ],
                  ),
                ),
                _GlassHamburger(
                  onTap: onToggle,
                  icon: Icons.menu_open_rounded,
                  label: AppStrings.closeSidebar,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _NewChatButton(onTap: onNewChat),
            const SizedBox(height: 16),
            const _SearchField(),
            const SizedBox(height: 18),
            const Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(right: 4, bottom: 8),
                child: Text(AppStrings.chatHistory, style: AppTheme.sectionLabel),
              ),
            ),
            Expanded(
              child: Consumer<ConversationsProvider>(
                builder: (_, ConversationsProvider convs, __) {
                  final List<ConversationModel> list = convs.filtered;
                  if (list.isEmpty) {
                    return const _EmptyHistory();
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (BuildContext context, int i) {
                      final ConversationModel c = list[i];
                      return _HistoryTile(
                        conv: c,
                        active: c.id == activeId,
                        onTap: () => onSelect(c.id),
                        onDelete: () => onDelete(c.id),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            const Divider(color: AppTheme.rowDivider, height: 1),
            const SizedBox(height: 12),
            const _SidebarAccount(),
          ],
        ),
      ),
    );
  }
}

/// Full-width neon "new chat" button.
class _NewChatButton extends StatelessWidget {
  const _NewChatButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.newChat,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppTheme.neon,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.sendGlow,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.add_rounded, size: 20, color: Colors.white),
              SizedBox(width: 8),
              Text(
                AppStrings.newChat,
                style: TextStyle(
                  fontFamily: AppTheme.fontFa,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slim glass search box wired to [ConversationsProvider.search].
class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.inputBorder, width: 0.8),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.search_rounded, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              textDirection: TextDirection.rtl,
              onChanged: (String q) =>
                  context.read<ConversationsProvider>().search(q),
              style: const TextStyle(
                fontFamily: AppTheme.fontFa,
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: AppStrings.searchHint,
                hintTextDirection: TextDirection.rtl,
                hintStyle: TextStyle(
                  fontFamily: AppTheme.fontFa,
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One history row in the sidebar; highlighted when it is the open chat.
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.conv,
    required this.active,
    required this.onTap,
    required this.onDelete,
  });

  final ConversationModel conv;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: active ? AppTheme.chipFill : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppTheme.chipBorder : Colors.transparent,
            width: 0.8,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.forum_outlined,
              size: 18,
              color: active ? AppTheme.cyan : AppTheme.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                conv.title,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.fontFa,
                  fontSize: 13.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? AppTheme.textPrimary : AppTheme.textBody,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Semantics(
              button: true,
              label: AppStrings.deleteConversationTitle,
              child: GestureDetector(
                onTap: onDelete,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: Color(0x80FF8597),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 8, right: 4),
      child: Align(
        alignment: Alignment.topRight,
        child: Text(
          AppStrings.emptyHistorySidebar,
          textAlign: TextAlign.right,
          style: AppTheme.tilePreview,
        ),
      ),
    );
  }
}

/// Bottom-of-sidebar account block: guest → Google CTA, signed-in → profile.
class _SidebarAccount extends StatelessWidget {
  const _SidebarAccount();

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();

    if (auth.isSignedIn) {
      return Row(
        children: <Widget>[
          _Avatar(auth: auth),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  auth.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.tileTitle,
                ),
                const SizedBox(height: 2),
                Text(
                  auth.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.tileMeta,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Semantics(
            button: true,
            label: AppStrings.signOut,
            child: GestureDetector(
              onTap: () => context.read<AuthProvider>().signOut(),
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.logout_rounded, size: 18, color: AppTheme.textSecondary),
              ),
            ),
          ),
        ],
      );
    }

    // Guest → Google sign-in CTA.
    return GestureDetector(
      onTap: auth.isLoading
          ? null
          : () => context.read<AuthProvider>().signInWithGoogle(),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.glassFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.chipBorder, width: 0.8),
        ),
        child: auth.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: AppTheme.cyan),
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.login_rounded, size: 18, color: AppTheme.cyan),
                  SizedBox(width: 8),
                  Text(
                    AppStrings.signInWithGoogle,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFa,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.auth});

  final AuthProvider auth;

  @override
  Widget build(BuildContext context) {
    if (auth.photoUrl != null) {
      return Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppTheme.neon,
          boxShadow: AppTheme.ringGlow,
        ),
        child: ClipOval(
          child: Image.network(
            auth.photoUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _initial(),
          ),
        ),
      );
    }
    return _initial();
  }

  Widget _initial() {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.neon,
        boxShadow: AppTheme.ringGlow,
      ),
      child: Text(
        auth.photoInitial,
        style: const TextStyle(
          fontFamily: AppTheme.fontFa,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Circular glass icon button — the sidebar collapse control and the floating
/// button that reopens the sidebar.
class _GlassHamburger extends StatelessWidget {
  const _GlassHamburger({
    required this.onTap,
    this.icon = Icons.menu_rounded,
    this.label = AppStrings.sidebar,
  });

  final VoidCallback onTap;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.inputFill,
            border: Border.all(color: AppTheme.ghostBorder, width: 0.8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFFD6D6F2)),
        ),
      ),
    );
  }
}
