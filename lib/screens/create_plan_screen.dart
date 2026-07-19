import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/exercise.dart';
import '../models/workout_plan.dart';
import '../services/exercise_service.dart';
import '../services/database_service.dart';
import '../design/theme/kl_theme.dart';

class CreatePlanScreen extends StatefulWidget {
  final WorkoutPlan? existingPlan;

  const CreatePlanScreen({super.key, this.existingPlan});

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  List<Exercise> _allExercises = [];
  List<Exercise> _filtered = [];
  List<String> _selectedIds = [];
  bool _loading = true;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.existingPlan != null) {
      _nameCtrl.text = widget.existingPlan!.name;
      _descCtrl.text = widget.existingPlan!.description ?? '';
      _selectedIds = List.from(widget.existingPlan!.exerciseIds);
    }
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
  }

  void _search(String q) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _filtered = q.isEmpty
            ? _allExercises
            : ExerciseService.search(q);
      });
    });
  }

  Future<void> _save() async {
    HapticFeedback.lightImpact();
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请输入计划名称'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请至少选择一个练习'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final plan = WorkoutPlan(
      id: widget.existingPlan?.id,
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      exerciseIds: _selectedIds,
    );

    try {
      await DatabaseService.savePlan(plan);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;

    return Scaffold(
      backgroundColor: colors.systemBackground,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: CustomScrollView(
                slivers: [
                  // ── Header ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
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
                          Expanded(
                            child: Text(
                              widget.existingPlan != null
                                  ? '编辑计划'
                                  : '创建计划',
                              style: typography.title2,
                            ),
                          ),
                          GestureDetector(
                            onTap: _save,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: colors.primaryAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '保存',
                                style: typography.subhead.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Name + description ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: colors.secondarySystemBackground,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: colors.separator, width: 0.5),
                            ),
                            child: TextField(
                              controller: _nameCtrl,
                              decoration: InputDecoration(
                                labelText: '计划名称',
                                hintText: '例如：胸肌训练日',
                                labelStyle: TextStyle(
                                    color: colors.secondaryLabel),
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: colors.secondarySystemBackground,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: colors.separator, width: 0.5),
                            ),
                            child: TextField(
                              controller: _descCtrl,
                              decoration: InputDecoration(
                                labelText: '备注（可选）',
                                hintText: '训练说明、注意事项...',
                                labelStyle: TextStyle(
                                    color: colors.secondaryLabel),
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                              ),
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Selected exercises ──
                  if (_selectedIds.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                        child: Row(
                          children: [
                            Text(
                              '已选 ${_selectedIds.length} 个动作',
                              style: typography.subhead.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
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

                  // ── Selected horizontal scroll ──
                  if (_selectedIds.isNotEmpty)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 56,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _selectedIds.length,
                          itemBuilder: (ctx, index) {
                            final id = _selectedIds[index];
                            final ex = ExerciseService.findById(id);
                            return Container(
                              width: 56,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(
                                children: [
                                  Container(
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: colors.tertiarySystemBackground,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                          color: colors.primaryAccent
                                              .withValues(alpha: 0.3),
                                          width: 1),
                                    ),
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(9),
                                      child: ex != null
                                          ? Image.asset(ex.image,
                                              fit: BoxFit.cover,
                                              cacheWidth: 160)
                                          : Icon(Icons.fitness_center,
                                              size: 16,
                                              color: colors.tertiaryLabel),
                                    ),
                                  ),
                                  Text(
                                    ex?.name ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 9),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
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

                  // ── Exercise list ──
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final e = _filtered[index];
                          final selected = _selectedIds.contains(e.id);
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
                                color: colors.secondarySystemBackground,
                                borderRadius: BorderRadius.circular(14),
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
                                      color:
                                          colors.tertiarySystemBackground,
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
                                        errorBuilder: (_, _, _) => Icon(
                                            Icons.fitness_center,
                                            color: colors.tertiaryLabel),
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
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${Exercise.categoryLabel(e.category)} · ${Exercise.equipmentLabel(e.equipment)}',
                                          style: typography.caption2
                                              .copyWith(
                                            color: colors.tertiaryLabel,
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
                                            color: Colors.white, size: 16)
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
    );
  }
}
