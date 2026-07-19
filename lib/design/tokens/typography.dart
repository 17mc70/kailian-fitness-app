import 'package:flutter/material.dart';
import 'colors.dart';

/// Apple-style typography tokens.
class KLTypography {
  final TextStyle largeTitle;
  final TextStyle title1;
  final TextStyle title2;
  final TextStyle title3;
  final TextStyle headline;
  final TextStyle body;
  final TextStyle callout;
  final TextStyle subhead;
  final TextStyle footnote;
  final TextStyle caption1;
  final TextStyle caption2;

  const KLTypography({
    required this.largeTitle,
    required this.title1,
    required this.title2,
    required this.title3,
    required this.headline,
    required this.body,
    required this.callout,
    required this.subhead,
    required this.footnote,
    required this.caption1,
    required this.caption2,
  });

  static KLTypography forScheme(KLColorScheme colors) {
    const fontFamily = 'Roboto';
    final labelColor = colors.label;
    final secondary = colors.secondaryLabel;

    return KLTypography(
      largeTitle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: labelColor,
        height: 1.1,
      ),
      title1: TextStyle(
        fontFamily: fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: labelColor,
        height: 1.2,
      ),
      title2: TextStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: labelColor,
        height: 1.25,
      ),
      title3: TextStyle(
        fontFamily: fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: labelColor,
        height: 1.25,
      ),
      headline: TextStyle(
        fontFamily: fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: labelColor,
        height: 1.29,
      ),
      body: TextStyle(
        fontFamily: fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: labelColor,
        height: 1.29,
      ),
      callout: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: labelColor,
        height: 1.25,
      ),
      subhead: TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: labelColor,
        height: 1.33,
      ),
      footnote: TextStyle(
        fontFamily: fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: secondary,
        height: 1.38,
      ),
      caption1: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: secondary,
        height: 1.33,
      ),
      caption2: TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: secondary,
        height: 1.18,
      ),
    );
  }
}
