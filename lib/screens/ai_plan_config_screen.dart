import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../agent/agent_service.dart';
import '../agent/fitness_agent.dart';
import '../models/exercise.dart';
import '../models/workout_plan.dart';
import '../services/database_service.dart';
import '../services/exercise_service.dart';
import '../utils/exercise_labels.dart';
import '../design/theme/kl_theme.dart';

/// Screen that lets users configure and generate an AI-powered workout plan.
class AIPlanConfigScreen extends StatefulWidget {
  const AIPlanConfigScreen({super.key});

  @override
  State<AIPlanConfigScreen> createState() => _AIPlanConfigScreenState();
}

class _AIPlanConfigScreenState extends State<AIPlanConfigScreen> {
  // ── Config state ──
  String _goal = 'hypertrophy';
  String _experience = 'intermediate';
  int _daysPerWeek = 3;
  final Set<String> _selectedEquipment = {};
  String _focusMuscle = '';
  bool _generating = false;
  AgentPlanResult? _result;

  List<Exercise> _allExercises = [];

  static const _goals = [
    ('hypertrophy', '增肌', Icons.fitness_center_rounded),
    ('strength', '力量', Icons.bolt_rounded),
    ('endurance', '耐力', Icons.timer_rounded),
    ('fat_loss', '减脂', Icons.local_fire_department_rounded),
  ];

  static const _expLevels = [
    ('beginner', '新手'),
    ('intermediate', '中级'),
    ('advanced', '高级'),
  ];

  static const _focusOptions = [
    '',
    'chest',
    'back',
    'shoulders',
    'upper legs',
    'upper arms',
    'waist',
  ];

  String _focusLabel(String? en) {
    if (en == null || en.isEmpty) return '不限';
    return ExerciseLabels.category(en);
  }

  @override
  void initState() {
    super.initState();
    _loadEquipment();
  }

  Future<void> _loadEquipment() async {
    final exercises = await ExerciseService.loadExercises();
    if (!mounted) return;
    setState(() {
      _allExercises = exercises;
      // Default: body weight always available
      _selectedEquipment.add('body weight');
    });
  }

