import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/theme/soama_colors.dart';
import '../../../../shared/models/service_category.dart';
import '../../../../shared/widgets/glass_surface.dart';
import '../../../../shared/widgets/soama_buttons.dart';
import '../../domain/search_filter_options.dart';

class SearchFilterBottomSheet extends StatefulWidget {
  final SearchFilterCriteria initialCriteria;
  final ValueChanged<SearchFilterCriteria> onApply;

  const SearchFilterBottomSheet({
    super.key,
    required this.initialCriteria,
    required this.onApply,
  });

  static Future<void> show({
    required BuildContext context,
    required SearchFilterCriteria currentCriteria,
    required ValueChanged<SearchFilterCriteria> onApply,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SearchFilterBottomSheet(
        initialCriteria: currentCriteria,
        onApply: onApply,
      ),
    );
  }

  @override
  State<SearchFilterBottomSheet> createState() => _SearchFilterBottomSheetState();
}

class _SearchFilterBottomSheetState extends State<SearchFilterBottomSheet> {
  late SearchFilterCriteria _criteria;

  @override
  void initState() {
    super.initState();
    _criteria = widget.initialCriteria;
  }

  void _reset() {
    HapticFeedback.lightImpact();
    setState(() {
      _criteria = SearchFilterCriteria(query: _criteria.query);
    });
  }

