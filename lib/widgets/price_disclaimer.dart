import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Sticky glassmorphism banner reminding users to verify prices before buying.
/// Sits at the top of the chat area, always visible but minimal — doesn't
/// consume precious chat real estate.
class PriceDisclaimer extends StatelessWidget {
  const PriceDisclaimer({super.key, this.compact = false});

  /// When true, renders a single-line compact version for the empty state.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 6 : 7,
          ),
          decoration: BoxDecoration(
            color: AppTheme.disclaimerFill,
            border: Border(
              bottom: BorderSide(color: AppTheme.disclaimerBorder, width: 0.6),
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.info_outline_rounded,
                    size: 12, color: AppTheme.amber),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'قیمت‌ها از منابع ایرانی جست‌وجو می‌شوند. صحت قیمت را پیش از خرید تأیید کنید.',
                    style: compact
                        ? AppTheme.disclaimer.copyWith(fontSize: 10)
                        : AppTheme.disclaimer,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
