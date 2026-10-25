import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/design_system/design_system.dart';
import '../../core/theme/soama_colors.dart';

class GlassNavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String? tooltip;
  final int? badgeCount;

  const GlassNavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.tooltip,
    this.badgeCount,
  });
}

class GlassBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;
  final List<GlassNavigationItem> items;
  final double height;

  const GlassBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
    required this.items,
    this.height = 66.0,
  }) : assert(items.length >= 2, 'GlassBottomNavigation requires at least 2 items');

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16.0,
        0.0,
        16.0,
        bottomInset > 0 ? bottomInset + 6.0 : 16.0,
      ),
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16181D) : Colors.white,
          borderRadius: SoamaRadii.radiusPill,
          border: Border.all(
            color: colors.border,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isSelected = index == currentIndex;

            return _buildItem(
              context: context,
              item: item,
              index: index,
              isSelected: isSelected,
              colors: colors,
            );
          }),
        ),
      ),
    );
  }

  Widget _buildItem({
    required BuildContext context,
    required GlassNavigationItem item,
    required int index,
    required bool isSelected,
    required SoamaThemeColors colors,
  }) {
    final isReducedMotion = SoamaMotion.isReducedMotion(context);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${item.label} tab',
      tooltip: item.tooltip ?? item.label,
      child: GestureDetector(
        onTap: () {
          if (index != currentIndex) {
            HapticFeedback.lightImpact();
            onItemSelected(index);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: isReducedMotion ? Duration.zero : SoamaMotion.standard,
          curve: SoamaMotion.easeOutSpring,
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: isSelected ? colors.accent : Colors.transparent,
            borderRadius: SoamaRadii.radiusPill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isSelected ? item.selectedIcon : item.icon,
                    size: 20,
                    color: isSelected ? colors.onAccent : colors.textSecondary,
                  ),
                  if (item.badgeCount != null && item.badgeCount! > 0)
                    Positioned(
                      top: -2,
                      right: -3,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: colors.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                      ),
                    ),
                ],
              ),
              if (isSelected) ...[
                const SizedBox(width: 5),
                Text(
                  item.label,
                  style: SoamaTypography.labelSmall.copyWith(
                    color: colors.onAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
