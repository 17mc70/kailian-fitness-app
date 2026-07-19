import 'package:flutter/material.dart';

/// Apple-style semantic color tokens for 开练.
class KLColorScheme {
  final Color primaryAccent;
  final Color primaryAccentLight;
  final Color systemBackground;
  final Color secondarySystemBackground;
  final Color tertiarySystemBackground;
  final Color elevatedSystemBackground;
  final Color label;
  final Color secondaryLabel;
  final Color tertiaryLabel;
  final Color placeholder;
  final Color separator;
  final Color opaqueSeparator;
  final Color fill;
  final Color secondaryFill;
  final Color positive;
  final Color warning;
  final Color negative;
  final Brightness brightness;

  const KLColorScheme({
    required this.primaryAccent,
    required this.primaryAccentLight,
    required this.systemBackground,
    required this.secondarySystemBackground,
    required this.tertiarySystemBackground,
    required this.elevatedSystemBackground,
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.placeholder,
    required this.separator,
    required this.opaqueSeparator,
    required this.fill,
    required this.secondaryFill,
    required this.positive,
    required this.warning,
    required this.negative,
    required this.brightness,
  });

  // A restrained energy green keeps training and AI actions recognisable.
  static const Color _energyGreen = Color(0xFF0A955C);
  static const Color _energyGreenLight = Color(0xFF35C689);

  static KLColorScheme get light => const KLColorScheme(
    primaryAccent: _energyGreen,
    primaryAccentLight: _energyGreenLight,
    systemBackground: Color(0xFFF7F7F5),
    secondarySystemBackground: Color(0xFFFFFFFF),
    tertiarySystemBackground: Color(0xFFF2F2F7),
    elevatedSystemBackground: Color(0xFFFFFFFF),
    label: Color(0xFF000000),
    secondaryLabel: Color(0xFF6E6E73),
    tertiaryLabel: Color(0xFF8E8E93),
    placeholder: Color(0xFFC7C7CC),
    separator: Color(0x4D747480),
    opaqueSeparator: Color(0xFFC6C6C8),
    fill: Color(0xFFE5E5EA),
    secondaryFill: Color(0xFFE5E5EA),
    positive: Color(0xFF34C759),
    warning: Color(0xFFFF9500),
    negative: Color(0xFFFF3B30),
    brightness: Brightness.light,
  );

  static KLColorScheme get dark => const KLColorScheme(
    primaryAccent: Color(0xFFB8ED45),
    primaryAccentLight: Color(0xFFD2F77A),
    systemBackground: Color(0xFF0D0F0E),
    secondarySystemBackground: Color(0xFF171A18),
    tertiarySystemBackground: Color(0xFF232824),
    elevatedSystemBackground: Color(0xFF232824),
    label: Color(0xFFF5F5F2),
    secondaryLabel: Color(0xFF8E8E93),
    tertiaryLabel: Color(0xFF636366),
    placeholder: Color(0xFF636366),
    separator: Color(0x5C667066),
    opaqueSeparator: Color(0xFF343B35),
    fill: Color(0xFF343B35),
    secondaryFill: Color(0xFF293029),
    positive: Color(0xFFB8ED45),
    warning: Color(0xFFFF9F0A),
    negative: Color(0xFFFF453A),
    brightness: Brightness.dark,
  );

  Color get accent => primaryAccent;

  Color accentWithOpacity(double opacity) =>
      primaryAccent.withValues(alpha: opacity);
}
