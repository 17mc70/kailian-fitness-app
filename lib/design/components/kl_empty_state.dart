import 'package:flutter/material.dart';
import '../theme/kl_theme.dart';

/// Beautifully composed empty state with icon, title, subtitle and action.
class KLEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const KLEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.fill,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: colors.tertiaryLabel),
            ),
            const SizedBox(height: 20),
            Text(title, style: typography.title3, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: typography.footnote,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              _PlainButton(label: actionLabel!, onTap: onAction!),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlainButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PlainButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;

    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: typography.headline.copyWith(color: colors.primaryAccent),
      ),
    );
  }
}
