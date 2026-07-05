import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/design/design.dart';
import '../../core/session/session_resource_registry.dart';
import '../../shared/widgets/widgets.dart';
import '../catalog/catalog_ui.dart';
import 'camera_gateway.dart';
import 'visual_image_preview.dart';

enum CameraViewState {
  initializing,
  ready,
  permissionDenied,
  error,
  processing,
}

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key, this.gateway});

  final CameraGateway? gateway;

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final CameraGateway _gateway;
  late final AnimationController _scanController;
  late final AnimationController _focusController;
  late final AnimationController _captureController;
  CameraViewState _state = CameraViewState.initializing;
  String? _message;
  String? _processingImagePath;
  bool _wakingUp = false;
  Timer? _wakingTimer;
  late final SessionResourceDisposer _resourceDisposer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _gateway = widget.gateway ?? PluginCameraGateway();
    _resourceDisposer = _gateway.dispose;
    SessionResourceRegistry.instance.register(_resourceDisposer);
    _scanController = AnimationController(
      vsync: this,
      duration: AppMotion.durationScan,
    )..repeat(reverse: true);
    _focusController = AnimationController(
      vsync: this,
      duration: AppMotion.durationSlow,
    )..repeat(reverse: true);
    _captureController = AnimationController(
      vsync: this,
      duration: AppMotion.durationFast,
      value: 1,
      lowerBound: 0.88,
      upperBound: 1,
    );
    unawaited(_initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_gateway.dispose());
    } else if (state == AppLifecycleState.resumed &&
        _state != CameraViewState.processing) {
      unawaited(_initialize());
    }
  }

  Future<void> _initialize() async {
    if (!mounted) return;
    setState(() {
      _state = CameraViewState.initializing;
      _message = null;
    });
    try {
      await _gateway.initialize().timeout(AppMotion.durationNetworkTimeout);
      if (!mounted) return;
      setState(() => _state = CameraViewState.ready);
    } on CameraFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _state = error.kind == CameraFailureKind.permissionDenied
            ? CameraViewState.permissionDenied
            : CameraViewState.error;
        _message = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = CameraViewState.error;
        _message = 'The camera could not start. You can still choose a photo.';
      });
    }
  }

  Future<void> _capture() async {
    if (_state != CameraViewState.ready) return;
    HapticFeedback.mediumImpact();
    await _captureController.animateTo(
      0.88,
      duration: AppMotion.durationFast,
      curve: AppMotion.curveStandard,
    );
    try {
      final path = await _gateway.capture();
      await _process(path);
    } finally {
      if (mounted) {
        await _captureController.animateTo(
          1,
          duration: AppMotion.durationBase,
          curve: AppMotion.curveSpring,
        );
      }
    }
  }

  Future<void> _pickGallery() async {
    try {
      final path = await _gateway.pickFromGallery();
      if (path != null) await _process(path);
    } catch (_) {
      if (mounted) {
        _showMessage('That photo could not be opened. Try another one.');
      }
    }
  }

  Future<void> _process(String imagePath) async {
    if (!mounted) return;
    setState(() {
      _state = CameraViewState.processing;
      _processingImagePath = imagePath;
      _wakingUp = false;
    });
    _wakingTimer?.cancel();
    _wakingTimer = Timer(AppMotion.durationWakingThreshold, () {
      if (mounted && _state == CameraViewState.processing) {
        setState(() => _wakingUp = true);
      }
    });

    try {
      final labels = await _gateway.labelsFor(imagePath);
      final imageBytes = await _gateway.bytesFor(imagePath);
      final response = await ref
          .read(apiClientProvider)
          .visualSearch(
            imagePath: imagePath,
            imageBytes: imageBytes,
            mlKitLabels: labels,
          );
      _wakingTimer?.cancel();
      if (!mounted) return;
      await _showResults(response);
    } on ApiException catch (error) {
      if (!mounted) return;
      _showMessage(error.error.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Visual search is unavailable right now. Try again.');
    } finally {
      _wakingTimer?.cancel();
      if (mounted) {
        setState(() {
          _state = CameraViewState.ready;
          _processingImagePath = null;
          _wakingUp = false;
        });
      }
    }
  }

  Future<void> _showResults(VisualSearchResponse response) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim,
      builder: (sheetContext) => _VisualSearchResultsSheet(
        response: response,
        onProductTap: (product, heroTag) {
          Navigator.of(sheetContext).pop();
          context.push(
            '/products/${product.id}',
            extra: ProductRouteExtra(product: product, heroTag: heroTag),
          );
        },
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wakingTimer?.cancel();
    _scanController.dispose();
    _focusController.dispose();
    _captureController.dispose();
    SessionResourceRegistry.instance.unregister(_resourceDisposer);
    unawaited(_gateway.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.textPrimary,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(),
          if (_state == CameraViewState.ready)
            _RingsScannerOverlay(
              animation: _scanController,
            ),
          SafeArea(child: _buildControls()),
          if (_state == CameraViewState.processing)
            _ProcessingOverlay(wakingUp: _wakingUp),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    if (_state == CameraViewState.ready) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width,
          height: MediaQuery.sizeOf(context).height,
          child: _gateway.buildPreview(),
        ),
      );
    }
    if (_state == CameraViewState.processing && _processingImagePath != null) {
      return buildVisualImagePreview(_processingImagePath!);
    }
    return const ColoredBox(color: AppColors.textPrimary);
  }

  Widget _buildControls() {
    if (_state == CameraViewState.initializing) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (_state == CameraViewState.permissionDenied) {
      return _CameraRecoveryState(
        icon: Icons.no_photography_outlined,
        title: 'Camera access is off',
        message:
            _message ??
            'Allow camera access in Settings, or choose a photo instead.',
        primaryLabel: 'Open Settings',
        onPrimary: _gateway.openSettings,
        onGallery: _pickGallery,
      );
    }
    if (_state == CameraViewState.error) {
      return _CameraRecoveryState(
        icon: Icons.camera_alt_outlined,
        title: 'Camera needs a reset',
        message:
            _message ??
            'The camera could not start. You can retry or choose a photo.',
        primaryLabel: 'Try Again',
        onPrimary: _initialize,
        onGallery: _pickGallery,
      );
    }

    return Column(
      children: [
        Padding(
          padding: AppSpacing.paddingMd,
          child: Row(
            children: [
              _RoundCameraButton(
                tooltip: 'Close camera',
                icon: Icons.close_rounded,
                onPressed: context.pop,
              ),
              const Spacer(),
              if (_state == CameraViewState.ready)
                _RoundCameraButton(
                  tooltip: 'Toggle flash',
                  icon: _gateway.flashEnabled
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded,
                  onPressed: () async {
                    await _gateway.toggleFlash();
                    if (mounted) setState(() {});
                  },
                ),
            ],
          ),
        ),
        const Spacer(),
        if (_state == CameraViewState.ready)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _RoundCameraButton(
                  tooltip: 'Choose from gallery',
                  icon: Icons.photo_library_outlined,
                  onPressed: _pickGallery,
                ),
                ScaleTransition(
                  scale: _captureController,
                  child: Semantics(
                    button: true,
                    label: 'Capture photo',
                    child: GestureDetector(
                      key: const ValueKey('capture-button'),
                      onTap: _capture,
                      child: Container(
                        width: AppSpacing.xxxl,
                        height: AppSpacing.xxxl,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface,
                          border: Border.all(
                            color: AppColors.accent,
                            width: AppSpacing.xxs,
                          ),
                          boxShadow: AppShadows.elevated,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xxl),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProcessingOverlay extends StatelessWidget {
  const _ProcessingOverlay({required this.wakingUp});

  final bool wakingUp;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.scrim,
      child: Center(
        child: Container(
          key: const ValueKey('processing-card'),
          margin: AppSpacing.paddingLg,
          padding: AppSpacing.paddingXl,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardBorderRadius,
            boxShadow: AppShadows.elevated,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const HaulAiBadge(label: 'Visual Search'),
              AppSpacing.gapLg,
              const CircularProgressIndicator(color: AppColors.accent),
              AppSpacing.gapLg,
              AnimatedSwitcher(
                duration: AppMotion.durationBase,
                child: Column(
                  key: ValueKey(wakingUp),
                  children: [
                    Text(
                      wakingUp
                          ? 'Waking up your search'
                          : 'Reading the visual signals',
                      textAlign: TextAlign.center,
                      style: AppTypography.h2,
                    ),
                    AppSpacing.gapXs,
                    Text(
                      wakingUp
                          ? 'The search service is warming up. Your photo is safe and still processing.'
                          : 'Matching color, material, shape, and style.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraRecoveryState extends StatelessWidget {
  const _CameraRecoveryState({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onGallery,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final FutureOr<void> Function() onPrimary;
  final FutureOr<void> Function() onGallery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Container(
          padding: AppSpacing.paddingXl,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardBorderRadius,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.accent, size: AppSpacing.xxl),
              AppSpacing.gapMd,
              Text(title, style: AppTypography.h2, textAlign: TextAlign.center),
              AppSpacing.gapXs,
              Text(
                message,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapLg,
              HaulButton(
                label: primaryLabel,
                onPressed: () => onPrimary(),
                fullWidth: true,
              ),
              AppSpacing.gapSm,
              HaulButton(
                label: 'Choose from Gallery',
                onPressed: () => onGallery(),
                variant: HaulButtonVariant.secondary,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundCameraButton extends StatelessWidget {
  const _RoundCameraButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: AppColors.surface,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.scrim,
          minimumSize: const Size.square(AppSpacing.xxl),
        ),
      ),
    );
  }
}

class _RingsScannerOverlay extends StatelessWidget {
  const _RingsScannerOverlay({
    required this.animation,
  });

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.7),
            BlendMode.srcOut,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: MediaQuery.sizeOf(context).width * 0.85,
                  height: MediaQuery.sizeOf(context).width * 0.85,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        Center(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, child) => SizedBox(
                width: MediaQuery.sizeOf(context).width * 0.85,
                height: MediaQuery.sizeOf(context).width * 0.85,
                child: CustomPaint(
                  painter: _RingsPainter(animationValue: animation.value),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + AppSpacing.xxl,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera, color: AppColors.accent, size: AppSpacing.lg),
                  AppSpacing.hGapSm,
                  Text(
                    'AI SCANNER',
                    style: AppTypography.bodySmallMedium.copyWith(color: AppColors.accent, letterSpacing: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.animationValue});
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.5;

    final paint1 = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);

    final paint2 = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Ring 1
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi / 6); 
    canvas.scale(1.0, math.cos(animationValue * math.pi)); 
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: radius * 2, height: radius * 2),
      paint1,
    );
    canvas.restore();

    // Ring 2
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 3); 
    canvas.scale(1.0, math.cos(animationValue * math.pi + math.pi / 2)); 
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: radius * 2, height: radius * 2),
      paint2,
    );
    canvas.restore();
    
    // Center pulse dot
    final pulsePaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.4 + 0.6 * math.sin(animationValue * math.pi).abs())
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, pulsePaint);
  }

  @override
  bool shouldRepaint(covariant _RingsPainter oldDelegate) => 
      oldDelegate.animationValue != animationValue;
}

class _VisualSearchResultsSheet extends StatefulWidget {
  const _VisualSearchResultsSheet({
    required this.response,
    required this.onProductTap,
  });

  final VisualSearchResponse response;
  final void Function(Product product, String heroTag) onProductTap;

  @override
  State<_VisualSearchResultsSheet> createState() =>
      _VisualSearchResultsSheetState();
}

class _VisualSearchResultsSheetState extends State<_VisualSearchResultsSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _slide = Tween(
      begin: const Offset(0, 0.22),
      end: Offset.zero,
    ).animate(_controller);
    _fade = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.curveStandard,
    );
    _controller.animateWith(AppMotion.createSpring());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final response = widget.response;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          key: const ValueKey('visual-results-sheet'),
          height: MediaQuery.sizeOf(context).height * 0.82,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: AppRadius.bottomSheetBorderRadius,
            boxShadow: AppShadows.elevated,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                AppSpacing.gapSm,
                Container(
                  width: AppSpacing.xxl,
                  height: AppSpacing.xxs,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: AppRadius.chipBorderRadius,
                  ),
                ),
                Padding(
                  padding: AppSpacing.paddingLg,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Closest matches', style: AppTypography.h2),
                            AppSpacing.gapXxs,
                            Text(
                              response.detectedAttributes.objectType ??
                                  response
                                      .detectedAttributes
                                      .primaryCategory
                                      .name,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      HaulAiBadge(
                        label: response.fallbackMode
                            ? 'On-device match'
                            : 'AI match',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: AppSpacing.md,
                          mainAxisSpacing: AppSpacing.md,
                          childAspectRatio: 0.5,
                        ),
                    itemCount: response.products.length,
                    itemBuilder: (context, index) {
                      final product = response.products[index];
                      final heroTag = AppMotion.heroTag(
                        'visual_result',
                        product.id,
                      );
                      return StaggeredListItem(
                        index: index,
                        child: HaulProductCard(
                          data: product.toCardData().copyWithMatch(
                            score: index < response.matchScores.length
                                ? response.matchScores[index]
                                : null,
                            sourceLabel: response.fallbackMode
                                ? 'On-device'
                                : null,
                          ),
                          heroTag: heroTag,
                          onTap: () => widget.onProductTap(product, heroTag),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on HaulProductCardData {
  HaulProductCardData copyWithMatch({
    required double? score,
    required String? sourceLabel,
  }) {
    return HaulProductCardData(
      id: id,
      name: name,
      price: price,
      salePrice: salePrice,
      imageUrl: imageUrl,
      rating: rating,
      reviewCount: reviewCount,
      isNew: isNew,
      isSale: isSale,
      isOutOfStock: isOutOfStock,
      isWishlisted: isWishlisted,
      matchScore: score,
      matchSourceLabel: sourceLabel,
      category: category,
    );
  }
}
