import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'typography_environment.dart';

/// Warm Signal design system — Typography tokens.
///
/// Display / headings: **Syne** (distinctive, geometric).
/// Body / UI text: **Inter**.
/// Scale: Display 32/28, H1 24, H2 20, H3 18, Body 16/14, Caption 12.
abstract final class AppTypography {
  static final bool _isTest = isFlutterTest;

  static TextStyle _getSyne({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    required double height,
  }) {
    if (_isTest) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        fontFamily: 'Roboto',
      );
    }
    return GoogleFonts.syne(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  static TextStyle _getInter({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    required double height,
    TextDecoration? decoration,
  }) {
    if (_isTest) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        decoration: decoration,
        fontFamily: 'Roboto',
      );
    }
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      decoration: decoration,
    );
  }

  // ── Display (Syne) ────────────────────────────────────────────────────

  static TextStyle get displayLarge => _getSyne(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static TextStyle get displaySmall => _getSyne(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  // ── Headings (Syne) ──────────────────────────────────────────────────

  static TextStyle get h1 => _getSyne(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  static TextStyle get h2 => _getSyne(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static TextStyle get h3 => _getSyne(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.35,
  );

  // ── Body (Inter) ─────────────────────────────────────────────────────

  static TextStyle get bodyLarge => _getInter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static TextStyle get bodySmall => _getInter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static TextStyle get bodyLargeMedium => _getInter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static TextStyle get bodySmallMedium => _getInter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  // ── Caption (Inter) ──────────────────────────────────────────────────

  static TextStyle get caption => _getInter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static TextStyle get captionMedium => _getInter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static TextStyle get micro => _getInter(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.2,
  );

  static TextStyle get badge => _getInter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    height: 1.2,
  );

  // ── Button / Label (Inter) ───────────────────────────────────────────

  static TextStyle get buttonLarge => _getInter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.surface,
    height: 1.25,
  );

  static TextStyle get buttonSmall => _getInter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.surface,
    height: 1.25,
  );

  // ── Price styles ─────────────────────────────────────────────────────

  static TextStyle get priceRegular => _getInter(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  static TextStyle get priceSale => _getInter(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.accent,
    height: 1.25,
  );

  static TextStyle get priceOriginalStrikethrough => _getInter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    decoration: TextDecoration.lineThrough,
    height: 1.25,
  );
}
