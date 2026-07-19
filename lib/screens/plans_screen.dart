import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/workout_templates.dart';
import '../models/workout_plan.dart';
import '../services/database_service.dart';
import '../design/theme/kl_theme.dart';
import 'create_plan_screen.dart';
import 'plan_detail_screen.dart';
import 'ai_plan_config_screen.dart';

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
    _anim = Tween(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _ctrl, curve: KLAnimations.press));
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

// ── Main screen ──

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => PlansScreenState();
}

class PlansScreenState extends State<PlansScreen> {
  bool _loading = true;
  String _selectedGoal = '';
  List<WorkoutPlan> _userPlans = [];

  void refresh() => _loadPlans();

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    _userPlans = await DatabaseService.getPlans();
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  /// Filtered templates based on selected goal.
  List<WorkoutTemplate> get _filteredTemplates {
    if (_selectedGoal.isEmpty) return workoutTemplates;
    return workoutTemplates.where((t) => t.goalKey == _selectedGoal).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: CustomScrollView(
                physics: const ClampingScrollPhysics(),
                slivers: [
                  // ── Header ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('训练计划', style: typography.title1),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'AI 生成计划',
                            onPressed: () async {
                              HapticFeedback.lightImpact();
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AIPlanConfigScreen(),
                                ),
                              );
                              if (result == true) _loadPlans();
                            },
                            icon: const Icon(Icons.auto_awesome_rounded),
                          ),
                          const SizedBox(width: 4),
                          IconButton.filled(
                            tooltip: '新建计划',
                            onPressed: () async {
                              HapticFeedback.lightImpact();
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CreatePlanScreen(),
                                ),
                              );
                              if (result == true) _loadPlans();
                            },
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Featured templates (horizontal scroll) ──
                  if (_filteredTemplates.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 0, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '精选计划',
                              style: typography.title3.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 128,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: _filteredTemplates
                                    .where((t) => t.goal != null)
                                    .take(6)
                                    .map(
                                      (t) => _FeatureCard(
                                        template: t,
                                        onTap: () => _openDetail(t),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── Goal pills ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                      child: SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _goalPill(colors, '', '全部'),
                            ...PlanGoal.all.map(
                              (g) => _goalPill(colors, g.key, g.label),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Template grid ──
                  if (_filteredTemplates.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          '该分类暂无计划',
                          style: typography.subhead.copyWith(
                            color: colors.secondaryLabel,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final t = _filteredTemplates[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _TemplateCard(
                              template: t,
                              onTap: () => _openDetail(t),
                            ),
                          );
                        }, childCount: _filteredTemplates.length),
                      ),
                    ),

                  // ── User-created plans ──
                  if (_userPlans.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                        child: Text(
                          '我的计划',
                          style: typography.title3.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ),
                  if (_userPlans.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final plan = _userPlans[index];
                          return _UserPlanCard(
                            plan: plan,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlanDetailScreen(plan: plan),
                                ),
                              );
                            },
                            onDelete: () async {
                              if (plan.id == null) return;
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('删除计划'),
                                  content: Text('确定删除「${plan.name}」吗？'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('取消'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(
                                        '删除',
                                        style: TextStyle(
                                          color: colors.negative,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await DatabaseService.deletePlan(plan.id!);
                                _loadPlans();
                              }
                            },
                          );
                        }, childCount: _userPlans.length),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  void _openDetail(WorkoutTemplate t) {
    HapticFeedback.lightImpact();
    final plan = WorkoutPlan(
      name: t.name,
      description: t.description,
      exerciseIds: t.exerciseIds,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanDetailScreen(plan: plan, template: t, goal: t.goal),
      ),
    );
  }

  Widget _goalPill(KLColorScheme colors, String key, String label) {
    final sel = _selectedGoal == key;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: _PressableScale(
        onTap: () => setState(() => _selectedGoal = key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? colors.primaryAccent : colors.tertiarySystemBackground,
            borderRadius: BorderRadius.circular(12),
            boxShadow: sel
                ? [
                    BoxShadow(
                      color: colors.primaryAccent.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
              color: sel ? Colors.white : colors.secondaryLabel,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Featured horizontal card ──

class _FeatureCard extends StatelessWidget {
  final WorkoutTemplate template;
  final VoidCallback onTap;

  const _FeatureCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final goal = template.goal;
    final goalColor = goal?.color ?? colors.primaryAccent;
    final goalIcon = goal?.icon ?? Icons.fitness_center_rounded;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: _PressableScale(
        onTap: onTap,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: goalColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: goalColor.withValues(alpha: 0.24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: goalColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(goalIcon, color: goalColor, size: 18),
                  ),
                  const Spacer(),
                  _difficultyBadge(template.difficulty),
                ],
              ),
              const Spacer(),
              Text(
                template.name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${template.durationMinutes} 分钟 · ${template.exerciseCount} 个动作',
                style: TextStyle(fontSize: 11, color: colors.secondaryLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _difficultyBadge(String difficulty) {
    final bg = difficulty == '初级'
        ? Colors.green.withValues(alpha: 0.2)
        : difficulty == '中级'
        ? Colors.orange.withValues(alpha: 0.2)
        : Colors.red.withValues(alpha: 0.2);
    final text = difficulty == '初级'
        ? Colors.green.shade700
        : difficulty == '中级'
        ? Colors.orange.shade800
        : Colors.red.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        difficulty,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: text),
      ),
    );
  }
}

// ── Template grid card ──

class _TemplateCard extends StatelessWidget {
  final WorkoutTemplate template;
  final VoidCallback onTap;

  const _TemplateCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;
    final goal = template.goal;
    final goalColor = goal?.color ?? colors.primaryAccent;
    final goalIcon = goal?.icon ?? Icons.fitness_center_rounded;

    return _PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.secondarySystemBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.separator.withValues(alpha: 0.55)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: goalColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(goalIcon, color: goalColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: typography.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${template.durationMinutes} 分钟 · ${template.exerciseCount} 个动作',
                    style: typography.footnote.copyWith(
                      color: colors.secondaryLabel,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            _difficultyDot(template.difficulty),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: colors.tertiaryLabel),
          ],
        ),
      ),
    );
  }

  Widget _difficultyDot(String difficulty) {
    final color = difficulty == '初级'
        ? Colors.green
        : difficulty == '中级'
        ? Colors.orange
        : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        difficulty,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ── User-created plan card ──

class _UserPlanCard extends StatelessWidget {
  final WorkoutPlan plan;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _UserPlanCard({
    required this.plan,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: _PressableScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.secondarySystemBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colors.label.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primaryAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.fitness_center_rounded,
                  color: colors.primaryAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: typography.subhead.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (plan.description != null &&
                        plan.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          plan.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.secondaryLabel,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${plan.exerciseIds.length} 个动作',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.tertiaryLabel,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onDelete,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: colors.negative,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
