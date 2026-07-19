import 'dart:ui';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

/// Reusable dark-glass confirmation dialog.
/// Returns `true` via `Navigator.pop` when the user confirms, `false` on cancel.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.body,
    required this.confirmLabel,
  });

  final String title;
  final String body;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
            decoration: BoxDecoration(
              color: const Color(0xE00A1020),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.glassBorder, width: 0.8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  title,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFa,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFa,
                    fontSize: 13,
                    height: 1.7,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text(
                          AppStrings.cancel,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFa,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0x33FF5470),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(
                                color: Color(0x66FF5470), width: 0.8),
                          ),
                        ),
                        child: Text(
                          confirmLabel,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFa,
                            color: Color(0xFFFF8597),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
