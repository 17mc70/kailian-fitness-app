import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/kl_theme.dart';

/// Reusable pressable wrapper with spring scale and haptic feedback.
class ScaleOnPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;
  final HapticFeedbackType hapticType;

  const ScaleOnPress({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.haptic = true,
    this.hapticType = HapticFeedbackType.light,
  });

  @override
  State<ScaleOnPress> createState() => _ScaleOnPressState();
}

enum HapticFeedbackType { light, medium, heavy, selection }

class _ScaleOnPressState extends State<ScaleOnPress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: KLAnimations.fast,
      reverseDuration: KLAnimations.fast,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerHaptic() {
    if (!widget.haptic) return;
    switch (widget.hapticType) {
      case HapticFeedbackType.light:
        HapticFeedback.lightImpact();
      case HapticFeedbackType.medium:
        HapticFeedback.mediumImpact();
      case HapticFeedbackType.heavy:
        HapticFeedback.heavyImpact();
      case HapticFeedbackType.selection:
        HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
      },
      onTapUp: (_) {
        _controller.reverse();
        _triggerHaptic();
        widget.onTap?.call();
      },
      onTapCancel: () {
        _controller.reverse();
      },
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final value = 1 - (_controller.value * (1 - widget.scale));
          return Transform.scale(scale: value, child: child);
        },
        child: widget.child,
      ),
    );
  }
}

/// A card with Apple-style 1px border, optional shadow and tap feedback.
class KLCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final double radius;
  final List<BoxShadow>? shadows;
  final Border? border;

  const KLCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.gradient,
    this.onTap,
    this.radius = KLRadius.card,
    this.shadows,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.secondarySystemBackground,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border:
            border ??
            Border.all(
              color: colors.separator.withValues(alpha: 0.6),
              width: 0.7,
            ),
        boxShadow: shadows,
      ),
      child: child,
    );

    if (onTap != null) {
      content = ScaleOnPress(scale: 0.98, onTap: onTap, child: content);
    }

    return content;
  }
}
