import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/soama_colors.dart';
import '../../../../shared/models/user_account.dart';
import '../../../../shared/widgets/glass_surface.dart';
import '../../../../shared/widgets/soama_buttons.dart';
import '../providers/bookings_provider.dart';

class EscrowCheckoutSheet extends ConsumerStatefulWidget {
  final String bookingId;
  final String serviceTitle;
  final String providerName;
  final int amountMinorUnits;
  final String? passcode;

  const EscrowCheckoutSheet({
    super.key,
    required this.bookingId,
    required this.serviceTitle,
    required this.providerName,
    required this.amountMinorUnits,
    this.passcode,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String bookingId,
    required String serviceTitle,
    required String providerName,
    required int amountMinorUnits,
    String? passcode,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => EscrowCheckoutSheet(
        bookingId: bookingId,
        serviceTitle: serviceTitle,
        providerName: providerName,
        amountMinorUnits: amountMinorUnits,
        passcode: passcode,
      ),
    );
  }

  @override
  ConsumerState<EscrowCheckoutSheet> createState() => _EscrowCheckoutSheetState();
}

class _EscrowCheckoutSheetState extends ConsumerState<EscrowCheckoutSheet> {
  String _selectedMethod = 'card';
  bool _isProcessing = false;

  Future<void> _handlePayment() async {
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final paymentsRepo = ref.read(paymentsRepositoryProvider);
      final customerId = UserAccount.current.id;

      await paymentsRepo.initializeEscrowPayment(
        bookingId: widget.bookingId,
        customerId: customerId,
        amountMinorUnits: widget.amountMinorUnits,
        gateway: 'paystack',
      );

      // Invalidate customer bookings list so fresh data displays
      ref.invalidate(customerBookingsProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment authorized! Funds are safely held in escrow.'),
            backgroundColor: Color(0xFF15803D),
            duration: Duration(seconds: 4),
          ),
        );
        context.go(AppRoutes.bookings);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Escrow authorization note: $e'),
            backgroundColor: const Color(0xFFD97706),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;
    final nairaFormat = NumberFormat.currency(symbol: '₦', decimalDigits: 0);
    final amountNaira = (widget.amountMinorUnits / 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14171E) : colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: colors.glassBorder, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle pill
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textTertiary.withOpacity(0.3),
                  borderRadius: SoamaRadii.radiusPill,
                ),
              ),
            ),
            const SizedBox(height: SoamaSpacing.md),

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.shield_rounded, color: colors.accent, size: 24),
                ),
                const SizedBox(width: SoamaSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Secure Escrow Checkout',
                        style: SoamaTypography.titleMedium.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Powered by Paystack & Soama Escrow',
                        style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: colors.textTertiary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: SoamaSpacing.md),

            // Price & Service Summary Card
            GlassSurface(
              borderRadius: SoamaRadii.radiusLg,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Service', style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary)),
                      Text(widget.serviceTitle, style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Specialist', style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary)),
                      Text(widget.providerName, style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Escrow Protection Fee', style: SoamaTypography.bodySmall.copyWith(color: colors.textSecondary)),
                      Text('₦0 (Covered by Soama)', style: SoamaTypography.bodyMedium.copyWith(color: const Color(0xFF15803D), fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Amount', style: SoamaTypography.titleSmall.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700)),
                      Text(
                        nairaFormat.format(amountNaira),
                        style: SoamaTypography.headlineSmall.copyWith(color: colors.accent, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: SoamaSpacing.md),

            // Payment Channel Selector
            Text('Payment Method', style: SoamaTypography.labelMedium.copyWith(color: colors.textPrimary)),
            const SizedBox(height: SoamaSpacing.xs),
            Row(
              children: [
                _buildMethodChip(colors, 'card', 'Debit Card', Icons.credit_card_rounded),
                const SizedBox(width: 8),
                _buildMethodChip(colors, 'transfer', 'Bank Transfer', Icons.account_balance_rounded),
                const SizedBox(width: 8),
                _buildMethodChip(colors, 'ussd', 'USSD', Icons.dialpad_rounded),
              ],
            ),
            const SizedBox(height: SoamaSpacing.md),

            // Escrow Guarantee Notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.accent.withOpacity(0.08),
                borderRadius: SoamaRadii.radiusMd,
                border: Border.all(color: colors.accent.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: colors.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Funds remain safely locked in escrow and are only released to ${widget.providerName} when the job is completed and you give your verification passcode.',
                      style: SoamaTypography.labelSmall.copyWith(
                        color: colors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SoamaSpacing.lg),

            // Checkout CTA
            PrimaryButton(
              label: _isProcessing ? 'Securing Funds...' : 'Authorize & Lock in Escrow (${nairaFormat.format(amountNaira)})',
              size: ButtonSize.large,
              onPressed: _isProcessing ? null : _handlePayment,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodChip(SoamaThemeColors colors, String id, String label, IconData icon) {
    final isSelected = _selectedMethod == id;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedMethod = id),
        borderRadius: SoamaRadii.radiusMd,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? colors.accent.withOpacity(0.15) : colors.surfaceSubtle,
            borderRadius: SoamaRadii.radiusMd,
            border: Border.all(
              color: isSelected ? colors.accent : colors.glassBorder,
              width: isSelected ? 1.5 : 0.8,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? colors.accent : colors.textTertiary, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: SoamaTypography.labelSmall.copyWith(
                  color: isSelected ? colors.accent : colors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
