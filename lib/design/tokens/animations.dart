import 'package:flutter/material.dart';

/// Animation durations and curves inspired by Apple-style motion.
class KLAnimations {
  KLAnimations._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
  static const Duration spring = Duration(milliseconds: 500);

  static const Curve easeOutBack = Cubic(0.16, 1, 0.3, 1);
  static const Curve press = Cubic(0.2, 0, 0.2, 1);
  static const Curve listItem = Cubic(0.22, 0.61, 0.36, 1);
  static const Curve sheet = Cubic(0.32, 0.72, 0, 1.01);
  static const Curve exit = Cubic(0.4, 0, 1, 1);

  static SpringDescription springDescription({
    double stiffness = 100,
    double damping = 15,
    double mass = 1,
  }) =>
      SpringDescription(mass: mass, stiffness: stiffness, damping: damping);
}
