import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/soama_colors.dart';
import '../../../shared/models/service_category.dart';
import '../../../shared/models/service_provider.dart';
import 'widgets/featured_service_banner.dart';
import 'widgets/hero_heading.dart';
import 'widgets/home_search_bar.dart';
import 'widgets/location_header.dart';
import 'widgets/nearby_professionals.dart';
import 'widgets/popular_categories.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  String? _selectedCategoryId;

  // Staggered animation intervals
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;

  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;

  late final Animation<double> _searchFade;
  late final Animation<Offset> _searchSlide;

  late final Animation<double> _categoriesFade;
  late final Animation<Offset> _categoriesSlide;

  late final Animation<double> _bannerFade;
  late final Animation<Offset> _bannerSlide;

  late final Animation<double> _prosFade;
  late final Animation<Offset> _prosSlide;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    // Refined micro-transitions: subtle 15px slide rather than large visual jumps
    const beginOffset = Offset(0, 0.05);

    _headerFade = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.40, curve: SoamaMotion.smoothOut),
    ));

    _heroFade = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.08, 0.50, curve: Curves.easeOut),
    );
    _heroSlide = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.08, 0.50, curve: SoamaMotion.smoothOut),
    ));

    _searchFade = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.16, 0.60, curve: Curves.easeOut),
    );
    _searchSlide = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.16, 0.60, curve: SoamaMotion.smoothOut),
    ));

    _categoriesFade = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.24, 0.72, curve: Curves.easeOut),
    );
    _categoriesSlide = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.24, 0.72, curve: SoamaMotion.smoothOut),
    ));

    _bannerFade = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.32, 0.84, curve: Curves.easeOut),
    );
    _bannerSlide = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.32, 0.84, curve: SoamaMotion.smoothOut),
    ));

    _prosFade = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.40, 1.0, curve: Curves.easeOut),
    );
    _prosSlide = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.40, 1.0, curve: SoamaMotion.smoothOut),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onCategoryTapped(ServiceCategory category) {
    setState(() {
      _selectedCategoryId =
          _selectedCategoryId == category.id ? null : category.id;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing available ${category.title} specialists'),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: SoamaRadii.radiusMd,
        ),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Explore',
          textColor: context.soamaColors.accent,
          onPressed: () {
            context.go(AppRoutes.explore);
          },
        ),
      ),
    );
  }

  void _onProviderTapped(ServiceProvider provider) {
    HapticFeedback.lightImpact();
    context.push(
      AppRoutes.providerDetailsPath(provider.id),
      extra: provider,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final isReducedMotion = SoamaMotion.isReducedMotion(context);

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: colors.accent,
          backgroundColor: colors.surface,
          onRefresh: () async {
            HapticFeedback.lightImpact();
            await Future.delayed(const Duration(milliseconds: 600));
            if (mounted) setState(() {});
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // 1. Compact Location Header
              SliverToBoxAdapter(
                child: _buildAnimatedSection(
                  fade: _headerFade,
                  slide: _headerSlide,
                  isReducedMotion: isReducedMotion,
                  child: const LocationHeader(),
                ),
              ),

              // 2. Hero Heading ("Who do you need today?")
              SliverToBoxAdapter(
                child: _buildAnimatedSection(
                  fade: _heroFade,
                  slide: _heroSlide,
                  isReducedMotion: isReducedMotion,
                  child: const HeroHeading(),
                ),
              ),

              // 3. Floating Liquid Glass Search Bar
              SliverToBoxAdapter(
                child: _buildAnimatedSection(
                  fade: _searchFade,
                  slide: _searchSlide,
                  isReducedMotion: isReducedMotion,
                  child: HomeSearchBar(
                    onTap: () {},
                    onFilterTap: () {
                      context.go(AppRoutes.explore);
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: SoamaSpacing.xl),
              ),

              // 4. Popular Categories
              SliverToBoxAdapter(
                child: _buildAnimatedSection(
                  fade: _categoriesFade,
                  slide: _categoriesSlide,
                  isReducedMotion: isReducedMotion,
                  child: PopularCategories(
                    selectedCategoryId: _selectedCategoryId,
                    onCategoryTap: _onCategoryTapped,
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: SoamaSpacing.lg),
              ),

              // 5. Featured Service Banner
              SliverToBoxAdapter(
                child: _buildAnimatedSection(
                  fade: _bannerFade,
                  slide: _bannerSlide,
                  isReducedMotion: isReducedMotion,
                  child: FeaturedServiceBanner(
                    onTap: () {
                      context.go(AppRoutes.explore);
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: SoamaSpacing.xl),
              ),

              // 6. Nearby Professionals ("Near you" + "See all")
              SliverToBoxAdapter(
                child: _buildAnimatedSection(
                  fade: _prosFade,
                  slide: _prosSlide,
                  isReducedMotion: isReducedMotion,
                  child: NearbyProfessionals(
                    onSeeAllTap: () {
                      context.go(AppRoutes.explore);
                    },
                    onProviderTap: _onProviderTapped,
                  ),
                ),
              ),

              // Bottom inset padding to ensure content clears the floating Liquid Glass navigation bar
              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedSection({
    required Animation<double> fade,
    required Animation<Offset> slide,
    required bool isReducedMotion,
    required Widget child,
  }) {
    if (isReducedMotion) {
      return child;
    }
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: child,
      ),
    );
  }
}
