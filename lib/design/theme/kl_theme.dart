import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/typography.dart';

export '../tokens/colors.dart';
export '../tokens/typography.dart';
export '../tokens/spacing.dart';
export '../tokens/radius.dart';
export '../tokens/shadows.dart';
export '../tokens/animations.dart';

/// Lightweight inherited widget exposing the full design system.
class KLTheme extends InheritedWidget {
  final KLColorScheme colors;
  final KLTypography typography;

  const KLTheme({
    super.key,
    required this.colors,
    required this.typography,
    required super.child,
  });

  static KLTheme of(BuildContext context) {
    final theme = context.dependOnInheritedWidgetOfExactType<KLTheme>();
    assert(theme != null, 'KLTheme not found in widget tree');
    return theme!;
  }

  @override
  bool updateShouldNotify(covariant KLTheme oldWidget) =>
      oldWidget.colors != colors || oldWidget.typography != typography;
}

extension KLThemeContext on BuildContext {
  KLColorScheme get klColors => KLTheme.of(this).colors;
  KLTypography get klTypography => KLTheme.of(this).typography;
}
