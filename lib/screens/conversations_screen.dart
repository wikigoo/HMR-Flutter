import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../models/conversation_model.dart';
import '../providers/auth_provider.dart';
import '../utils/jalali.dart';
import '../providers/chat_provider.dart';
import '../providers/conversations_provider.dart';
import '../repositories/chat_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/hmr_avatar.dart';
import '../widgets/hmr_background.dart';
import 'chat_screen.dart';

/// History home: a glass list of past chat sessions with a slide-in
/// sidebar (account state, About, Privacy). New-chat FAB opens the chat.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final AuthProvider auth = context.read<AuthProvider>();
      if (!auth.initialized) auth.init();
      context.read<ConversationsProvider>().loadConversations();
    });
  }

  Future<void> _openConversation(ConversationModel conv) async {
    final ConversationsProvider convs = context.read<ConversationsProvider>();
    final ChatRepository repo = context.read<ChatRepository>();
    // Phase 4: capture the signed-in user's Google `sub` (null for guests) to
    // use as the Flowise sessionId for cross-device chat continuity.
    final String? uid = context.read<AuthProvider>().uid;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<ChatProvider>(
          create: (_) {
            final ChatProvider p = ChatProvider(
              conversationId: conv.id,
              userId: uid,
              repository: repo,
              onUpdate: (String title, String last) => convs.updateConversation(
                conv.id,
                title: title,
                lastMessage: last,
              ),
            );
            p.loadHistory();
            return p;
          },
          child: ChatScreen(conversationId: conv.id),
        ),
      ),
    );
    if (!mounted) return;
    // Ghost-conversation cleanup goes through the repository, not the DB
    // singleton — the UI no longer talks to persistence directly.
    final bool hasMessages = await repo.hasMessages(conv.id);
    if (!mounted) return;
    if (hasMessages) {
      await convs.loadConversations();
    } else {
      // User backed out without sending anything — silently remove the ghost.
      await convs.deleteConversation(conv.id);
    }
  }

  Future<void> _newConversation() async {
    final ConversationsProvider convs = context.read<ConversationsProvider>();
    final ConversationModel conv = await convs.createConversation();
    if (!mounted) return;
    await _openConversation(conv);
  }

  @override
  Widget build(BuildContext context) {
    final double bottomSafe = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: AppTheme.navy950,
      drawer: _Sidebar(
        onNewChat: _newConversation,
        onSearch: (String q) =>
            context.read<ConversationsProvider>().search(q),
      ),
      body: Stack(
        children: <Widget>[
          const HmrBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: <Widget>[
                const _TopBar(),
                Expanded(child: _buildList()),
              ],
            ),
          ),
          Positioned(
            right: 20,
            bottom: 24 + bottomSafe,
            child: _NewChatButton(onTap: _newConversation),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return Consumer<ConversationsProvider>(
      builder: (_, ConversationsProvider convs, __) {
        final List<ConversationModel> list = convs.filtered;
        if (list.isEmpty) {
          return _EmptyConversations(onNew: _newConversation);
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: list.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (BuildContext context, int i) {
            if (i == 0) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 4, top: 4, right: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(AppStrings.recentConversations, style: AppTheme.sectionLabel),
                ),
              );
            }
            final ConversationModel c = list[i - 1];
            return _ConversationTile(
              conv: c,
              onTap: () => _openConversation(c),
              onDelete: () async {
                final bool? ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => const ConfirmDialog(
                    title: AppStrings.deleteConversationTitle,
                    body: AppStrings.deleteConversationBody,
                    confirmLabel: AppStrings.delete,
                  ),
                );
                if ((ok ?? false) && context.mounted) {
                  context.read<ConversationsProvider>().deleteConversation(c.id);
                }
              },
            );
          },
        );
      },
    );
  }
}

// ── Top bar ──────────────────────────────────────────────────────────────

/// Menu (opens drawer) · title · brand orb.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 16, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.rowDivider)),
      ),
      child: Row(
        children: <Widget>[
          Builder(
            builder: (BuildContext context) => _GlassIcon(
              icon: Icons.menu_rounded,
              onTap: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              AppStrings.conversationsTitle,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: AppTheme.fontFa,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const HmrAvatar(size: 38),
        ],
      ),
    );
  }
}

// ── Conversation tile ─────────────────────────────────────────────────────

