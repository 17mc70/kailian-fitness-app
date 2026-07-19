import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../agent/agent_service.dart';
import '../agent/fitness_agent.dart';
import '../design/theme/kl_theme.dart';
import '../models/exercise.dart';
import '../navigation/app_router.dart';
import '../services/exercise_service.dart';
import '../utils/exercise_labels.dart';
import 'ai_plan_config_screen.dart';
import 'plans_screen.dart';
import 'progress_screen.dart';
import 'quick_workout_screen.dart';

/// AI 教练对话界面
class AgentChatScreen extends StatefulWidget {
  const AgentChatScreen({super.key});

  @override
  State<AgentChatScreen> createState() => AgentChatScreenState();
}

class AgentChatScreenState extends State<AgentChatScreen> {
  final _messages = <_ChatMessage>[];
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _waiting = false;

  @override
  void initState() {
    super.initState();
    _addWelcome();
  }

  void _addWelcome() {
    _messages.add(
      _ChatMessage(
        text:
            '我是你的开练教练。\n\n'
            '你可以直接告诉我今天想练什么，或者把目标、器材和每周频率交给我。\n\n'
            '我会先查找动作，再给你一份可以执行的建议。',
        isUser: false,
      ),
    );
  }

  void refresh() {
    // No-op: chat state is local
  }

