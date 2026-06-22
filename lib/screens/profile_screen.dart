import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/hmr_avatar.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.navy950,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _buildAppBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: <Widget>[
                      const SizedBox(height: 24),
                      _UserHeader(auth: auth),
                      const SizedBox(height: 28),
                      _MenuSection(auth: auth),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 20, 4),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: AppTheme.textPrimary),
            onPressed: () => Navigator.maybePop(context),
          ),
          const Expanded(
            child: Text(
              'پروفایل',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFa,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  const _UserHeader({required this.auth});

  final AuthProvider auth;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _avatar(),
        const SizedBox(height: 14),
        Text(
          auth.displayName,
          style: const TextStyle(
            fontFamily: AppTheme.fontFa,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          auth.email,
          style: const TextStyle(
            fontFamily: AppTheme.fontFa,
            fontSize: 12.5,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.chipFill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.chipBorder, width: 0.8),
          ),
          child: const Text(
            'طرح: رایگان',
            style: TextStyle(
              fontFamily: AppTheme.fontFa,
              fontSize: 12,
              color: AppTheme.cyan,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatar() {
    final String? url = auth.photoUrl;
    return Container(
      width: 80,
      height: 80,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.neon,
        boxShadow: AppTheme.ringGlow,
      ),
      padding: const EdgeInsets.all(2.5),
      child: ClipOval(
        child: url != null
            ? Image.network(url, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const HmrAvatar(size: 80))
            : const HmrAvatar(size: 80),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.auth});

  final AuthProvider auth;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.glassFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.glassBorder, width: 0.8),
          ),
          child: Column(
            children: <Widget>[
              _MenuItem(
                icon: Icons.person_outline_rounded,
                label: 'اطلاعات پروفایل',
                onTap: () {},
              ),
              _divider(),
              _MenuItem(
                icon: Icons.card_membership_rounded,
                label: 'جزئیات اشتراک',
                onTap: () {},
              ),
              _divider(),
              _MenuItem(
                icon: Icons.lock_outline_rounded,
                label: 'حریم خصوصی',
                onTap: () {},
              ),
              _divider(),
              _ThemeToggleItem(),
              _divider(),
              _MenuItem(
                icon: Icons.support_agent_rounded,
                label: 'پشتیبانی',
                onTap: () {},
              ),
              _divider(),
              _MenuItem(
                icon: Icons.logout_rounded,
                label: 'خروج از حساب',
                color: const Color(0xFFFF8597),
                onTap: () async {
                  await auth.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() => const Divider(
        height: 1,
        thickness: 0.5,
        color: AppTheme.glassBorder,
        indent: 52,
      );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? AppTheme.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: c.withAlpha(0xCC)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.fontFa,
                  fontSize: 14,
                  color: c,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_left_rounded,
                size: 18, color: AppTheme.textSecondary.withAlpha(0x99)),
          ],
        ),
      ),
    );
  }
}

class _ThemeToggleItem extends StatefulWidget {
  @override
  State<_ThemeToggleItem> createState() => _ThemeToggleItemState();
}

class _ThemeToggleItemState extends State<_ThemeToggleItem> {
  bool _dark = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: <Widget>[
          const Icon(Icons.dark_mode_outlined,
              size: 20, color: Color(0xCCFFFFFF)),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'تم تاریک',
              style: TextStyle(
                fontFamily: AppTheme.fontFa,
                fontSize: 14,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: _dark,
            onChanged: (v) => setState(() => _dark = v),
            activeThumbColor: AppTheme.cyan,
            activeTrackColor: AppTheme.glowFocus,
          ),
        ],
      ),
    );
  }
}
