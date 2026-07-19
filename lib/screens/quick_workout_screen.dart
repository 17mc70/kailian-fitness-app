import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/exercise.dart';
import '../models/workout_plan.dart';
import '../services/exercise_service.dart';
import '../design/theme/kl_theme.dart';
import '../utils/exercise_labels.dart';
import 'workout_screen.dart';

class QuickWorkoutScreen extends StatefulWidget {
  const QuickWorkoutScreen({super.key});

  @override
  State<QuickWorkoutScreen> createState() => _QuickWorkoutScreenState();
}

class _QuickWorkoutScreenState extends State<QuickWorkoutScreen> {
  final _searchCtrl = TextEditingController();
  List<Exercise> _allExercises = [];
  List<Exercise> _filtered = [];
  final Set<String> _selectedIds = {};
  bool _loading = true;
  bool _hasAutoRecommended = false;
  Timer? _searchDebounce;

  static const _targetCategories = [
    'chest', 'back', 'upper legs', 'shoulders',
    'upper arms', 'waist', 'cardio',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final exercises = await ExerciseService.loadExercises();
    if (!mounted) return;
    setState(() {
      _allExercises = exercises;
      _filtered = exercises;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoRecommend());
  }

  void _autoRecommend() {
    if (_hasAutoRecommended) return;
    _hasAutoRecommended = true;

    final rng = Random();
    final recommended = <String>{};

    final byCategory = <String, List<Exercise>>{};
    for (final e in _allExercises) {
      if (e.equipment.toLowerCase() != 'body weight') continue;
      final cat = e.category.toLowerCase();
      byCategory.putIfAbsent(cat, () => []).add(e);
    }

    for (final cat in _targetCategories) {
      final pool = byCategory[cat];
      if (pool == null || pool.isEmpty) continue;
      final usedTargets =
          recommended.map((id) => ExerciseService.findById(id)?.target).toSet();
      final fresh = pool.where((e) => !usedTargets.contains(e.target)).toList();
      final pick = fresh.isNotEmpty ? fresh : pool;
      recommended.add(pick[rng.nextInt(pick.length)].id);
    }

    if (recommended.length < 5) {
      final others = _allExercises
          .where((e) =>
              e.equipment.toLowerCase() == 'body weight' &&
              !recommended.contains(e.id))
          .toList();
      others.shuffle(rng);
      for (final e in others) {
        if (recommended.length >= 6) break;
        recommended.add(e.id);
      }
    }

    if (!mounted) return;
    setState(() => _selectedIds.addAll(recommended));
  }

  void _reshuffle() {
    _hasAutoRecommended = false;
    _selectedIds.clear();
    _autoRecommend();
  }

  void _search(String q) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _filtered =
            q.isEmpty ? _allExercises : ExerciseService.search(q);
      });
    });
  }

  void _startWorkout() {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请至少选择一个动作'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final plan = WorkoutPlan(
      name: '自由训练',
      description: '${_selectedIds.length} 个动作 · 快速开练',
      exerciseIds: _selectedIds.toList(),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => WorkoutScreen(plan: plan)),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
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
                slivers: [
                  // ── Header ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: colors.tertiarySystemBackground,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                  Icons.close_rounded, size: 20),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '快速开练',
                            style: typography.title2,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Recommendation banner ──
                  if (_selectedIds.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildRecommendBanner(colors, typography),
                    ),

                  // ── Search ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: colors.tertiarySystemBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            Icon(Icons.search_rounded,
                                size: 18, color: colors.tertiaryLabel),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                decoration: InputDecoration(
                                  hintText: '搜索动作...',
                                  hintStyle: TextStyle(
                                      color: colors.placeholder,
                                      fontSize: 15),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: TextStyle(
                                    color: colors.label, fontSize: 15),
                                onChanged: _search,
                              ),
                            ),
                            if (_searchCtrl.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchCtrl.clear();
                                  _search('');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(Icons.close_rounded,
                                      size: 18,
                                      color: colors.tertiaryLabel),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Selected count ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(24, 8, 24, 4),
                      child: Row(
                        children: [
                          Text(
                            '已选 ${_selectedIds.length} 个动作',
                            style: typography.subhead.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (_selectedIds.isNotEmpty)
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedIds.clear()),
                              child: Text(
                                '清空',
                                style: typography.footnote.copyWith(
                                  color: colors.secondaryLabel,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ── Exercise list ──
                  if (_filtered.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Text(
                          '没有找到匹配的动作',
                          style: typography.subhead.copyWith(
                            color: colors.secondaryLabel,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(0, 4, 0, 120),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final e = _filtered[index];
                            final selected =
                                _selectedIds.contains(e.id);
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  if (selected) {
                                    _selectedIds.remove(e.id);
                                  } else {
                                    _selectedIds.add(e.id);
                                  }
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      colors.secondarySystemBackground,
                                  borderRadius:
                                      BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected
                                        ? colors.primaryAccent
                                            .withValues(alpha: 0.5)
                                        : colors.separator,
                                    width: selected ? 1 : 0.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: colors
                                            .tertiarySystemBackground,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        child: Image.asset(
                                          e.image,
                                          fit: BoxFit.cover,
                                          cacheWidth: 168,
                                          errorBuilder: (_, _, _) =>
                                              Icon(Icons.fitness_center,
                                                  color:
                                                      colors.tertiaryLabel),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            e.name,
                                            style: typography.subhead
                                                .copyWith(
                                              fontWeight:
                                                  FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${Exercise.categoryLabel(e.category)} · ${Exercise.equipmentLabel(e.equipment)}',
                                            style:
                                                typography.caption2.copyWith(
                                              color:
                                                  colors.tertiaryLabel,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? colors.primaryAccent
                                            : Colors.transparent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: selected
                                              ? colors.primaryAccent
                                              : colors.separator,
                                          width: selected ? 0 : 1.5,
                                        ),
                                      ),
                                      child: selected
                                          ? const Icon(Icons.check_rounded,
                                              color: Colors.white,
                                              size: 16)
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: _filtered.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: _selectedIds.isNotEmpty
          ? Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _startWorkout();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: colors.primaryAccent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primaryAccent.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 6),
                      Text(
                        '开始训练 (${_selectedIds.length})',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildRecommendBanner(
      KLColorScheme colors, KLTypography typography) {
    final selected = _selectedIds
        .map((id) => ExerciseService.findById(id))
        .whereType<Exercise>()
        .toList();
    final cats = selected
        .map((e) => ExerciseLabels.category(e.category))
        .toSet()
        .join(' · ');

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primaryAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: colors.primaryAccent.withValues(alpha: 0.15),
            width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded,
              size: 18, color: colors.primaryAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已为你推荐 ${selected.length} 个动作',
                  style: typography.footnote.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.primaryAccent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cats,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.caption2.copyWith(
                    color: colors.tertiaryLabel,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _reshuffle,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colors.primaryAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded,
                      size: 14, color: colors.primaryAccent),
                  const SizedBox(width: 4),
                  Text(
                    '换一批',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colors.primaryAccent,
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
}
