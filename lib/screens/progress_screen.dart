import 'package:flutter/material.dart';
import '../agent/agent_service.dart';
import '../agent/fitness_agent.dart';
import '../models/workout_session.dart';
import '../services/database_service.dart';
import '../design/theme/kl_theme.dart';
import 'session_detail_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => ProgressScreenState();
}

class ProgressScreenState extends State<ProgressScreen> {
  int _totalWorkouts = 0;
  int _totalSets = 0;
  double _totalVolume = 0;
  Map<String, double> _dailyVolume = {};
  bool _loading = true;
  AgentAnalysis? _agentAnalysis;
  bool _analyzing = false;

  late Future<List<WorkoutSession>> _sessionsFuture;

  void refresh() {
    _sessionsFuture = DatabaseService.getSessions(limit: 10);
    _load();
  }

  @override
  void initState() {
    super.initState();
    _sessionsFuture = DatabaseService.getSessions(limit: 10);
    _load();
  }

  Future<void> _load() async {
    try {
      final workouts = await DatabaseService.getTotalWorkouts();
      final sets = await DatabaseService.getTotalSets();
      final totalVolume = await DatabaseService.getTotalVolume();
      final volume = await DatabaseService.getVolumeByDay(30);
      if (!mounted) return;

      setState(() {
        _totalWorkouts = workouts;
        _totalSets = sets;
        _totalVolume = totalVolume;
        _dailyVolume = volume;
        _loading = false;
      });
    } catch (e) {
      debugPrint('ProgressScreen._load: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }

    // Kick off AI analysis in background
    _analyzeSessions();
  }

  Future<void> _analyzeSessions() async {
    if (_analyzing) return;
    setState(() => _analyzing = true);
    try {
      final sessions = await DatabaseService.getSessions(limit: 20);
      final analysis = await FitnessAgentService.instance.currentAgent
          .analyzeProgress(sessions);
      if (!mounted) return;
      setState(() => _agentAnalysis = analysis);
    } catch (e) {
      debugPrint('ProgressScreen._analyzeSessions: $e');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
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
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('训练进度', style: typography.title1),
                          ),
                          IconButton(
                            tooltip: '刷新进度',
                            onPressed: refresh,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Stat row ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Row(
                        children: [
                          _StatTile(
                            value: _totalWorkouts.toString(),
                            label: '总训练',
                            color: colors.primaryAccent,
                          ),
                          _StatTile(
                            value: _totalSets.toString(),
                            label: '总组数',
                            color: colors.label,
                          ),
                          _StatTile(
                            value: _totalVolume.toStringAsFixed(0),
                            label: '总训练量 · kg',
                            color: colors.secondaryLabel,
                          ),
                          _StatTile(
                            value: _dailyVolume.isEmpty
                                ? '0'
                                : (_dailyVolume.values.fold<double>(
                                            0,
                                            (a, b) => a + b,
                                          ) /
                                          _dailyVolume.length)
                                      .toStringAsFixed(0),
                            label: '日均 · kg',
                            color: colors.primaryAccentLight,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── AI Analysis section ──
                  if (_agentAnalysis != null &&
                      _agentAnalysis!.insights.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.tertiarySystemBackground,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: colors.primaryAccent.withValues(
                                alpha: 0.15,
                              ),
                              width: 0.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.psychology_rounded,
                                    size: 18,
                                    color: colors.primaryAccent,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'AI 分析',
                                    style: typography.subhead.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (_analyzing) ...[
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: Icon(
                                        Icons.more_horiz_rounded,
                                        size: 16,
                                        color: colors.tertiaryLabel,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 10),
                              ...(_agentAnalysis?.insights ?? []).map(
                                (insight) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('📌 ', style: typography.footnote),
                                      Expanded(
                                        child: Text(
                                          insight,
                                          style: typography.footnote.copyWith(
                                            color: colors.secondaryLabel,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if ((_agentAnalysis?.suggestions ?? [])
                                  .isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Divider(height: 1, color: colors.separator),
                                const SizedBox(height: 8),
                                ...(_agentAnalysis?.suggestions ?? []).map(
                                  (suggestion) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('💡 ', style: typography.footnote),
                                        Expanded(
                                          child: Text(
                                            suggestion,
                                            style: typography.footnote.copyWith(
                                              color: colors.secondaryLabel,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ── Section title ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      child: Text(
                        '近 30 天训练量',
                        style: typography.title3.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // ── Volume chart ──
                  if (_dailyVolume.isEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: colors.tertiarySystemBackground,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: colors.separator,
                            width: 0.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.bar_chart_rounded,
                              size: 40,
                              color: colors.tertiaryLabel,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '还没有训练记录',
                              style: typography.subhead.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.secondaryLabel,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '完成一次训练就能看到图表',
                              style: typography.footnote.copyWith(
                                color: colors.tertiaryLabel,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: _VolumeChart(
                          data: _dailyVolume,
                          accentColor: colors.primaryAccent,
                        ),
                      ),
                    ),

                  // ── Recent sessions ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Text(
                        '最近训练',
                        style: typography.title3.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // ── Session list ──
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: _buildSessionList(colors, typography),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSessionList(KLColorScheme colors, KLTypography typography) {
    return FutureBuilder(
      future: _sessionsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: colors.tertiarySystemBackground,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.separator, width: 0.5),
              ),
              child: Center(
                child: Text(
                  '暂无训练记录',
                  style: typography.subhead.copyWith(
                    color: colors.secondaryLabel,
                  ),
                ),
              ),
            ),
          );
        }

        final sessions = snapshot.data!;
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final s = sessions[index];
            final dur = s.duration;
            final min = dur.inMinutes;
            final timeStr = min > 0 ? '$min 分钟' : '${dur.inSeconds} 秒';

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SessionDetailScreen(session: s),
                ),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.secondarySystemBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.separator, width: 0.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.primaryAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.fitness_center_rounded,
                        color: colors.primaryAccent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.planName ?? '自由训练',
                            style: typography.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${s.startTime.month}/${s.startTime.day} '
                            '${s.startTime.hour}:${s.startTime.minute.toString().padLeft(2, '0')} '
                            '· $timeStr · ${s.totalSets} 组',
                            style: typography.footnote.copyWith(
                              color: colors.tertiaryLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${s.totalVolume.toStringAsFixed(0)} kg',
                      style: typography.subhead.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.primaryAccent,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: colors.tertiaryLabel,
                    ),
                  ],
                ),
              ),
            );
          }, childCount: sessions.length),
        );
      },
    );
  }
}

// ── Stat tile ──

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final typography = context.klTypography;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: typography.title2.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: typography.caption2.copyWith(
              color: context.klColors.tertiaryLabel,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Volume chart ──

class _VolumeChart extends StatelessWidget {
  final Map<String, double> data;
  final Color accentColor;

  const _VolumeChart({required this.data, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final days = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final maxVal = days.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: BoxDecoration(
        color: colors.secondarySystemBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.separator, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Max value label
          Text(
            '${maxVal.toStringAsFixed(0)} kg',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: accentColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = (constraints.maxWidth / days.length) * 0.55;
                final gap = (constraints.maxWidth / days.length) * 0.45;

                return CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _BarChartPainter(
                    data: days,
                    maxValue: maxVal,
                    barColor: accentColor,
                    barWidth: barWidth,
                    gap: gap,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<MapEntry<String, double>> data;
  final double maxValue;
  final Color barColor;
  final double barWidth;
  final double gap;

  _BarChartPainter({
    required this.data,
    required this.maxValue,
    required this.barColor,
    required this.barWidth,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    final bgPaint = Paint()
      ..color = barColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final value = data[i].value;
      final chartHeight = size.height - 4;
      final barHeight = maxValue > 0 ? (value / maxValue) * chartHeight : 0.0;
      final x = i * (barWidth + gap) + gap / 2;
      final y = chartHeight - barHeight;

      // Background bar
      canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(x, 0, barWidth, chartHeight)),
        bgPaint,
      );

      // Filled bar
      if (barHeight > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, y, barWidth, barHeight),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.maxValue != maxValue ||
      oldDelegate.barWidth != barWidth;
}
