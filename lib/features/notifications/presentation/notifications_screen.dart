import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/soama_colors.dart';
import '../../../shared/models/app_notification.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glass_container.dart';
import 'providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _markAllAsRead() async {
    HapticFeedback.lightImpact();
    await ref.read(notificationsProvider.notifier).markAllAsRead();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _onNotificationTap(AppNotification notif) {
    HapticFeedback.lightImpact();
    ref.read(notificationsProvider.notifier).markAsRead(notif.id);

    if (notif.targetRoute == '/negotiation' && notif.targetId != null) {
      context.push(AppRoutes.negotiationPath(notif.targetId!));
    } else if (notif.targetRoute == '/messages' && notif.targetId != null) {
      context.push(AppRoutes.conversationPath(notif.targetId!));
    } else if (notif.targetRoute == '/bookings') {
      context.go(AppRoutes.bookings);
    } else if (notif.targetRoute != null && notif.targetRoute!.isNotEmpty) {
      context.push(notif.targetRoute!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final state = ref.watch(notificationsProvider);
    final allNotifs = state.notifications;
    final bookingNotifs = allNotifs.where((n) => n.category == NotificationCategory.bookings).toList();
    final messageNotifs = allNotifs.where((n) => n.category == NotificationCategory.messages).toList();
    final paymentNotifs = allNotifs.where((n) => n.category == NotificationCategory.payments).toList();

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas.withOpacity(0.92),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: colors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Notifications',
          style: SoamaTypography.titleMedium.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.done_all_rounded, color: colors.accent, size: 22),
            tooltip: 'Mark all as read',
            onPressed: allNotifs.isEmpty ? null : _markAllAsRead,
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Filter Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: GlassContainer(
                borderRadius: SoamaRadii.radiusPill,
                padding: const EdgeInsets.all(4.0),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: colors.accent,
                    borderRadius: SoamaRadii.radiusPill,
                  ),
                  labelColor: colors.onAccent,
                  unselectedLabelColor: colors.textSecondary,
                  labelStyle: SoamaTypography.labelSmall.copyWith(fontWeight: FontWeight.w700),
                  unselectedLabelStyle: SoamaTypography.labelSmall,
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(text: 'All (${allNotifs.length})'),
                    Tab(text: 'Bookings (${bookingNotifs.length})'),
                    Tab(text: 'Messages (${messageNotifs.length})'),
                    Tab(text: 'Payments (${paymentNotifs.length})'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: SoamaSpacing.xs),

            // Tab Views with Pull-to-Refresh
            Expanded(
              child: state.isLoading && allNotifs.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colors.accent,
                      ),
                    )
                  : RefreshIndicator(
                      color: colors.accent,
                      backgroundColor: colors.surface,
                      onRefresh: () => ref
                          .read(notificationsProvider.notifier)
                          .loadNotifications(forceRefresh: true),
                      child: TabBarView(
                        controller: _tabController,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        children: [
                          _buildNotificationList(context, allNotifs, 'No notifications right now.'),
                          _buildNotificationList(context, bookingNotifs, 'No booking notifications.'),
                          _buildNotificationList(context, messageNotifs, 'No message notifications.'),
                          _buildNotificationList(context, paymentNotifs, 'No payment or escrow notifications.'),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationList(
    BuildContext context,
    List<AppNotification> list,
    String emptyMessage,
  ) {
    if (list.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: EmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'All Caught Up',
                message: emptyMessage,
              ),
            ),
          ),
        ),
      );
    }

    final dateFormatter = DateFormat('MMM d, h:mm a');

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 32.0),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: SoamaSpacing.sm),
      itemBuilder: (context, index) {
        final notif = list[index];
        final colors = context.soamaColors;

        Color iconBg;
        Color iconColor;
        switch (notif.category) {
          case NotificationCategory.bookings:
            iconBg = const Color(0xFF38BDF8).withOpacity(0.15);
            iconColor = const Color(0xFF38BDF8);
            break;
          case NotificationCategory.messages:
            iconBg = colors.accent.withOpacity(0.15);
            iconColor = colors.accent;
            break;
          case NotificationCategory.payments:
            iconBg = const Color(0xFF4ADE80).withOpacity(0.15);
            iconColor = const Color(0xFF4ADE80);
            break;
          case NotificationCategory.all:
            iconBg = colors.surfaceSubtle;
            iconColor = colors.textPrimary;
            break;
        }

        return GlassCard(
          borderRadius: SoamaRadii.radiusXl,
          padding: const EdgeInsets.all(14.0),
          onTap: () => _onNotificationTap(notif),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(notif.category.icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: SoamaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            notif.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SoamaTypography.titleSmall.copyWith(
                              color: colors.textPrimary,
                              fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!notif.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: colors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notif.message,
                      style: SoamaTypography.bodySmall.copyWith(
                        color: notif.isRead ? colors.textTertiary : colors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dateFormatter.format(notif.timestamp),
                      style: SoamaTypography.labelSmall.copyWith(
                        color: colors.textTertiary.withOpacity(0.6),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
