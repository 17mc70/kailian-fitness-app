import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/exercise.dart';
import '../utils/equipment_groups.dart';

class ExerciseService {
  static List<Exercise>? _exercises;
  static List<String>? _equipmentList;

  static Future<List<Exercise>> loadExercises() async {
    if (_exercises != null) return _exercises!;
    try {
      final jsonStr =
          await rootBundle.loadString('assets/data/exercises.json');
      final List<dynamic> jsonList = json.decode(jsonStr) as List<dynamic>;
      _exercises = jsonList
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList();
      return _exercises!;
    } catch (e) {
      throw Exception('加载练习数据失败: $e');
    }
  }

  static List<Exercise> get all => _exercises ?? [];

  static List<String> get equipmentList {
    if (_equipmentList != null) return _equipmentList!;
    if (_exercises == null) return [];
    _equipmentList = _exercises!
        .map((e) => e.equipment)
        .toSet()
        .toList()
      ..sort();
    return _equipmentList!;
  }

  static List<String>? _categoryList;
  static List<String>? _targetList;

  static List<String> get categoryList {
    if (_categoryList != null) return _categoryList!;
    if (_exercises == null) return [];
    _categoryList = _exercises!
        .map((e) => e.category)
        .toSet()
        .toList()
      ..sort();
    return _categoryList!;
  }

  static List<String> get targetList {
    if (_targetList != null) return _targetList!;
    if (_exercises == null) return [];
    _targetList = _exercises!
        .map((e) => e.target)
        .toSet()
        .toList()
      ..sort();
    return _targetList!;
  }

  static List<Exercise> sortExercises(List<Exercise> list, String sortBy) {
    if (list.length < 2) return list;
    final sorted = List<Exercise>.from(list);
    switch (sortBy) {
      case 'name_asc':
        sorted.sort((a, b) => a.name.compareTo(b.name));
      case 'name_desc':
        sorted.sort((a, b) => b.name.compareTo(a.name));
      case 'target':
        sorted.sort((a, b) => a.target.compareTo(b.target));
      case 'equipment':
        sorted.sort((a, b) => a.equipment.compareTo(b.equipment));
      default:
        sorted.sort((a, b) => a.name.compareTo(b.name));
    }
    return sorted;
  }

  static Exercise? findById(String id) {
    if (_exercises == null) return null;
    try {
      return _exercises!.firstWhere((e) => e.id == id);
    } on StateError {
      return null;
    }
  }

  static List<Exercise> search(String query) {
    if (_exercises == null) return [];
    if (query.isEmpty) return _exercises!;
    final q = query.trim().toLowerCase();
    return _exercises!
        .where((e) =>
            e.name.toLowerCase().contains(q) ||
            e.target.toLowerCase().contains(q) ||
            e.category.toLowerCase().contains(q) ||
            e.muscleGroup.toLowerCase().contains(q) ||
            e.equipment.toLowerCase().contains(q))
        .toList();
  }

  static List<Exercise> filter({
    String? category,
    String? equipment,
    String? equipmentGroup,
    String? target,
    String? searchQuery,
  }) {
    var results = _exercises ?? <Exercise>[];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      results = results.where((e) =>
          e.name.toLowerCase().contains(q) ||
          e.target.toLowerCase().contains(q) ||
          e.category.toLowerCase().contains(q) ||
          e.muscleGroup.toLowerCase().contains(q) ||
          e.equipment.toLowerCase().contains(q)).toList();
    }
    if (category != null && category.isNotEmpty && category != 'all') {
      results = results.where((e) =>
          e.category.toLowerCase() == category.toLowerCase()).toList();
    }
    if (equipmentGroup != null && equipmentGroup.isNotEmpty) {
      results = results.where((e) =>
          EquipmentGroup.find(e.equipment)?.key == equipmentGroup).toList();
    }
    if (equipment != null && equipment.isNotEmpty && equipment != 'all') {
      results = results.where((e) =>
          e.equipment.toLowerCase() == equipment.toLowerCase()).toList();
    }
    if (target != null && target.isNotEmpty && target != 'all') {
      results = results
          .where(
              (e) => e.target.toLowerCase() == target.toLowerCase())
          .toList();
    }
    return results;
  }
}