  Future<void> _generate() async {
    HapticFeedback.mediumImpact();
    setState(() => _generating = true);

    try {
      final service = FitnessAgentService.instance;
      final request = PlanRequest(
        goal: _goal,
        availableEquipment: _selectedEquipment.toList(),
        experienceLevel: _experience,
        daysPerWeek: _daysPerWeek,
        focusMuscles: _focusMuscle.isNotEmpty ? [_focusMuscle] : null,
      );

      final result = await service.currentAgent.generatePlan(request);
      if (!mounted) return;
      setState(() {
        _result = result;
        _generating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('生成失败: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _savePlan() async {
    if (_result == null || _result!.days.isEmpty) return;
    HapticFeedback.lightImpact();

    // Flatten all exercises from all days
    final exerciseIds = <String>[];
    for (final day in _result!.days) {
      for (final ex in day.exercises) {
        if (ex.exerciseId.isNotEmpty && ex.exerciseId != 'unknown') {
          exerciseIds.add(ex.exerciseId);
        }
      }
    }

    if (exerciseIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('计划中没有有效的练习，无法保存'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final goalLabel = _goalLabel(_goal);
    final plan = WorkoutPlan(
      name: 'AI · $goalLabel ($_daysPerWeek天)',
      description: _result!.description.isNotEmpty
          ? _result!.description
          : '由 AI 教练生成的 $goalLabel 训练计划，每周 $_daysPerWeek 天',
      exerciseIds: exerciseIds,
    );

    try {
      await DatabaseService.savePlan(plan);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('计划已保存！'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;

    return Scaffold(
      backgroundColor: colors.systemBackground,
      appBar: AppBar(
        backgroundColor: colors.systemBackground,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('AI 生成计划', style: typography.title2),
        centerTitle: false,
        actions: [
          if (_result != null)
            TextButton(
              onPressed: _savePlan,
              child: const Text('保存'),
            ),
        ],
      ),
      body: _generating
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('AI 教练正在为你定制计划...'),
                ],
              ),
            )
          : _result != null
              ? _buildResultView(colors, typography)
              : _buildConfigView(colors, typography),
    );
  }

  Widget _buildConfigView(KLColorScheme colors, KLTypography typography) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Goal ──
          Text('训练目标', style: typography.title3),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _goals.map((g) {
              final sel = _goal == g.$1;
              return _ChoiceChip(
                selected: sel,
                label: g.$2,
                icon: g.$3,
                onTap: () => setState(() => _goal = g.$1),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── Experience ──
          Text('经验水平', style: typography.title3),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: _expLevels.map((e) {
              final sel = _experience == e.$1;
              return _ChoiceChip(
                selected: sel,
                label: e.$2,
                onTap: () => setState(() => _experience = e.$1),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── Days per week ──
          Text('每周训练天数', style: typography.title3),
          const SizedBox(height: 10),
          Row(
            children: [
              for (int d = 1; d <= 6; d++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ChoiceChip(
                    selected: _daysPerWeek == d,
                    label: d.toString(),
                    onTap: () => setState(() => _daysPerWeek = d),
                    compact: true,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Equipment ──
          Text('可用器材', style: typography.title3),
          const SizedBox(height: 6),
          Text(
            '选择你已有的器材，AI 会只推荐能练的动作',
            style: typography.footnote.copyWith(color: colors.secondaryLabel),
          ),
          const SizedBox(height: 10),
          if (_allExercises.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExerciseService.equipmentList.map((eq) {
                final sel = _selectedEquipment.contains(eq);
                return FilterChip(
                  label: Text(
                    ExerciseLabels.equipment(eq),
                    style: TextStyle(
                      fontSize: 12,
                      color: sel ? Colors.white : colors.label,
                    ),
                  ),
                  selected: sel,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedEquipment.add(eq);
                      } else {
                        _selectedEquipment.remove(eq);
                      }
                    });
                  },
                  selectedColor: colors.primaryAccent,
                  checkmarkColor: Colors.white,
                  backgroundColor: colors.tertiarySystemBackground,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          const SizedBox(height: 24),

          // ── Focus muscle ──
          Text('专注部位（可选）', style: typography.title3),
          const SizedBox(height: 6),
          Text(
            '如果只想练某个部位，可以选择专注',
            style: typography.footnote.copyWith(color: colors.secondaryLabel),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: _focusOptions.map((f) {
              final sel = _focusMuscle == f;
              return _ChoiceChip(
                selected: sel,
                label: _focusLabel(f),
                onTap: () => setState(() => _focusMuscle = f),
                compact: true,
              );
            }).toList(),
          ),
          const SizedBox(height: 40),

          // ── Generate button ──
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _selectedEquipment.isNotEmpty ? _generate : null,
              icon: Icon(
                FitnessAgentService.instance.isUsingApi
                    ? Icons.auto_awesome_rounded
                    : Icons.psychology_rounded,
              ),
              label: Text(
                FitnessAgentService.instance.isUsingApi
                    ? 'AI 生成计划'
                    : '智能生成计划',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primaryAccent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: colors.separator,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(KLColorScheme colors, KLTypography typography) {
    final result = _result!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.primaryAccent.withValues(alpha: 0.15),
                  colors.systemBackground,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  FitnessAgentService.instance.isUsingApi
                      ? Icons.auto_awesome_rounded
                      : Icons.psychology_rounded,
                  color: colors.primaryAccent,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(result.title, style: typography.title1),
                if (result.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    result.description,
                    style: typography.subhead.copyWith(
                      color: colors.secondaryLabel,
                    ),
                  ),
                ],
                if (result.explanation != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.tertiarySystemBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      result.explanation!,
                      style: typography.footnote.copyWith(
                        color: colors.secondaryLabel,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Days
          for (var i = 0; i < result.days.length; i++) ...[
            _buildDayCard(result.days[i], colors, typography, i),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildDayCard(WorkoutPlanDay day, KLColorScheme colors,
      KLTypography typography, int index) {
    final dayColors = [
      0xFFE85D3A,
      0xFF2D9CDB,
      0xFF27AE60,
      0xFF9B51E0,
      0xFFF2994A,
      0xFFEB5757,
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.secondarySystemBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.separator, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Color(dayColors[index % dayColors.length])
                  .withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Color(dayColors[index % dayColors.length]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  day.dayName,
                  style: typography.subhead.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Exercises
          ...day.exercises.map((ex) => Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(dayColors[index % dayColors.length])
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ex.exerciseName,
                            style: typography.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${ex.sets}组 × ${ex.minReps}-${ex.maxReps}次${ex.restSeconds != null ? ' · 休息 ${ex.restSeconds}' : ''}',
                            style: typography.footnote.copyWith(
                              color: colors.secondaryLabel,
                            ),
                          ),
                          if (ex.note != null && ex.note!.isNotEmpty)
                            Text(
                              ex.note!,
                              style: typography.caption2.copyWith(
                                color: colors.tertiaryLabel,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (ex.exerciseId.isNotEmpty && ex.exerciseId != 'unknown')
                      _buildExerciseThumb(ex.exerciseId, colors),
                  ],
                ),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildExerciseThumb(String id, KLColorScheme colors) {
    final ex = ExerciseService.findById(id);
    if (ex == null) return const SizedBox.shrink();

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors.tertiarySystemBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.separator, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.asset(
          ex.image,
          fit: BoxFit.cover,
          cacheWidth: 120,
          errorBuilder: (_, _, _) => Icon(
            Icons.fitness_center,
            size: 18,
            color: colors.tertiaryLabel,
          ),
        ),
      ),
    );
  }

  String _goalLabel(String goal) {
    switch (goal) {
      case 'strength': return '力量';
      case 'hypertrophy': return '增肌';
      case 'endurance': return '耐力';
      case 'fat_loss': return '减脂';
      default: return '综合';
    }
  }
}

// ── Reusable choice chip ──

class _ChoiceChip extends StatelessWidget {
  final bool selected;
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool compact;

  const _ChoiceChip({
    required this.selected,
    required this.label,
    this.icon,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 16,
          vertical: compact ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: selected
              ? colors.primaryAccent
              : colors.tertiarySystemBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? colors.primaryAccent
                : colors.separator,
            width: 0.5,
          ),
        ),
        child: icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: selected ? Colors.white : colors.secondaryLabel,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: compact ? 13 : 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? Colors.white : colors.label,
                    ),
                  ),
                ],
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 13 : 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? Colors.white : colors.label,
                ),
              ),
      ),
    );
  }
}
