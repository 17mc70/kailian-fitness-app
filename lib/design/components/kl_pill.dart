import 'package:flutter/material.dart';
import '../theme/kl_theme.dart';
import 'kl_card.dart';

/// Apple-style pill / chip with animated selection fill.
class KLPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final Color? accentColor;

  const KLPill({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;
    final accent = accentColor ?? colors.primaryAccent;

    return ScaleOnPress(
      scale: 0.94,
      hapticType: HapticFeedbackType.selection,
      onTap: onTap,
      child: AnimatedContainer(
        duration: KLAnimations.fast,
        curve: KLAnimations.easeOutBack,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.12) : colors.fill,
          borderRadius: BorderRadius.circular(KLRadius.pill),
          border: Border.all(
            color: isSelected ? accent.withValues(alpha: 0.3) : colors.separator,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: typography.footnote.copyWith(
            color: isSelected ? accent : colors.secondaryLabel,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
