import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/soama_colors.dart';
import '../../../shared/models/service_category.dart';
import '../../../shared/models/service_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_search_field.dart';
import '../../../shared/widgets/provider_card.dart';
import '../../../shared/widgets/service_category_item.dart';
import '../../categories/presentation/providers/categories_provider.dart';
import '../../providers/presentation/providers/provider_provider.dart';
import '../domain/search_filter_options.dart';
import 'widgets/provider_preview_sheet.dart';
import 'widgets/search_filter_bottom_sheet.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  SearchFilterCriteria _criteria = const SearchFilterCriteria();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    setState(() {
      _criteria = _criteria.copyWith(query: query);
    });
  }

  void _onCategoryTapped(String? categoryId) {
    HapticFeedback.selectionClick();
    setState(() {
      _criteria = _criteria.copyWith(
        categoryId: () => _criteria.categoryId == categoryId ? null : categoryId,
      );
    });
  }

  void _openFilterBottomSheet() {
    SearchFilterBottomSheet.show(
      context: context,
      currentCriteria: _criteria,
      onApply: (newCriteria) {
        setState(() {
          _criteria = newCriteria;
        });
      },
    );
  }

  void _resetAllFilters() {
    HapticFeedback.lightImpact();
    _searchController.clear();
    setState(() {
      _criteria = const SearchFilterCriteria();
    });
  }

  void _showSortPicker() {
    HapticFeedback.lightImpact();
    final colors = context.soamaColors;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: SoamaRadii.sheetTopRadius,
            border: Border.all(color: colors.border),
          ),
          padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textTertiary.withOpacity(0.3),
                    borderRadius: SoamaRadii.radiusPill,
                  ),
                ),
              ),
              const SizedBox(height: SoamaSpacing.md),
              Text(
                'Sort Results',
                style: SoamaTypography.titleLarge.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: SoamaSpacing.sm),
              ...SearchSortOption.values.map((opt) {
                final isSelected = _criteria.sortBy == opt;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    opt.label,
                    style: SoamaTypography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded, color: colors.accent, size: 20)
                      : null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _criteria = _criteria.copyWith(sortBy: opt);
                    });
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.valueOrNull ?? ServiceCategory.mockCategories;

    final queryParams = ProviderQueryParams(
      categoryId: _criteria.categoryId,
      searchQuery: _criteria.query,
      maxPrice: _criteria.maxPrice,
      sortBy: _criteria.sortBy.name,
    );
    final prosAsync = ref.watch(marketplaceProvidersProvider(queryParams));
    final livePros = prosAsync.valueOrNull ?? ServiceProvider.nearbyPros;

    // Filter and sort providers in real-time
    final filteredPros = _criteria.filterAndSort(livePros);

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: colors.accent,
          backgroundColor: colors.surface,
          onRefresh: () async {
            HapticFeedback.lightImpact();
            ref.invalidate(marketplaceProvidersProvider);
            await ref.read(categoriesProvider.notifier).refresh();
            if (mounted) setState(() {});
          },
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // 1. Heading & Supporting Text
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Explore Services',
                        style: SoamaTypography.displayMedium.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 28.0,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Discover and book vetted local specialists in ${AppConstants.defaultLocation.split(',').first}',
                        style: SoamaTypography.bodyMedium.copyWith(
                          color: colors.textSecondary,
                          fontSize: 14.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: SoamaSpacing.sm),
              ),

              // 2. Functional Liquid Glass Search Field
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: GlassSearchField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    hintText: 'Search plumber, generator, cleaning, name...',
                    onChanged: _onQueryChanged,
                    onTrailingActionTap: _openFilterBottomSheet,
                    trailingTooltip: 'Filter & sort',
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: SoamaSpacing.md),
              ),

              // 3. Quick Filter & Sort Controls Bar
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      // Filter Sheet Trigger Button
                      GestureDetector(
                        onTap: _openFilterBottomSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
                          decoration: BoxDecoration(
                            color: _criteria.activeFilterCount > 0
                                ? colors.accent
                                : colors.surfaceSecondary,
                            borderRadius: SoamaRadii.radiusPill,
                            border: Border.all(
                              color: _criteria.activeFilterCount > 0
                                  ? colors.accent
                                  : colors.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                size: 15,
                                color: _criteria.activeFilterCount > 0
                                    ? colors.onAccent
                                    : colors.textPrimary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Filters',
                                style: SoamaTypography.labelMedium.copyWith(
                                  color: _criteria.activeFilterCount > 0
                                      ? colors.onAccent
                                      : colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_criteria.activeFilterCount > 0) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: colors.onAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${_criteria.activeFilterCount}',
                                    style: TextStyle(
                                      color: colors.accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: SoamaSpacing.xs),

                      // Quick Sort Selector
                      GestureDetector(
                        onTap: _showSortPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
                          decoration: BoxDecoration(
                            color: _criteria.sortBy != SearchSortOption.recommended
                                ? colors.accentMuted
                                : colors.surfaceSecondary,
                            borderRadius: SoamaRadii.radiusPill,
                            border: Border.all(
                              color: _criteria.sortBy != SearchSortOption.recommended
                                  ? colors.accent.withOpacity(0.6)
                                  : colors.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.swap_vert_rounded,
                                size: 15,
                                color: _criteria.sortBy != SearchSortOption.recommended
                                    ? colors.accent
                                    : colors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _criteria.sortBy.label,
                                style: SoamaTypography.labelMedium.copyWith(
                                  color: _criteria.sortBy != SearchSortOption.recommended
                                      ? (context.isDarkMode ? colors.accent : const Color(0xFF3F4D02))
                                      : colors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: colors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Quick Distance filter chip if active
                      if (_criteria.maxDistanceKm != null) ...[
                        const SizedBox(width: SoamaSpacing.xs),
                        _buildActiveFilterPill(
                          label: '< ${_criteria.maxDistanceKm!.toInt()} km',
                          onRemove: () {
                            setState(() {
                              _criteria = _criteria.copyWith(maxDistanceKm: () => null);
                            });
                          },
                        ),
                      ],

                      // Quick Rating filter chip if active
                      if (_criteria.minRating != null) ...[
                        const SizedBox(width: SoamaSpacing.xs),
                        _buildActiveFilterPill(
                          label: '★ ${_criteria.minRating}+',
                          onRemove: () {
                            setState(() {
                              _criteria = _criteria.copyWith(minRating: () => null);
                            });
                          },
                        ),
                      ],

                      // Quick Price filter chip if active
                      if (_criteria.maxPrice != null) ...[
                        const SizedBox(width: SoamaSpacing.xs),
                        _buildActiveFilterPill(
                          label: '< ₦${_criteria.maxPrice! ~/ 1000}k',
                          onRemove: () {
                            setState(() {
                              _criteria = _criteria.copyWith(maxPrice: () => null);
                            });
                          },
                        ),
                      ],

                      // Reset all shortcut
                      if (_criteria.hasActiveFilters || _searchController.text.isNotEmpty) ...[
                        const SizedBox(width: SoamaSpacing.xs),
                        GestureDetector(
                          onTap: _resetAllFilters,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                            child: Text(
                              'Clear all',
                              style: SoamaTypography.labelSmall.copyWith(
                                color: colors.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: SoamaSpacing.lg),
              ),

              // 4. Popular Service Categories Horizontal Rail
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 98,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: categories.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: SoamaSpacing.xs),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        final isAllSelected = _criteria.categoryId == null || _criteria.categoryId!.isEmpty;
                        return SizedBox(
                          width: 80,
                          child: ServiceCategoryItem.compact(
                            label: 'All Trades',
                            icon: Icons.all_inclusive_rounded,
                            isSelected: isAllSelected,
                            onTap: () => _onCategoryTapped(null),
                          ),
                        );
                      }

                      final cat = categories[index - 1];
                      final isSelected = _criteria.categoryId == cat.id;

                      return SizedBox(
                        width: 80,
                        child: ServiceCategoryItem.compact(
                          label: cat.title,
                          icon: cat.icon,
                          isSelected: isSelected,
                          onTap: () => _onCategoryTapped(cat.id),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: SoamaSpacing.md),
              ),

              // 5. Results Count & Scope Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${filteredPros.length} ${filteredPros.length == 1 ? 'artisan' : 'artisans'} found',
                        style: SoamaTypography.labelLarge.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _criteria.sortBy.label,
                        style: SoamaTypography.labelSmall.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 6. Results List or Clean Empty State
              if (filteredPros.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No matching artisans found',
                    message: _searchController.text.isNotEmpty
                        ? 'No professionals match "${_searchController.text}". Try another trade or reset filters.'
                        : 'No specialists match your active filter combination. Try expanding distance or budget.',
                    actionLabel: 'Reset All Filters',
                    onActionPressed: _resetAllFilters,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final pro = filteredPros[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: SoamaSpacing.sm),
                          child: ProviderCard(
                            provider: pro,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              context.push(
                                AppRoutes.providerDetailsPath(pro.id),
                                extra: pro,
                              );
                            },
                            onBookTap: () {
                              ProviderPreviewSheet.show(context, pro);
                            },
                          ),
                        );
                      },
                      childCount: filteredPros.length,
                    ),
                  ),
                ),

              // Bottom padding to ensure content comfortably clears floating bottom navigation bar
              const SliverToBoxAdapter(
                child: SizedBox(height: 120),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFilterPill({
    required String label,
    required VoidCallback onRemove,
  }) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.fromLTRB(10.0, 6.0, 6.0, 6.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242833) : const Color(0xFFE4DFD5),
        borderRadius: SoamaRadii.radiusPill,
        border: Border.all(color: colors.accent.withOpacity(0.5), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: SoamaTypography.labelSmall.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onRemove();
            },
            child: Icon(
              Icons.close_rounded,
              size: 14,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
