import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/theme/soama_colors.dart';
import '../../../../shared/models/service_request.dart';
import '../../../../shared/models/user_account.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/glass_surface.dart';
import '../../bookings/presentation/providers/bookings_provider.dart';
import '../../requests/presentation/providers/requests_provider.dart';

class ProviderJobsScreen extends ConsumerStatefulWidget {
  const ProviderJobsScreen({super.key});

  @override
  ConsumerState<ProviderJobsScreen> createState() => _ProviderJobsScreenState();
}

class _ProviderJobsScreenState extends ConsumerState<ProviderJobsScreen> {
  int _selectedTab = 0; // 0: All, 1: Upcoming, 2: Active, 3: Completed

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final account = UserAccount.current;
    final providerId = account.providerProfile?.providerId ?? account.id;

    final jobsAsync = ref.watch(providerJobsProvider);
    final inboxAsync = ref.watch(providerInboxRequestsProvider);

    final realJobs = jobsAsync.valueOrNull?.map((b) => b.toServiceRequest()).toList() ?? [];
    final realRequests = inboxAsync.valueOrNull ?? ServiceRequest.getRequestsForProvider(providerId);

    final Set<String> seenIds = {};
    final List<ServiceRequest> allJobs = [];
    for (final j in realJobs) {
      if (seenIds.add(j.id)) allJobs.add(j);
    }
    for (final r in realRequests) {
      if (seenIds.add(r.id)) allJobs.add(r);
    }

    final filteredJobs = allJobs.where((job) {
      final s = job.status.toLowerCase();
      if (_selectedTab == 1) {
        return s.contains('confirmed');
      }
      if (_selectedTab == 2) {
        return s.contains('arrived') || s.contains('progress');
      }
      if (_selectedTab == 3) {
        return s.contains('completed');
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          'My Provider Jobs',
          style: SoamaTypography.titleMedium.copyWith(color: colors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Segmented Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SoamaSpacing.lg, vertical: SoamaSpacing.sm),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary,
                  borderRadius: SoamaRadii.radiusMd,
                ),
                child: Row(
                  children: [
                    _buildTab(0, 'All (${allJobs.length})', colors),
                    _buildTab(1, 'Upcoming', colors),
                    _buildTab(2, 'Active', colors),
                    _buildTab(3, 'Done', colors),
                  ],
                ),
              ),
            ),

            Expanded(
              child: filteredJobs.isEmpty
                  ? EmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'No Jobs in this Category',
                      message: 'When customer appointments are booked and confirmed, they will show up here.',
                      actionLabel: 'Refresh',
                      onActionPressed: () => setState(() {}),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: SoamaSpacing.lg, vertical: SoamaSpacing.sm),
                      itemCount: filteredJobs.length,
                      itemBuilder: (context, index) {
                        final job = filteredJobs[index];
                        return _buildJobCard(context, colors, job);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, String label, SoamaThemeColors colors) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedTab = index);
        },
        child: AnimatedContainer(
          duration: SoamaMotion.snappy,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? colors.surface : Colors.transparent,
            borderRadius: SoamaRadii.radiusSm,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(15),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: SoamaTypography.labelSmall.copyWith(
                color: isSelected ? colors.textPrimary : colors.textTertiary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, SoamaThemeColors colors, ServiceRequest job) {
    Color statusColor;
    if (job.status.toLowerCase().contains('completed')) {
      statusColor = const Color(0xFF15803D);
    } else if (job.status.toLowerCase().contains('progress') || job.status.toLowerCase().contains('arrived')) {
      statusColor = const Color(0xFF7C3AED);
    } else {
      statusColor = colors.accent;
    }

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
                    color: statusColor.withAlpha(25),
                    borderRadius: SoamaRadii.radiusFull,
                  ),
                  child: Text(
                    job.status,
                    style: SoamaTypography.labelSmall.copyWith(
                      color: statusColor,
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
            const SizedBox(height: SoamaSpacing.sm),
            Text(
              job.serviceTitle,
              style: SoamaTypography.titleSmall.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${job.address} • ${job.preferredTimeSlot}',
              style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary),
            ),
            const SizedBox(height: SoamaSpacing.xs),
            Text(
              'Client Ref: ${job.id}',
              style: SoamaTypography.labelSmall.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: SoamaSpacing.md),

            // Status Transition Buttons
            Row(
              children: [
                if (job.status == 'Confirmed Appointment') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        ref.read(bookingsRepositoryProvider).startJob(bookingId: job.id);
                        ServiceRequest.updateJobStatus(job.id, 'Specialist Arrived');
                        ref.invalidate(providerJobsProvider);
                        ref.invalidate(providerInboxRequestsProvider);
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Arrival confirmed for job ${job.id}. Client notified.'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: const Color(0xFF15803D),
                          ),
                        );
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
                        HapticFeedback.mediumImpact();
                        ref.read(bookingsRepositoryProvider).startJob(bookingId: job.id);
                        ServiceRequest.updateJobStatus(job.id, 'Job In Progress');
                        ref.invalidate(providerJobsProvider);
                        ref.invalidate(providerInboxRequestsProvider);
                        setState(() {});
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
                        ref.read(bookingsRepositoryProvider).completeJob(bookingId: job.id);
                        ServiceRequest.updateJobStatus(job.id, 'Completed');
                        ref.invalidate(providerJobsProvider);
                        ref.invalidate(providerInboxRequestsProvider);
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Job marked completed! Escrow funds released to your balance.'),
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF15803D).withAlpha(15),
                        borderRadius: SoamaRadii.radiusMd,
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.task_alt_rounded, size: 16, color: Color(0xFF15803D)),
                            const SizedBox(width: 6),
                            Text(
                              'Completed & Paid via Escrow',
                              style: SoamaTypography.labelSmall.copyWith(
                                color: const Color(0xFF15803D),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
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
}
