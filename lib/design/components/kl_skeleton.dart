import 'package:flutter/material.dart';
import '../theme/kl_theme.dart';

/// Shimmer skeleton placeholder matching the Apple-style card shape.
class KLSkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const KLSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 12,
  });

  @override
  State<KLSkeleton> createState() => _KLSkeletonState();
}

class _KLSkeletonState extends State<KLSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.klColors;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: colors.fill,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_controller.value * 2 - 1, 0),
              end: Alignment(_controller.value * 2 + 1, 0),
              colors: [
                colors.fill,
                colors.secondarySystemBackground,
                colors.fill,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Grid of skeleton cards matching the exercise grid layout.
class KLSkeletonGrid extends StatelessWidget {
  final int count;
  final double childAspectRatio;

  const KLSkeletonGrid({
    super.key,
    this.count = 6,
    this.childAspectRatio = 0.75,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: count,
      itemBuilder: (_, _) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: KLSkeleton(borderRadius: 18)),
        SizedBox(height: 8),
        KLSkeleton(width: double.infinity, height: 14, borderRadius: 4),
        SizedBox(height: 6),
        KLSkeleton(width: 80, height: 10, borderRadius: 3),
      ],
    );
  }
}
