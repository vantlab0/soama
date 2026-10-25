import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/supabase_config.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/theme/soama_colors.dart';
import '../../../../shared/models/service_request.dart';
import '../../../../shared/models/user_account.dart';
import '../../../../shared/widgets/glass_surface.dart';
import '../../../../shared/widgets/soama_buttons.dart';
import '../../bookings/presentation/widgets/escrow_checkout_sheet.dart';
import '../../requests/presentation/providers/requests_provider.dart';

class NegotiationScreen extends ConsumerStatefulWidget {
  final String requestId;
  final ServiceRequest? initialRequest;

  const NegotiationScreen({
    super.key,
    required this.requestId,
    this.initialRequest,
  });

  @override
  ConsumerState<NegotiationScreen> createState() => _NegotiationScreenState();
}

class _NegotiationScreenState extends ConsumerState<NegotiationScreen> {
  late ServiceRequest _request;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isProposingOffer = false;
  bool _isSimulatingReply = false;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    _request = widget.initialRequest ??
        ServiceRequest.findById(widget.requestId) ??
        ServiceRequest.submittedRequests.first;

    // Pre-populate price with current base or latest counteroffer
    _priceController.text = _request.servicePriceAmount.toString();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _priceController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _syncRequest() {
    final idx = ServiceRequest.submittedRequests.indexWhere((r) => r.id == _request.id);
    if (idx != -1) {
      ServiceRequest.submittedRequests[idx] = _request;
    } else {
      ServiceRequest.submittedRequests.add(_request);
    }
  }

