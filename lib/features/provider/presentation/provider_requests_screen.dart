import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/theme/soama_colors.dart';
import '../../../../shared/models/service_request.dart';
import '../../../../shared/models/user_account.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/glass_surface.dart';
import '../../requests/presentation/providers/requests_provider.dart';

class ProviderRequestsScreen extends ConsumerStatefulWidget {
  const ProviderRequestsScreen({super.key});

  @override
  ConsumerState<ProviderRequestsScreen> createState() => _ProviderRequestsScreenState();
}

class _ProviderRequestsScreenState extends ConsumerState<ProviderRequestsScreen> {
  int _selectedFilterIndex = 0; // 0: All, 1: Pending, 2: Countered

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final account = UserAccount.current;
    final providerId = account.providerProfile?.providerId ?? account.id;

    final inboxAsync = ref.watch(providerInboxRequestsProvider);
    final allRequests = inboxAsync.valueOrNull ?? ServiceRequest.getRequestsForProvider(providerId);

    final filteredRequests = allRequests.where((r) {
      if (_selectedFilterIndex == 1) {
        return r.negotiationStatus == NegotiationStatus.awaitingResponse;
      }
      if (_selectedFilterIndex == 2) {
        return r.negotiationStatus == NegotiationStatus.counterofferReceived;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          'Customer Requests',
          style: SoamaTypography.titleMedium.copyWith(color: colors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: colors.textPrimary),
            onPressed: () {
              ref.invalidate(providerInboxRequestsProvider);
              setState(() {});
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Pills
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SoamaSpacing.lg, vertical: SoamaSpacing.sm),
              child: Row(
                children: [
                  _buildFilterTab(0, 'All (${allRequests.length})', colors),
                  const SizedBox(width: 8),
                  _buildFilterTab(
                    1,
                    'Pending (${allRequests.where((r) => r.negotiationStatus == NegotiationStatus.awaitingResponse).length})',
                    colors,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterTab(
                    2,
                    'Countered (${allRequests.where((r) => r.negotiationStatus == NegotiationStatus.counterofferReceived).length})',
                    colors,
                  ),
                ],
              ),
            ),

            Expanded(
              child: filteredRequests.isEmpty
                  ? EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'No Requests Found',
                      message: 'Customer inquiries and service requests will be listed here.',
                      actionLabel: 'Refresh',
                      onActionPressed: () => setState(() {}),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: SoamaSpacing.lg, vertical: SoamaSpacing.sm),
                      itemCount: filteredRequests.length,
                      itemBuilder: (context, index) {
                        final req = filteredRequests[index];
                        return _buildRequestItem(context, colors, req);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(int index, String label, SoamaThemeColors colors) {
    final isSelected = _selectedFilterIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedFilterIndex = index);
        },
        child: AnimatedContainer(
          duration: SoamaMotion.snappy,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? colors.accent : colors.surfaceSecondary,
            borderRadius: SoamaRadii.radiusFull,
          ),
          child: Center(
            child: Text(
              label,
              style: SoamaTypography.labelSmall.copyWith(
                color: isSelected ? colors.onAccent : colors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestItem(BuildContext context, SoamaThemeColors colors, ServiceRequest req) {
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
                    color: req.negotiationStatus.color.withAlpha(25),
                    borderRadius: SoamaRadii.radiusFull,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(req.negotiationStatus.icon, size: 12, color: req.negotiationStatus.color),
                      const SizedBox(width: 4),
                      Text(
                        req.negotiationStatus.label,
                        style: SoamaTypography.labelSmall.copyWith(
                          color: req.negotiationStatus.color,
                          fontWeight: FontWeight.w700,
                        ),
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
              req.serviceTitle,
              style: SoamaTypography.titleSmall.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${req.address} • Schedule: ${req.preferredTimeSlot}',
              style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary),
            ),
            const SizedBox(height: SoamaSpacing.sm),
            Text(
              req.description,
              style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: SoamaSpacing.md),

            // Negotiation Message history preview if present
            if (req.negotiationMessages.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary,
                  borderRadius: SoamaRadii.radiusMd,
                ),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: 14, color: colors.textTertiary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Latest: "${req.negotiationMessages.last.text}"',
                        style: SoamaTypography.labelSmall.copyWith(
                          color: colors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SoamaSpacing.md),
            ],

            // Action row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openCounterDialog(context, req),
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
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      final pendingOffer = req.negotiationMessages.reversed.cast<NegotiationMessage?>().firstWhere(
                            (m) => m?.offerStatus == OfferStatus.pending,
                            orElse: () => null,
                          );
                      if (pendingOffer != null) {
                        final account = UserAccount.current;
                        final callerId = account.providerProfile?.providerId ?? account.id;
                        ref.read(requestsRepositoryProvider).acceptPriceOffer(
                              offerId: pendingOffer.id,
                              callerId: callerId,
                            );
                      }
                      ServiceRequest.acceptCustomerOffer(req.id);
                      ref.invalidate(providerInboxRequestsProvider);
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Offer accepted at ${req.servicePrice}! Booking confirmed.'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: const Color(0xFF15803D),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: colors.onAccent,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusMd),
                      elevation: 0,
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

  void _openCounterDialog(BuildContext context, ServiceRequest req) {
    final colors = context.soamaColors;
    final priceCtrl = TextEditingController(text: (req.servicePriceAmount + 2000).toString());
    final noteCtrl = TextEditingController(text: 'I can inspect and execute this job tomorrow morning.');

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
              ref.read(requestsRepositoryProvider).submitPriceOffer(
                requestId: req.id,
                amountNaira: price,
                message: noteCtrl.text.trim(),
              );
              ServiceRequest.sendProviderCounteroffer(
                requestId: req.id,
                counterPrice: price,
                messageText: noteCtrl.text.trim(),
              );
              ref.invalidate(providerInboxRequestsProvider);
              Navigator.of(ctx).pop();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Counteroffer sent to customer!'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Color(0xFF15803D),
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
