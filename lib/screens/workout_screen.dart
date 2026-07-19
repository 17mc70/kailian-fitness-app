import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/exercise.dart';
import '../models/workout_plan.dart';
import '../models/workout_session.dart';
import '../services/exercise_service.dart';
import '../services/database_service.dart';
import '../design/theme/kl_theme.dart';

/// ── Set row ──

class _SetRow extends StatefulWidget {
  final ExerciseSet set;
  final int setNumber;
  final VoidCallback onToggle;
  final void Function(ExerciseSet updatedSet)? onSetChanged;

  const _SetRow({
    super.key,
    required this.set,
    required this.setNumber,
    required this.onToggle,
    this.onSetChanged,
  });

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late TextEditingController _weightCtrl;
  late TextEditingController _repsCtrl;

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(
      text: widget.set.weight > 0 ? _weightText(widget.set.weight) : '',
    );
    _repsCtrl = TextEditingController(
      text: widget.set.reps > 0 ? widget.set.reps.toString() : '',
    );
  }

  @override
  void didUpdateWidget(covariant _SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.set.weight != widget.set.weight) {
      final newText = widget.set.weight > 0
          ? _weightText(widget.set.weight)
          : '';
      if (_weightCtrl.text != newText) _weightCtrl.text = newText;
    }
    if (oldWidget.set.reps != widget.set.reps) {
      final newText = widget.set.reps > 0 ? widget.set.reps.toString() : '';
      if (_repsCtrl.text != newText) _repsCtrl.text = newText;
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  /// Format weight without trailing ".0" for whole numbers.
  static String _weightText(double w) {
    if (w <= 0) return '';
    if (w == w.roundToDouble()) return w.round().toString();
    return w.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: widget.set.isCompleted
            ? colors.primaryAccent.withValues(alpha: 0.04)
            : colors.tertiarySystemBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.set.isCompleted
              ? colors.primaryAccent.withValues(alpha: 0.2)
              : colors.separator,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${widget.setNumber}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colors.secondaryLabel,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: TextField(
                controller: _weightCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: _inputDeco(colors),
                onChanged: (v) {
                  final w = double.tryParse(v) ?? 0;
                  widget.onSetChanged?.call(widget.set.copyWith(weight: w));
                },
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: TextField(
                controller: _repsCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: _inputDeco(colors),
                onChanged: (v) {
                  final r = int.tryParse(v) ?? 0;
                  widget.onSetChanged?.call(widget.set.copyWith(reps: r));
                },
              ),
            ),
          ),
          GestureDetector(
            onTap: widget.onToggle,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.set.isCompleted
                    ? colors.positive
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.set.isCompleted
                      ? colors.positive
                      : colors.separator,
                  width: widget.set.isCompleted ? 0 : 1.5,
                ),
              ),
              child: widget.set.isCompleted
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 20,
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(KLColorScheme colors) => InputDecoration(
    isDense: true,
    hintText: '0',
    hintStyle: TextStyle(color: colors.placeholder),
    filled: true,
    fillColor: colors.secondarySystemBackground,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(vertical: 8),
  );
}

/// ── Main workout screen ──

class WorkoutScreen extends StatefulWidget {
  final WorkoutPlan plan;

  const WorkoutScreen({super.key, required this.plan});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen>
    with WidgetsBindingObserver {
  final List<ExerciseLogEntry> _logs = [];
  int _currentIndex = 0;
  int? _sessionId;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _timeStr = '00:00';
  bool _finished = false;
  bool _isWarmingUp = true;
  int _warmupSeconds = 60;
  static const int _initialWarmupSeconds = 60;
  Timer? _warmupTimer;

  // Rest timer
  final int _restDuration = 60;
  static const int _maxRestDuration = 300;
  int _restRemaining = 0;
  Timer? _restTimer;
  bool _isResting = false;

  late List<Exercise> _exercises;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _exercises = widget.plan.exerciseIds
        .map((id) => ExerciseService.findById(id))
        .whereType<Exercise>()
        .toList();
    _startSession();
  }

