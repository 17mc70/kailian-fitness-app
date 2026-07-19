import 'package:flutter/cupertino.dart';
import '../models/exercise.dart';
import '../models/workout_plan.dart';
import '../models/workout_session.dart';
import '../screens/exercise_detail_screen.dart';
import '../screens/exercise_list_screen.dart';
import '../screens/create_plan_screen.dart';
import '../screens/plans_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/quick_workout_screen.dart';
import '../screens/session_detail_screen.dart';
import '../screens/workout_screen.dart';

/// Centralized hero tag generation.
class HeroTags {
  HeroTags._();

  static String exerciseImage(String id) => 'exercise-image-$id';
  static String exerciseName(String id) => 'exercise-name-$id';
}

/// Apple-style router using CupertinoPageRoute for smooth transitions.
class AppRouter {
  AppRouter._();

  static Route<T> _route<T>(WidgetBuilder builder, {Object? arguments}) {
    return CupertinoPageRoute<T>(
      builder: builder,
      settings: RouteSettings(arguments: arguments),
    );
  }

  static Route<void> toExerciseList({
    String? initialCategory,
    String? categoryLabel,
  }) {
    return _route((_) => ExerciseListScreen(
          initialCategory: initialCategory,
          categoryLabel: categoryLabel,
        ));
  }

  static Route<void> toExerciseDetail(Exercise exercise) {
    return _route((_) => ExerciseDetailScreen(exercise: exercise));
  }

  static Route<void> toWorkout(WorkoutPlan plan) {
    return _route((_) => WorkoutScreen(plan: plan));
  }

  static Route<void> toCreatePlan({WorkoutPlan? existingPlan}) {
    return _route((_) => CreatePlanScreen(existingPlan: existingPlan));
  }

  static Route<void> toPlans() {
    return _route((_) => const PlansScreen());
  }

  static Route<void> toProgress() {
    return _route((_) => const ProgressScreen());
  }

  static Route<void> toQuickWorkout() {
    return _route((_) => const QuickWorkoutScreen());
  }

  static Route<void> toSessionDetail(WorkoutSession session) {
    return _route((_) => SessionDetailScreen(session: session));
  }
}
