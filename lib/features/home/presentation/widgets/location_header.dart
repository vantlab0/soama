import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/theme.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../../shared/widgets/glass_card.dart';

class LocationHeader extends ConsumerStatefulWidget {
  const LocationHeader({super.key});

  @override
  ConsumerState<LocationHeader> createState() => _LocationHeaderState();
}

class _LocationHeaderState extends ConsumerState<LocationHeader> {
  String _selectedLocation = AppConstants.defaultLocation;

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Location Selector (Flexible for narrow screens)
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _showLocationPicker(context);
              },
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 13,
                        color: colors.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'YOUR LOCATION',
                        style: SoamaTypography.labelSmall.copyWith(
                          color: colors.textTertiary,
                          letterSpacing: 1.1,
                          fontSize: 10.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _selectedLocation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SoamaTypography.titleMedium.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: colors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: SoamaSpacing.xs),

          // Floating Translucent Controls: Theme Toggle & Notifications
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlassCard(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(themeModeProvider.notifier).toggleTheme();
                },
                borderRadius: SoamaRadii.radiusPill,
                padding: const EdgeInsets.all(9.0),
                child: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  size: 18,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: SoamaSpacing.xs),
              GlassCard(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push(AppRoutes.notifications);
                },
                borderRadius: SoamaRadii.radiusPill,
                padding: const EdgeInsets.all(9.0),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 18,
                      color: colors.textPrimary,
                    ),
                    Builder(builder: (context) {
                      final unreadCount = ref.watch(unreadNotificationCountProvider);
                      if (unreadCount <= 0) return const SizedBox.shrink();
                      return Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLocationPicker(BuildContext context) {
    final colors = context.soamaColors;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: SoamaRadii.sheetTopRadius,
            border: Border.all(color: colors.border),
          ),
          padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textTertiary.withOpacity(0.4),
                    borderRadius: SoamaRadii.radiusPill,
                  ),
                ),
              ),
              const SizedBox(height: SoamaSpacing.lg),
              Text(
                'Change Location',
                style: SoamaTypography.headlineSmall.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Find nearby verified artisans and service pros',
                style: SoamaTypography.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: SoamaSpacing.md),
              ...AppConstants.primaryLocations.map((loc) {
                final isSelected = loc == _selectedLocation;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 2.0),
                  leading: Icon(
                    Icons.place_rounded,
                    color: isSelected ? colors.accent : colors.textSecondary,
                    size: 20,
                  ),
                  title: Text(
                    loc,
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
                      _selectedLocation = loc;
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
}
