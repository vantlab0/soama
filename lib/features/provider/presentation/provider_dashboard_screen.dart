import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/soama_colors.dart';
import '../../../../shared/models/service_request.dart';
import '../../../../shared/models/user_account.dart';
import '../../../../shared/widgets/glass_surface.dart';
import '../../bookings/presentation/providers/bookings_provider.dart';
import '../../notifications/presentation/providers/notifications_provider.dart';
import '../../requests/presentation/providers/requests_provider.dart';
import 'widgets/role_switcher_pill.dart';

class ProviderDashboardScreen extends ConsumerStatefulWidget {
  const ProviderDashboardScreen({super.key});

  @override
  ConsumerState<ProviderDashboardScreen> createState() => _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends ConsumerState<ProviderDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final currencyFormatter = NumberFormat.currency(symbol: '₦', decimalDigits: 0);

    return ValueListenableBuilder<UserAccount>(
      valueListenable: UserAccount.notifier,
      builder: (context, account, _) {
        final profile = account.providerProfile;
        final providerId = profile?.providerId ?? account.id;

        // Load jobs and requests with real Supabase provider
        final jobsAsync = ref.watch(providerJobsProvider);
        final inboxAsync = ref.watch(providerInboxRequestsProvider);

        final realJobs = jobsAsync.valueOrNull?.map((b) => b.toServiceRequest()).toList() ?? [];
        final realRequests = inboxAsync.valueOrNull ?? ServiceRequest.getRequestsForProvider(providerId);

        final Set<String> seenIds = {};
        final List<ServiceRequest> providerRequests = [];
        for (final j in realJobs) {
          if (seenIds.add(j.id)) providerRequests.add(j);
        }
        for (final r in realRequests) {
          if (seenIds.add(r.id)) providerRequests.add(r);
        }

        final pendingRequests = providerRequests
            .where((r) => r.status.toLowerCase().contains('pending'))
            .toList();

        final upcomingJobs = providerRequests
            .where((r) => r.status.toLowerCase().contains('confirmed'))
            .toList();

        final activeJobs = providerRequests
            .where((r) => r.status.toLowerCase().contains('progress') || r.status.toLowerCase().contains('arrived'))
            .toList();

        final completedJobs = providerRequests
            .where((r) => r.status.toLowerCase().contains('completed'))
            .toList();

        final totalEarned = profile?.totalEarnings ?? 142500;
        final inEscrow = profile?.inEscrowEarnings ?? 16500;

        return Scaffold(
          backgroundColor: colors.canvas,
          body: SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                // Header Sliver
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: SoamaSpacing.lg, vertical: SoamaSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top bar with Mode Badge & Notification Icon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Provider Workspace',
                                  style: SoamaTypography.labelSmall.copyWith(
                                    color: colors.accent,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  profile?.businessName ?? 'Adams Precision Works',
                                  style: SoamaTypography.headlineSmall.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: colors.surfaceSecondary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.notifications_none_rounded, color: colors.textPrimary, size: 20),
                                  ),
                                  Builder(builder: (context) {
                                    final unread = ref.watch(unreadNotificationCountProvider);
                                    if (unread <= 0) return const SizedBox.shrink();
                                    return Positioned(
                                      top: 2,
                                      right: 2,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: colors.accent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                context.push(AppRoutes.notifications);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: SoamaSpacing.md),

                        // Mode Switcher Banner
                        const RoleSwitcherCard(),
                        const SizedBox(height: SoamaSpacing.md),

                        // Mock Verification Status Notice
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBBF24).withAlpha(20),
                            borderRadius: SoamaRadii.radiusMd,
                            border: Border.all(color: const Color(0xFFFBBF24).withAlpha(90), width: 0.8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Mock Verification: Pending Review • Ready for local jobs',
                                  style: SoamaTypography.labelSmall.copyWith(
                                    color: const Color(0xFFD97706),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: SoamaSpacing.lg),

                        // Mock Earnings Summary Cards
                        Text(
                          'Earnings & Escrow Balance',
                          style: SoamaTypography.titleSmall.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: SoamaSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: GlassSurface(
                                padding: const EdgeInsets.all(SoamaSpacing.md),
                                borderRadius: SoamaRadii.radiusLg,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.account_balance_wallet_rounded, color: colors.accent, size: 18),
                                        const SizedBox(width: 6),
                                        Text('Total Earned', style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      currencyFormatter.format(totalEarned),
                                      style: SoamaTypography.titleLarge.copyWith(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${completedJobs.length} jobs completed',
                                      style: SoamaTypography.labelSmall.copyWith(color: const Color(0xFF15803D)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: SoamaSpacing.md),
                            Expanded(
                              child: GlassSurface(
                                padding: const EdgeInsets.all(SoamaSpacing.md),
                                borderRadius: SoamaRadii.radiusLg,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.lock_clock_rounded, color: Color(0xFFF59E0B), size: 18),
                                        const SizedBox(width: 6),
                                        Text('In Escrow', style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      currencyFormatter.format(inEscrow),
                                      style: SoamaTypography.titleLarge.copyWith(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Protected by Soama',
                                      style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: SoamaSpacing.lg),

                        // Quick Operational Stats Grid
                        Row(
                          children: [
                            _buildStatChip(colors, 'Incoming', pendingRequests.length.toString(), Colors.blueAccent),
                            const SizedBox(width: 8),
                            _buildStatChip(colors, 'Confirmed', upcomingJobs.length.toString(), const Color(0xFF15803D)),
                            const SizedBox(width: 8),
                            _buildStatChip(colors, 'In Progress', activeJobs.length.toString(), Colors.purpleAccent),
                            const SizedBox(width: 8),
                            _buildStatChip(colors, 'Completed', completedJobs.length.toString(), colors.textSecondary),
                          ],
                        ),
                        const SizedBox(height: SoamaSpacing.xl),

                        // Section: Incoming Service Requests
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Incoming Service Requests',
                              style: SoamaTypography.titleMedium.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (pendingRequests.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withAlpha(25),
                                  borderRadius: SoamaRadii.radiusFull,
                                ),
                                child: Text(
                                  '${pendingRequests.length} New',
                                  style: SoamaTypography.labelSmall.copyWith(
                                    color: Colors.blueAccent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: SoamaSpacing.sm),
                      ],
                    ),
                  ),
                ),

                // Incoming Requests List Sliver
                if (pendingRequests.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: SoamaSpacing.lg),
                      child: GlassSurface(
                        padding: const EdgeInsets.all(SoamaSpacing.xl),
                        borderRadius: SoamaRadii.radiusLg,
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.inbox_rounded, color: colors.textTertiary, size: 36),
                              const SizedBox(height: 8),
                              Text('No Pending Requests', style: SoamaTypography.titleSmall.copyWith(color: colors.textPrimary)),
                              const SizedBox(height: 4),
                              Text('New customer requests will show up here.', style: SoamaTypography.labelSmall.copyWith(color: colors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: SoamaSpacing.lg),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final req = pendingRequests[index];
                          return _buildIncomingRequestCard(context, colors, req);
                        },
                        childCount: pendingRequests.length,
                      ),
                    ),
                  ),

                // Upcoming Confirmed Jobs Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(SoamaSpacing.lg, SoamaSpacing.xl, SoamaSpacing.lg, SoamaSpacing.sm),
                    child: Text(
                      'Upcoming & Active Jobs',
                      style: SoamaTypography.titleMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                if (upcomingJobs.isEmpty && activeJobs.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: SoamaSpacing.lg),
                      child: GlassSurface(
                        padding: const EdgeInsets.all(SoamaSpacing.lg),
                        borderRadius: SoamaRadii.radiusLg,
                        child: Center(
                          child: Text(
                            'No scheduled jobs right now.',
                            style: SoamaTypography.labelMedium.copyWith(color: colors.textTertiary),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: SoamaSpacing.lg),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final jobs = [...activeJobs, ...upcomingJobs];
                          final job = jobs[index];
                          return _buildJobCard(context, colors, job);
                        },
                        childCount: [...activeJobs, ...upcomingJobs].length,
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatChip(SoamaThemeColors colors, String label, String count, Color countColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: colors.surfaceSecondary,
          borderRadius: SoamaRadii.radiusMd,
        ),
        child: Column(
          children: [
            Text(
              count,
              style: SoamaTypography.titleMedium.copyWith(
                color: countColor,
                fontWeight: FontWeight.w800,
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
      ),
    );
  }

  Widget _buildIncomingRequestCard(BuildContext context, SoamaThemeColors colors, ServiceRequest req) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SoamaSpacing.md),
      child: GlassSurface(
        padding: const EdgeInsets.all(SoamaSpacing.md),
        borderRadius: SoamaRadii.radiusLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.accent.withAlpha(25),
                    borderRadius: SoamaRadii.radiusMd,
                  ),
                  child: Icon(Icons.handyman_rounded, color: colors.accent, size: 20),
                ),
                const SizedBox(width: SoamaSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.serviceTitle,
                        style: SoamaTypography.titleSmall.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Ref: ${req.id} • ${req.address}',
                        style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  req.servicePrice,
                  style: SoamaTypography.titleSmall.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SoamaSpacing.sm),
            Text(
              req.description,
              style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: SoamaSpacing.md),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openCounterofferDialog(context, req),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.accent,
                      side: BorderSide(color: colors.accent, width: 0.8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusMd),
                    ),
                    child: const Text('Counteroffer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      setState(() {
                        ServiceRequest.acceptCustomerOffer(req.id);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Accepted job ${req.id}! Locked into Escrow.'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: const Color(0xFF15803D),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: colors.onAccent,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusMd),
                    ),
                    child: const Text('Accept Offer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, SoamaThemeColors colors, ServiceRequest job) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SoamaSpacing.md),
      child: GlassSurface(
        padding: const EdgeInsets.all(SoamaSpacing.md),
        borderRadius: SoamaRadii.radiusLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF15803D).withAlpha(25),
                    borderRadius: SoamaRadii.radiusFull,
                  ),
                  child: Text(
                    job.status,
                    style: SoamaTypography.labelSmall.copyWith(
                      color: const Color(0xFF15803D),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  job.agreedPriceFormatted ?? job.servicePrice,
                  style: SoamaTypography.titleSmall.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              job.serviceTitle,
              style: SoamaTypography.titleSmall.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${job.address} • Preferred: ${job.preferredTimeSlot}',
              style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary),
            ),
            const SizedBox(height: SoamaSpacing.md),

            // Job Status Transition Buttons
            Row(
              children: [
                if (job.status == 'Confirmed Appointment') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          ServiceRequest.updateJobStatus(job.id, 'Specialist Arrived');
                        });
                      },
                      icon: const Icon(Icons.location_on_rounded, size: 16),
                      label: const Text('Confirm Arrival', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: colors.onAccent,
                        shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusMd),
                      ),
                    ),
                  ),
                ] else if (job.status == 'Specialist Arrived') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          ServiceRequest.updateJobStatus(job.id, 'Job In Progress');
                        });
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text('Start Work', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusMd),
                      ),
                    ),
                  ),
                ] else if (job.status == 'Job In Progress') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          ServiceRequest.updateJobStatus(job.id, 'Completed');
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Job marked completed! Escrow release authorized.'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Color(0xFF15803D),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text('Mark Completed', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF15803D),
                        foregroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusMd),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Open conversation with customer
                        context.push('/messages/conv-1');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        side: BorderSide(color: colors.glassBorder, width: 0.8),
                        shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusMd),
                      ),
                      child: const Text('Message Customer', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openCounterofferDialog(BuildContext context, ServiceRequest req) {
    final colors = context.soamaColors;
    final priceCtrl = TextEditingController(text: (req.servicePriceAmount + 1500).toString());
    final noteCtrl = TextEditingController(text: 'I can take on this repair today. Materials and transport included.');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusXl),
        title: Text('Propose Counteroffer', style: SoamaTypography.titleMedium.copyWith(color: colors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client proposed ${req.servicePrice}. Enter your counter price:', style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Counteroffer Price (₦)', prefixText: '₦ '),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Note to Customer'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancel', style: TextStyle(color: colors.textSecondary))),
          TextButton(
            onPressed: () {
              final price = int.tryParse(priceCtrl.text.trim()) ?? req.servicePriceAmount;
              ServiceRequest.sendProviderCounteroffer(
                requestId: req.id,
                counterPrice: price,
                messageText: noteCtrl.text.trim(),
              );
              Navigator.of(ctx).pop();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Counteroffer of ₦${priceCtrl.text} sent to customer!'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xFF15803D),
                ),
              );
            },
            child: Text('Send Offer', style: TextStyle(color: colors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
