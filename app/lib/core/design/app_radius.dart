import 'package:flutter/widgets.dart';

/// Warm Signal design system — Radius tokens.
///
/// Card: 20, Button: 14, Bottom sheet (top corners): 28, Chip/pill: 999.
abstract final class AppRadius {
  // ── Raw values ───────────────────────────────────────────────────────

  static const double card = 20;
  static const double button = 14;
  static const double bottomSheet = 28;
  static const double chip = 999;
  static const double image = 16;

  // ── BorderRadius shortcuts ───────────────────────────────────────────

  static const BorderRadius cardBorderRadius =
      BorderRadius.all(Radius.circular(card));

  static const BorderRadius buttonBorderRadius =
      BorderRadius.all(Radius.circular(button));

  static const BorderRadius bottomSheetBorderRadius = BorderRadius.only(
    topLeft: Radius.circular(bottomSheet),
    topRight: Radius.circular(bottomSheet),
  );

  static const BorderRadius chipBorderRadius =
      BorderRadius.all(Radius.circular(chip));

  static const BorderRadius imageBorderRadius =
      BorderRadius.all(Radius.circular(image));
}
