import 'package:flutter/material.dart';
import '../models/workout_session.dart';
import '../design/theme/kl_theme.dart';

class SessionDetailScreen extends StatelessWidget {
  final WorkoutSession session;

  const SessionDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;
    final typography = context.klTypography;
    final dur = session.duration;
    final min = dur.inMinutes;
    final timeStr = min > 0
        ? '$min分${dur.inSeconds.remainder(60)}秒'
        : '${dur.inSeconds}秒';

    return Scaffold(
      body: SafeArea(
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
                            Icons.chevron_left_rounded, size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        session.planName ?? '自由训练',
                        style: typography.title2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Summary ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.secondarySystemBackground,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: colors.separator, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${session.startTime.year}/${session.startTime.month}/${session.startTime.day} '
                        '${session.startTime.hour}:${session.startTime.minute.toString().padLeft(2, '0')}',
                        style: typography.footnote.copyWith(
                          color: colors.tertiaryLabel,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _summaryChip(colors, Icons.timer_outlined,
                              timeStr),
                          const SizedBox(width: 10),
                          _summaryChip(colors, Icons.repeat_rounded,
                              '${session.totalSets} 组'),
                          const SizedBox(width: 10),
                          _summaryChip(
                            colors,
                            Icons.fitness_center_rounded,
                            '${session.totalVolume.toStringAsFixed(0)} kg',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Section title ──
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Text(
                  '训练详情',
                  style: typography.title3.copyWith(
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),

            // ── Exercise logs ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final log = session.logs[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.secondarySystemBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: colors.separator, width: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.exerciseName,
                            style: typography.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Table header
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color:
                                  colors.tertiarySystemBackground,
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 28,
                                    child: Text('组',
                                        style: TextStyle(
                                            fontWeight:
                                                FontWeight.w600,
                                            fontSize: 11))),
                                Expanded(
                                    child: Center(
                                        child: Text('重量',
                                            style: TextStyle(
                                                fontWeight:
                                                    FontWeight.w600,
                                                fontSize: 11)))),
                                Expanded(
                                    child: Center(
                                        child: Text('次数',
                                            style: TextStyle(
                                                fontWeight:
                                                    FontWeight.w600,
                                                fontSize: 11)))),
                                const SizedBox(width: 42,
                                    child: Center(
                                        child: Text('1RM',
                                            style: TextStyle(
                                                fontWeight:
                                                    FontWeight.w600,
                                                fontSize: 11)))),
                                const SizedBox(width: 24),
                              ],
                            ),
                          ),

                          // Sets
                          ...log.sets.asMap().entries.map(
                              (entry) {
                            final set = entry.value;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: colors.separator,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 28,
                                    child: Text('${set.setNumber}',
                                        style: const TextStyle(
                                            fontSize: 13)),
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        set.weight > 0
                                            ? '${set.weight}'
                                            : '-',
                                        style: const TextStyle(
                                            fontSize: 13),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        set.reps > 0
                                            ? '${set.reps}'
                                            : '-',
                                        style: const TextStyle(
                                            fontSize: 13),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 42,
                                    child: Center(
                                      child: Text(
                                        set.estimatedOneRM > 0
                                            ? set.estimatedOneRM
                                                .toStringAsFixed(1)
                                            : '-',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: set.estimatedOneRM > 0
                                              ? colors.primaryAccent
                                              : colors.tertiaryLabel,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 24,
                                    child: set.isCompleted
                                        ? Icon(
                                            Icons.check_circle_rounded,
                                            size: 18,
                                            color: colors.positive)
                                        : const SizedBox(),
                                  ),
                                ],
                              ),
                            );
                          }),

                          // Total
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Spacer(),
                              Text(
                                '${log.sets.where((s) => s.isCompleted).length} 组完成 · '
                                '${log.totalVolume.toStringAsFixed(0)} kg'
                                '${log.maxOneRM > 0 ? " · 最大 1RM ${log.maxOneRM.toStringAsFixed(1)} kg" : ""}',
                                style: typography.caption2.copyWith(
                                  color: colors.tertiaryLabel,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: session.logs.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(
      KLColorScheme colors, IconData icon, String label) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.tertiarySystemBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.tertiaryLabel),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: colors.secondaryLabel)),
        ],
      ),
    );
  }
}