  Future<void> _startSession() async {
    final session = WorkoutSession(
      planId: widget.plan.id,
      planName: widget.plan.name,
      startTime: DateTime.now(),
    );
    final id = await DatabaseService.saveSession(session);
    if (!mounted) return;
    setState(() => _sessionId = id);
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _timeStr = _formatTime(_stopwatch.elapsed));
    });

    for (final ex in _exercises) {
      _logs.add(
        ExerciseLogEntry(
          sessionId: id,
          exerciseId: ex.id,
          exerciseName: ex.name,
          sets: [ExerciseSet(setNumber: 1)],
        ),
      );
    }
    if (!mounted) return;
    setState(() {});

    _warmupTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _warmupTimer?.cancel();
        return;
      }
      setState(() {
        if (_warmupSeconds > 0) _warmupSeconds--;
        if (_warmupSeconds == 0) {
          _warmupTimer?.cancel();
          _isWarmingUp = false;
        }
      });
    });
  }

  String _formatTime(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hour = d.inHours.toString().padLeft(2, '0');
    if (d.inHours > 0) return '$hour:$min:$sec';
    return '$min:$sec';
  }

  void _addSet(int logIndex) {
    setState(() {
      final entry = _logs[logIndex];
      final updatedSets = List<ExerciseSet>.from(entry.sets)
        ..add(ExerciseSet(setNumber: entry.sets.length + 1));
      _logs[logIndex] = entry.copyWith(sets: updatedSets);
    });
  }

  void _removeSet(int logIndex, int setIndex) {
    if (_logs[logIndex].sets.length <= 1) return;
    setState(() {
      final entry = _logs[logIndex];
      final updatedSets = List<ExerciseSet>.from(entry.sets)
        ..removeAt(setIndex);
      for (int i = 0; i < updatedSets.length; i++) {
        updatedSets[i] = updatedSets[i].copyWith(setNumber: i + 1);
      }
      _logs[logIndex] = entry.copyWith(sets: updatedSets);
    });
  }

  void _updateSet(int logIndex, int setIndex, ExerciseSet updatedSet) {
    setState(() {
      final entry = _logs[logIndex];
      final updatedSets = List<ExerciseSet>.from(entry.sets);
      updatedSets[setIndex] = updatedSet;
      _logs[logIndex] = entry.copyWith(sets: updatedSets);
    });
  }

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _restRemaining = seconds;
      _isResting = true;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _restTimer?.cancel();
        return;
      }
      setState(() {
        if (_restRemaining > 0) _restRemaining--;
        if (_restRemaining == 0) {
          _isResting = false;
          _restTimer?.cancel();
          HapticFeedback.heavyImpact();
        }
      });
    });
  }

  void _skipWarmup() {
    _warmupTimer?.cancel();
    if (mounted) setState(() => _isWarmingUp = false);
  }

  void _skipRest() {
    _restTimer?.cancel();
    if (mounted) {
      setState(() {
        _isResting = false;
        _restRemaining = 0;
      });
    }
  }

  Future<void> _saveCheckpoint() async {
    final sid = _sessionId;
    if (sid == null) return;
    final updatedLogs = await DatabaseService.saveSessionCheckpoint(sid, _logs);
    _logs
      ..clear()
      ..addAll(updatedLogs);
  }

  Future<void> _finishWorkout() async {
    if (_finished) return;
    final sid = _sessionId;
    if (sid == null) return;
    _restTimer?.cancel();
    _restTimer = null;
    _isResting = false;
    _restRemaining = 0;
    await _saveCheckpoint();
    await DatabaseService.updateSessionEndTime(sid);
    _stopwatch.stop();
    _timer?.cancel();
    if (mounted) {
      setState(() => _finished = true);
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _showExitConfirm() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('退出训练？'),
        content: const Text('训练进度将自动保存，下次可从计划页继续查看。'),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pop(ctx, false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: const Text('继续训练'),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                '退出',
                style: TextStyle(color: context.klColors.negative),
              ),
            ),
          ),
        ],
      ),
    );
    if (shouldExit == true && mounted) {
      await _saveCheckpoint();
      if (_sessionId != null) {
        await DatabaseService.updateSessionEndTime(_sessionId!);
      }
      _stopwatch.stop();
      _timer?.cancel();
      _restTimer?.cancel();
      _warmupTimer?.cancel();
      if (mounted) Navigator.pop(context);
    }
  }

  void _showExerciseDetail(Exercise? ex) {
    if (ex == null) return;
    final steps = ex.getSteps('zh');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final themeColors = KLTheme.of(ctx).colors;
        final themeTypo = KLTheme.of(ctx).typography;
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: themeColors.tertiaryLabel.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        ex.name,
                        style: themeTypo.title3.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: themeColors.tertiarySystemBackground,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: themeColors.secondaryLabel,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: themeColors.tertiarySystemBackground,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          ex.gifUrl,
                          fit: BoxFit.contain,
                          cacheWidth: 720,
                          errorBuilder: (_, _, _) => Image.asset(
                            ex.image,
                            fit: BoxFit.contain,
                            cacheWidth: 720,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.fitness_center,
                              size: 48,
                              color: themeColors.tertiaryLabel,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (steps.isNotEmpty) ...[
                      Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: themeColors.primaryAccent.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.list_alt_rounded,
                              size: 14,
                              color: themeColors.primaryAccent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '动作要领',
                            style: themeTypo.subhead.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(steps.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                margin: const EdgeInsets.only(top: 1),
                                decoration: BoxDecoration(
                                  color: themeColors.primaryAccent.withValues(
                                    alpha: 0.12,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    color: themeColors.primaryAccent,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  steps[i],
                                  style: themeTypo.callout.copyWith(
                                    height: 1.5,
                                    color: themeColors.secondaryLabel,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _stopwatch.stop();
      _timer?.cancel();
      _timer = null;
      if (_isResting) {
        _restTimer?.cancel();
        _restTimer = null;
      }
      if (_isWarmingUp) {
        _warmupTimer?.cancel();
        _warmupTimer = null;
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_finished || _sessionId == null) return;
      _stopwatch.start();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _timeStr = _formatTime(_stopwatch.elapsed));
      });
      if (_isResting && _restRemaining > 0) _resumeRestTimer();
      if (_isWarmingUp && _warmupSeconds > 0) _resumeWarmupTimer();
    }
  }

  void _resumeRestTimer() {
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _restTimer?.cancel();
        return;
      }
      setState(() {
        if (_restRemaining > 0) _restRemaining--;
        if (_restRemaining == 0) {
          _isResting = false;
          _restTimer?.cancel();
          HapticFeedback.heavyImpact();
        }
      });
    });
  }

  void _resumeWarmupTimer() {
    _warmupTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _warmupTimer?.cancel();
        return;
      }
      setState(() {
        if (_warmupSeconds > 0) _warmupSeconds--;
        if (_warmupSeconds == 0) {
          _warmupTimer?.cancel();
          _isWarmingUp = false;
        }
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restTimer?.cancel();
    _warmupTimer?.cancel();
    _timer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;

    if (_exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('训练')),
        body: const Center(child: Text('计划中没有动作')),
      );
    }

    if (_isWarmingUp) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (_, _) => _showExitConfirm(),
        child: _buildWarmupView(colors, typography),
      );
    }

    if (_finished) {
      return _buildFinishedView(colors, typography);
    }

    final currentLog = _logs.isNotEmpty ? _logs[_currentIndex] : null;
    final currentEx = _exercises.isNotEmpty ? _exercises[_currentIndex] : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitConfirm();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // ── Top bar: timer + progress ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _showExitConfirm,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.tertiarySystemBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: colors.secondaryLabel,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.plan.name,
                            style: typography.subhead.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 13,
                                color: colors.tertiaryLabel,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _timeStr,
                                style: typography.footnote.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: colors.tertiaryLabel,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        showMenu(
                          context: context,
                          position: RelativeRect.fromLTRB(
                            MediaQuery.of(context).size.width - 60,
                            60,
                            MediaQuery.of(context).size.width - 20,
                            100,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          items: _exercises.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final ex = entry.value;
                            final log = _logs.length > idx ? _logs[idx] : null;
                            final completed =
                                log?.sets.any((s) => s.isCompleted) ?? false;
                            return PopupMenuItem<int>(
                              value: idx,
                              child: Row(
                                children: [
                                  Icon(
                                    completed
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                    size: 16,
                                    color: completed
                                        ? colors.positive
                                        : colors.tertiaryLabel,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${idx + 1}. ${ex.name}',
                                    style: TextStyle(
                                      fontWeight: idx == _currentIndex
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ).then((v) {
                          if (v != null && v != _currentIndex) {
                            _saveCheckpoint().catchError(
                              (e) => debugPrint('_saveCheckpoint: $e'),
                            );
                            setState(() => _currentIndex = v);
                          }
                        });
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.tertiarySystemBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.list_alt_rounded,
                          size: 20,
                          color: colors.secondaryLabel,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Progress bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Row(
                  children: [
                    Text(
                      '${_currentIndex + 1} / ${_exercises.length}',
                      style: typography.caption2.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.primaryAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: (_currentIndex + 1) / _exercises.length,
                          minHeight: 4,
                          backgroundColor: colors.tertiarySystemBackground,
                          color: colors.primaryAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Exercise card ──
              GestureDetector(
                onTap: () => _showExerciseDetail(currentEx),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.secondarySystemBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.separator, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: colors.tertiarySystemBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: currentEx != null
                              ? Image.asset(
                                  currentEx.image,
                                  fit: BoxFit.cover,
                                  cacheWidth: 168,
                                )
                              : const SizedBox(),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentEx?.name ?? '',
                              style: typography.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (currentEx != null)
                              Text(
                                '${Exercise.categoryLabel(currentEx.category)} · ${Exercise.equipmentLabel(currentEx.equipment)}',
                                style: typography.caption2.copyWith(
                                  color: colors.tertiaryLabel,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colors.tertiarySystemBackground,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: colors.tertiaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Sets table ──
              Expanded(
                child: currentLog == null
                    ? const SizedBox()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        children: [
                          // Header
                          Row(
                            children: [
                              const SizedBox(width: 28),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '重量 (kg)',
                                    style: typography.footnote.copyWith(
                                      color: colors.tertiaryLabel,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    '次数',
                                    style: typography.footnote.copyWith(
                                      color: colors.tertiaryLabel,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 36),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Sets
                          ...currentLog.sets.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final set = entry.value;
                            return _SetRow(
                              key: ValueKey('$_currentIndex-$idx'),
                              set: set,
                              setNumber: set.setNumber,
                              onToggle: () {
                                final was = set.isCompleted;
                                final toggled = set.copyWith(isCompleted: !was);
                                _updateSet(_currentIndex, idx, toggled);
                                if (!was && toggled.isCompleted) {
                                  _startRestTimer(_restDuration);
                                }
                              },
                              onSetChanged: (updated) {
                                _updateSet(_currentIndex, idx, updated);
                              },
                            );
                          }),

                          // Add / remove set
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _addSet(_currentIndex),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.primaryAccent.withValues(
                                          alpha: 0.06,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_rounded,
                                            size: 16,
                                            color: colors.primaryAccent,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '添加一组',
                                            style: typography.footnote.copyWith(
                                              fontWeight: FontWeight.w500,
                                              color: colors.primaryAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (currentLog.sets.length > 1)
                                  const SizedBox(width: 8),
                                if (currentLog.sets.length > 1)
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _removeSet(
                                        _currentIndex,
                                        currentLog.sets.length - 1,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.negative.withValues(
                                            alpha: 0.06,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.remove_rounded,
                                              size: 16,
                                              color: colors.negative,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '移除',
                                              style: typography.footnote
                                                  .copyWith(
                                                    fontWeight: FontWeight.w500,
                                                    color: colors.negative,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
              ),

              // ── Bottom navigation ──
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  decoration: BoxDecoration(
                    color: colors.systemBackground.withValues(alpha: 0.95),
                    border: Border(
                      top: BorderSide(color: colors.separator, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_currentIndex > 0)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _saveCheckpoint().catchError(
                                (e) => debugPrint('_saveCheckpoint: $e'),
                              );
                              setState(() => _currentIndex--);
                            },
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: colors.separator),
                              ),
                              child: const Center(
                                child: Text(
                                  '上一个',
                                  style: TextStyle(fontSize: 15),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_currentIndex > 0) const SizedBox(width: 12),
                      Expanded(
                        flex: _currentIndex > 0 ? 1 : 1,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            if (_currentIndex < _exercises.length - 1) {
                              _saveCheckpoint().catchError(
                                (e) => debugPrint('_saveCheckpoint: $e'),
                              );
                              setState(() => _currentIndex++);
                            } else {
                              _finishWorkout();
                            }
                          },
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: colors.primaryAccent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _currentIndex < _exercises.length - 1
                                        ? Icons.arrow_forward_rounded
                                        : Icons.check_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _currentIndex < _exercises.length - 1
                                        ? '下一个'
                                        : '完成训练',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Rest timer overlay ──
              if (_isResting)
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 18,
                  ),
                  decoration: BoxDecoration(
                    color: colors.secondarySystemBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.separator, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: (_restRemaining / _restDuration).clamp(
                                0.0,
                                1.0,
                              ),
                              strokeWidth: 4,
                              backgroundColor: colors.tertiarySystemBackground,
                              color: colors.primaryAccent,
                            ),
                            Center(
                              child: Text(
                                '$_restRemaining',
                                style: typography.subhead.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '休息中',
                        style: typography.subhead.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(
                          () => _restRemaining = (_restRemaining + 30).clamp(
                            0,
                            _maxRestDuration,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colors.tertiarySystemBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '+30s',
                            style: typography.footnote.copyWith(
                              fontWeight: FontWeight.w500,
                              color: colors.primaryAccent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _skipRest,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primaryAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '跳过',
                            style: typography.footnote.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Warmup view ──

  Widget _buildWarmupView(KLColorScheme colors, KLTypography typography) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: colors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    size: 40,
                    color: colors.warning,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '训练前热身',
                  style: typography.title2.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_warmupSeconds 秒后自动开始训练',
                  style: typography.callout.copyWith(
                    color: colors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: 88,
                  height: 88,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: 1 - (_warmupSeconds / _initialWarmupSeconds),
                        strokeWidth: 6,
                        backgroundColor: colors.tertiarySystemBackground,
                        color: colors.warning,
                      ),
                      Center(
                        child: Text(
                          '$_warmupSeconds',
                          style: typography.title1.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                GestureDetector(
                  onTap: _skipWarmup,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primaryAccent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.skip_next_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '跳过热身直接开始',
                          style: typography.subhead.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.tertiarySystemBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.separator, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 16,
                            color: colors.warning,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '热身建议',
                            style: typography.subhead.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '简单活动关节、轻度拉伸 3-5 分钟\n'
                        '可有效预防受伤、提升训练表现',
                        style: typography.footnote.copyWith(
                          color: colors.secondaryLabel,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Finished view ──

  Widget _buildFinishedView(KLColorScheme colors, KLTypography typography) {
    final totalSets = _logs.fold(
      0,
      (sum, l) => sum + l.sets.where((s) => s.isCompleted).length,
    );
    final totalVolume = _logs.fold(0.0, (sum, l) => sum + l.totalVolume);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 32),
            // Icon
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colors.positive.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 44,
                  color: colors.positive,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '训练完成！',
                style: typography.title1.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Center(
              child: Text(
                widget.plan.name,
                style: typography.callout.copyWith(
                  color: colors.secondaryLabel,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.secondarySystemBackground,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.separator, width: 0.5),
              ),
              child: Column(
                children: [
                  _statRow(colors, typography, '训练时长', _timeStr),
                  const SizedBox(height: 12),
                  _divider(colors),
                  const SizedBox(height: 12),
                  _statRow(colors, typography, '完成组数', '$totalSets 组'),
                  const SizedBox(height: 12),
                  _divider(colors),
                  const SizedBox(height: 12),
                  _statRow(
                    colors,
                    typography,
                    '总训练量',
                    '${totalVolume.toStringAsFixed(0)} kg',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Per exercise
            Text(
              '各动作完成情况',
              style: typography.title3.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            ..._logs.asMap().entries.map((entry) {
              final log = entry.value;
              final ex = _exercises.length > entry.key
                  ? _exercises[entry.key]
                  : null;
              final completedSets = log.sets.where((s) => s.isCompleted).length;
              if (completedSets == 0 && log.totalVolume == 0) {
                return const SizedBox.shrink();
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.secondarySystemBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.separator, width: 0.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.tertiarySystemBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: ex != null
                            ? Image.asset(
                                ex.image,
                                fit: BoxFit.cover,
                                cacheWidth: 144,
                                errorBuilder: (_, _, _) => Icon(
                                  Icons.fitness_center,
                                  color: colors.tertiaryLabel,
                                ),
                              )
                            : const Icon(Icons.fitness_center),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.exerciseName,
                            style: typography.subhead.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$completedSets 组 · ${log.totalVolume.toStringAsFixed(0)} kg'
                            '${log.sets.any((s) => s.weight > 0) ? " · 最大 ${log.sets.where((s) => s.isCompleted).fold<double>(0, (m, s) => s.weight > m ? s.weight : m)} kg" : ""}',
                            style: typography.caption2.copyWith(
                              color: colors.tertiaryLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: completedSets > 0
                            ? colors.positive.withValues(alpha: 0.1)
                            : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$completedSets 组',
                        style: typography.caption2.copyWith(
                          fontWeight: FontWeight.w600,
                          color: completedSets > 0
                              ? colors.positive
                              : colors.tertiaryLabel,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: colors.primaryAccent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    '返回首页',
                    style: typography.headline.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _statRow(
    KLColorScheme colors,
    KLTypography typography,
    String label,
    String value,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: typography.subhead.copyWith(color: colors.secondaryLabel),
        ),
        Text(
          value,
          style: typography.body.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _divider(KLColorScheme colors) {
    return Container(height: 1, color: colors.separator);
  }
}
