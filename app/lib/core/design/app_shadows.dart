import 'package:flutter/widgets.dart';

/// Warm Signal design system — Shadow tokens.
///
/// Soft diffuse shadows — no hard Material elevation look.
abstract final class AppShadows {
  /// Card shadow: soft diffuse, `0 8 24 rgba(0,0,0,0.06)`.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0F000000), // rgba(0,0,0,0.06)
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: 0,
    ),
  ];

  /// Button / floating element shadow: `0 4 12 rgba(0,0,0,0.08)`.
  static const List<BoxShadow> button = [
    BoxShadow(
      color: Color(0x14000000), // rgba(0,0,0,0.08)
      offset: Offset(0, 4),
      blurRadius: 12,
      spreadRadius: 0,
    ),
  ];

  /// Elevated surface (bottom sheets, modals).
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x1A000000), // rgba(0,0,0,0.10)
      offset: Offset(0, -4),
      blurRadius: 32,
      spreadRadius: 0,
    ),
  ];

  /// No shadow.
  static const List<BoxShadow> none = [];
}
