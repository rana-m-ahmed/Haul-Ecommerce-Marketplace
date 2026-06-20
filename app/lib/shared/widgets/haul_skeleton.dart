import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/design/design.dart';

/// Shimmer skeleton loader matching exact HaulProductCard dimensions.
///
/// Use [HaulSkeleton.productCard] for the grid variant skeleton
/// and [HaulSkeleton.productCardHorizontal] for the horizontal variant.
class HaulSkeleton extends StatelessWidget {
  const HaulSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  final double width;
  final double height;
  final BorderRadius? borderRadius;

  /// Grid-variant product card skeleton (matches HaulProductCard grid layout).
  static Widget productCard() {
    return const _ProductCardSkeleton(isHorizontal: false);
  }

  /// Horizontal-variant product card skeleton.
  static Widget productCardHorizontal() {
    return const _ProductCardSkeleton(isHorizontal: true);
  }

  /// Generic rectangular skeleton placeholder.
  static Widget rect({
    required double width,
    required double height,
    BorderRadius? borderRadius,
  }) {
    return HaulSkeleton(
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }

  /// Circular skeleton placeholder.
  static Widget circle({required double diameter}) {
    return HaulSkeleton(
      width: diameter,
      height: diameter,
      borderRadius: BorderRadius.all(Radius.circular(diameter / 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.shimmerBase,
          borderRadius: borderRadius ?? AppRadius.cardBorderRadius,
        ),
      ),
    );
  }
}

/// Product card skeleton that matches the exact real card dimensions.
class _ProductCardSkeleton extends StatelessWidget {
  const _ProductCardSkeleton({required this.isHorizontal});

  final bool isHorizontal;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: isHorizontal ? _buildHorizontal() : _buildGrid(),
    );
  }

  Widget _buildGrid() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.shimmerBase,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.card),
                  topRight: Radius.circular(AppRadius.card),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.shimmerBase,
                    borderRadius: AppRadius.microBorderRadius,
                  ),
                ),
                AppSpacing.gapXs,
                Container(
                  height: 14,
                  width: 100,
                  decoration: BoxDecoration(
                    color: AppColors.shimmerBase,
                    borderRadius: AppRadius.microBorderRadius,
                  ),
                ),
                AppSpacing.gapXs,
                Container(
                  height: 14,
                  width: 60,
                  decoration: BoxDecoration(
                    color: AppColors.shimmerBase,
                    borderRadius: AppRadius.microBorderRadius,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontal() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorderRadius,
      ),
      child: Row(
        children: [
          Container(
            width: 120,
            decoration: BoxDecoration(
              color: AppColors.shimmerBase,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.card),
                bottomLeft: Radius.circular(AppRadius.card),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.shimmerBase,
                      borderRadius: AppRadius.microBorderRadius,
                    ),
                  ),
                  AppSpacing.gapXs,
                  Container(
                    height: 14,
                    width: 80,
                    decoration: BoxDecoration(
                      color: AppColors.shimmerBase,
                      borderRadius: AppRadius.microBorderRadius,
                    ),
                  ),
                  AppSpacing.gapSm,
                  Container(
                    height: 14,
                    width: 50,
                    decoration: BoxDecoration(
                      color: AppColors.shimmerBase,
                      borderRadius: AppRadius.microBorderRadius,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
