import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../agent/agent_service.dart';
import '../models/exercise.dart';
import '../services/database_service.dart';
import '../design/theme/kl_theme.dart';
import '../utils/exercise_labels.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final Exercise exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadFav();
  }

  Future<void> _loadFav() async {
    final fav = await DatabaseService.isFavorite(widget.exercise.id);
    if (mounted) setState(() => _isFavorite = fav);
  }

  Future<void> _toggleFav() async {
    HapticFeedback.lightImpact();
    await DatabaseService.toggleFavorite(widget.exercise.id);
    if (mounted) setState(() => _isFavorite = !_isFavorite);
  }

  String get _lang => 'zh';

  Future<void> _showAITips(BuildContext context, Exercise exercise,
      KLColorScheme colors, KLTypography typography) async {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.systemBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AITipSheet(exercise: exercise),
    );
  }

  String _tipForExercise() {
    switch (widget.exercise.category.toLowerCase()) {
      case 'chest':
        return '推起时呼气，下落时吸气。肘部与身体呈 45° 保护肩关节。';
      case 'back':
        return '划船时肩胛骨先收缩再拉，不要用身体晃动借力。';
      case 'shoulders':
        return '肩关节最灵活也最脆弱，控制重量不要用惯性甩。';
      case 'upper arms':
        return '大臂夹紧身体不要晃动，只有前臂在动才是对的。';
      case 'upper legs':
        return '膝盖不要超过脚尖过多，保持重心在脚掌中部。';
      case 'lower legs':
        return '动作幅度要完整，充分拉伸再收缩小腿肌肉。';
      case 'waist':
        return '核心始终收紧，下背部贴地。动作慢比快有效。';
      case 'cardio':
        return '保持心率在目标区间，能说话但说不完整句子。';
      case 'neck':
        return '颈部动作要轻柔，不要用力过猛。有不适立刻停止。';
      case 'lower arms':
        return '手腕保持中立位，不要过度弯曲或伸展。';
      default:
        return '保持呼吸平稳，关注目标肌肉发力感，动作质量比数量更重要。';
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exercise;
    final colors = context.klColors;
    final typography = context.klTypography;
    final steps = e.getSteps(_lang);
    final hasSteps = steps.isNotEmpty;

    return Scaffold(
      backgroundColor: colors.systemBackground,
      body: CustomScrollView(
        slivers: [
          // ── Hero GIF with overlaid controls ──
          SliverAppBar(
            expandedHeight: 360,
            pinned: false,
            stretch: true,
            backgroundColor: colors.tertiarySystemBackground,
            leading: Padding(
              padding: const EdgeInsets.only(top: 4, left: 8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.systemBackground.withValues(alpha: 0.75),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_left_rounded, size: 24),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: GestureDetector(
                  onTap: _toggleFav,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.systemBackground.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: _isFavorite ? colors.warning : colors.secondaryLabel,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: colors.tertiarySystemBackground,
                child: Image.asset(
                  e.gifUrl,
                  fit: BoxFit.contain,
                  cacheWidth: 720,
                  errorBuilder: (_, _, _) => Image.asset(
                    e.image,
                    fit: BoxFit.contain,
                    cacheWidth: 720,
                    errorBuilder: (_, _, _) => Center(
                      child: Icon(Icons.fitness_center,
                          size: 48, color: colors.tertiaryLabel),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Exercise name ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Text(
                e.name,
                style: typography.title1,
              ),
            ),
          ),

          // ── Info chips ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(colors, '部位', Exercise.categoryLabel(e.category),
                      colors.primaryAccent),
                  _chip(colors, '器材', Exercise.equipmentLabel(e.equipment),
                      const Color(0xFF2D9CDB)),
                  _chip(colors, '目标肌肉',
                      ExerciseLabels.muscleGroup(e.target),
                      const Color(0xFF27AE60)),
                  if (e.secondaryMuscles.isNotEmpty)
                    _chip(colors, '辅助',
                        e.secondaryMuscles
                            .map((m) => ExerciseLabels.muscleGroup(m))
                            .join('、'),
                        colors.tertiaryLabel),
                ],
              ),
            ),
          ),

          // ── Section: 动作要领 ──
          if (hasSteps) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: colors.primaryAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.list_alt_rounded,
                          size: 16, color: colors.primaryAccent),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '动作要领',
                      style: typography.title3.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                child: Column(
                  children: List.generate(steps.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            margin: const EdgeInsets.only(top: 1),
                            decoration: BoxDecoration(
                              color: colors.primaryAccent.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: colors.primaryAccent,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              steps[i],
                              style: typography.callout.copyWith(
                                height: 1.5,
                                color: colors.secondaryLabel,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],

          // ── Section: 小贴士 + AI 指导 ──
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  24, hasSteps ? 28 : 32, 24, 32 + MediaQuery.of(context).padding.bottom),
              child: Column(
                children: [
                  // Built-in tip
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.tertiarySystemBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.separator, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb_outline_rounded,
                                size: 16, color: colors.warning),
                            const SizedBox(width: 8),
                            Text(
                              '小贴士',
                              style: typography.subhead.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _tipForExercise(),
                          style: typography.footnote.copyWith(
                            color: colors.secondaryLabel,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // AI guidance button
                  GestureDetector(
                    onTap: () => _showAITips(context, e, colors, typography),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.primaryAccent.withValues(alpha: 0.08),
                            const Color(0xFF9B51E0).withValues(alpha: 0.04),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.primaryAccent.withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 18,
                            color: colors.primaryAccent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AI 深度指导',
                                  style: typography.subhead.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '详细动作分析 + 常见错误 + 进阶变式',
                                  style: typography.caption2.copyWith(
                                    color: colors.tertiaryLabel,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: colors.tertiaryLabel,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
      KLColorScheme colors, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI Tip Bottom Sheet ──

class _AITipSheet extends StatefulWidget {
  final Exercise exercise;

  const _AITipSheet({required this.exercise});

  @override
  State<_AITipSheet> createState() => _AITipSheetState();
}

class _AITipSheetState extends State<_AITipSheet> {
  String? _tipContent;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tip = await FitnessAgentService.instance.currentAgent
          .getExerciseTip(widget.exercise);
      if (!mounted) return;
      setState(() {
        _tipContent = tip;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tipContent = '获取指导失败，请稍后再试';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;
    final bottom = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.separator,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 20, color: colors.primaryAccent),
                  const SizedBox(width: 8),
                  Text(
                    'AI 深度指导',
                    style: typography.title3.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Text(
                        _tipContent ?? '',
                        style: typography.callout.copyWith(
                          color: colors.secondaryLabel,
                          height: 1.6,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
