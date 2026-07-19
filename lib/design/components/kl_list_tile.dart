import 'package:flutter/material.dart';
import '../theme/kl_theme.dart';
import 'kl_card.dart';

/// Apple-style list tile with chevron and optional leading icon/image.
class KLListTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  const KLListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;

    return ScaleOnPress(
      scale: 0.98,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colors.secondarySystemBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.separator, width: 1),
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: typography.headline),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: typography.footnote,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            ?trailing,
            if (showChevron)
              Icon(
                Icons.chevron_right,
                size: 18,
                color: colors.tertiaryLabel,
              ),
          ],
        ),
      ),
    );
  }
}