  void _apply() {
    HapticFeedback.lightImpact();
    widget.onApply(_criteria);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13151A) : colors.surface,
        borderRadius: SoamaRadii.sheetTopRadius,
        border: Border.all(color: colors.glassBorder, width: 1.0),
        boxShadow: isDark
            ? SoamaGlass.elevatedGlassShadowDark
            : SoamaGlass.elevatedGlassShadowLight,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
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

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 14.0, 14.0, 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Filter & Sort',
                      style: SoamaTypography.titleLarge.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18.0,
                      ),
                    ),
                    if (_criteria.activeFilterCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: colors.accent,
                          borderRadius: SoamaRadii.radiusPill,
                        ),
                        child: Text(
                          '${_criteria.activeFilterCount}',
                          style: SoamaTypography.labelSmall.copyWith(
                            color: colors.onAccent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                TextButton(
                  onPressed: _criteria.hasActiveFilters ? _reset : null,
                  child: Text(
                    'Reset all',
                    style: SoamaTypography.labelLarge.copyWith(
                      color: _criteria.hasActiveFilters
                          ? colors.accent
                          : colors.textTertiary.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.8),

          // Scrollable Filter Options
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Sort By
                  _buildSectionTitle('Sort by'),
                  const SizedBox(height: SoamaSpacing.xs),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: SearchSortOption.values.map((opt) {
                      final isSelected = _criteria.sortBy == opt;
                      return _buildChoiceChip(
                        label: opt.label,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            _criteria = _criteria.copyWith(sortBy: opt);
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: SoamaSpacing.xl),

                  // 2. Category
                  _buildSectionTitle('Trade Category'),
                  const SizedBox(height: SoamaSpacing.xs),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      _buildChoiceChip(
                        label: 'All Trades',
                        isSelected: _criteria.categoryId == null || _criteria.categoryId!.isEmpty,
                        onTap: () {
                          setState(() {
                            _criteria = _criteria.copyWith(categoryId: () => null);
                          });
                        },
                      ),
                      ...ServiceCategory.mockCategories.map((cat) {
                        final isSelected = _criteria.categoryId == cat.id;
                        return _buildChoiceChip(
                          label: cat.title,
                          icon: cat.icon,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              _criteria = _criteria.copyWith(
                                categoryId: () => isSelected ? null : cat.id,
                              );
                            });
                          },
                        );
                      }),
                    ],
                  ),

                  const SizedBox(height: SoamaSpacing.xl),

                  // 3. Distance
                  _buildSectionTitle('Maximum Distance'),
                  const SizedBox(height: SoamaSpacing.xs),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      _buildChoiceChip(
                        label: 'Any distance',
                        isSelected: _criteria.maxDistanceKm == null,
                        onTap: () {
                          setState(() {
                            _criteria = _criteria.copyWith(maxDistanceKm: () => null);
                          });
                        },
                      ),
                      _buildChoiceChip(
                        label: 'Under 2 km',
                        isSelected: _criteria.maxDistanceKm == 2.0,
                        onTap: () {
                          setState(() {
                            _criteria = _criteria.copyWith(maxDistanceKm: () => 2.0);
                          });
                        },
                      ),
                      _buildChoiceChip(
                        label: 'Under 5 km',
                        isSelected: _criteria.maxDistanceKm == 5.0,
                        onTap: () {
                          setState(() {
                            _criteria = _criteria.copyWith(maxDistanceKm: () => 5.0);
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: SoamaSpacing.xl),

                  // 4. Minimum Rating
                  _buildSectionTitle('Minimum Rating'),
                  const SizedBox(height: SoamaSpacing.xs),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      _buildChoiceChip(
                        label: 'Any rating',
                        isSelected: _criteria.minRating == null,
                        onTap: () {
                          setState(() {
                            _criteria = _criteria.copyWith(minRating: () => null);
                          });
                        },
                      ),
                      _buildChoiceChip(
                        label: '★ 4.5 & up',
                        isSelected: _criteria.minRating == 4.5,
                        onTap: () {
                          setState(() {
                            _criteria = _criteria.copyWith(minRating: () => 4.5);
                          });
                        },
                      ),
                      _buildChoiceChip(
                        label: '★ 4.8 & up',
                        isSelected: _criteria.minRating == 4.8,
                        onTap: () {
                          setState(() {
                            _criteria = _criteria.copyWith(minRating: () => 4.8);
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: SoamaSpacing.xl),

                  // 5. Max Starting Price
                  _buildSectionTitle('Price Budget'),
                  const SizedBox(height: SoamaSpacing.xs),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: [
                      _buildChoiceChip(
                        label: 'Any budget',
                        isSelected: _criteria.maxPrice == null,
                        onTap: () {
                          setState(() {
                            _criteria = _criteria.copyWith(maxPrice: () => null);
                          });
                        },
                      ),
                      _buildChoiceChip(
                        label: 'Under ${AppConstants.currencySymbol}15,000',
                        isSelected: _criteria.maxPrice == 15000,
                        onTap: () {
                          setState(() {
                            _criteria = _criteria.copyWith(maxPrice: () => 15000);
                          });
                        },
                      ),
                      _buildChoiceChip(
                        label: 'Under ${AppConstants.currencySymbol}25,000',
                        isSelected: _criteria.maxPrice == 25000,
                        onTap: () {
                          setState(() {
                            _criteria = _criteria.copyWith(maxPrice: () => 25000);
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: SoamaSpacing.xl),

                  // 6. Verified Artisans Only Toggle
                  GlassSurface(
                    borderRadius: SoamaRadii.radiusLg,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    blurIntensity: GlassBlurIntensity.none,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.verified_rounded, size: 20, color: colors.accent),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Verified Pros Only',
                                  style: SoamaTypography.bodyMedium.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Only display identity-vetted artisans',
                                  style: SoamaTypography.labelSmall.copyWith(
                                    color: colors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch(
                          value: _criteria.verifiedOnly,
                          activeThumbColor: colors.accent,
                          activeTrackColor: colors.accentMuted,
                          inactiveThumbColor: colors.textTertiary,
                          onChanged: (val) {
                            setState(() {
                              _criteria = _criteria.copyWith(verifiedOnly: val);
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: SoamaSpacing.xxl),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: EdgeInsets.fromLTRB(20.0, 12.0, 20.0, bottomInset > 0 ? bottomInset + 8.0 : 16.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13151A) : colors.surface,
              border: Border(top: BorderSide(color: colors.border, width: 0.8)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'Apply Filters',
                    onPressed: _apply,
                    size: ButtonSize.large,
                    isFullWidth: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: SoamaTypography.labelLarge.copyWith(
        color: context.soamaColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 13.5,
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: SoamaMotion.fast,
        curve: SoamaMotion.easeOutSpring,
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.accent
              : (isDark ? const Color(0xFF1F222B) : const Color(0xFFECE7DB)),
          borderRadius: SoamaRadii.radiusPill,
          border: Border.all(
            color: isSelected ? colors.accent : colors.border,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: isSelected ? colors.onAccent : colors.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: SoamaTypography.labelMedium.copyWith(
                color: isSelected ? colors.onAccent : colors.textPrimary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
