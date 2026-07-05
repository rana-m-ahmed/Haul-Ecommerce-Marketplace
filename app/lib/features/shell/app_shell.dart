import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../cart/providers/cart_controller.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: navigationShell,
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: navigationShell.currentIndex,
        bottomPadding: bottomPadding,
        onTabTap: (index) => _onTap(context, index),
        onCameraTap: () => context.push('/camera'),
      ),
    );
  }
}

// ── Floating Nav Bar ────────────────────────────────────────────────────────

class _FloatingNavBar extends ConsumerWidget {
  const _FloatingNavBar({
    required this.currentIndex,
    required this.bottomPadding,
    required this.onTabTap,
    required this.onCameraTap,
  });

  final int currentIndex;
  final double bottomPadding;
  final ValueChanged<int> onTabTap;
  final VoidCallback onCameraTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartControllerProvider.select((state) {
      return state.value?.fold(0, (sum, item) => sum + item.quantity) ?? 0;
    }));

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        bottomPadding + AppSpacing.sm,
      ),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardBorderRadius,
          border: Border.all(color: AppColors.border, width: 0.5),
          boxShadow: AppShadows.elevated,
        ),
        child: Row(
          children: [
            // Home
            _NavTab(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
              isActive: currentIndex == 0,
              onTap: () => onTabTap(0),
            ),
            // Search
            _NavTab(
              icon: Icons.search_outlined,
              activeIcon: Icons.search_rounded,
              label: 'Search',
              isActive: currentIndex == 1,
              onTap: () => onTabTap(1),
            ),
            // Camera (center)
            _CenterCameraButton(onTap: onCameraTap),
            // Cart
            _NavTab(
              icon: Icons.shopping_bag_outlined,
              activeIcon: Icons.shopping_bag_rounded,
              label: 'Cart',
              isActive: currentIndex == 2,
              badgeCount: cartCount,
              onTap: () => onTabTap(2),
            ),
            // Profile
            _NavTab(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
              isActive: currentIndex == 3,
              onTap: () => onTabTap(3),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Individual Nav Tab ──────────────────────────────────────────────────────

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.accent : AppColors.textSecondary;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: AppMotion.durationFast,
              child: Badge(
                key: ValueKey(isActive),
                isLabelVisible: badgeCount > 0,
                label: Text(
                  badgeCount.toString(),
                  style: const TextStyle(fontSize: 10),
                ),
                child: Icon(
                  isActive ? activeIcon : icon,
                  color: color,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: AppMotion.durationFast,
              style: AppTypography.captionMedium.copyWith(
                color: color,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Center Camera Button with Pulse ─────────────────────────────────────────

class _CenterCameraButton extends StatefulWidget {
  const _CenterCameraButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_CenterCameraButton> createState() => _CenterCameraButtonState();
}

class _CenterCameraButtonState extends State<_CenterCameraButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.durationSlow,
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.curveSpring),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _pulse,
        child: Container(
          width: 56,
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF6B47), // slightly lighter coral
                AppColors.accent,  // core accent
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.35),
                offset: const Offset(0, 4),
                blurRadius: 16,
                spreadRadius: 0,
              ),
            ],
          ),
          child: const Icon(
            Icons.photo_camera_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}
