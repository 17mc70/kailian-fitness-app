import 'package:flutter/material.dart';

/// Goal category for a workout plan.
class PlanGoal {
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  const PlanGoal(this.key, this.label, this.icon, this.color);

  static const all = <PlanGoal>[
    PlanGoal('full_body', '全身', Icons.accessibility_new_rounded, Color(0xFFE85D3A)),
    PlanGoal('strength', '增肌', Icons.fitness_center_rounded, Color(0xFF2D9CDB)),
    PlanGoal('fat_burn', '减脂', Icons.local_fire_department_rounded, Color(0xFFF2994A)),
    PlanGoal('sculpt', '塑形', Icons.self_improvement_rounded, Color(0xFF27AE60)),
    PlanGoal('core', '核心', Icons.foundation_rounded, Color(0xFF9B51E0)),
  ];

  static PlanGoal? fromKey(String key) =>
      all.where((g) => g.key == key).firstOrNull;
}

/// Pre-built workout plan template.
///
/// Each template has a stable [id], a [goalKey] matching [PlanGoal],
/// [difficulty] level, estimated [durationMinutes], and a list of
/// [exerciseIds] referencing exercises in exercises.json.
class WorkoutTemplate {
  final String id;
  final String name;
  final String description;
  final String goalKey;
  final String difficulty; // '初级' | '中级' | '高级'
  final int durationMinutes; // estimated time
  final int exerciseCount; // how many distinct exercises
  final List<String> exerciseIds;

  const WorkoutTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.goalKey,
    required this.difficulty,
    required this.durationMinutes,
    required this.exerciseCount,
    required this.exerciseIds,
  });

  PlanGoal? get goal => PlanGoal.fromKey(goalKey);

  /// Short metadata line used when seeding into the database.
  String get tagLine => '$difficulty · $durationMinutes 分钟 · $exerciseCount 个动作';
}

