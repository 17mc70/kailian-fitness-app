import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/typography.dart';

/// Builds the Material ThemeData from our Apple-style tokens.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(KLColorScheme.light);

  static ThemeData dark() => _build(KLColorScheme.dark);

  static ThemeData _build(KLColorScheme colors) {
    final typography = KLTypography.forScheme(colors);

    return ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      colorScheme: ColorScheme(
        brightness: colors.brightness,
        primary: colors.primaryAccent,
        onPrimary: colors.brightness == Brightness.dark
            ? colors.label
            : Colors.white,
        primaryContainer: colors.primaryAccent.withValues(alpha: 0.12),
        onPrimaryContainer: colors.primaryAccent,
        secondary: colors.secondaryLabel,
        onSecondary: colors.label,
        secondaryContainer: colors.secondarySystemBackground,
        onSecondaryContainer: colors.label,
        surface: colors.systemBackground,
        onSurface: colors.label,
        surfaceContainerHighest: colors.tertiarySystemBackground,
        surfaceContainerLow: colors.secondarySystemBackground,
        onSurfaceVariant: colors.secondaryLabel,
        error: colors.negative,
        onError: Colors.white,
        outline: colors.separator,
        shadow: const Color(0xFF000000).withValues(alpha: 0.08),
      ),
      scaffoldBackgroundColor: colors.systemBackground,
      fontFamily: 'Roboto',
      textTheme: TextTheme(
        displayLarge: typography.largeTitle,
        displayMedium: typography.title1,
        displaySmall: typography.title2,
        headlineLarge: typography.title3,
        headlineMedium: typography.headline,
        bodyLarge: typography.body,
        bodyMedium: typography.callout,
        bodySmall: typography.subhead,
        titleLarge: typography.title3,
        titleMedium: typography.headline,
        titleSmall: typography.subhead,
        labelLarge: typography.footnote,
        labelMedium: typography.caption1,
        labelSmall: typography.caption2,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colors.systemBackground,
        foregroundColor: colors.label,
        titleTextStyle: typography.headline,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.secondarySystemBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.secondarySystemBackground,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.label,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? colors.primaryAccent : colors.secondaryLabel,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.label,
        contentTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: colors.systemBackground,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.tertiarySystemBackground,
        hintStyle: TextStyle(color: colors.placeholder, fontSize: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primaryAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );
  }
}