/// One past-session card.
class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conv,
    required this.onTap,
    required this.onDelete,
  });

  final ConversationModel conv;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: AppTheme.glassFill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.glassBorder, width: 0.8),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x40000000), blurRadius: 20, offset: Offset(0, 8)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.chipFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.chipBorder, width: 0.8),
              ),
              child: const Icon(Icons.forum_outlined, size: 20, color: AppTheme.cyan),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    conv.title,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.tileTitle,
                  ),
                  if (conv.lastMessage.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 5),
                    Text(
                      conv.lastMessage,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.tilePreview,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Semantics(
                        button: true,
                        label: AppStrings.deleteConversationTitle,
                        child: GestureDetector(
                          onTap: onDelete,
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                            color: Color(0x80FF8597),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(_dateLabel(conv.updatedAt), style: AppTheme.tileMeta),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dateLabel(DateTime dt) {
    final DateTime now = DateTime.now();
    final Duration diff = now.difference(dt);
    if (diff.inHours < 24 && now.day == dt.day) return AppStrings.today;
    if (diff.inDays <= 1) return AppStrings.yesterday;
    if (diff.inDays < 7) return AppStrings.daysAgo(diff.inDays);
    return jalaliLabel(dt);
  }
}

// ── FAB ───────────────────────────────────────────────────────────────────

/// Circular neon "new chat" pill button.
class _NewChatButton extends StatelessWidget {
  const _NewChatButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.newConversation,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppTheme.neon,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.sendGlow,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.add_rounded, size: 22, color: Colors.white),
              SizedBox(width: 8),
              Text(
                AppStrings.newConversation,
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

// ── Empty state ───────────────────────────────────────────────────────────

class _EmptyConversations extends StatelessWidget {
  const _EmptyConversations({required this.onNew});
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const HmrAvatar(size: 72),
          const SizedBox(height: 20),
          const Text(
            AppStrings.noConversationsTitle,
            style: TextStyle(
              fontFamily: AppTheme.fontFa,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            AppStrings.noConversationsBody,
            style: AppTheme.tilePreview,
          ),
          const SizedBox(height: 28),
          TextButton(
            onPressed: onNew,
            child: const Text(
              AppStrings.newConversationPlus,
              style: TextStyle(
                fontFamily: AppTheme.fontFa,
                fontSize: 14,
                color: AppTheme.cyan,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sidebar ───────────────────────────────────────────────────────────────

// ⚠️ USER ACTION REQUIRED: replace with the live privacy-policy URL before release.
const String _kPrivacyPolicyUrl = 'https://hmrbot.com/privacy';
const String _kDownloadUrl = 'https://hmrbot.com/download';
const String _kDisclaimerUrl = 'https://hmrbot.com/disclaimer';

/// Sidebar "new chat" row — icon trailing, label leading (RTL).
class _SidebarNewChat extends StatelessWidget {
  const _SidebarNewChat({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  AppStrings.newChatShort,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFa,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Icon(Icons.edit_outlined, size: 18, color: AppTheme.cyan),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sidebar search field — filters the conversations list behind the drawer.
class _SidebarSearch extends StatelessWidget {
  const _SidebarSearch({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.inputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.inputBorder, width: 0.8),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.search_rounded, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              textAlign: TextAlign.right,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                fontFamily: AppTheme.fontFa,
                fontSize: 13.5,
                color: AppTheme.textBody,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: AppStrings.searchHint,
                hintStyle: TextStyle(
                  fontFamily: AppTheme.fontFa,
                  fontSize: 13.5,
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

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.onNewChat, required this.onSearch});

  /// Starts a new conversation — same entry point as the list screen's FAB.
  final VoidCallback onNewChat;

  /// Live query for the conversations list behind the drawer.
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    return Drawer(
      width: 304,
      backgroundColor: AppTheme.sidebarFill,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  HmrAvatar(size: 42),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('HMR', style: AppTheme.appTitle),
                      SizedBox(height: 2),
                      Text(AppStrings.brandSubtitle, style: AppTheme.subtitle),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SidebarNewChat(
                onTap: () {
                  Navigator.pop(context);
                  onNewChat();
                },
              ),
              const SizedBox(height: 14),
              _SidebarSearch(onChanged: onSearch),
              const SizedBox(height: 22),
              _AccountCard(auth: auth),
              const SizedBox(height: 22),
              const Padding(
                padding: EdgeInsets.only(right: 4, bottom: 6),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(AppStrings.moreSection, style: AppTheme.sectionLabel),
                ),
              ),
              _DrawerTile(
                icon: Icons.download_rounded,
                label: AppStrings.downloadApp,
                onTap: () async {
                  Navigator.pop(context);
                  await launchUrl(
                    Uri.parse(_kDownloadUrl),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
              _DrawerTile(
                icon: Icons.info_outline_rounded,
                label: AppStrings.about,
                onTap: () => Navigator.pop(context),
              ),
              _DrawerTile(
                icon: Icons.shield_outlined,
                label: AppStrings.privacy,
                onTap: () async {
                  Navigator.pop(context);
                  await launchUrl(
                    Uri.parse(_kPrivacyPolicyUrl),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
              _DrawerTile(
                icon: Icons.description_outlined,
                label: AppStrings.disclaimer,
                onTap: () async {
                  Navigator.pop(context);
                  await launchUrl(
                    Uri.parse(_kDisclaimerUrl),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
              const Spacer(),
              if (auth.isSignedIn) ...<Widget>[
                _DrawerTile(
                  icon: Icons.logout_rounded,
                  label: AppStrings.signOut,
                  danger: false,
                  onTap: () {
                    context.read<AuthProvider>().signOut();
                    Navigator.pop(context);
                  },
                ),
                _DrawerTile(
                  icon: Icons.delete_forever_rounded,
                  label: AppStrings.deleteAccount,
                  danger: true,
                  onTap: () async {
                    final ConversationsProvider convs =
                        context.read<ConversationsProvider>();
                    final AuthProvider authP = context.read<AuthProvider>();
                    final NavigatorState nav = Navigator.of(context);
                    final bool? ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => const ConfirmDialog(
                        title: AppStrings.deleteAccount,
                        body: AppStrings.deleteAccountBody,
                        confirmLabel: AppStrings.deleteAccount,
                      ),
                    );
                    if (!(ok ?? false)) return;
                    await convs.deleteAllConversations();
                    await authP.signOut();
                    nav.pop();
                    await launchUrl(
                      Uri(
                        scheme: 'mailto',
                        path: 'support@hmrbot.com',
                        queryParameters: <String, String>{
                          'subject': 'Account Deletion Request — HMR',
                          'body':
                              'Please delete my HMR account and all associated data.',
                        },
                      ),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
              ],
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  AppStrings.appVersionLabel,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFa,
                    fontSize: 10.5,
                    color: AppTheme.timeMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Guest → Google CTA; signed-in → profile card.
class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.auth});

  final AuthProvider auth;

  @override
  Widget build(BuildContext context) {
    if (auth.isGuest) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: <Color>[Color(0x332F6BFF), Color(0x1A00D4FF)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.chipBorder, width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              AppStrings.createAccountTitle,
              textAlign: TextAlign.right,
              style: AppTheme.tileTitle,
            ),
            const SizedBox(height: 6),
            const Text(
              AppStrings.createAccountBody,
              textAlign: TextAlign.right,
              style: AppTheme.tilePreview,
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: auth.isLoading
                  ? null
                  : () async {
                      final bool ok = await context.read<AuthProvider>().signInWithGoogle();
                      if (ok && context.mounted) Navigator.pop(context);
                    },
              child: Container(
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppTheme.neon,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppTheme.ringGlow,
                ),
                child: auth.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                      )
                    : const Text(
                        AppStrings.signInWithGoogle,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFa,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            if (auth.error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                auth.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFa,
                  fontSize: 12,
                  color: Color(0xFFFF8597),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Signed-in: profile row
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.glassFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.glassBorder, width: 0.8),
      ),
      child: Row(
        children: <Widget>[
          _avatarWidget(auth),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  auth.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.tileTitle,
                ),
                const SizedBox(height: 3),
                Text(
                  auth.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.tileMeta,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarWidget(AuthProvider auth) {
    if (auth.photoUrl != null) {
      return Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppTheme.neon,
          boxShadow: AppTheme.ringGlow,
        ),
        child: ClipOval(
          child: Image.network(
            auth.photoUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _initialAvatar(auth),
          ),
        ),
      );
    }
    return _initialAvatar(auth);
  }

  Widget _initialAvatar(AuthProvider auth) {
    return Container(
      width: 46,
      height: 46,
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
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color tint = danger ? const Color(0xFFFF8597) : AppTheme.textBody;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: danger ? const Color(0xFFFF8597) : AppTheme.cyan),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: AppTheme.fontFa,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small glass icon button (drawer trigger in the top bar).
class _GlassIcon extends StatelessWidget {
  const _GlassIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
            child: Icon(icon, size: 20, color: const Color(0xFFD6D6F2)),
          ),
        ),
      ),
    );
  }
}
