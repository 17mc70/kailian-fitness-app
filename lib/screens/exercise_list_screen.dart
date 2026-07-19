import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../agent/agent_service.dart';
import '../models/exercise.dart';
import '../services/exercise_service.dart';
import '../services/database_service.dart';
import '../design/theme/kl_theme.dart';
import '../utils/equipment_groups.dart';
import '../utils/exercise_labels.dart';
import '../widgets/exercise_card.dart';
import '../widgets/skeleton_card.dart';
import 'exercise_detail_screen.dart';

// ── Pressable scale wrapper (shared with HomeScreen) ──

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
        builder: (_, child) => Transform.scale(scale: _anim.value, child: child),
        child: widget.child,
      ),
    );
  }
}

// ── Main list screen ──

class ExerciseListScreen extends StatefulWidget {
  final String? initialCategory;
  final String? initialEquipmentGroup;
  final String? initialTarget;
  final String? categoryLabel;

  const ExerciseListScreen({
    super.key,
    this.initialCategory,
    this.initialEquipmentGroup,
    this.initialTarget,
    this.categoryLabel,
  });

  @override
  State<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends State<ExerciseListScreen> {
  List<Exercise> _filtered = [];
  bool _loading = true;
  Set<String> _favoriteIds = {};
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedEquipment;
  String? _selectedEquipmentGroup;
  String? _selectedTarget;
  String _sortBy = '';
  List<String> _categories = [];
  List<String> _equipments = [];
  List<String> _targets = [];
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _searchDebounce;

  static const _sortOptions = [
    _SortOption('', '默认'),
    _SortOption('name_asc', '名称 A→Z'),
    _SortOption('name_desc', '名称 Z→A'),
    _SortOption('target', '按目标肌肉'),
    _SortOption('equipment', '按器材类型'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _selectedEquipmentGroup = widget.initialEquipmentGroup;
    _selectedTarget = widget.initialTarget;
    _load();
  }

  Future<void> _load() async {
    await ExerciseService.loadExercises();
    final favs = await DatabaseService.getFavoriteIds();
    if (!mounted) return;
    setState(() {
      _favoriteIds = favs;
      _categories = ExerciseService.categoryList;
      _equipments = ['all', ...ExerciseService.equipmentList];
      _targets = [...ExerciseService.targetList];
      _loading = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filtered = ExerciseService.filter(
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        category: _selectedCategory,
        equipment: _selectedEquipment != null && _selectedEquipment != 'all'
            ? _selectedEquipment
            : null,
        equipmentGroup: _selectedEquipmentGroup,
        target: _selectedTarget,
      );
      if (_sortBy.isNotEmpty) {
        _filtered = ExerciseService.sortExercises(_filtered, _sortBy);
      }
    });
  }

  Future<void> _toggleFav(String id) async {
    HapticFeedback.lightImpact();
    await DatabaseService.toggleFavorite(id);
    setState(() {
      if (_favoriteIds.contains(id)) {
        _favoriteIds.remove(id);
      } else {
        _favoriteIds.add(id);
      }
    });
  }

  Future<void> _showAISearch(KLColorScheme colors) async {
    HapticFeedback.lightImpact();
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.systemBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 20, color: colors.primaryAccent),
            const SizedBox(width: 8),
            const Text('AI 智能搜索'),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '例如：练胸的哑铃动作、核心训练...',
            hintStyle: TextStyle(color: colors.placeholder),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.separator),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.primaryAccent),
            ),
          ),
          maxLines: 3,
          minLines: 1,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            icon: const Icon(Icons.search_rounded, size: 16),
            label: const Text('搜索'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final answer = await FitnessAgentService.instance.currentAgent
          .answerQuery(result, contextExercises: ExerciseService.all);
      if (!mounted) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(answer.answer),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: answer.relatedExerciseIds != null &&
                    answer.relatedExerciseIds!.isNotEmpty
                ? SnackBarAction(
                    label: '查看结果',
                    onPressed: () {
                      _searchCtrl.text = result;
                      _searchQuery = result;
                      _applyFilters();
                    },
                  )
                : null,
          ),
        );
      }
    }
  }

  void _showFilterSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        var localEquipment = _selectedEquipment;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: context.klColors.tertiaryLabel.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '器材筛选',
                      style: context.klTypography.title3.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    _PressableScale(
                      onTap: () => setSheetState(() => localEquipment = null),
                      child: Text(
                        '重置',
                        style: TextStyle(
                          color: context.klColors.primaryAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _equipments.map((eq) {
                    final sel = localEquipment == eq;
                    return _PressableScale(
                      onTap: () =>
                          setSheetState(() => localEquipment = sel ? null : eq),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? context.klColors.primaryAccent.withValues(alpha: 0.1)
                              : context.klColors.tertiarySystemBackground,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: sel
                              ? [
                                  BoxShadow(
                                    color: context.klColors.primaryAccent.withValues(alpha: 0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                          border: sel
                              ? Border.all(color: context.klColors.primaryAccent, width: 0.5)
                              : null,
                        ),
                        child: Text(
                          ExerciseLabels.equipment(eq),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                            color: sel
                                ? context.klColors.primaryAccent
                                : context.klColors.secondaryLabel,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: _PressableScale(
                    onTap: () {
                      setState(() {
                        _selectedEquipment =
                            localEquipment == 'all' ? null : localEquipment;
                      });
                      _applyFilters();
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: context.klColors.primaryAccent,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: context.klColors.primaryAccent.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '确定',
                          style: TextStyle(
                            color: context.klColors.label,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;

    return Scaffold(
      body: _loading
          ? const SkeletonGrid()
          : SafeArea(
              child: CustomScrollView(
                controller: _scrollCtrl,
                physics: const ClampingScrollPhysics(),
                slivers: [
                  // ── Large title + sort + filter ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.categoryLabel ?? '全部练习',
                              style: typography.title1,
                            ),
                          ),
                          _sortDropdown(colors, typography),
                          const SizedBox(width: 8),
                          _PressableScale(
                            onTap: _showFilterSheet,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: colors.tertiarySystemBackground,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.label.withValues(alpha: 0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.tune_rounded,
                                size: 20,
                                color: colors.secondaryLabel,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Search bar ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: colors.tertiarySystemBackground,
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
                                      color: colors.placeholder, fontSize: 15),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: TextStyle(
                                    color: colors.label, fontSize: 15),
                                onChanged: (v) {
                                  _searchQuery = v;
                                  _searchDebounce?.cancel();
                                  _searchDebounce = Timer(
                                    const Duration(milliseconds: 300),
                                    _applyFilters,
                                  );
                                },
                              ),
                            ),
                            // AI search button
                            _PressableScale(
                              onTap: () => _showAISearch(colors),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 16,
                                  color: colors.primaryAccent,
                                ),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              _PressableScale(
                                onTap: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                  _applyFilters();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(Icons.close_rounded,
                                      size: 18, color: colors.tertiaryLabel),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Category pills ──
                  if (widget.initialCategory == null)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _pill(colors, null, '全部'),
                            ..._categories.map((c) => _pill(
                                colors, c, ExerciseLabels.category(c))),
                          ],
                        ),
                      ),
                    ),

                  // ── Equipment group pills ──
                  if (widget.initialEquipmentGroup == null)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _equipmentGroupPill(colors, null, '全部器械'),
                            ...EquipmentGroup.all.map((g) =>
                                _equipmentGroupPill(colors, g.key, g.label)),
                          ],
                        ),
                      ),
                    ),

                  // ── Target pills ──
                  if (widget.initialTarget == null)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _targetPill(colors, null, '全部肌群'),
                            ..._targets.map((t) => _targetPill(
                                colors, t, ExerciseLabels.target(t))),
                          ],
                        ),
                      ),
                    ),

                  // ── Result count + active tags ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                      child: Row(
                        children: [
                          Text(
                            '${_filtered.length} 个动作',
                            style: typography.footnote.copyWith(
                              color: colors.tertiaryLabel,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          if (_selectedEquipmentGroup != null) ...[
                            const SizedBox(width: 8),
                            _activeTag(
                              colors,
                              typography,
                              EquipmentGroup.all
                                  .firstWhere((g) => g.key == _selectedEquipmentGroup)
                                  .label,
                              () {
                                setState(() => _selectedEquipmentGroup = null);
                                _applyFilters();
                              },
                            ),
                          ],
                          if (_selectedEquipment != null) ...[
                            const SizedBox(width: 8),
                            _equipmentTag(colors, typography),
                          ],
                          if (_selectedTarget != null && _selectedTarget != 'all') ...[
                            const SizedBox(width: 8),
                            _activeTag(
                              colors,
                              typography,
                              ExerciseLabels.target(_selectedTarget!),
                              () {
                                setState(() => _selectedTarget = null);
                                _applyFilters();
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // ── Exercise grid or empty state ──
                  if (_filtered.isEmpty)
                    SliverFillRemaining(
                      child: _buildEmptyState(colors, typography),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final e = _filtered[i];
                            return ExerciseCard(
                              exercise: e,
                              isFavorite: _favoriteIds.contains(e.id),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ExerciseDetailScreen(exercise: e),
                                ),
                              ),
                              onToggleFavorite: () => _toggleFav(e.id),
                            );
                          },
                          childCount: _filtered.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  // ── Empty state with suggestions ──

  Widget _buildEmptyState(KLColorScheme colors, KLTypography typography) {
    final suggestions = <_Suggestion>[];
    final cat = _selectedCategory;
    final eqGroup = _selectedEquipmentGroup;
    final target = _selectedTarget;

    if (cat != null) {
      for (final g in EquipmentGroup.all) {
        if (g.key != eqGroup) {
          final count =
              ExerciseService.filter(category: cat, equipmentGroup: g.key).length;
          if (count > 0) {
            suggestions.add(_Suggestion(
              '${ExerciseLabels.category(cat)} + ${g.label}',
              count,
              () {
                setState(() => _selectedEquipmentGroup = g.key);
                _applyFilters();
              },
            ));
            if (suggestions.length >= 3) break;
          }
        }
      }
    }
    if (eqGroup != null && suggestions.isEmpty) {
      for (final c in _categories) {
        if (c != cat) {
          final count =
              ExerciseService.filter(category: c, equipmentGroup: eqGroup).length;
          if (count > 0) {
            suggestions.add(_Suggestion(
              '${ExerciseLabels.category(c)} + ${EquipmentGroup.all.firstWhere((g) => g.key == eqGroup).label}',
              count,
              () {
                setState(() => _selectedCategory = c);
                _applyFilters();
              },
            ));
            if (suggestions.length >= 3) break;
          }
        }
      }
    }
    if (target != null && suggestions.isEmpty) {
      for (final c in _categories) {
        final count = ExerciseService.filter(category: c, target: target).length;
        if (count > 0) {
          suggestions.add(_Suggestion(
            '${ExerciseLabels.category(c)} + ${ExerciseLabels.target(target)}',
            count,
            () {
              setState(() => _selectedCategory = c);
              _applyFilters();
            },
          ));
          if (suggestions.length >= 3) break;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              size: 48, color: colors.tertiaryLabel),
          const SizedBox(height: 12),
          Text(
            '没有找到匹配的动作',
            style: typography.callout.copyWith(
              color: colors.secondaryLabel,
            ),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              '试试这些组合',
              style: typography.footnote.copyWith(
                color: colors.tertiaryLabel,
              ),
            ),
            const SizedBox(height: 12),
            ...suggestions.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PressableScale(
                    onTap: s.onTap,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: colors.primaryAccent.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colors.primaryAccent.withValues(alpha: 0.12),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primaryAccent.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            s.label,
                            style: typography.callout.copyWith(
                              color: colors.primaryAccent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.primaryAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${s.count}',
                              style: typography.caption2.copyWith(
                                color: colors.primaryAccent,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  // ── Sort dropdown ──

  Widget _sortDropdown(KLColorScheme colors, KLTypography typography) {
    return _PressableScale(
      onTap: () {
        showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(
            MediaQuery.of(context).size.width - 160,
            60,
            MediaQuery.of(context).size.width - 20,
            100,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          items: _sortOptions.map((opt) => PopupMenuItem<String>(
            value: opt.key,
            child: Row(
              children: [
                if (_sortBy == opt.key)
                  Icon(Icons.check_rounded,
                      size: 16, color: colors.primaryAccent)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(opt.label, style: const TextStyle(fontSize: 14)),
              ],
            ),
          )).toList(),
        ).then((value) {
          if (value != null) {
            setState(() => _sortBy = value);
            _applyFilters();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.tertiarySystemBackground,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: colors.label.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, size: 16, color: colors.secondaryLabel),
            const SizedBox(width: 4),
            Text(
              _sortOptions.firstWhere((o) => o.key == _sortBy).label,
              style: typography.caption2.copyWith(
                color: colors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pill widgets ──

  Widget _pill(KLColorScheme colors, String? cat, String label) {
    final sel = _selectedCategory == cat;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: _PressableScale(
        onTap: () {
          setState(() => _selectedCategory = sel ? null : cat);
          _applyFilters();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: sel
                ? colors.primaryAccent
                : colors.tertiarySystemBackground,
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

  Widget _targetPill(KLColorScheme colors, String? target, String label) {
    final sel = _selectedTarget == target;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: _PressableScale(
        onTap: () {
          setState(() => _selectedTarget = sel ? null : target);
          _applyFilters();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: sel
                ? colors.primaryAccent
                : colors.tertiarySystemBackground,
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

  Widget _equipmentGroupPill(
      KLColorScheme colors, String? groupKey, String label) {
    final sel = _selectedEquipmentGroup == groupKey;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: _PressableScale(
        onTap: () {
          setState(() => _selectedEquipmentGroup = sel ? null : groupKey);
          _applyFilters();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: sel
                ? colors.primaryAccent
                : colors.tertiarySystemBackground,
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

  // ── Tag widgets ──

  Widget _equipmentTag(KLColorScheme colors, KLTypography typography) {
    return _activeTag(
      colors,
      typography,
      ExerciseLabels.equipment(_selectedEquipment!),
      () {
        setState(() => _selectedEquipment = null);
        _applyFilters();
      },
    );
  }

  Widget _activeTag(
    KLColorScheme colors,
    KLTypography typography,
    String label,
    VoidCallback onClear,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.primaryAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: typography.caption2.copyWith(
              fontWeight: FontWeight.w500,
              color: colors.primaryAccent,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 4),
          _PressableScale(
            onTap: onClear,
            child: Icon(Icons.close_rounded,
                size: 14, color: colors.primaryAccent),
          ),
        ],
      ),
    );
  }
}

class _SortOption {
  final String key;
  final String label;
  const _SortOption(this.key, this.label);
}

class _Suggestion {
  final String label;
  final int count;
  final VoidCallback onTap;
  _Suggestion(this.label, this.count, this.onTap);
}
