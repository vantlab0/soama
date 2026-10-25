import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum ServiceDeliveryMode {
  onSiteVisit(
    'On-site visit at my location',
    'Artisan comes to your home, office, or site in Delta State',
    Icons.home_repair_service_rounded,
  ),
  visitProvider(
    'Visit artisan workshop',
    'Drop off equipment or visit provider’s workshop address',
    Icons.storefront_rounded,
  );

  final String title;
  final String description;
  final IconData icon;

  const ServiceDeliveryMode(this.title, this.description, this.icon);
}

enum OfferStatus {
  pending('Pending Decision'),
  accepted('Offer Accepted'),
  declined('Offer Declined'),
  replaced('Superseded');

  final String label;
  const OfferStatus(this.label);
}

enum OfferSender {
  customer('Customer (You)'),
  provider('Artisan Specialist');

  final String label;
  const OfferSender(this.label);
}

enum NegotiationStatus {
  awaitingResponse(
    'Awaiting Response',
    Color(0xFFFBBF24),
    Icons.hourglass_top_rounded,
  ),
  counterofferReceived(
    'Counteroffer Received',
    Color(0xFF38BDF8),
    Icons.swap_horiz_rounded,
  ),
  priceAgreed(
    'Price Agreed',
    Color(0xFF4ADE80),
    Icons.check_circle_rounded,
  ),
  requestCancelled(
    'Request Cancelled',
    Color(0xFFF87171),
    Icons.cancel_rounded,
  );

  final String label;
  final Color color;
  final IconData icon;

  const NegotiationStatus(this.label, this.color, this.icon);
}

class NegotiationMessage {
  final String id;
  final OfferSender sender;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final int? proposedPrice;
  final OfferStatus? offerStatus;
  final bool isSimulatedProvider;

  const NegotiationMessage({
    required this.id,
    required this.sender,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.proposedPrice,
    this.offerStatus,
    this.isSimulatedProvider = false,
  });

  bool get isOffer => proposedPrice != null;

  String get formattedPrice {
    if (proposedPrice == null) return '';
    return NumberFormat.currency(
      symbol: '₦',
      decimalDigits: 0,
    ).format(proposedPrice);
  }

  NegotiationMessage copyWith({
    OfferStatus? offerStatus,
    String? text,
  }) {
    return NegotiationMessage(
      id: id,
      sender: sender,
      senderName: senderName,
      text: text ?? this.text,
      timestamp: timestamp,
      proposedPrice: proposedPrice,
      offerStatus: offerStatus ?? this.offerStatus,
      isSimulatedProvider: isSimulatedProvider,
    );
  }

  factory NegotiationMessage.fromSupabase(Map<String, dynamic> map) {
    final role = map['sender_role'] as String? ?? 'customer';
    final isCustomer = role == 'customer';
    final amountMinor = map['amount_minor_units'] as num?;
    final amountMajor = amountMinor != null ? (amountMinor / 100).round() : null;

    final statusStr = map['status'] as String? ?? 'pending';
    OfferStatus status;
    switch (statusStr.toLowerCase()) {
      case 'accepted':
        status = OfferStatus.accepted;
        break;
      case 'rejected':
      case 'declined':
        status = OfferStatus.declined;
        break;
      case 'countered':
      case 'withdrawn':
      case 'expired':
        status = OfferStatus.replaced;
        break;
      default:
        status = OfferStatus.pending;
    }

    final createdAtStr = map['created_at'] as String?;
    final time = createdAtStr != null ? DateTime.tryParse(createdAtStr) ?? DateTime.now() : DateTime.now();

    return NegotiationMessage(
      id: map['id'] as String? ?? 'off-${DateTime.now().millisecondsSinceEpoch}',
      sender: isCustomer ? OfferSender.customer : OfferSender.provider,
      senderName: map['sender_name'] as String? ?? (isCustomer ? 'Customer' : 'Artisan Specialist'),
      text: map['message'] as String? ?? (amountMajor != null ? 'Proposed price offer of ₦$amountMajor' : 'Message'),
      timestamp: time,
      proposedPrice: amountMajor,
      offerStatus: status,
      isSimulatedProvider: false,
    );
  }
}

