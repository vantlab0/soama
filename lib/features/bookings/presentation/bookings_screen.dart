import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/soama_colors.dart';
import '../../../shared/models/chat_conversation.dart';
import '../../../shared/models/service_request.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/soama_button.dart';
import '../../../shared/widgets/soama_buttons.dart';
import '../../requests/presentation/providers/requests_provider.dart';
import '../../reviews/presentation/providers/reviews_provider.dart';
import 'providers/bookings_provider.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen>
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

  void _showPasscodeSheet(BuildContext context, ServiceRequest request) {
    HapticFeedback.lightImpact();
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;

    // Deterministic 6-character job code derived from request ID
    final code = request.id.replaceAll('SOA-', 'SEC-');

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13151A) : colors.surface,
            borderRadius: SoamaRadii.sheetTopRadius,
            border: Border.all(color: colors.glassBorder, width: 1.0),
          ),
          padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textTertiary.withOpacity(0.3),
                  borderRadius: SoamaRadii.radiusPill,
                ),
              ),
              const SizedBox(height: SoamaSpacing.md),
              Icon(Icons.vpn_key_rounded, size: 36, color: colors.accent),
              const SizedBox(height: SoamaSpacing.xs),
              Text(
                'Job Start & Release Passcode',
                style: SoamaTypography.titleMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Share this code with ${request.providerName} upon arrival to verify work commencement.',
                textAlign: TextAlign.center,
                style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: SoamaSpacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
                decoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  borderRadius: SoamaRadii.radiusLg,
                  border: Border.all(color: colors.accent.withOpacity(0.6), width: 1.5),
                ),
                child: Text(
                  code,
                  style: SoamaTypography.displayMedium.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4.0,
                  ),
                ),
              ),
              const SizedBox(height: SoamaSpacing.lg),
              PrimaryButton(
                label: 'Close Passcode',
                size: ButtonSize.large,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReviewDialog(BuildContext context, ServiceRequest request) async {
    HapticFeedback.lightImpact();
    final colors = context.soamaColors;

    // Fetch existing review if customer already reviewed this booking
    final existingReview = await ref.read(reviewsRepositoryProvider).getBookingReview(request.id);
    double selectedRating = existingReview?.rating ?? 5.0;
    final reviewController = TextEditingController(text: existingReview?.comment ?? '');
    bool isSubmitting = false;

    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isEditing = existingReview != null;
            return AlertDialog(
              backgroundColor: colors.surface,
              shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusXl),
              title: Text(
                isEditing ? 'Edit Review for ${request.providerName}' : 'Rate ${request.providerName}',
                style: SoamaTypography.titleLarge.copyWith(color: colors.textPrimary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How was the service for "${request.serviceTitle}"?',
                    style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary),
                  ),
                  const SizedBox(height: SoamaSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = index + 1;
                      return IconButton(
                        icon: Icon(
                          starValue <= selectedRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 32,
                          color: const Color(0xFFFBBF24),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                setDialogState(() => selectedRating = starValue.toDouble());
                              },
                      );
                    }),
                  ),
                  const SizedBox(height: SoamaSpacing.sm),
                  TextField(
                    controller: reviewController,
                    maxLines: 3,
                    enabled: !isSubmitting,
                    maxLength: 1000,
                    style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Write feedback about the artisan’s punctuality and quality...',
                      hintStyle: SoamaTypography.bodySmall.copyWith(color: colors.textTertiary),
                      filled: true,
                      fillColor: colors.surfaceSubtle,
                      counterStyle: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary),
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: SoamaRadii.radiusMd,
                        borderSide: BorderSide(color: colors.glassBorder, width: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
                  child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
                ),
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final comment = reviewController.text.trim();
                          if (comment.isNotEmpty && comment.length < 3) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Review comment must be at least 3 characters.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          try {
                            await ref.read(reviewsRepositoryProvider).submitBookingReview(
                                  bookingId: request.id,
                                  rating: selectedRating.toInt(),
                                  comment: comment.isEmpty ? null : comment,
                                );

                            ref.invalidate(bookingReviewProvider(request.id));
                            ref.invalidate(customerBookingsProvider);

                            if (dialogCtx.mounted) {
                              Navigator.of(dialogCtx).pop();
                            }

                            HapticFeedback.mediumImpact();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEditing
                                        ? 'Your review has been updated!'
                                        : 'Thank you! Your ${selectedRating.toInt()}-star review has been recorded.',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusMd),
                                  backgroundColor: const Color(0xFF15803D),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to submit review: ${e.toString().replaceAll('Exception: ', '')}'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.accent,
                          ),
                        )
                      : Text(
                          isEditing ? 'Update Review' : 'Submit Review',
                          style: TextStyle(color: colors.accent, fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReceiptDialog(BuildContext context, ServiceRequest request) {
    HapticFeedback.lightImpact();
    final colors = context.soamaColors;
    final dateFormatter = DateFormat('EEE, MMM d, yyyy');
    final price = request.agreedPriceFormatted ?? request.servicePrice;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusXl),
        title: Row(
          children: [
            Icon(Icons.receipt_long_rounded, color: colors.accent, size: 24),
            const SizedBox(width: 8),
            Text(
              'Job Receipt',
              style: SoamaTypography.titleLarge.copyWith(color: colors.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildReceiptRow('Booking Ref', request.id, colors),
            _buildReceiptRow('Provider', request.providerName, colors),
            _buildReceiptRow('Service', request.serviceTitle, colors),
            _buildReceiptRow('Date Completed', dateFormatter.format(request.preferredDate), colors),
            _buildReceiptRow('Total Paid', price, colors, isHighlight: true),
            _buildReceiptRow('Escrow Release', 'Settled & Verified', colors),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text('Close', style: TextStyle(color: colors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, SoamaColors colors, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: SoamaTypography.labelMedium.copyWith(
                color: isHighlight ? colors.accent : colors.textPrimary,
                fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _markJobCompleted(BuildContext context, ServiceRequest request) async {
    final colors = context.soamaColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusXl),
        title: Text(
          'Confirm Job Completion?',
          style: SoamaTypography.titleLarge.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          'Has ${request.providerName} satisfactorily finished "${request.serviceTitle}"? This will release ${request.agreedPriceFormatted ?? request.servicePrice} from Soama Escrow to the specialist.',
          style: SoamaTypography.bodyMedium.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text('Not Yet', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text('Release Escrow', style: TextStyle(color: colors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      HapticFeedback.mediumImpact();
      ref.read(bookingsRepositoryProvider).completeJob(bookingId: request.id);
      final idx = ServiceRequest.submittedRequests.indexWhere((r) => r.id == request.id);
      if (idx != -1) {
        ServiceRequest.submittedRequests[idx] = request.copyWith(status: 'Completed');
      }
      ref.invalidate(customerBookingsProvider);
      ref.invalidate(customerRequestsProvider);
      setState(() {});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job marked as completed. Funds released from escrow.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF15803D),
          ),
        );
      }
    }
  }

  void _confirmAndLockEscrow(BuildContext context, ServiceRequest request) {
    HapticFeedback.mediumImpact();
    final idx = ServiceRequest.submittedRequests.indexWhere((r) => r.id == request.id);
    if (idx != -1) {
      setState(() {
        ServiceRequest.submittedRequests[idx] = request.copyWith(
          status: 'Confirmed Appointment',
          negotiationStatus: NegotiationStatus.priceAgreed,
        );
      });
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Appointment confirmed with ${request.providerName}! Job passcode generated.'),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusMd),
        backgroundColor: const Color(0xFF15803D),
      ),
    );
  }

  void _cancelBooking(BuildContext context, ServiceRequest request) async {
    final colors = context.soamaColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusXl),
        title: Text(
          'Cancel Service Request?',
          style: SoamaTypography.titleLarge.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to cancel the request for "${request.serviceTitle}" with ${request.providerName}?',
          style: SoamaTypography.bodyMedium.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text('Keep Active', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Cancel Request', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      HapticFeedback.lightImpact();
      ref.read(bookingsRepositoryProvider).cancelBooking(
        bookingId: request.id,
        reason: 'Customer cancelled booking',
      );
      ref.read(requestsRepositoryProvider).cancelRequest(request.id);
      ServiceRequest.declineRequest(request.id);
      ref.invalidate(customerBookingsProvider);
      ref.invalidate(customerRequestsProvider);
      setState(() {});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service request has been cancelled.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final bookingsAsync = ref.watch(customerBookingsProvider);
    final requestsAsync = ref.watch(customerRequestsProvider);

    // Convert real Supabase bookings to unified ServiceRequest representation
    final realBookings = bookingsAsync.valueOrNull?.map((b) => b.toServiceRequest()).toList() ?? [];
    final realRequests = requestsAsync.valueOrNull ?? ServiceRequest.submittedRequests;

    // Merge real bookings with open requests, ensuring uniqueness by ID
    final Set<String> seenIds = {};
    final List<ServiceRequest> allRequests = [];
    for (final b in realBookings) {
      if (seenIds.add(b.id)) allRequests.add(b);
    }
    for (final r in realRequests) {
      if (seenIds.add(r.id)) allRequests.add(r);
    }

    // Filter subsets
    final pendingRequests = allRequests.where((r) => r.isPending).toList();
    final ongoingRequests = allRequests.where((r) => r.isOngoing).toList();
    final completedRequests = allRequests.where((r) => r.isCompleted).toList();

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: colors.accent,
          backgroundColor: colors.surface,
          onRefresh: () async {
            HapticFeedback.lightImpact();
            ref.invalidate(customerBookingsProvider);
            ref.invalidate(customerRequestsProvider);
            if (mounted) setState(() {});
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Title & Subtitle
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 4.0),
                child: Text(
                  'My Bookings',
                  style: SoamaTypography.displayMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'Track scheduled services, price negotiations, and escrow milestones',
                  style: SoamaTypography.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: SoamaSpacing.md),

              // 4 Segmented Tabs: All, Pending, Ongoing, Completed
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
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
                    labelStyle: SoamaTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: SoamaTypography.labelMedium,
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(text: 'All (${allRequests.length})'),
                      Tab(text: 'Pending (${pendingRequests.length})'),
                      Tab(text: 'Ongoing (${ongoingRequests.length})'),
                      Tab(text: 'Completed (${completedRequests.length})'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: SoamaSpacing.md),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildBookingList(
                      context,
                      allRequests,
                      emptyTitle: 'No Bookings Found',
                      emptyMessage: 'When you book or request an artisan specialist, your jobs will appear here.',
                      canExplore: true,
                    ),
                    _buildBookingList(
                      context,
                      pendingRequests,
                      emptyTitle: 'No Pending Requests',
                      emptyMessage: 'You currently have no pending quotes or open negotiations awaiting decision.',
                    ),
                    _buildBookingList(
                      context,
                      ongoingRequests,
                      emptyTitle: 'No Ongoing Jobs',
                      emptyMessage: 'Active appointments and in-progress jobs will appear here once confirmed.',
                    ),
                    _buildBookingList(
                      context,
                      completedRequests,
                      emptyTitle: 'No Completed Jobs Yet',
                      emptyMessage: 'Completed services with verified escrow releases will be recorded here.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingList(
    BuildContext context,
    List<ServiceRequest> requests, {
    required String emptyTitle,
    required String emptyMessage,
    bool canExplore = false,
  }) {
    final colors = context.soamaColors;

    if (requests.isEmpty) {
      return EmptyState(
        icon: Icons.calendar_today_outlined,
        title: emptyTitle,
        message: emptyMessage,
        actionLabel: canExplore ? 'Explore Services' : null,
        onActionPressed: canExplore ? () => context.go(AppRoutes.explore) : null,
      );
    }

    final dateFormatter = DateFormat('EEE, MMM d');

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 110.0),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      itemCount: requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: SoamaSpacing.md),
      itemBuilder: (context, index) {
        final req = requests[index];
        final formattedDate = dateFormatter.format(req.preferredDate);
        final price = req.agreedPriceFormatted ?? req.servicePrice;
        final hasAgreedPrice = req.agreedPrice != null;

        return GlassCard(
          borderRadius: SoamaRadii.radiusXxl,
          padding: const EdgeInsets.all(18.0),
          onTap: () {
            // Tapping opens negotiation if active/pending, or details
            if (!req.isCompleted && !req.isCancelled) {
              context.push(
                AppRoutes.negotiationPath(req.id),
                extra: req,
              );
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Status badge & Price tag
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusPill(context, req),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        tooltip: 'Message ${req.providerName}',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          final conv = ChatConversation.findOrCreateForProvider(
                            providerId: req.providerId,
                            providerName: req.providerName,
                            providerProfession: req.providerProfession,
                            providerAvatarUrl: req.providerAvatarUrl,
                            serviceRequestId: req.id,
                            serviceTitle: req.serviceTitle,
                            agreedPrice: req.agreedPriceFormatted ?? req.servicePrice,
                          );
                          context.push(AppRoutes.conversationPath(conv.id), extra: conv);
                        },
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasAgreedPrice ? '$price in Escrow' : '$price (Est)',
                        style: SoamaTypography.labelMedium.copyWith(
                          color: colors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: SoamaSpacing.md),

              // Provider and Service Info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: SoamaRadii.radiusMd,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Image(
                        image: ResizeImage(
                          NetworkImage(req.providerAvatarUrl),
                          width: 120,
                          height: 120,
                        ),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: colors.surfaceSubtle,
                          child: Icon(Icons.person_rounded, color: colors.textTertiary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: SoamaSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req.serviceTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SoamaTypography.titleMedium.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${req.providerName} • ${req.providerProfession}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SoamaTypography.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ref: ${req.id}',
                          style: SoamaTypography.labelSmall.copyWith(
                            color: colors.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: SoamaSpacing.md),

              // Date, Time & Location Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary,
                  borderRadius: SoamaRadii.radiusMd,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_available_rounded,
                      size: 16,
                      color: colors.accent,
                    ),
                    const SizedBox(width: SoamaSpacing.xs),
                    Expanded(
                      child: Text(
                        '$formattedDate • ${req.preferredTimeSlot.split('(').first.trim()}',
                        style: SoamaTypography.labelMedium.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.place_outlined,
                      size: 14,
                      color: colors.textTertiary,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      req.address.split(',').first,
                      style: SoamaTypography.labelSmall.copyWith(
                        color: colors.textTertiary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: SoamaSpacing.md),

              // Contextual Action Buttons depending on status
              _buildContextualActions(context, req),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusPill(BuildContext context, ServiceRequest req) {
    Color badgeColor;
    String label;
    IconData icon;

    if (req.isCancelled) {
      badgeColor = const Color(0xFFF87171);
      label = 'Cancelled';
      icon = Icons.cancel_rounded;
    } else if (req.isCompleted) {
      badgeColor = const Color(0xFF4ADE80);
      label = 'Completed';
      icon = Icons.check_circle_rounded;
    } else if (req.isOngoing) {
      badgeColor = const Color(0xFF38BDF8);
      label = 'Ongoing Appointment';
      icon = Icons.engineering_rounded;
    } else if (req.negotiationStatus == NegotiationStatus.priceAgreed) {
      badgeColor = const Color(0xFF4ADE80);
      label = 'Price Agreed';
      icon = Icons.handshake_rounded;
    } else if (req.negotiationStatus == NegotiationStatus.counterofferReceived) {
      badgeColor = const Color(0xFF38BDF8);
      label = 'Counteroffer Received';
      icon = Icons.swap_horiz_rounded;
    } else {
      badgeColor = const Color(0xFFFBBF24);
      label = 'Pending Response';
      icon = Icons.hourglass_top_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.14),
        borderRadius: SoamaRadii.radiusPill,
        border: Border.all(color: badgeColor.withOpacity(0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextualActions(BuildContext context, ServiceRequest req) {
    if (req.isCancelled) {
      return Center(
        child: Text(
          'Request was cancelled.',
          style: SoamaTypography.labelSmall.copyWith(color: Colors.redAccent),
        ),
      );
    }

    if (req.isCompleted) {
      return Row(
        children: [
          Expanded(
            child: SoamaButton.glass(
              label: 'View Receipt',
              icon: Icons.receipt_long_rounded,
              size: SoamaButtonSize.small,
              onPressed: () => _showReceiptDialog(context, req),
            ),
          ),
          const SizedBox(width: SoamaSpacing.sm),
          Expanded(
            child: SoamaButton(
              label: 'Leave Review',
              icon: Icons.star_outline_rounded,
              size: SoamaButtonSize.small,
              onPressed: () => _showReviewDialog(context, req),
            ),
          ),
        ],
      );
    }

    if (req.isOngoing) {
      return Row(
        children: [
          Expanded(
            child: SoamaButton.glass(
              label: 'View Passcode',
              icon: Icons.vpn_key_rounded,
              size: SoamaButtonSize.small,
              onPressed: () => _showPasscodeSheet(context, req),
            ),
          ),
          const SizedBox(width: SoamaSpacing.sm),
          Expanded(
            child: SoamaButton(
              label: 'Mark Completed',
              icon: Icons.check_circle_outline_rounded,
              size: SoamaButtonSize.small,
              onPressed: () => _markJobCompleted(context, req),
            ),
          ),
        ],
      );
    }

    // Pending / In Negotiation actions
    if (req.negotiationStatus == NegotiationStatus.priceAgreed && req.status != 'Confirmed Appointment') {
      return Row(
        children: [
          Expanded(
            child: SoamaButton.glass(
              label: 'Review Agreement',
              icon: Icons.handshake_outlined,
              size: SoamaButtonSize.small,
              onPressed: () {
                context.push(AppRoutes.negotiationPath(req.id), extra: req);
              },
            ),
          ),
          const SizedBox(width: SoamaSpacing.sm),
          Expanded(
            child: SoamaButton(
              label: 'Confirm & Lock',
              icon: Icons.lock_outline_rounded,
              size: SoamaButtonSize.small,
              onPressed: () => _confirmAndLockEscrow(context, req),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: SoamaButton.glass(
            label: req.negotiationStatus == NegotiationStatus.counterofferReceived
                ? 'Review Offer'
                : 'Negotiate Rate',
            icon: Icons.payments_outlined,
            size: SoamaButtonSize.small,
            onPressed: () {
              context.push(AppRoutes.negotiationPath(req.id), extra: req);
            },
          ),
        ),
        const SizedBox(width: SoamaSpacing.sm),
        Expanded(
          child: OutlinedButton(
            onPressed: () => _cancelBooking(context, req),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent, width: 0.8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusLg),
            ),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
      ],
    );
  }
}
