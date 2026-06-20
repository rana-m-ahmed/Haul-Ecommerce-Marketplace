import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Warm Signal design system — Motion tokens and toolkit.
///
/// Every state transition in the app should use these values,
/// never a hand-typed Duration or Curves.easeInOut.
abstract final class AppMotion {
  // ── Duration tokens ──────────────────────────────────────────────────

  /// Fast micro-interactions (toggle, ripple).
  static const Duration durationFast = Duration(milliseconds: 150);

  /// Standard transitions.
  static const Duration durationBase = Duration(milliseconds: 250);

  /// Slower transitions (page shifts, large reveals).
  static const Duration durationSlow = Duration(milliseconds: 400);

  /// Hero card↔detail transitions.
  static const Duration durationHero = Duration(milliseconds: 500);

  /// Camera scanning loop.
  static const Duration durationScan = Duration(milliseconds: 1600);

  /// Cold-start copy threshold for backend calls.
  static const Duration durationWakingThreshold = Duration(seconds: 2);

  /// Upper bound for network-backed loading states.
  static const Duration durationNetworkTimeout = Duration(seconds: 20);

  /// Loop duration for branded shimmer effects.
  static const Duration durationShimmer = Duration(seconds: 2);

  // ── Curve tokens ─────────────────────────────────────────────────────

  /// Standard ease-out for most transitions.
  static const Curve curveStandard = Curves.easeOutCubic;

  /// Emphasis curve for hero transitions.
  static const Curve curveEmphasis = Curves.easeInOutQuart;

  // ── Spring simulation ────────────────────────────────────────────────

  /// Spring description: mass 1, stiffness 180, damping 20.
  /// Used for bounce/elastic interactions (add-to-cart, bottom sheets).
  static const SpringDescription springDescription = SpringDescription(
    mass: 1,
    stiffness: 180,
    damping: 20,
  );

  /// Creates a [SpringSimulation] starting from [start] to [end].
  ///
  /// [velocity] defaults to 0 (released from rest).
  static SpringSimulation createSpring({
    double start = 0,
    double end = 1,
    double velocity = 0,
  }) {
    return SpringSimulation(springDescription, start, end, velocity);
  }

  /// A [Curve] backed by our spring simulation.
  /// Use this when you need a Curve rather than a raw simulation
  /// (e.g. inside an [AnimatedContainer] or [CurvedAnimation]).
  static const Curve curveSpring = _SpringCurve(
    mass: 1,
    stiffness: 180,
    damping: 20,
  );

  // ── Staggered list helpers ───────────────────────────────────────────

  /// Default stagger interval per item.
  static const Duration staggerInterval = Duration(milliseconds: 50);

  /// Minimum stagger interval.
  static const Duration staggerIntervalMin = Duration(milliseconds: 40);

  /// Maximum stagger interval.
  static const Duration staggerIntervalMax = Duration(milliseconds: 60);

  /// Returns the delay for the [index]-th item in a staggered reveal.
  ///
  /// [intervalMs] defaults to 50ms (midpoint of 40–60ms range).
  static Duration staggerDelay(int index, {int intervalMs = 50}) {
    return Duration(milliseconds: index * intervalMs);
  }

  /// Returns a total animation duration for a staggered list of [itemCount]
  /// items, accounting for stagger + per-item animation.
  static Duration staggeredListDuration(
    int itemCount, {
    int intervalMs = 50,
    Duration itemDuration = durationBase,
  }) {
    if (itemCount <= 0) return Duration.zero;
    final totalStagger = (itemCount - 1) * intervalMs;
    return Duration(milliseconds: totalStagger + itemDuration.inMilliseconds);
  }

  // ── Hero tag convention ──────────────────────────────────────────────

  /// Generates a consistent hero tag for card→detail transitions.
  ///
  /// Usage:
  /// ```dart
  /// Hero(
  ///   tag: AppMotion.heroTag('product_image', productId),
  ///   child: ...
  /// )
  /// ```
  static String heroTag(String prefix, String id) => '${prefix}_$id';

