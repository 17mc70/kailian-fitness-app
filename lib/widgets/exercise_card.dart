import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../design/theme/kl_theme.dart';
import '../utils/exercise_labels.dart';

/// Apple-style exercise card with clean border, minimal shadow, and clear info.
class ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback? onToggleFavorite;

  const ExerciseCard({
    super.key,
    required this.exercise,
    this.isFavorite = false,
    required this.onTap,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.secondarySystemBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.separator, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    color: colors.tertiarySystemBackground,
                    child: Image.asset(
                      exercise.image,
                      fit: BoxFit.contain,
                      cacheWidth: 360,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.fitness_center,
                        size: 32,
                        color: colors.tertiaryLabel,
                      ),
                    ),
                  ),
                  // Favorite button
                  if (onToggleFavorite != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: onToggleFavorite,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: colors.systemBackground
                                .withValues(alpha: 0.75),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFavorite
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 17,
                            color: isFavorite
                                ? colors.warning
                                : colors.tertiaryLabel,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.subhead.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _tag(
                        context,
                        ExerciseLabels.category(exercise.category),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          ExerciseLabels.equipment(exercise.equipment),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.caption2.copyWith(
                            color: colors.tertiaryLabel,
                          ),
                        ),
                      ),
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

  Widget _tag(BuildContext context, String text) {
    final colors = context.klColors;
    final typography = context.klTypography;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.primaryAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: typography.caption2.copyWith(
          fontWeight: FontWeight.w500,
          color: colors.primaryAccent,
        ),
      ),
    );
  }
}