  void _acceptOffer(NegotiationMessage offer) {
    if (offer.offerStatus != OfferStatus.pending) return;

    HapticFeedback.mediumImpact();

    // Mark offer as accepted and supersede any earlier offers
    final updatedMessages = _request.negotiationMessages.map((msg) {
      if (msg.id == offer.id) {
        return msg.copyWith(offerStatus: OfferStatus.accepted);
      } else if (msg.isOffer && msg.offerStatus == OfferStatus.pending) {
        return msg.copyWith(offerStatus: OfferStatus.replaced);
      }
      return msg;
    }).toList();

    // Add confirmation text message
    final confirmationMsg = NegotiationMessage(
      id: 'msg-acc-${DateTime.now().millisecondsSinceEpoch}',
      sender: OfferSender.customer,
      senderName: 'You',
      text: 'I have accepted your offer of ${offer.formattedPrice}. Looking forward to the service.',
      timestamp: DateTime.now(),
    );
    updatedMessages.add(confirmationMsg);

    setState(() {
      _request = _request.copyWith(
        negotiationStatus: NegotiationStatus.priceAgreed,
        agreedPrice: offer.proposedPrice,
        status: 'Price Agreed (Escrow Ready)',
        negotiationMessages: updatedMessages,
      );
    });

    _syncRequest();
    _scrollToBottom();

    // Call real backend RPC
    ref.read(requestsRepositoryProvider).acceptPriceOffer(
      offerId: offer.id,
      callerId: UserAccount.current.id,
    );

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Offer accepted at ${offer.formattedPrice}! Escrow agreement locked.'),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusMd),
        backgroundColor: const Color(0xFF15803D),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _declineOffer(NegotiationMessage offer) {
    if (offer.offerStatus != OfferStatus.pending) return;

    HapticFeedback.lightImpact();

    final updatedMessages = _request.negotiationMessages.map((msg) {
      if (msg.id == offer.id) {
        return msg.copyWith(offerStatus: OfferStatus.declined);
      }
      return msg;
    }).toList();

    // Add decline text message
    final declineMsg = NegotiationMessage(
      id: 'msg-dec-${DateTime.now().millisecondsSinceEpoch}',
      sender: OfferSender.customer,
      senderName: 'You',
      text: 'I declined the offer of ${offer.formattedPrice}. Let us negotiate a more suitable budget.',
      timestamp: DateTime.now(),
    );
    updatedMessages.add(declineMsg);

    setState(() {
      _request = _request.copyWith(
        negotiationStatus: NegotiationStatus.awaitingResponse,
        negotiationMessages: updatedMessages,
      );
    });

    _syncRequest();
    _scrollToBottom();

    // Call real backend RPC
    ref.read(requestsRepositoryProvider).rejectPriceOffer(offer.id);
  }

  void _sendCustomerMessageOrOffer() {
    if (_isSimulatingReply) return;

    setState(() => _priceError = null);
    final text = _messageController.text.trim();
    int? proposedPrice;

    if (_isProposingOffer) {
      final priceRaw = _priceController.text.trim().replaceAll(',', '');
      final parsed = int.tryParse(priceRaw);

      if (parsed == null || parsed <= 0) {
        setState(() => _priceError = 'Please enter a valid amount.');
        return;
      }
      if (parsed < 1000) {
        setState(() => _priceError = 'Minimum negotiable rate is ₦1,000.');
        return;
      }
      if (parsed > 2000000) {
        setState(() => _priceError = 'Amount exceeds maximum marketplace limit.');
        return;
      }
      proposedPrice = parsed;
    } else {
      if (text.isEmpty) return;
    }

    HapticFeedback.lightImpact();

    // Supersede any prior customer pending offers if sending a new offer
    final updatedMessages = _request.negotiationMessages.map((msg) {
      if (_isProposingOffer && msg.isOffer && msg.offerStatus == OfferStatus.pending) {
        return msg.copyWith(offerStatus: OfferStatus.replaced);
      }
      return msg;
    }).toList();

    final newCustomerMessage = NegotiationMessage(
      id: 'msg-cust-${DateTime.now().millisecondsSinceEpoch}',
      sender: OfferSender.customer,
      senderName: 'You',
      text: text.isNotEmpty
          ? text
          : (_isProposingOffer ? 'I would like to propose an offer of ${NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(proposedPrice)}.' : ''),
      timestamp: DateTime.now(),
      proposedPrice: proposedPrice,
      offerStatus: _isProposingOffer ? OfferStatus.pending : null,
    );

    updatedMessages.add(newCustomerMessage);

    setState(() {
      _request = _request.copyWith(
        negotiationStatus: NegotiationStatus.awaitingResponse,
        negotiationMessages: updatedMessages,
      );
      _messageController.clear();
      _isProposingOffer = false;
      _isSimulatingReply = !SupabaseConfig.isConfigured;
    });

    _syncRequest();
    _scrollToBottom();

    // Call real backend RPC when proposing price offer
    if (proposedPrice != null) {
      ref.read(requestsRepositoryProvider).submitPriceOffer(
        requestId: _request.id,
        amountNaira: proposedPrice,
        message: text.isNotEmpty ? text : null,
      );
    }

    // Predictable local provider simulation when unconfigured/offline
    if (!SupabaseConfig.isConfigured) {
      _simulateArtisanResponse(proposedPrice);
    }
  }

  void _simulateArtisanResponse(int? customerProposedPrice) {
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;

      final basePrice = _request.servicePriceAmount;
      final currentOffer = customerProposedPrice;

      NegotiationMessage artisanReply;
      NegotiationStatus nextStatus = NegotiationStatus.counterofferReceived;
      int? agreedPrice;

      // Predictable, testable simulation rules:
      if (currentOffer != null) {
        if (currentOffer >= (basePrice * 0.90)) {
          // If within 10% of base, artisan accepts!
          artisanReply = NegotiationMessage(
            id: 'sim-${DateTime.now().millisecondsSinceEpoch}',
            sender: OfferSender.provider,
            senderName: '${_request.providerName} (Artisan)',
            text: 'I accept your offer of ${NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(currentOffer)}. I have locked the schedule and will come prepared.',
            timestamp: DateTime.now(),
            proposedPrice: currentOffer,
            offerStatus: OfferStatus.accepted,
            isSimulatedProvider: true,
          );
          nextStatus = NegotiationStatus.priceAgreed;
          agreedPrice = currentOffer;
        } else if (currentOffer < (basePrice * 0.70)) {
          // If significantly lower, artisan counters at 85% of base
          final counter = ((basePrice * 0.85) / 500).round() * 500;
          artisanReply = NegotiationMessage(
            id: 'sim-${DateTime.now().millisecondsSinceEpoch}',
            sender: OfferSender.provider,
            senderName: '${_request.providerName} (Artisan)',
            text: 'Considering the scope of work and travel in Warri, the lowest I can do is ${NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(counter)}. Can we agree on this?',
            timestamp: DateTime.now(),
            proposedPrice: counter,
            offerStatus: OfferStatus.pending,
            isSimulatedProvider: true,
          );
          nextStatus = NegotiationStatus.counterofferReceived;
        } else {
          // Middle ground counter
          final counter = ((basePrice * 0.88) / 500).round() * 500;
          artisanReply = NegotiationMessage(
            id: 'sim-${DateTime.now().millisecondsSinceEpoch}',
            sender: OfferSender.provider,
            senderName: '${_request.providerName} (Artisan)',
            text: 'Let us meet in the middle at ${NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(counter)} so I can cover standard high-grade materials.',
            timestamp: DateTime.now(),
            proposedPrice: counter,
            offerStatus: OfferStatus.pending,
            isSimulatedProvider: true,
          );
          nextStatus = NegotiationStatus.counterofferReceived;
        }
      } else {
        // Standard conversational reply
        artisanReply = NegotiationMessage(
          id: 'sim-${DateTime.now().millisecondsSinceEpoch}',
          sender: OfferSender.provider,
          senderName: '${_request.providerName} (Artisan)',
          text: 'Thank you for the update. Let me know what specific budget you have in mind for this service.',
          timestamp: DateTime.now(),
          isSimulatedProvider: true,
        );
        nextStatus = NegotiationStatus.awaitingResponse;
      }

      final messages = List<NegotiationMessage>.from(_request.negotiationMessages);
      if (nextStatus == NegotiationStatus.priceAgreed) {
        // Mark customer offer as accepted
        for (int i = 0; i < messages.length; i++) {
          if (messages[i].isOffer && messages[i].offerStatus == OfferStatus.pending) {
            messages[i] = messages[i].copyWith(offerStatus: OfferStatus.accepted);
          }
        }
      }
      messages.add(artisanReply);

      setState(() {
        _isSimulatingReply = false;
        _request = _request.copyWith(
          negotiationStatus: nextStatus,
          agreedPrice: agreedPrice ?? _request.agreedPrice,
          status: nextStatus == NegotiationStatus.priceAgreed
              ? 'Price Agreed (Escrow Ready)'
              : _request.status,
          negotiationMessages: messages,
        );
      });

      _syncRequest();
      _scrollToBottom();
    });
  }

  void _cancelNegotiation() async {
    final colors = context.soamaColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusXl),
        title: Text(
          'Cancel Service Request?',
          style: SoamaTypography.titleLarge.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          'This will cancel the active price negotiation with ${_request.providerName}.',
          style: SoamaTypography.bodyMedium.copyWith(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Keep Active', style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel Request', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      HapticFeedback.lightImpact();
      setState(() {
        _request = _request.copyWith(
          negotiationStatus: NegotiationStatus.requestCancelled,
          status: 'Request Cancelled',
        );
      });
      _syncRequest();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final isPriceAgreed = _request.negotiationStatus == NegotiationStatus.priceAgreed;
    final isCancelled = _request.negotiationStatus == NegotiationStatus.requestCancelled;

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
        title: Column(
          children: [
            Text(
              'Price Negotiation',
              style: SoamaTypography.titleMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Ref: ${_request.id}',
              style: SoamaTypography.labelSmall.copyWith(
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (!isPriceAgreed && !isCancelled)
            IconButton(
              icon: Icon(Icons.more_vert_rounded, color: colors.textSecondary),
              onPressed: _cancelNegotiation,
              tooltip: 'Cancel Request',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Status Indicator Banner
            _buildStatusHeader(context),

            // 2. Compact Service Request Summary Card
            _buildServiceSummaryCard(context),

            // 3. Agreed Price Highlight Banner (if price agreed)
            if (isPriceAgreed) _buildAgreedPriceBanner(context),

            // 4. Conversation & Offer History Feed
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                itemCount: _request.negotiationMessages.length + (_isSimulatingReply ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _request.negotiationMessages.length && _isSimulatingReply) {
                    return _buildSimulatingIndicator(context);
                  }
                  final msg = _request.negotiationMessages[index];
                  return _buildMessageBubble(context, msg);
                },
              ),
            ),

            // 5. Persistent Composer / Booking Action Bar
            _buildBottomActionBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(BuildContext context) {
    final status = _request.negotiationStatus;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.12),
        border: Border(
          bottom: BorderSide(color: status.color.withOpacity(0.3), width: 0.8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(status.icon, size: 16, color: status.color),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: SoamaTypography.labelMedium.copyWith(
              color: status.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceSummaryCard(BuildContext context) {
    final colors = context.soamaColors;
    final dateFormatter = DateFormat('EEE, MMM d');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 4.0),
      child: GlassSurface(
        borderRadius: SoamaRadii.radiusLg,
        padding: const EdgeInsets.all(12.0),
        blurIntensity: GlassBlurIntensity.none,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: SoamaRadii.radiusMd,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Image(
                  image: ResizeImage(
                    NetworkImage(_request.providerAvatarUrl),
                    width: 100,
                    height: 100,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          _request.serviceTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SoamaTypography.titleSmall.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        'Base: ${_request.servicePrice}',
                        style: SoamaTypography.labelSmall.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_request.providerName} • ${dateFormatter.format(_request.preferredDate)} (${_request.preferredTimeSlot.split('(').first.trim()})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SoamaTypography.labelSmall.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgreedPriceBanner(BuildContext context) {
    final colors = context.soamaColors;
    final agreedFormatted = _request.agreedPriceFormatted ?? _request.servicePrice;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: colors.accent.withOpacity(0.18),
        borderRadius: SoamaRadii.radiusLg,
        border: Border.all(color: colors.accent, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_rounded, color: colors.accent, size: 24),
          const SizedBox(width: SoamaSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agreed Price: $agreedFormatted',
                  style: SoamaTypography.titleSmall.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Both parties agreed. Escrow funds will be secured when you continue to booking.',
                  style: SoamaTypography.bodySmall.copyWith(
                    color: colors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, NegotiationMessage msg) {
    final colors = context.soamaColors;
    final isCustomer = msg.sender == OfferSender.customer;
    final timeFormatter = DateFormat('h:mm a');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: isCustomer ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  msg.senderName,
                  style: SoamaTypography.labelSmall.copyWith(
                    color: colors.textTertiary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                if (msg.isSimulatedProvider) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: colors.textTertiary.withOpacity(0.15),
                      borderRadius: SoamaRadii.radiusPill,
                    ),
                    child: Text(
                      'Simulated Artisan',
                      style: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                Text(
                  timeFormatter.format(msg.timestamp),
                  style: SoamaTypography.labelSmall.copyWith(
                    color: colors.textTertiary.withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          // Message Body or Offer Card
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: isCustomer
                  ? (context.isDarkMode ? const Color(0xFF272D3B) : const Color(0xFFE4DFD5))
                  : (context.isDarkMode ? const Color(0xFF1B1E26) : colors.surface),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isCustomer ? 16 : 4),
                bottomRight: Radius.circular(isCustomer ? 4 : 16),
              ),
              border: Border.all(
                color: msg.isOffer ? colors.accent.withOpacity(0.5) : colors.glassBorder,
                width: msg.isOffer ? 1.2 : 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Offer Price Block (if offer)
                if (msg.isOffer) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Proposed Rate',
                        style: SoamaTypography.labelSmall.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                      _buildOfferStatusBadge(context, msg.offerStatus),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    msg.formattedPrice,
                    style: SoamaTypography.titleLarge.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],

                // Message Text
                if (msg.text.isNotEmpty)
                  Text(
                    msg.text,
                    style: SoamaTypography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                      height: 1.35,
                    ),
                  ),

                // Accept / Decline Buttons (only for pending provider offers)
                if (msg.isOffer &&
                    msg.offerStatus == OfferStatus.pending &&
                    msg.sender == OfferSender.provider &&
                    _request.negotiationStatus != NegotiationStatus.priceAgreed) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _declineOffer(msg),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent, width: 0.8),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusMd),
                          ),
                          child: const Text('Decline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _acceptOffer(msg),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.accent,
                            foregroundColor: colors.onAccent,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusMd),
                          ),
                          child: const Text('Accept', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferStatusBadge(BuildContext context, OfferStatus? status) {
    if (status == null) return const SizedBox.shrink();

    Color color;
    IconData icon;

    switch (status) {
      case OfferStatus.accepted:
        color = const Color(0xFF4ADE80);
        icon = Icons.check_circle_rounded;
        break;
      case OfferStatus.declined:
        color = const Color(0xFFF87171);
        icon = Icons.cancel_rounded;
        break;
      case OfferStatus.replaced:
        color = Colors.grey;
        icon = Icons.history_rounded;
        break;
      case OfferStatus.pending:
        color = const Color(0xFFFBBF24);
        icon = Icons.hourglass_empty_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: SoamaRadii.radiusPill,
        border: Border.all(color: color.withOpacity(0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulatingIndicator(BuildContext context) {
    final colors = context.soamaColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: colors.surfaceSubtle,
              borderRadius: SoamaRadii.radiusPill,
              border: Border.all(color: colors.glassBorder, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_request.providerName} is reviewing your offer...',
                  style: SoamaTypography.labelSmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;
    final isPriceAgreed = _request.negotiationStatus == NegotiationStatus.priceAgreed;
    final isCancelled = _request.negotiationStatus == NegotiationStatus.requestCancelled;

    if (isPriceAgreed) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 16.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13151A) : colors.surface,
          border: Border(top: BorderSide(color: colors.glassBorder, width: 1.0)),
        ),
        child: PrimaryButton(
          label: 'Continue to Booking (${_request.agreedPriceFormatted ?? _request.servicePrice})',
          size: ButtonSize.large,
          onPressed: () {
            HapticFeedback.lightImpact();
            final priceNaira = _request.agreedPrice ?? _request.servicePriceAmount;
            EscrowCheckoutSheet.show(
              context,
              bookingId: _request.id,
              serviceTitle: _request.serviceTitle,
              providerName: _request.providerName,
              amountMinorUnits: priceNaira * 100,
            );
          },
        ),
      );
    }

    if (isCancelled) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13151A) : colors.surface,
          border: Border(top: BorderSide(color: colors.glassBorder, width: 1.0)),
        ),
        child: Center(
          child: Text(
            'This negotiation request has been cancelled.',
            style: SoamaTypography.bodySmall.copyWith(color: Colors.redAccent),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13151A) : colors.surface,
        border: Border(top: BorderSide(color: colors.glassBorder, width: 1.0)),
      ),
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 14.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mode Toggle Row
          Row(
            children: [
              FilterChip(
                selected: _isProposingOffer,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isProposingOffer ? Icons.check_circle_rounded : Icons.payments_outlined,
                      size: 14,
                      color: _isProposingOffer ? colors.onAccent : colors.accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isProposingOffer ? 'Proposing Price' : 'Propose Price',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _isProposingOffer ? colors.onAccent : colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                backgroundColor: colors.surfaceSubtle,
                selectedColor: colors.accent,
                showCheckmark: false,
                onSelected: (val) {
                  HapticFeedback.selectionClick();
                  setState(() => _isProposingOffer = val);
                },
              ),
              const SizedBox(width: 8),
              if (_isProposingOffer)
                Text(
                  'Base: ${_request.servicePrice}',
                  style: SoamaTypography.labelSmall.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
            ],
          ),

          // Price Input (if proposing offer)
          if (_isProposingOffer) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: SoamaTypography.titleMedium.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                prefixText: '₦ ',
                prefixStyle: SoamaTypography.titleMedium.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w700,
                ),
                hintText: 'Enter offer amount',
                errorText: _priceError,
                errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
                filled: true,
                fillColor: colors.surfaceSubtle,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: SoamaRadii.radiusMd,
                  borderSide: BorderSide(color: colors.glassBorder, width: 0.8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: SoamaRadii.radiusMd,
                  borderSide: BorderSide(color: colors.accent, width: 1.5),
                ),
              ),
            ),
          ],

          const SizedBox(height: 6),

          // Message Input & Send Button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  maxLines: 2,
                  minLines: 1,
                  style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: _isProposingOffer ? 'Explain your proposed price (optional)...' : 'Type a message to the specialist...',
                    hintStyle: SoamaTypography.bodySmall.copyWith(color: colors.textTertiary),
                    filled: true,
                    fillColor: colors.surfaceSubtle,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: SoamaRadii.radiusLg,
                      borderSide: BorderSide(color: colors.glassBorder, width: 0.8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: SoamaRadii.radiusLg,
                      borderSide: BorderSide(color: colors.accent, width: 1.2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: colors.accent,
                borderRadius: SoamaRadii.radiusLg,
                child: InkWell(
                  onTap: _sendCustomerMessageOrOffer,
                  borderRadius: SoamaRadii.radiusLg,
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    child: Icon(
                      _isProposingOffer ? Icons.send_rounded : Icons.arrow_upward_rounded,
                      color: colors.onAccent,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