class ServiceRequest {
  final String id;
  final String providerId;
  final String providerName;
  final String providerProfession;
  final String providerAvatarUrl;
  final String serviceId;
  final String serviceTitle;
  final String servicePrice;
  final int servicePriceAmount;
  final String description;
  final List<String> photoAttachments;
  final String address;
  final String locationNote;
  final DateTime preferredDate;
  final String preferredTimeSlot;
  final ServiceDeliveryMode deliveryMode;
  final bool isEstimatedPrice;
  final DateTime createdAt;
  final String status;
  final NegotiationStatus negotiationStatus;
  final List<NegotiationMessage> negotiationMessages;
  final int? agreedPrice;

  const ServiceRequest({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.providerProfession,
    required this.providerAvatarUrl,
    required this.serviceId,
    required this.serviceTitle,
    required this.servicePrice,
    required this.servicePriceAmount,
    required this.description,
    this.photoAttachments = const [],
    required this.address,
    this.locationNote = '',
    required this.preferredDate,
    required this.preferredTimeSlot,
    required this.deliveryMode,
    this.isEstimatedPrice = true,
    required this.createdAt,
    this.status = 'Pending Provider Confirmation',
    this.negotiationStatus = NegotiationStatus.awaitingResponse,
    this.negotiationMessages = const [],
    this.agreedPrice,
  });

  String? get agreedPriceFormatted {
    if (agreedPrice == null) return null;
    return NumberFormat.currency(
      symbol: '₦',
      decimalDigits: 0,
    ).format(agreedPrice);
  }

  ServiceRequest copyWith({
    String? status,
    NegotiationStatus? negotiationStatus,
    List<NegotiationMessage>? negotiationMessages,
    int? agreedPrice,
  }) {
    return ServiceRequest(
      id: id,
      providerId: providerId,
      providerName: providerName,
      providerProfession: providerProfession,
      providerAvatarUrl: providerAvatarUrl,
      serviceId: serviceId,
      serviceTitle: serviceTitle,
      servicePrice: servicePrice,
      servicePriceAmount: servicePriceAmount,
      description: description,
      photoAttachments: photoAttachments,
      address: address,
      locationNote: locationNote,
      preferredDate: preferredDate,
      preferredTimeSlot: preferredTimeSlot,
      deliveryMode: deliveryMode,
      isEstimatedPrice: isEstimatedPrice,
      createdAt: createdAt,
      status: status ?? this.status,
      negotiationStatus: negotiationStatus ?? this.negotiationStatus,
      negotiationMessages: negotiationMessages ?? this.negotiationMessages,
      agreedPrice: agreedPrice ?? this.agreedPrice,
    );
  }

