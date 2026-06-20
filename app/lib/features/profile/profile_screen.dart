import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/design/design.dart';
import '../../shared/widgets/widgets.dart';
import '../catalog/catalog_ui.dart';
import '../wishlist/providers/wishlist_controller.dart';

class ProfileIdentity {
  const ProfileIdentity({
    required this.title,
    required this.subtitle,
    required this.isGuest,
  });

  final String title;
  final String subtitle;
  final bool isGuest;
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({
    super.key,
    this.identityOverride,
    this.wishlistProductsOverride,
    this.logoutAction,
  });

  final ProfileIdentity? identityOverride;
  final List<Product>? wishlistProductsOverride;
  final Future<void> Function()? logoutAction;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _loggingOut = false;

  ProfileIdentity get _identity {
    final override = widget.identityOverride;
    if (override != null) return override;
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } on FirebaseException {
      user = null;
    }
    final displayName = user?.displayName?.trim();
    return ProfileIdentity(
      title: displayName?.isNotEmpty == true
          ? displayName!
          : user?.isAnonymous == true
          ? 'Guest explorer'
          : 'Haul member',
      subtitle: user?.email ?? 'A private guest session',
      isGuest: user?.isAnonymous ?? true,
    );
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await (widget.logoutAction?.call() ??
          ref.read(authControllerProvider.notifier).logout());
      if (mounted) context.go('/auth');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
          duration: const Duration(seconds: 10),
        ),
      );
      setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = _identity;
    final wishlist = widget.wishlistProductsOverride == null
        ? ref.watch(wishlistControllerProvider)
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: AppSpacing.paddingLg,
                  sliver: SliverList.list(
                    children: [
                      _ProfileHeader(identity: identity),
                      AppSpacing.gapXl,
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Saved signals',
                              style: AppTypography.h2,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/wishlist'),
                            child: const Text('View wishlist'),
                          ),
                        ],
                      ),
                      AppSpacing.gapSm,
                      if (widget.wishlistProductsOverride != null)
                        _WishlistPreview(
                          products: widget.wishlistProductsOverride!,
                        )
                      else
                        wishlist!.when(
                          data: (ids) => _WishlistProductLoader(ids: ids),
                          loading: _WishlistPreview.loading,
                          error: (_, _) => const HaulErrorState(
                            title: 'Wishlist unavailable',
                            subtitle: 'Your saved items are still safe.',
                          ),
                        ),
                      AppSpacing.gapXl,
                      Text('Your account', style: AppTypography.h2),
                      AppSpacing.gapSm,
                      _SettingsCard(
                        children: [
                          _SettingsRow(
                            icon: Icons.receipt_long_outlined,
                            title: 'Order history',
                            subtitle: 'Track every immutable purchase snapshot',
                            onTap: () => context.push('/orders'),
                          ),
                          _SettingsRow(
                            icon: Icons.favorite_border_rounded,
                            title: 'Wishlist',
                            subtitle: 'Return to products you saved',
                            onTap: () => context.push('/wishlist'),
                          ),
                          _SettingsRow(
                            icon: Icons.tune_rounded,
                            title: 'Recommendation settings',
                            subtitle: identity.isGuest
                                ? 'Create an account to save preferences'
                                : 'Personalized from your selected categories',
                            onTap: identity.isGuest
                                ? () => context.push('/auth?link=true')
                                : null,
                          ),
                          const _SettingsRow(
                            icon: Icons.shield_outlined,
                            title: 'Privacy',
                            subtitle:
                                'Firebase-backed account and session data',
                          ),
                        ],
                      ),
                      AppSpacing.gapLg,
                      HaulButton(
                        label: 'Log out',
                        icon: const Icon(Icons.logout_rounded),
                        variant: HaulButtonVariant.secondary,
                        isLoading: _loggingOut,
                        onPressed: _loggingOut ? null : _logout,
                        fullWidth: true,
                      ),
                      AppSpacing.gapXl,
                    ],
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.identity});

  final ProfileIdentity identity;

  @override
  Widget build(BuildContext context) {
    final initial = identity.title.characters.first.toUpperCase();
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: AppRadius.cardBorderRadius,
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: AppSpacing.xxxl,
            height: AppSpacing.xxxl,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: AppTypography.h1.copyWith(color: AppColors.surface),
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  identity.title,
                  style: AppTypography.h2.copyWith(color: AppColors.surface),
                ),
                AppSpacing.gapXxs,
                Text(
                  identity.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.accentSoft,
                  ),
                ),
              ],
            ),
          ),
          if (identity.isGuest) const _GuestBadge(),
        ],
      ),
    );
  }
}

class _GuestBadge extends StatelessWidget {
  const _GuestBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentSoft.withValues(alpha: 0.25),
        borderRadius: AppRadius.chipBorderRadius,
      ),
      child: Text(
        'GUEST',
        style: AppTypography.captionMedium.copyWith(color: AppColors.surface),
      ),
    );
  }
}

class _WishlistProductLoader extends ConsumerWidget {
  const _WishlistProductLoader({required this.ids});

  final List<String> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ids.isEmpty) {
      return HaulEmptyState(
        title: 'Nothing saved yet',
        subtitle: 'Tap a heart on any product to keep it close.',
        icon: Icons.favorite_border_rounded,
        actionLabel: 'Browse products',
        onAction: () => context.go('/home'),
      );
    }
    return FutureBuilder<List<Product>>(
      future: Future.wait(
        ids.take(4).map(ref.read(apiClientProvider).getProduct),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _WishlistPreview.loading();
        }
        if (snapshot.hasError) {
          return const HaulErrorState(
            title: 'Saved items are waking up',
            subtitle: 'Open your wishlist to retry.',
          );
        }
        return _WishlistPreview(products: snapshot.data ?? const []);
      },
    );
  }
}

class _WishlistPreview extends StatelessWidget {
  const _WishlistPreview({required this.products});

  final List<Product> products;

  static Widget loading() {
    return SizedBox(
      height: 104,
      child: Row(
        children: List.generate(
          3,
          (index) => Expanded(
            child: Padding(
              padding: index == 2
                  ? EdgeInsets.zero
                  : const EdgeInsets.only(right: AppSpacing.sm),
              child: HaulSkeleton.rect(
                width: double.infinity,
                height: 104,
                borderRadius: AppRadius.cardBorderRadius,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, _) => AppSpacing.hGapSm,
        itemBuilder: (context, index) {
          final product = products[index];
          return InkWell(
            onTap: () => context.push(
              '/products/${product.id}',
              extra: ProductRouteExtra(
                product: product,
                heroTag: AppMotion.productCardHero(product.id),
              ),
            ),
            borderRadius: AppRadius.cardBorderRadius,
            child: SizedBox(
              width: 104,
              child: ClipRRect(
                borderRadius: AppRadius.cardBorderRadius,
                child: ColoredBox(
                  color: AppColors.border,
                  child: product.primaryImageUrl == null
                      ? const Icon(Icons.image_outlined)
                      : Image.network(
                          product.primaryImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.image_not_supported_outlined),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorderRadius,
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              Divider(height: AppSpacing.xxs, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        contentPadding: AppSpacing.paddingHorizontalMd,
        leading: Icon(icon, color: AppColors.accent),
        title: Text(title, style: AppTypography.bodySmallMedium),
        subtitle: Text(subtitle, style: AppTypography.caption),
        trailing: onTap == null
            ? null
            : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