  void _addMessage(
    String text, {
    required bool isUser,
    List<String> exerciseIds = const [],
    List<AgentAction> actions = const [],
  }) {
    setState(() {
      _messages.add(
        _ChatMessage(
          text: text,
          isUser: isUser,
          exerciseIds: exerciseIds,
          actions: actions,
        ),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _waiting) return;

    HapticFeedback.lightImpact();
    _inputCtrl.clear();
    _addMessage(text, isUser: true);

    setState(() => _waiting = true);

    try {
      // Build multi-turn context from prior messages (skip the welcome
      // message and the just-added user turn; cap to recent turns).
      final history = _messages
          .where((m) => m.text.isNotEmpty)
          .map(
            (m) => ChatTurn(
              role: m.isUser ? 'user' : 'assistant',
              content: m.text,
            ),
          )
          .toList();
      if (history.isNotEmpty) history.removeLast(); // drop current question
      final trimmed = history.length > 10
          ? history.sublist(history.length - 10)
          : history;

      final answer = await FitnessAgentService.instance.currentAgent
          .answerQuery(text, history: trimmed);
      _addMessage(
        answer.answer,
        isUser: false,
        exerciseIds: answer.relatedExerciseIds ?? const [],
        actions: answer.actions,
      );
    } catch (e) {
      _addMessage('这次没有拿到有效回复。你可以检查 API 设置，或稍后再试。', isUser: false);
    } finally {
      if (mounted) setState(() => _waiting = false);
    }
  }

  void _handleAction(AgentAction action) {
    HapticFeedback.selectionClick();
    switch (action.kind) {
      case AgentActionKind.openExercise:
        final exercise = action.exerciseId == null
            ? null
            : ExerciseService.findById(action.exerciseId!);
        if (exercise != null) {
          Navigator.of(context).push(AppRouter.toExerciseDetail(exercise));
        }
      case AgentActionKind.openPlans:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const PlansScreen()));
      case AgentActionKind.openProgress:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ProgressScreen()));
      case AgentActionKind.startQuickWorkout:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const QuickWorkoutScreen()));
      case AgentActionKind.createPlan:
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AIPlanConfigScreen()));
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;

    return Scaffold(
      backgroundColor: colors.systemBackground,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.primaryAccent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: colors.primaryAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI 教练', style: typography.title2),
                        ValueListenableBuilder<FitnessAgentServiceSnapshot>(
                          valueListenable: FitnessAgentService.instance,
                          builder: (context, snapshot, _) => Text(
                            snapshot.apiAgent?.isAvailable == true
                                ? '在线 Agent · 可检索动作和训练记录'
                                : '离线 Agent · 可搜索动作和生成基础建议',
                            style: typography.caption2.copyWith(
                              color: colors.tertiaryLabel,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'AI 设置',
                    onPressed: () => _showSettings(context),
                    icon: const Icon(Icons.settings_rounded),
                  ),
                ],
              ),
            ),

            // ── Messages ──
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        '开始和你的 AI 教练对话吧',
                        style: typography.subhead.copyWith(
                          color: colors.tertiaryLabel,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _MessageBubble(
                              message: msg,
                              colors: colors,
                              typography: typography,
                            ),
                            if (!msg.isUser && msg.exerciseIds.isNotEmpty)
                              _ExerciseCardStrip(exerciseIds: msg.exerciseIds),
                            if (!msg.isUser && msg.actions.isNotEmpty)
                              _AgentActionStrip(
                                actions: msg.actions,
                                onAction: _handleAction,
                              ),
                          ],
                        );
                      },
                    ),
            ),

            // ── Quick actions ──
            if (_messages.length <= 1)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _QuickChip(
                      label: '今天练什么',
                      icon: Icons.fitness_center_rounded,
                      onTap: () {
                        _inputCtrl.text = '根据我的情况，今天练什么？';
                        _send();
                      },
                    ),
                    _QuickChip(
                      label: '生成我的计划',
                      icon: Icons.trending_up_rounded,
                      onTap: () {
                        _inputCtrl.text = '帮我生成一份每周训练计划';
                        _send();
                      },
                    ),
                    _QuickChip(
                      label: '找一个动作',
                      icon: Icons.search_rounded,
                      onTap: () {
                        _inputCtrl.text = '找几个适合我的胸部动作';
                        _send();
                      },
                    ),
                    _QuickChip(
                      label: '分析最近表现',
                      icon: Icons.lightbulb_rounded,
                      onTap: () {
                        _inputCtrl.text = '分析我最近的训练表现';
                        _send();
                      },
                    ),
                  ],
                ),
              ),

            // ── Input bar ──
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: BoxDecoration(
                color: colors.secondarySystemBackground,
                border: Border(
                  top: BorderSide(color: colors.separator, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: colors.tertiarySystemBackground,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: TextField(
                        controller: _inputCtrl,
                        decoration: InputDecoration(
                          hintText: '问你的 AI 教练...',
                          hintStyle: TextStyle(color: colors.placeholder),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        style: TextStyle(color: colors.label),
                        maxLines: 4,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: '发送',
                    onPressed: _waiting ? null : _send,
                    icon: _waiting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;
    final service = FitnessAgentService.instance;
    final config = service.config;

    final endpointCtrl = TextEditingController(text: config.endpoint);
    final apiKeyCtrl = TextEditingController(text: config.apiKey);
    final modelCtrl = TextEditingController(text: config.model);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.systemBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          16 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.separator,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('AI 设置', style: typography.title2),
            const SizedBox(height: 6),
            Text(
              '默认按 DeepSeek 配置，也可以继续使用离线教练',
              style: typography.footnote.copyWith(color: colors.secondaryLabel),
            ),
            const SizedBox(height: 16),

            // Enable toggle
            StatefulBuilder(
              builder: (ctx, setSheetState) => Row(
                children: [
                  Text('启用 AI API', style: typography.subhead),
                  const Spacer(),
                  Switch(
                    value: config.enabled,
                    onChanged: (v) {
                      setSheetState(() {
                        service.updateConfig(config.copyWith(enabled: v));
                      });
                    },
                    activeThumbColor: colors.primaryAccent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: endpointCtrl,
              decoration: InputDecoration(
                labelText: 'Endpoint',
                hintText: 'https://api.deepseek.com/chat/completions',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.separator),
                ),
                isDense: true,
              ),
              style: TextStyle(fontSize: 14, color: colors.label),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: apiKeyCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.separator),
                ),
                isDense: true,
              ),
              style: TextStyle(fontSize: 14, color: colors.label),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: modelCtrl,
              decoration: InputDecoration(
                labelText: 'Model',
                hintText: 'deepseek-v4-flash',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.separator),
                ),
                isDense: true,
              ),
              style: TextStyle(fontSize: 14, color: colors.label),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  service.updateConfig(
                    ApiAgentConfig(
                      endpoint: endpointCtrl.text.trim(),
                      apiKey: apiKeyCtrl.text.trim(),
                      model: modelCtrl.text.trim(),
                      enabled: config.enabled,
                    ),
                  );
                  Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primaryAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data types ──

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String> exerciseIds; // related exercises to show as cards
  final List<AgentAction> actions;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.exerciseIds = const [],
    this.actions = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ── Message bubble ──

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final KLColorScheme colors;
  final KLTypography typography;

  const _MessageBubble({
    required this.message,
    required this.colors,
    required this.typography,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.label,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: message.isUser
                    ? colors.primaryAccent
                    : colors.tertiarySystemBackground,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(message.isUser ? 18 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 18),
                ),
                border: message.isUser
                    ? null
                    : Border.all(color: colors.separator, width: 0.5),
              ),
              child: Text(
                message.text,
                style: typography.callout.copyWith(
                  color: message.isUser ? Colors.white : colors.label,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (message.isUser) const SizedBox(width: 0),
        ],
      ),
    );
  }
}

