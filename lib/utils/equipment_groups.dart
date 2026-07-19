import 'package:flutter/material.dart';

/// Equipment group definitions for multi-dimensional filtering.
///
/// Groups 28 equipment types from the dataset into 6 meaningful categories
/// that users can quickly filter by, alongside body-part category pills.
class EquipmentGroup {
  final String key;
  final String label;
  final List<String> members;
  final IconData icon;

  const EquipmentGroup(this.key, this.label, this.members, this.icon);

  /// Check whether a specific equipment string belongs to this group.
  bool contains(String equipment) =>
      members.any((m) => m.toLowerCase() == equipment.toLowerCase());

  static const List<EquipmentGroup> all = [
    EquipmentGroup('bodyweight', '无器械', ['body weight'], Icons.accessibility_new_rounded),
    EquipmentGroup('dumbbell', '哑铃', ['dumbbell'], Icons.fitness_center_rounded),
    EquipmentGroup(
      'barbell',
      '杠铃',
      ['barbell', 'ez barbell', 'olympic barbell', 'trap bar'],
      Icons.balance_rounded,
    ),
    EquipmentGroup(
      'cable_band',
      '绳索弹力带',
      ['cable', 'band', 'resistance band', 'rope'],
      Icons.swap_vert_rounded,
    ),
    EquipmentGroup(
      'machine',
      '固定器械',
      ['leverage machine', 'smith machine', 'sled machine', 'assisted'],
      Icons.precision_manufacturing_rounded,
    ),
    EquipmentGroup(
      'other',
      '其他器械',
      [
        'kettlebell',
        'medicine ball',
        'stability ball',
        'bosu ball',
        'weighted',
        'roller',
        'wheel roller',
        'hammer',
        'tire',
        'skierg machine',
        'elliptical machine',
        'stationary bike',
        'stepmill machine',
        'upper body ergometer',
      ],
      Icons.sports_kabaddi_rounded,
    ),
  ];

  /// Find the group that contains the given equipment string.
  static EquipmentGroup? find(String equipment) {
    for (final g in all) {
      if (g.contains(equipment)) return g;
    }
    return null;
  }

  /// Count exercises in [items] that belong to the group with [groupKey].
  /// [equipmentOf] extracts the equipment string from each item.
  static int countFor<T>(
    String groupKey,
    Iterable<T> items,
    String Function(T) equipmentOf,
  ) {
    final group = all.where((g) => g.key == groupKey).firstOrNull;
    if (group == null) return 0;
    return items.where((item) => group.contains(equipmentOf(item))).length;
  }
}
