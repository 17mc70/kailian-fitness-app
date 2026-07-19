import 'package:flutter/material.dart';
import '../theme/kl_theme.dart';

/// Standard bottom sheet handle pill.
class KLSheetHandle extends StatelessWidget {
  const KLSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;

    return Center(
      child: Container(
        width: 36,
        height: 5,
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        decoration: BoxDecoration(
          color: colors.tertiaryLabel.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(2.5),
        ),
      ),
    );
  }
}
