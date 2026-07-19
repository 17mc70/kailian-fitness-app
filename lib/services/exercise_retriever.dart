import '../models/exercise.dart';
import '../utils/exercise_labels.dart';
import 'exercise_service.dart';

/// Lightweight, zero-dependency retrieval over the exercise dataset.
///
/// Scores each exercise against a (possibly Chinese) natural-language query by
/// matching query tokens to structured fields (name / target / category /
/// muscle group / equipment / secondary muscles). Chinese tokens are mapped to
/// their English field values via [ExerciseLabels] reverse lookups, so a query
/// like "绳索练背" retrieves cable + back exercises without any embeddings.
class ExerciseRetriever {
  ExerciseRetriever._();

  /// Reverse map: Chinese label -> set of English keys. Built once, lazily.
  static Map<String, Set<String>>? _zhToEn;

  static Map<String, Set<String>> get _reverse {
    if (_zhToEn != null) return _zhToEn!;
    final map = <String, Set<String>>{};
    void add(String zh, String en) =>
        map.putIfAbsent(zh, () => <String>{}).add(en.toLowerCase());
    for (final e in ExerciseLabels.categoryMap.entries) {
      add(e.value, e.key);
    }
    for (final e in ExerciseLabels.equipmentMap.entries) {
      add(e.value, e.key);
    }
    for (final e in ExerciseLabels.targetMap.entries) {
      add(e.value, e.key);
    }
    for (final e in ExerciseLabels.muscleGroupMap.entries) {
      add(e.value, e.key);
    }
    _zhToEn = map;
    return map;
  }

  /// Retrieve the top [limit] exercises most relevant to [query].
  ///
  /// Returns an empty list for an empty query. When nothing scores above zero,
  /// falls back to a plain substring [ExerciseService.search].
  static List<Exercise> retrieve(
    String query, {
    int limit = 15,
    List<Exercise>? source,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final all = source ?? ExerciseService.all;
    if (all.isEmpty) return const [];

    // Expand query into English field terms: any Chinese label found as a
    // substring contributes its English keys; the raw query is kept too so
    // English/latin queries still match by substring.
    // Bidirectional containment so single-char queries ("背") match multi-char
    // labels ("背部"/"背阔肌"), and full queries ("绳索练背") match short labels.
    final terms = <String>{};
    _reverse.forEach((zh, ens) {
      if (q.contains(zh) || zh.contains(q)) terms.addAll(ens);
    });

    final scored = <_Scored>[];
    for (final e in all) {
      final score = _score(e, q, terms);
      if (score > 0) scored.add(_Scored(e, score));
    }

    if (scored.isEmpty) {
      // No structured match — fall back to plain name substring search.
      return all
          .where((e) => e.name.toLowerCase().contains(q))
          .take(limit)
          .toList();
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((s) => s.exercise).toList();
  }

  /// Field-weighted score. Exact field equality outranks substring hits.
  static int _score(Exercise e, String rawQuery, Set<String> terms) {
    var score = 0;
    final cat = e.category.toLowerCase();
    final eq = e.equipment.toLowerCase();
    final target = e.target.toLowerCase();
    final mg = e.muscleGroup.toLowerCase();
    final name = e.name.toLowerCase();
    final secondary = e.secondaryMuscles.map((m) => m.toLowerCase()).toSet();

    // Mapped Chinese terms → exact field matches (highest signal).
    for (final t in terms) {
      if (target == t) score += 6;
      if (cat == t) score += 5;
      if (eq == t) score += 5;
      if (mg == t) score += 4;
      if (secondary.contains(t)) score += 2;
      if (name.contains(t)) score += 2;
    }

    // Raw query substring hits (covers English / partial input).
    if (name.contains(rawQuery)) score += 3;
    if (target.contains(rawQuery)) score += 2;
    if (cat.contains(rawQuery)) score += 2;
    if (eq.contains(rawQuery)) score += 1;
    if (mg.contains(rawQuery)) score += 1;

    return score;
  }
}

class _Scored {
  final Exercise exercise;
  final int score;
  const _Scored(this.exercise, this.score);
}
