import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/theme/soama_colors.dart';
import '../../../shared/models/user_account.dart';
import '../../../shared/widgets/glass_bottom_navigation.dart';

class AppShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({
    super.key,
    required this.navigationShell,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  void _onItemTapped(int index) {
    if (widget.navigationShell.currentIndex != index) {
      HapticFeedback.lightImpact();
      widget.navigationShell.goBranch(
        index,
        initialLocation: index == widget.navigationShell.currentIndex,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = viewInsetsBottom > 0;
    final isReducedMotion = SoamaMotion.isReducedMotion(context);
    final canDirectlyPop = widget.navigationShell.currentIndex == 0;

    return PopScope(
      canPop: canDirectlyPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // If on another tab, return to Home tab first (Predictable mobile UX)
        if (widget.navigationShell.currentIndex != 0) {
          HapticFeedback.lightImpact();
          widget.navigationShell.goBranch(0);
        }
      },
      child: Scaffold(
        backgroundColor: colors.canvas,
        resizeToAvoidBottomInset: false,
        extendBody: true,
        body: widget.navigationShell,
        bottomNavigationBar: AnimatedSlide(
          offset: isKeyboardOpen ? const Offset(0, 1.8) : Offset.zero,
          duration: isReducedMotion ? Duration.zero : SoamaMotion.standard,
          curve: SoamaMotion.easeOutSpring,
          child: AnimatedOpacity(
            opacity: isKeyboardOpen ? 0.0 : 1.0,
            duration: isReducedMotion ? Duration.zero : SoamaMotion.fast,
          child: ValueListenableBuilder<UserAccount>(
            valueListenable: UserAccount.notifier,
            builder: (context, account, _) {
              final isProvider = account.currentMode == AppMode.provider;
              final items = isProvider
                  ? const [
                      GlassNavigationItem(
                        icon: Icons.dashboard_outlined,
                        selectedIcon: Icons.dashboard_rounded,
                        label: 'Dashboard',
                        tooltip: 'Provider Dashboard',
                      ),
                      GlassNavigationItem(
                        icon: Icons.inbox_outlined,
                        selectedIcon: Icons.inbox_rounded,
                        label: 'Requests',
                        tooltip: 'Incoming Requests',
                      ),
                      GlassNavigationItem(
                        icon: Icons.work_outline_rounded,
                        selectedIcon: Icons.work_rounded,
                        label: 'Jobs',
                        tooltip: 'Active & Upcoming Jobs',
                      ),
                      GlassNavigationItem(
                        icon: Icons.chat_bubble_outline_rounded,
                        selectedIcon: Icons.chat_bubble_rounded,
                        label: 'Messages',
                        tooltip: 'Messages',
                      ),
                      GlassNavigationItem(
                        icon: Icons.storefront_outlined,
                        selectedIcon: Icons.storefront_rounded,
                        label: 'Profile',
                        tooltip: 'Provider Profile',
                      ),
                    ]
                  : const [
                      GlassNavigationItem(
                        icon: Icons.home_outlined,
                        selectedIcon: Icons.home_rounded,
                        label: 'Home',
                        tooltip: 'Home',
                      ),
                      GlassNavigationItem(
                        icon: Icons.explore_outlined,
                        selectedIcon: Icons.explore_rounded,
                        label: 'Explore',
                        tooltip: 'Explore services',
                      ),
                      GlassNavigationItem(
                        icon: Icons.calendar_today_outlined,
                        selectedIcon: Icons.calendar_month_rounded,
                        label: 'Bookings',
                        tooltip: 'My Bookings',
                      ),
                      GlassNavigationItem(
                        icon: Icons.chat_bubble_outline_rounded,
                        selectedIcon: Icons.chat_bubble_rounded,
                        label: 'Messages',
                        tooltip: 'Messages',
                      ),
                      GlassNavigationItem(
                        icon: Icons.person_outline_rounded,
                        selectedIcon: Icons.person_rounded,
                        label: 'Profile',
                        tooltip: 'Account Profile',
                      ),
                    ];

              return GlassBottomNavigation(
                currentIndex: widget.navigationShell.currentIndex,
                onItemSelected: _onItemTapped,
                items: items,
              );
            },
          ),
          ),
        ),
      ),
    );
  }
}
