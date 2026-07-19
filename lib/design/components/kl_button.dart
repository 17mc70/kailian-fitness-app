import 'package:flutter/material.dart';
import '../theme/kl_theme.dart';
import 'kl_card.dart';

enum KLButtonType { filled, tonal, plain, glass }

/// Apple-style button with spring press feedback.
class KLButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final KLButtonType type;
  final IconData? icon;
  final bool expand;
  final double height;

  const KLButton({
    super.key,
    required this.label,
    this.onTap,
    this.type = KLButtonType.filled,
    this.icon,
    this.expand = true,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;

    Color background;
    Color foreground;
    List<BoxShadow>? shadows;
    Border? border;

    switch (type) {
      case KLButtonType.filled:
        background = colors.primaryAccent;
        foreground = colors.brightness == Brightness.dark
            ? colors.label
            : Colors.white;
        shadows = null;
        border = null;
      case KLButtonType.tonal:
        background = colors.primaryAccent.withValues(alpha: 0.12);
        foreground = colors.primaryAccent;
        shadows = null;
        border = null;
      case KLButtonType.plain:
        background = Colors.transparent;
        foreground = colors.primaryAccent;
        shadows = null;
        border = null;
      case KLButtonType.glass:
        background = colors.secondarySystemBackground.withValues(alpha: 0.72);
        foreground = colors.label;
        shadows = [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ];
        border = Border.all(color: colors.separator, width: 1);
    }

    final child = Container(
      height: height,
      width: expand ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(KLRadius.button),
        boxShadow: shadows,
        border: border,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: foreground, size: 20),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: typography.headline.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (type == KLButtonType.plain) {
      return ScaleOnPress(scale: 0.95, onTap: onTap, child: child);
    }

    return ScaleOnPress(
      scale: 0.97,
      hapticType: HapticFeedbackType.medium,
      onTap: onTap,
      child: child,
    );
  }
}

/// A smaller icon-only circular button.
class KLIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;

  const KLIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 40,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;

    return ScaleOnPress(
      scale: 0.9,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color:
              backgroundColor ??
              colors.secondarySystemBackground.withValues(alpha: 0.8),
          shape: BoxShape.circle,
          border: Border.all(color: colors.separator, width: 1),
        ),
        child: Icon(icon, color: iconColor ?? colors.label, size: size * 0.45),
      ),
    );
  }
}
