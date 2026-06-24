import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Amber glassmorphism strip reminding users to verify prices before buying.
/// Used in the chat empty-state and as a persistent note above the composer.
class PriceDisclaimer extends StatelessWidget {
  const PriceDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.disclaimerFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.disclaimerBorder, width: 0.8),
        ),
        child: const Row(
          children: <Widget>[
            Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.amber),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'قیمت‌ها از منابع ایرانی جست‌وجو می‌شوند. صحت قیمت را پیش از خرید تأیید کنید.',
                style: AppTheme.disclaimer,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
