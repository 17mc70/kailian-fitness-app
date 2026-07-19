import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/workout_templates.dart';
import '../models/exercise.dart';
import '../models/workout_plan.dart';
import '../services/exercise_service.dart';
import '../design/theme/kl_theme.dart';
import 'workout_screen.dart';
import 'exercise_detail_screen.dart';

/// Preview screen shown before starting a workout plan.
/// Works for both template plans and user-created plans.
class PlanDetailScreen extends StatelessWidget {
  final WorkoutPlan plan;
  final WorkoutTemplate? template;
  final PlanGoal? goal;

  const PlanDetailScreen({
    super.key,
    required this.plan,
    this.template,
    this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;

    final exercises = plan.exerciseIds
        .map((id) => ExerciseService.findById(id))
        .whereType<Exercise>()
        .toList();

    final goalColor = goal?.color ?? colors.primaryAccent;
    final goalIcon = goal?.icon ?? Icons.fitness_center_rounded;
    final tagLine = template?.tagLine ??
        '${plan.exerciseIds.length} 个动作';

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Row(
                  children: [
                    _PressableScale(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.tertiarySystemBackground,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: colors.label.withValues(alpha: 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.chevron_left_rounded, size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(plan.name, style: typography.title2),
                    ),
                  ],
                ),
              ),
            ),

            // ── Goal hero ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: goalColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: goalColor.withValues(alpha: 0.1),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: goalColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(goalIcon, color: goalColor, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              template?.goal?.label ?? '',
                              style: typography.footnote.copyWith(
                                color: goalColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tagLine,
                              style: typography.subhead.copyWith(
                                color: colors.secondaryLabel,
                              ),
                            ),
                            if (template?.description != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                template!.description,
                                style: typography.footnote.copyWith(
                                  color: colors.tertiaryLabel,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Start button ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                child: _PressableScale(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WorkoutScreen(plan: plan),
                      ),
                    );
                  },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: goalColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: goalColor.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 24),
                        const SizedBox(width: 6),
                        Text(
                          '开始训练',
                          style: typography.headline.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Exercise list title ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Text(
                  '训练动作',
                  style: typography.title3.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            // ── Exercise list ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final ex = exercises.length > index ? exercises[index] : null;
                    if (ex == null) return const SizedBox();
                    return _PressableScale(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExerciseDetailScreen(exercise: ex),
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.secondarySystemBackground,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: colors.label.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: colors.tertiarySystemBackground,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  ex.image,
                                  fit: BoxFit.cover,
                                  cacheWidth: 144,
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.fitness_center,
                                    color: colors.tertiaryLabel,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${index + 1}. ${ex.name}',
                                    style: typography.subhead.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${Exercise.categoryLabel(ex.category)} · ${Exercise.equipmentLabel(ex.equipment)}',
                                    style: typography.caption2.copyWith(
                                      color: colors.tertiaryLabel,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                size: 18, color: colors.tertiaryLabel),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: exercises.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pressable scale wrapper ──

class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _PressableScale({required this.child, this.onTap});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: KLAnimations.fast,
      value: 1,
    );
    _anim = Tween(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: KLAnimations.press),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, child) =>
            Transform.scale(scale: _anim.value, child: child),
        child: widget.child,
      ),
    );
  }
}