const List<WorkoutTemplate> workoutTemplates = [
  // ═══════════════════════
  // 全身 (Full Body)
  // ═══════════════════════

  WorkoutTemplate(
    id: 'full-body-beginner',
    name: '全身激活',
    description: '适合新手的自重训练，激活全身主要肌群。每天 15 分钟，建立运动习惯。',
    goalKey: 'full_body',
    difficulty: '初级',
    durationMinutes: 15,
    exerciseCount: 6,
    exerciseIds: [
      '2398', '1685', '3013', '0274', '1373', '0464',
    ],
  ),
  WorkoutTemplate(
    id: 'full-body-intermediate',
    name: '全身塑形',
    description: '中等强度全身训练，加入跳跃和复合动作，提升力量与心肺。',
    goalKey: 'full_body',
    difficulty: '中级',
    durationMinutes: 25,
    exerciseCount: 7,
    exerciseIds: [
      '3216', '3470', '3561', '1160', '1686', '0687', '0803',
    ],
  ),
  WorkoutTemplate(
    id: 'full-body-advanced',
    name: '全身挑战',
    description: '高强度自重训练，需要一定力量基础。单腿蹲、弓箭手俯卧撑等进阶动作。',
    goalKey: 'full_body',
    difficulty: '高级',
    durationMinutes: 35,
    exerciseCount: 6,
    exerciseIds: [
      '3294', '3582', '0501', '0472', '1476', '0496',
    ],
  ),

  // ═══════════════════════
  // 增肌 (Strength)
  // ═══════════════════════

  WorkoutTemplate(
    id: 'upper-body-strength',
    name: '上肢力量',
    description: '集中刺激胸、背、肩、手臂。需椅子或矮桌辅助，塑造上肢线条。',
    goalKey: 'strength',
    difficulty: '中级',
    durationMinutes: 25,
    exerciseCount: 6,
    exerciseIds: [
      '0251', '3293', '0129', '1273', '0139', '3216',
    ],
  ),
  WorkoutTemplate(
    id: 'lower-body-strength',
    name: '下肢力量',
    description: '全面刺激大腿、臀部和腘绳肌。无需器械，打造有力下肢。',
    goalKey: 'strength',
    difficulty: '中级',
    durationMinutes: 25,
    exerciseCount: 6,
    exerciseIds: [
      '3470', '3523', '1373', '1473', '1460', '0130',
    ],
  ),
  WorkoutTemplate(
    id: 'push-day',
    name: '推力训练',
    description: '专注推力肌群：胸、肩、肱三头肌。含俯卧撑变式与支撑动作。',
    goalKey: 'strength',
    difficulty: '中级',
    durationMinutes: 20,
    exerciseCount: 5,
    exerciseIds: [
      '0251', '3216', '1273', '3294', '0129',
    ],
  ),
  WorkoutTemplate(
    id: 'pull-day',
    name: '拉力训练',
    description: '专注拉力肌群：背、肱二头肌。含引体向上变式（需单杠）。',
    goalKey: 'strength',
    difficulty: '中级',
    durationMinutes: 20,
    exerciseCount: 5,
    exerciseIds: [
      '3293', '0803', '0139', '1775', '2367',
    ],
  ),

  // ═══════════════════════
  // 减脂 (Fat Burn)
  // ═══════════════════════

  WorkoutTemplate(
    id: 'hiit-cardio',
    name: 'HIIT 燃脂',
    description: '20 分钟高强度间歇训练。快速提升心率，后燃效应持续燃烧。',
    goalKey: 'fat_burn',
    difficulty: '中级',
    durationMinutes: 20,
    exerciseCount: 6,
    exerciseIds: [
      '1160', '3220', '3360', '0630', '1374', '1473',
    ],
  ),
  WorkoutTemplate(
    id: 'tabata-burn',
    name: 'Tabata 极速燃脂',
    description: '4 分钟一组 × 4 轮 = 16 分钟的极限燃脂。动作 20 秒，休息 10 秒。',
    goalKey: 'fat_burn',
    difficulty: '高级',
    durationMinutes: 16,
    exerciseCount: 4,
    exerciseIds: [
      '0501', '0630', '3220', '1160',
    ],
  ),
  WorkoutTemplate(
    id: 'low-impact-cardio',
    name: '低冲击有氧',
    description: '关节友好的有氧训练，无跳跃。适合大体重或膝盖不适。',
    goalKey: 'fat_burn',
    difficulty: '初级',
    durationMinutes: 20,
    exerciseCount: 6,
    exerciseIds: [
      '1373', '1685', '3013', '0464', '0274', '0803',
    ],
  ),

  // ═══════════════════════
  // 塑形 (Sculpt)
  // ═══════════════════════

  WorkoutTemplate(
    id: 'sculpt-glute',
    name: '蜜桃臀养成',
    description: '集中刺激臀大肌和腘绳肌，塑造翘臀线条。无需器械。',
    goalKey: 'sculpt',
    difficulty: '中级',
    durationMinutes: 25,
    exerciseCount: 6,
    exerciseIds: [
      '3013', '3470', '3523', '3561', '1460', '0130',
    ],
  ),
  WorkoutTemplate(
    id: 'sculpt-arm',
    name: '手臂紧致',
    description: '告别拜拜肉，紧致手臂线条。自重训练为主，可配合弹力带。',
    goalKey: 'sculpt',
    difficulty: '初级',
    durationMinutes: 15,
    exerciseCount: 5,
    exerciseIds: [
      '0129', '2398', '3216', '0139', '0464',
    ],
  ),
  WorkoutTemplate(
    id: 'sculpt-waist',
    name: '腰腹塑形',
    description: '全方位刺激腹肌，雕刻腰腹线条。无需器械，在家可练。',
    goalKey: 'sculpt',
    difficulty: '中级',
    durationMinutes: 20,
    exerciseCount: 6,
    exerciseIds: [
      '0274', '0003', '0687', '2429', '0464', '0006',
    ],
  ),

  // ═══════════════════════
  // 核心 (Core)
  // ═══════════════════════

  WorkoutTemplate(
    id: 'core-beginner',
    name: '核心入门',
    description: '零基础核心训练，动作温和，建立核心稳定性和身体控制力。',
    goalKey: 'core',
    difficulty: '初级',
    durationMinutes: 12,
    exerciseCount: 5,
    exerciseIds: [
      '0274', '0464', '3239', '0003', '0006',
    ],
  ),
  WorkoutTemplate(
    id: 'core-advanced',
    name: '核心挑战',
    description: '高难度核心训练，含悬挂举腿、平板变式。需要一定力量基础。',
    goalKey: 'core',
    difficulty: '高级',
    durationMinutes: 20,
    exerciseCount: 6,
    exerciseIds: [
      '0472', '0687', '0473', '1775', '2466', '2963',
    ],
  ),
  WorkoutTemplate(
    id: 'core-stability',
    name: '稳定训练',
    description: '强调身体平衡与核心稳定，改善体态，预防运动损伤。',
    goalKey: 'core',
    difficulty: '初级',
    durationMinutes: 18,
    exerciseCount: 6,
    exerciseIds: [
      '0464', '3239', '0803', '3013', '0006', '0274',
    ],
  ),
];