class _AgentActionStrip extends StatelessWidget {
  final List<AgentAction> actions;
  final ValueChanged<AgentAction> onAction;

  const _AgentActionStrip({required this.actions, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 8, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: actions
            .map(
              (action) => OutlinedButton.icon(
                onPressed: () => onAction(action),
                icon: Icon(_iconFor(action.kind), size: 16),
                label: Text(action.label),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.primaryAccent,
                  side: BorderSide(color: colors.primaryAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  IconData _iconFor(AgentActionKind kind) {
    switch (kind) {
      case AgentActionKind.openExercise:
        return Icons.open_in_new_rounded;
      case AgentActionKind.openPlans:
        return Icons.view_agenda_outlined;
      case AgentActionKind.openProgress:
        return Icons.insights_outlined;
      case AgentActionKind.startQuickWorkout:
        return Icons.play_arrow_rounded;
      case AgentActionKind.createPlan:
        return Icons.auto_awesome_rounded;
    }
  }
}

// ── Related exercise cards (horizontal strip under a bot message) ──

class _ExerciseCardStrip extends StatelessWidget {
  final List<String> exerciseIds;

  const _ExerciseCardStrip({required this.exerciseIds});

  @override
  Widget build(BuildContext context) {
    // Resolve IDs to exercises, dropping any that don't exist (e.g. LLM noise).
    final exercises = exerciseIds
        .map(ExerciseService.findById)
        .whereType<Exercise>()
        .take(10)
        .toList();
    if (exercises.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 8, 12),
      child: SizedBox(
        height: 128,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: exercises.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) =>
              _MiniExerciseCard(exercise: exercises[i]),
        ),
      ),
    );
  }
}

class _MiniExerciseCard extends StatelessWidget {
  final Exercise exercise;

  const _MiniExerciseCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;

    return GestureDetector(
      onTap: () =>
          Navigator.of(context).push(AppRouter.toExerciseDetail(exercise)),
      child: Container(
        width: 108,
        decoration: BoxDecoration(
          color: colors.secondarySystemBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.separator, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: colors.tertiarySystemBackground,
                child: Image.asset(
                  exercise.image,
                  fit: BoxFit.contain,
                  cacheWidth: 216,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.fitness_center,
                    size: 24,
                    color: colors.tertiaryLabel,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.caption1.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ExerciseLabels.category(exercise.category),
                    style: typography.caption2.copyWith(
                      color: colors.tertiaryLabel,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick action chip ──

class _QuickChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 16, color: colors.primaryAccent),
      label: Text(label),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      backgroundColor: colors.tertiarySystemBackground,
      side: BorderSide(color: colors.separator.withValues(alpha: 0.65)),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: colors.label,
      ),
    );
  }
}
