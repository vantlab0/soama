import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/soama_colors.dart';
import '../../../../shared/models/service_provider.dart';
import '../../../../shared/widgets/glass_surface.dart';
import '../../../../shared/widgets/service_badge.dart';
import '../../../../shared/widgets/soama_buttons.dart';
import '../../reviews/presentation/providers/reviews_provider.dart';
import 'providers/provider_provider.dart';

class ProviderDetailsScreen extends ConsumerStatefulWidget {
  final String providerId;
  final ServiceProvider? initialProvider;

  const ProviderDetailsScreen({
    super.key,
    required this.providerId,
    this.initialProvider,
  });

  @override
  ConsumerState<ProviderDetailsScreen> createState() => _ProviderDetailsScreenState();
}

class _ProviderDetailsScreenState extends ConsumerState<ProviderDetailsScreen> {
  late ServiceProvider _provider;
  bool _isBookmarked = false;
  bool _isBioExpanded = false;
  ProviderServiceOffering? _selectedService;

  @override
  void initState() {
    super.initState();
    _provider = widget.initialProvider ??
        ServiceProvider.findById(widget.providerId) ??
        ServiceProvider.nearbyPros.first;
  }

  @override
  void didUpdateWidget(covariant ProviderDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.providerId != oldWidget.providerId ||
        widget.initialProvider != oldWidget.initialProvider) {
      setState(() {
        _provider = widget.initialProvider ??
            ServiceProvider.findById(widget.providerId) ??
            ServiceProvider.nearbyPros.first;
        _selectedService = null;
      });
    }
  }

  void _toggleBookmark() {
    HapticFeedback.selectionClick();
    setState(() {
      _isBookmarked = !_isBookmarked;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isBookmarked
              ? '${_provider.name} saved to your favorites'
              : '${_provider.name} removed from your favorites',
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusMd),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareProvider() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Profile link copied: soama.ng/pro/${_provider.id}'),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusMd),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openGalleryImage(BuildContext context, String imageUrl, int index) {
    HapticFeedback.lightImpact();
    final colors = context.soamaColors;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
              const SizedBox(height: SoamaSpacing.xs),
              ClipRRect(
                borderRadius: SoamaRadii.radiusXl,
                child: Image(
                  image: ResizeImage(
                    NetworkImage(imageUrl),
                    width: 1080,
                    height: 1080,
                  ),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 260,
                    color: colors.surfaceSubtle,
                    child: Center(
                      child: Icon(Icons.broken_image_rounded, color: colors.textTertiary, size: 48),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: SoamaSpacing.md),
              Text(
                'Project Image ${index + 1} of ${_provider.gallery.length}',
                style: SoamaTypography.bodySmall.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToRequestService() {
    HapticFeedback.lightImpact();
    context.push(
      AppRoutes.requestService,
      extra: RequestServiceArgs(
        provider: _provider,
        selectedService: _selectedService,
      ),
    );
  }

  void _navigateToMessages() {
    HapticFeedback.lightImpact();
    context.go(AppRoutes.messages);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting chat with ${_provider.name}...'),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusMd),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final providerAsync = ref.watch(providerDetailsProvider(widget.providerId));
    final liveProvider = widget.initialProvider ??
        providerAsync.valueOrNull ??
        ServiceProvider.findById(widget.providerId) ??
        ServiceProvider.nearbyPros.first;
    _provider = liveProvider;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Stack(
        children: [
          // Scrollable Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Cover Photo & Floating Navigation Controls
              _buildSliverHeader(context),

              // 2. Main Provider Body Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: SoamaSpacing.md),

                      // Availability & Working Hours Pill
                      _buildAvailabilityBadge(context),

                      const SizedBox(height: SoamaSpacing.lg),

                      // Metric Stats Grid (Distance, Pricing, Completed Jobs)
                      _buildMetricRow(context),

                      const SizedBox(height: SoamaSpacing.xl),

                      // Professional Biography Section
                      _buildBiographySection(context),

                      const SizedBox(height: SoamaSpacing.xl),

                      // Trust & Verification Guarantee Badges
                      _buildTrustBadges(context),

                      const SizedBox(height: SoamaSpacing.xl),

                      // Services & Pricing List with Selection
                      _buildServicesSection(context),

                      const SizedBox(height: SoamaSpacing.xl),

                      // Portfolio / Project Gallery
                      if (_provider.gallery.isNotEmpty) ...[
                        _buildGallerySection(context),
                        const SizedBox(height: SoamaSpacing.xl),
                      ],

                      // Customer Reviews Section
                      _buildReviewsSection(context),

                      // Spacing for floating bottom action bar
                      SizedBox(height: bottomInset > 0 ? bottomInset + 100 : 110),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 3. Persistent Floating Bottom Action Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomActionBar(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverHeader(BuildContext context) {
    final colors = context.soamaColors;
    final topInset = MediaQuery.of(context).padding.top;

    return SliverToBoxAdapter(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Hero Cover Photo
          SizedBox(
            height: 270,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image(
                  image: ResizeImage(
                    NetworkImage(_provider.coverUrl),
                    width: 900,
                    height: 600,
                  ),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: colors.surfaceSubtle,
                    child: Center(
                      child: Icon(Icons.handyman_rounded, color: colors.textTertiary, size: 54),
                    ),
                  ),
                ),
                // Gradient Scrim for readable controls
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.65),
                        Colors.transparent,
                        Colors.black.withOpacity(0.55),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Floating Top App Bar (Back, Share, Bookmark)
          Positioned(
            top: topInset > 0 ? topInset + 6 : 14,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button
                _buildCircleActionButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                // Actions (Share & Bookmark)
                Row(
                  children: [
                    _buildCircleActionButton(
                      icon: Icons.share_outlined,
                      onTap: _shareProvider,
                    ),
                    const SizedBox(width: SoamaSpacing.xs),
                    _buildCircleActionButton(
                      icon: _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                      iconColor: _isBookmarked ? colors.accent : Colors.white,
                      onTap: _toggleBookmark,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Overlapping Provider Identity Card
          Positioned(
            left: 20,
            right: 20,
            bottom: -32,
            child: GlassSurface(
              borderRadius: SoamaRadii.radiusXl,
              padding: const EdgeInsets.all(16.0),
              blurIntensity: GlassBlurIntensity.medium,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar with verified badge
                  Stack(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          borderRadius: SoamaRadii.radiusLg,
                          border: Border.all(
                            color: colors.accent.withOpacity(0.7),
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image(
                            image: ResizeImage(
                              NetworkImage(_provider.avatarUrl),
                              width: 200,
                              height: 200,
                            ),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: colors.surfaceSubtle,
                              child: Icon(Icons.person_rounded, color: colors.textTertiary),
                            ),
                          ),
                        ),
                      ),
                      if (_provider.isVerified)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.verified_rounded,
                              size: 20,
                              color: colors.accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: SoamaSpacing.md),
                  // Provider name & trade
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _provider.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: SoamaTypography.titleLarge.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _provider.businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SoamaTypography.bodySmall.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            ServiceBadge.rating(
                              label: '${_provider.rating.toStringAsFixed(1)} (${_provider.reviewCount})',
                            ),
                            const SizedBox(width: SoamaSpacing.xs),
                            ServiceBadge(
                              label: _provider.badgeTitle,
                              color: colors.accent,
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildCircleActionButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.black.withOpacity(0.55),
      shape: CircleBorder(
        side: BorderSide(
          color: Colors.white.withOpacity(0.25),
          width: 0.8,
        ),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: iconColor ?? Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityBadge(BuildContext context) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;

    return Container(
      margin: const EdgeInsets.only(top: 24.0),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2214) : const Color(0xFFF3F8E4),
        borderRadius: SoamaRadii.radiusLg,
        border: Border.all(
          color: colors.accent.withOpacity(isDark ? 0.35 : 0.6),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: colors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: SoamaSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _provider.availability,
                  style: SoamaTypography.labelMedium.copyWith(
                    color: isDark ? colors.accent : const Color(0xFF283400),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _provider.workingHours,
                  style: SoamaTypography.labelSmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.access_time_rounded,
            size: 18,
            color: isDark ? colors.accent : const Color(0xFF4C5E09),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(BuildContext context) {
    final colors = context.soamaColors;

    return GlassSurface(
      borderRadius: SoamaRadii.radiusLg,
      padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 8.0),
      blurIntensity: GlassBlurIntensity.none,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricItem(
            context,
            icon: Icons.navigation_rounded,
            label: 'Distance',
            value: _provider.approximateDistance,
          ),
          Container(width: 1, height: 32, color: colors.border),
          _buildMetricItem(
            context,
            icon: Icons.payments_rounded,
            label: 'Rates From',
            value: _provider.startingPrice,
          ),
          Container(width: 1, height: 32, color: colors.border),
          _buildMetricItem(
            context,
            icon: Icons.place_rounded,
            label: 'Base Area',
            value: _provider.location.split(',').first,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colors = context.soamaColors;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colors.accent),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SoamaTypography.labelMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: SoamaTypography.labelSmall.copyWith(
              color: colors.textTertiary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiographySection(BuildContext context) {
    final colors = context.soamaColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About the Specialist',
          style: SoamaTypography.titleMedium.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: SoamaSpacing.xs),
        Text(
          _provider.bio,
          maxLines: _isBioExpanded ? 15 : 3,
          overflow: TextOverflow.ellipsis,
          style: SoamaTypography.bodyMedium.copyWith(
            color: colors.textSecondary,
            height: 1.5,
          ),
        ),
        if (_provider.bio.length > 120) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _isBioExpanded = !_isBioExpanded;
              });
            },
            child: Text(
              _isBioExpanded ? 'Show less' : 'Read more',
              style: SoamaTypography.labelMedium.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTrustBadges(BuildContext context) {
    final colors = context.soamaColors;

    final badges = [
      {
        'icon': Icons.shield_rounded,
        'title': 'Identity Verified',
        'subtitle': 'CAC / NIN Confirmed',
      },
      {
        'icon': Icons.lock_clock_rounded,
        'title': 'Escrow Protected',
        'subtitle': 'Funds held safely',
      },
      {
        'icon': Icons.thumb_up_alt_rounded,
        'title': 'Quality Guarantee',
        'subtitle': 'Verified standard',
      },
    ];

    return Row(
      children: badges.map((badge) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 6.0),
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
            decoration: BoxDecoration(
              color: colors.surfaceSubtle,
              borderRadius: SoamaRadii.radiusMd,
              border: Border.all(color: colors.glassBorder, width: 0.8),
            ),
            child: Column(
              children: [
                Icon(badge['icon'] as IconData, size: 20, color: colors.accent),
                const SizedBox(height: 6),
                Text(
                  badge['title'] as String,
                  textAlign: TextAlign.center,
                  style: SoamaTypography.labelSmall.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  badge['subtitle'] as String,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SoamaTypography.labelSmall.copyWith(
                    color: colors.textTertiary,
                    fontSize: 8.5,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildServicesSection(BuildContext context) {
    final colors = context.soamaColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Services & Pricing',
              style: SoamaTypography.titleMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_selectedService != null)
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedService = null);
                },
                child: Text(
                  'Clear selection',
                  style: SoamaTypography.labelSmall.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Select a service to tailor your request or request a custom quote',
          style: SoamaTypography.bodySmall.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: SoamaSpacing.sm),

        // List of service offerings
        ..._provider.services.map((service) {
          final isSelected = _selectedService?.id == service.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: SoamaSpacing.sm),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedService = isSelected ? null : service;
                });
              },
              borderRadius: SoamaRadii.radiusLg,
              child: AnimatedContainer(
                duration: SoamaMotion.snappy,
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.accent.withOpacity(context.isDarkMode ? 0.15 : 0.12)
                      : colors.surfaceSubtle,
                  borderRadius: SoamaRadii.radiusLg,
                  border: Border.all(
                    color: isSelected ? colors.accent : colors.glassBorder,
                    width: isSelected ? 1.6 : 0.8,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Radio/Check indicator
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? colors.accent : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? colors.accent : colors.textTertiary,
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Color(0xFF111215),
                            )
                          : null,
                    ),
                    const SizedBox(width: SoamaSpacing.md),
                    if (service.imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: SoamaRadii.radiusMd,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Image.network(
                            service.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: colors.surfaceSubtle,
                              child: Icon(Icons.broken_image_rounded, size: 18, color: colors.textTertiary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: SoamaSpacing.sm),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  service.title,
                                  style: SoamaTypography.titleSmall.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                service.price,
                                style: SoamaTypography.titleSmall.copyWith(
                                  color: colors.accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            service.description,
                            style: SoamaTypography.bodySmall.copyWith(
                              color: colors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.timer_outlined, size: 14, color: colors.textTertiary),
                              const SizedBox(width: 4),
                              Text(
                                service.duration,
                                style: SoamaTypography.labelSmall.copyWith(
                                  color: colors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildGallerySection(BuildContext context) {
    final colors = context.soamaColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Work Portfolio',
              style: SoamaTypography.titleMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${_provider.gallery.length} photos',
              style: SoamaTypography.labelSmall.copyWith(
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: SoamaSpacing.sm),
        SizedBox(
          height: 124,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _provider.gallery.length,
            separatorBuilder: (_, __) => const SizedBox(width: SoamaSpacing.sm),
            itemBuilder: (context, index) {
              final imageUrl = _provider.gallery[index];
              return GestureDetector(
                onTap: () => _openGalleryImage(context, imageUrl, index),
                child: ClipRRect(
                  borderRadius: SoamaRadii.radiusLg,
                  child: Stack(
                    children: [
                      SizedBox(
                        width: 140,
                        height: 124,
                        child: Image(
                          image: ResizeImage(
                            NetworkImage(imageUrl),
                            width: 320,
                            height: 280,
                          ),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: colors.surfaceSubtle,
                            child: Icon(Icons.broken_image_rounded, color: colors.textTertiary),
                          ),
                        ),
                      ),
                      // Expand prompt icon overlay
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.fullscreen_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsSection(BuildContext context) {
    final colors = context.soamaColors;
    final reviewsAsync = ref.watch(providerReviewsProvider(_provider.id));
    final liveReviews = reviewsAsync.valueOrNull;
    final reviews = liveReviews != null && liveReviews.isNotEmpty
        ? liveReviews
        : _provider.reviews;
    final effectiveCount = liveReviews != null ? liveReviews.length : _provider.reviewCount;
    final effectiveRating = liveReviews != null && liveReviews.isNotEmpty
        ? liveReviews.map((r) => r.rating).reduce((a, b) => a + b) / liveReviews.length
        : _provider.rating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Customer Reviews',
              style: SoamaTypography.titleMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFBBF24)),
                const SizedBox(width: 2),
                Text(
                  effectiveCount > 0 ? effectiveRating.toStringAsFixed(1) : 'New',
                  style: SoamaTypography.titleSmall.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (effectiveCount > 0)
                  Text(
                    ' ($effectiveCount)',
                    style: SoamaTypography.bodySmall.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: SoamaSpacing.sm),

        // Review list or empty state
        if (reviews.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: colors.surfaceSubtle,
              borderRadius: SoamaRadii.radiusLg,
              border: Border.all(color: colors.glassBorder, width: 0.8),
            ),
            child: Column(
              children: [
                Icon(Icons.rate_review_outlined, size: 28, color: colors.textTertiary),
                const SizedBox(height: 8),
                Text(
                  'No reviews yet',
                  style: SoamaTypography.titleSmall.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete a booking to be the first to leave verified feedback for ${_provider.name}.',
                  textAlign: TextAlign.center,
                  style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          )
        else
          ...reviews.map((rev) {
            return Padding(
              padding: const EdgeInsets.only(bottom: SoamaSpacing.sm),
              child: Container(
                padding: const EdgeInsets.all(14.0),
                decoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  borderRadius: SoamaRadii.radiusLg,
                  border: Border.all(color: colors.glassBorder, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: ResizeImage(
                            NetworkImage(rev.userAvatarUrl),
                            width: 80,
                            height: 80,
                          ),
                          onBackgroundImageError: (_, __) {},
                        ),
                        const SizedBox(width: SoamaSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rev.userName,
                                style: SoamaTypography.titleSmall.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                rev.date,
                                style: SoamaTypography.labelSmall.copyWith(
                                  color: colors.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: List.generate(5, (starIdx) {
                            return Icon(
                              starIdx < rev.rating.round()
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 14,
                              color: const Color(0xFFFBBF24),
                            );
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rev.comment,
                      style: SoamaTypography.bodySmall.copyWith(
                        color: colors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    // Provider reply (if present)
                    if (rev.providerReply != null && rev.providerReply!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.surfaceSecondary.withOpacity(0.5),
                          borderRadius: SoamaRadii.radiusMd,
                          border: Border(left: BorderSide(color: colors.accent, width: 2.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Response from ${_provider.name}',
                                  style: SoamaTypography.labelSmall.copyWith(
                                    color: colors.accent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (rev.providerReplyDate != null) ...[
                                  const Spacer(),
                                  Text(
                                    rev.providerReplyDate!,
                                    style: SoamaTypography.labelSmall.copyWith(
                                      color: colors.textTertiary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              rev.providerReply!,
                              style: SoamaTypography.bodySmall.copyWith(
                                color: colors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildBottomActionBar(BuildContext context) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final actionLabel = _selectedService != null
        ? 'Request ${_selectedService!.title} • ${_selectedService!.price}'
        : 'Request Service';

    return Container(
      padding: EdgeInsets.fromLTRB(
        20.0,
        12.0,
        20.0,
        bottomInset > 0 ? bottomInset + 8.0 : 16.0,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13151A) : colors.surface,
        border: Border(
          top: BorderSide(
            color: colors.border,
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          // Secondary Messaging Action
          Material(
            color: isDark ? const Color(0xFF242833) : const Color(0xFFE8E3DA),
            borderRadius: SoamaRadii.radiusLg,
            child: InkWell(
              onTap: _navigateToMessages,
              borderRadius: SoamaRadii.radiusLg,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: SoamaRadii.radiusLg,
                  border: Border.all(
                    color: colors.border,
                    width: 0.8,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: colors.textPrimary,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: SoamaSpacing.sm),

          // Prominent Primary Action: Request Service
          Expanded(
            child: PrimaryButton(
              label: actionLabel,
              size: ButtonSize.large,
              onPressed: _navigateToRequestService,
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper model for strongly-typed routing arguments
class RequestServiceArgs {
  final ServiceProvider provider;
  final ProviderServiceOffering? selectedService;

  const RequestServiceArgs({
    required this.provider,
    this.selectedService,
  });
}