  factory ServiceRequest.fromSupabase(Map<String, dynamic> map) {
    final budgetMinor = (map['budget_amount_minor_units'] ?? map['budget_minor_units']) as num? ?? 0;
    final budgetMajor = (budgetMinor / 100).round();
    final formattedBudget = NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(budgetMajor);

    // Negotiation status mapping
    final negStatusStr = map['negotiation_status'] as String? ?? 'submitted';
    NegotiationStatus negStatus;
    String displayStatus;
    switch (negStatusStr.toLowerCase()) {
      case 'in_negotiation':
        negStatus = NegotiationStatus.counterofferReceived;
        displayStatus = 'Counteroffer Received';
        break;
      case 'offer_accepted':
      case 'booked':
        negStatus = NegotiationStatus.priceAgreed;
        displayStatus = 'Confirmed Appointment';
        break;
      case 'cancelled':
      case 'expired':
        negStatus = NegotiationStatus.requestCancelled;
        displayStatus = 'Request Cancelled';
        break;
      default:
        negStatus = NegotiationStatus.awaitingResponse;
        displayStatus = 'Pending Provider Confirmation';
    }

    // Delivery mode
    final delModeStr = map['delivery_mode'] as String? ?? 'at_customer_location';
    final deliveryMode = delModeStr == 'at_provider_workshop'
        ? ServiceDeliveryMode.visitProvider
        : ServiceDeliveryMode.onSiteVisit;

    // Negotiation offers / messages
    final rawOffers = map['price_offers'] as List<dynamic>? ?? [];
    final messages = rawOffers.map((o) => NegotiationMessage.fromSupabase(o as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    int? agreedAmount;
    for (final m in messages.reversed) {
      if (m.offerStatus == OfferStatus.accepted && m.proposedPrice != null) {
        agreedAmount = m.proposedPrice;
        break;
      }
    }

    // Provider details if recipient is joined
    String provId = 'pro-general';
    String provName = 'Verified Artisan Specialist';
    String provProfession = map['category_id'] as String? ?? 'Trade Specialist';
    String provAvatar = 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=400&q=80';

    final recipients = map['request_recipients'] as List<dynamic>? ?? [];
    if (recipients.isNotEmpty) {
      final rec = recipients.first as Map<String, dynamic>;
      provId = rec['provider_id'] as String? ?? provId;
      if (rec['provider_profiles'] != null) {
        final pp = rec['provider_profiles'] as Map<String, dynamic>;
        provName = pp['business_name'] as String? ?? provName;
      }
    }

    final scheduleStartStr = map['preferred_schedule_start'] as String?;
    final preferredDate = scheduleStartStr != null ? DateTime.tryParse(scheduleStartStr) ?? DateTime.now() : DateTime.now();

    final createdAtStr = map['created_at'] as String?;
    final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) ?? DateTime.now() : DateTime.now();

    return ServiceRequest(
      id: map['id'] as String? ?? 'req-${DateTime.now().millisecondsSinceEpoch}',
      providerId: provId,
      providerName: provName,
      providerProfession: provProfession,
      providerAvatarUrl: provAvatar,
      serviceId: map['category_id'] as String? ?? 'general',
      serviceTitle: map['title'] as String? ?? 'Service Request',
      servicePrice: formattedBudget,
      servicePriceAmount: budgetMajor,
      description: map['description'] as String? ?? '',
      photoAttachments: const [],
      address: map['exact_address'] as String? ?? map['location_area'] as String? ?? 'Warri, Delta State',
      locationNote: map['location_area'] as String? ?? '',
      preferredDate: preferredDate,
      preferredTimeSlot: 'Morning (8:00 AM – 12:00 PM)',
      deliveryMode: deliveryMode,
      isEstimatedPrice: true,
      createdAt: createdAt,
      status: displayStatus,
      negotiationStatus: negStatus,
      negotiationMessages: messages,
      agreedPrice: agreedAmount,
    );
  }

  static ServiceRequest? findById(String id) {
    try {
      return submittedRequests.firstWhere((r) => r.id == id);
    } catch (_) {
      return submittedRequests.isNotEmpty ? submittedRequests.first : null;
    }
  }

  bool get isPending =>
      !isCancelled &&
      !isCompleted &&
      (status == 'Pending Provider Confirmation' ||
          status.contains('Pending') ||
          negotiationStatus == NegotiationStatus.awaitingResponse ||
          negotiationStatus == NegotiationStatus.counterofferReceived ||
          negotiationStatus == NegotiationStatus.priceAgreed);

  bool get isOngoing =>
      !isCancelled &&
      !isCompleted &&
      (status == 'Confirmed Appointment' ||
          status == 'In Progress' ||
          status == 'Ongoing');

  bool get isCompleted => status == 'Completed';

  bool get isCancelled =>
      status == 'Request Cancelled' ||
      status == 'Cancelled' ||
      negotiationStatus == NegotiationStatus.requestCancelled;

  /// In-memory repository of submitted service requests for the active session
  static final List<ServiceRequest> submittedRequests = _createInitialRequests();

  static void reset() {
    submittedRequests
      ..clear()
      ..addAll(_createInitialRequests());
  }

  static List<ServiceRequest> _createInitialRequests() => [
    // 1. Pending / Negotiation record
    ServiceRequest(
      id: 'SOA-2084',
      providerId: 'pro-warri-1',
      providerName: 'Ochuko Efe',
      providerProfession: 'Piping & Water Pump Specialist',
      providerAvatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
      serviceId: 'srv-plumb-1',
      serviceTitle: 'Emergency Pipe Leak Repair',
      servicePrice: '₦8,500',
      servicePriceAmount: 8500,
      description: 'Main kitchen cold water inlet pipe burst, need immediate coupling replacement and isolation valve check.',
      address: '14 Airport Road, Effurun, Warri',
      preferredDate: DateTime.now().add(const Duration(days: 1)),
      preferredTimeSlot: 'Morning (8:00 AM – 12:00 PM)',
      deliveryMode: ServiceDeliveryMode.onSiteVisit,
      isEstimatedPrice: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      status: 'Pending Provider Confirmation',
      negotiationStatus: NegotiationStatus.counterofferReceived,
      negotiationMessages: [
        NegotiationMessage(
          id: 'msg-plumb-1',
          sender: OfferSender.customer,
          senderName: 'You',
          text: 'Good day Ochuko, could we negotiate ₦7,500 for the kitchen pipe repair?',
          timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
          proposedPrice: 7500,
          offerStatus: OfferStatus.replaced,
        ),
        NegotiationMessage(
          id: 'msg-plumb-2',
          sender: OfferSender.provider,
          senderName: 'Ochuko Efe (Artisan)',
          text: 'Hello! I can do ₦8,000 including high-pressure solvent cement and PVC fittings. Let me know if that works.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
          proposedPrice: 8000,
          offerStatus: OfferStatus.pending,
          isSimulatedProvider: true,
        ),
      ],
    ),

    // 2. Ongoing / Confirmed appointment record
    ServiceRequest(
      id: 'SOA-3091',
      providerId: 'pro-warri-3',
      providerName: 'Tunde Adeleke',
      providerProfession: 'Industrial & Domestic Generator Technician',
      providerAvatarUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=400&q=80',
      serviceId: 'srv-gen-1',
      serviceTitle: 'Routine Servicing (Oil & Filters)',
      servicePrice: '₦18,000',
      servicePriceAmount: 18000,
      agreedPrice: 16500,
      description: 'Mikano 20kVA Generator Maintenance: Oil filter replacement and diesel injector cleaning before weekend runs.',
      address: 'Plot 4, Effurun Roundabout, Warri',
      preferredDate: DateTime.now().add(const Duration(days: 2)),
      preferredTimeSlot: '10:00 AM – 12:00 PM',
      deliveryMode: ServiceDeliveryMode.onSiteVisit,
      isEstimatedPrice: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      status: 'Confirmed Appointment',
      negotiationStatus: NegotiationStatus.priceAgreed,
    ),

    // 3. Completed record
    ServiceRequest(
      id: 'SOA-1042',
      providerId: 'pro-warri-2',
      providerName: 'Blessing Igbinoba',
      providerProfession: 'Deep Cleaning & Post-Construction Specialist',
      providerAvatarUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=400&q=80',
      serviceId: 'srv-clean-1',
      serviceTitle: 'Deep Home Sanitization (3-Bed Flat)',
      servicePrice: '₦14,000',
      servicePriceAmount: 14000,
      agreedPrice: 14000,
      description: 'Complete 3-bedroom flat sanitization, tile descaling, and kitchen degreasing in GRA.',
      address: '22 Airport Road, GRA Phase 2, Warri',
      preferredDate: DateTime.now().subtract(const Duration(days: 2)),
      preferredTimeSlot: 'Morning (8:00 AM – 12:00 PM)',
      deliveryMode: ServiceDeliveryMode.onSiteVisit,
      isEstimatedPrice: false,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      status: 'Completed',
      negotiationStatus: NegotiationStatus.priceAgreed,
    ),

    // 4. Seed incoming request for user's provider profile
    ServiceRequest(
      id: 'SOA-PRO-401',
      providerId: 'pro-current-user',
      providerName: 'Adams Precision Electro-Works',
      providerProfession: 'Certified Electrician & Inverter Specialist',
      providerAvatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
      serviceId: 'pro-srv-1',
      serviceTitle: 'Emergency Electrical Diagnostics & Fuse Repair',
      servicePrice: '₦7,500',
      servicePriceAmount: 7500,
      description: 'Distribution box tripped and smell of burning wire near AC breaker. Need urgent inspection.',
      address: '7 Refinery Road, Ekpan, Warri',
      preferredDate: DateTime.now().add(const Duration(days: 1)),
      preferredTimeSlot: 'Morning (8:00 AM – 12:00 PM)',
      deliveryMode: ServiceDeliveryMode.onSiteVisit,
      isEstimatedPrice: true,
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      status: 'Pending Provider Confirmation',
      negotiationStatus: NegotiationStatus.awaitingResponse,
      negotiationMessages: [
        NegotiationMessage(
          id: 'msg-usr-pro-1',
          sender: OfferSender.customer,
          senderName: 'Chioma Nnamdi',
          text: 'Good day, please I have a critical breaker tripping issue at my salon. Can you inspect today?',
          timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
          proposedPrice: 7500,
          offerStatus: OfferStatus.pending,
        ),
      ],
    ),
  ];

  static List<ServiceRequest> getRequestsForProvider(String? providerId) {
    if (providerId == null || providerId.isEmpty) {
      return submittedRequests;
    }
    final matched = submittedRequests.where((r) => r.providerId == providerId).toList();
    if (matched.isNotEmpty) return matched;
    // If no direct matches yet, return all submitted requests so provider can manage marketplace requests
    return submittedRequests;
  }

  static void sendProviderCounteroffer({
    required String requestId,
    required int counterPrice,
    required String messageText,
    String providerName = 'Adams Electro-Works (You)',
  }) {
    final idx = submittedRequests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      final req = submittedRequests[idx];
      final newMsg = NegotiationMessage(
        id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
        sender: OfferSender.provider,
        senderName: providerName,
        text: messageText,
        timestamp: DateTime.now(),
        proposedPrice: counterPrice,
        offerStatus: OfferStatus.pending,
      );
      final updatedMsgs = req.negotiationMessages.map((m) {
        if (m.offerStatus == OfferStatus.pending) {
          return m.copyWith(offerStatus: OfferStatus.replaced);
        }
        return m;
      }).toList()..add(newMsg);

      submittedRequests[idx] = req.copyWith(
        negotiationStatus: NegotiationStatus.counterofferReceived,
        negotiationMessages: updatedMsgs,
      );
    }
  }

  static void acceptCustomerOffer(String requestId) {
    final idx = submittedRequests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      final req = submittedRequests[idx];
      int agreed = req.servicePriceAmount;
      for (final m in req.negotiationMessages.reversed) {
        if (m.proposedPrice != null) {
          agreed = m.proposedPrice!;
          break;
        }
      }
      final updatedMsgs = req.negotiationMessages.map((m) {
        if (m.proposedPrice != null) {
          return m.copyWith(offerStatus: OfferStatus.accepted);
        }
        return m;
      }).toList();

      submittedRequests[idx] = req.copyWith(
        agreedPrice: agreed,
        status: 'Confirmed Appointment',
        negotiationStatus: NegotiationStatus.priceAgreed,
        negotiationMessages: updatedMsgs,
      );
    }
  }

  static void updateJobStatus(String requestId, String newStatus) {
    final idx = submittedRequests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      submittedRequests[idx] = submittedRequests[idx].copyWith(status: newStatus);
    }
  }

  static void declineRequest(String requestId) {
    final idx = submittedRequests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      submittedRequests[idx] = submittedRequests[idx].copyWith(
        status: 'Request Cancelled',
        negotiationStatus: NegotiationStatus.requestCancelled,
      );
    }
  }
}