  /// Product image hero tag.
  static String productImageHero(String productId) =>
      heroTag('product_image', productId);

  /// Product card hero tag (for the entire card container).
  static String productCardHero(String productId) =>
      heroTag('product_card', productId);

  /// Product price hero tag.
  static String productPriceHero(String productId) =>
      heroTag('product_price', productId);
}

/// A [Curve] implementation backed by a spring simulation.
///
/// The curve is normalised so that t ∈ [0, 1] maps to the spring's
/// settling trajectory. The spring is considered settled when the
/// simulation reports `isDone`.
class _SpringCurve extends Curve {
  const _SpringCurve({
    required this.mass,
    required this.stiffness,
    required this.damping,
  });

  final double mass;
  final double stiffness;
  final double damping;

  @override
  double transformInternal(double t) {
    final spring = SpringDescription(
      mass: mass,
      stiffness: stiffness,
      damping: damping,
    );
    // Simulate from 0 → 1 with 0 initial velocity.
    final simulation = SpringSimulation(spring, 0, 1, 0);

    // Find the settling time by sampling up to 5 seconds.
    const maxTime = 5.0;
    const step = 0.001;
    var settlingTime = maxTime;
    for (var time = 0.0; time <= maxTime; time += step) {
      if (simulation.isDone(time)) {
        settlingTime = time;
        break;
      }
    }

    // Map normalised t to the spring's position.
    final simulationTime = t * settlingTime;
    return simulation.x(simulationTime).clamp(0.0, 1.0);
  }
}

/// A widget that animates its child into view with a staggered delay
/// and the spring curve.
///
/// Wrap list items with this for the canonical staggered-reveal pattern.
class StaggeredListItem extends StatefulWidget {
  const StaggeredListItem({
    super.key,
    required this.index,
    required this.child,
    this.intervalMs = 50,
    this.direction = AxisDirection.up,
  });

  /// The index of this item in the list (determines delay).
  final int index;

  /// The child widget to animate.
  final Widget child;

  /// Stagger interval in ms per item.
  final int intervalMs;

  /// Direction of the slide-in animation.
  final AxisDirection direction;

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.durationBase,
    );

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.curveStandard,
    );

    final slideBegin = switch (widget.direction) {
      AxisDirection.up => const Offset(0, 0.15),
      AxisDirection.down => const Offset(0, -0.15),
      AxisDirection.left => const Offset(0.15, 0),
      AxisDirection.right => const Offset(-0.15, 0),
    };

    _slide = Tween<Offset>(begin: slideBegin, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.curveSpring),
    );

    // Delay based on index.
    Future.delayed(
      AppMotion.staggerDelay(widget.index, intervalMs: widget.intervalMs),
      () {
        if (mounted) _controller.forward();
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Mixin providing a spring-animated controller for widgets that need
/// bounce/elastic interactions (e.g. add-to-cart button).
mixin SpringAnimationMixin<T extends StatefulWidget>
    on SingleTickerProviderStateMixin<T> {
  late final AnimationController springController;

  void initSpringController({Duration? duration}) {
    springController = AnimationController(
      vsync: this,
      duration: duration ?? AppMotion.durationBase,
    );
  }

  /// Runs a spring-forward animation from current value to 1.0.
  void springForward() {
    springController.forward();
  }

  /// Runs a bounce animation: quick scale up then back to rest.
  Future<void> springBounce({double peak = 1.15}) async {
    await springController.animateTo(
      peak,
      duration: AppMotion.durationFast,
      curve: AppMotion.curveStandard,
    );
    await springController.animateTo(
      1.0,
      duration: AppMotion.durationBase,
      curve: AppMotion.curveSpring,
    );
  }

  @mustCallSuper
  void disposeSpringController() {
    springController.dispose();
  }
}
