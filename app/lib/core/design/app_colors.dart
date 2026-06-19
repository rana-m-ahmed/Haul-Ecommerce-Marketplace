import 'package:flutter/material.dart';

/// Warm Signal design system — Color tokens.
///
/// Source of truth: `/progress/03_DESIGN_SYSTEM.md`.
/// No raw hex value should ever appear outside this file.
abstract final class AppColors {
  // ── Core palette ──────────────────────────────────────────────────────

  /// Warm ivory base background.
  static const Color background = Color(0xFFFAF6EF);

  /// Pure white card surface.
  static const Color surface = Color(0xFFFFFFFF);

  /// Deep charcoal-brown primary text.
  static const Color textPrimary = Color(0xFF2B2520);

  /// Warm gray secondary text.
  static const Color textSecondary = Color(0xFF6B6258);

  /// Signal coral — CTAs, active states, AI badges.
  static const Color accent = Color(0xFFFF5A36);

  /// Light coral — badge backgrounds, soft emphasis.
  static const Color accentSoft = Color(0xFFFFB199);

  /// Success states (confirmation, in-stock).
  static const Color success = Color(0xFF2F9E5B);

  /// Error states (validation, out-of-stock).
  static const Color error = Color(0xFFC73E3A);

  /// Dividers, card outlines, borders.
  static const Color border = Color(0xFFEDE6DA);

  // ── Derived / utility ─────────────────────────────────────────────────

  /// Shimmer base (skeleton loaders).
  static const Color shimmerBase = Color(0xFFEDE6DA);

  /// Shimmer highlight.
  static const Color shimmerHighlight = Color(0xFFFAF6EF);

  /// Overlay scrim for bottom sheets / modals.
  static const Color scrim = Color(0x662B2520);

  /// Disabled text / icon tint.
  static const Color disabled = Color(0xFFB5AFA6);

  /// Sale badge background.
  static const Color saleBadge = accent;

  /// "New" badge background.
  static const Color newBadge = Color(0xFF2B2520);

  /// Out-of-stock overlay.
  static const Color outOfStockOverlay = Color(0x99FFFFFF);
}
