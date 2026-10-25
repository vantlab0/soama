import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'service_request.dart';

enum BookingJobStatus {
  pendingConfirmation('Pending Confirmation', Color(0xFFFBBF24)),
  confirmed('Confirmed Appointment', Color(0xFF38BDF8)),
  inProgress('Job In Progress', Color(0xFF7C3AED)),
  completed('Completed', Color(0xFF4ADE80)),
  cancelledByCustomer('Cancelled by Customer', Color(0xFFF87171)),
  cancelledByProvider('Cancelled by Provider', Color(0xFFF87171)),
  disputed('In Dispute', Color(0xFFEF4444));

  final String label;
  final Color color;
  const BookingJobStatus(this.label, this.color);

  static BookingJobStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'confirmed':
        return BookingJobStatus.confirmed;
      case 'in_progress':
      case 'specialist arrived':
      case 'job in progress':
        return BookingJobStatus.inProgress;
      case 'completed':
        return BookingJobStatus.completed;
      case 'cancelled_by_customer':
        return BookingJobStatus.cancelledByCustomer;
      case 'cancelled_by_provider':
        return BookingJobStatus.cancelledByProvider;
      case 'disputed':
        return BookingJobStatus.disputed;
      case 'pending_confirmation':
      default:
        return BookingJobStatus.pendingConfirmation;
    }
  }

  String toDbString() {
    switch (this) {
      case BookingJobStatus.confirmed:
        return 'confirmed';
      case BookingJobStatus.inProgress:
        return 'in_progress';
      case BookingJobStatus.completed:
        return 'completed';
      case BookingJobStatus.cancelledByCustomer:
        return 'cancelled_by_customer';
      case BookingJobStatus.cancelledByProvider:
        return 'cancelled_by_provider';
      case BookingJobStatus.disputed:
        return 'disputed';
      case BookingJobStatus.pendingConfirmation:
        return 'pending_confirmation';
    }
  }
}

enum BookingEscrowStatus {
  awaitingPayment('Awaiting Payment'),
  funded('Escrow Funded'),
  released('Escrow Released'),
  refunded('Refunded'),
  disputed('In Dispute');

  final String label;
  const BookingEscrowStatus(this.label);

  static BookingEscrowStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'funded':
        return BookingEscrowStatus.funded;
      case 'released':
        return BookingEscrowStatus.released;
      case 'refunded':
        return BookingEscrowStatus.refunded;
      case 'disputed':
        return BookingEscrowStatus.disputed;
      case 'awaiting_payment':
      default:
        return BookingEscrowStatus.awaitingPayment;
    }
  }
}

class Booking {
  final String id;
  final String bookingReference;
  final String requestId;
  final String acceptedOfferId;
  final String customerId;
  final String providerId;
  final String serviceTitle;
  final int agreedPriceMinorUnits;
  final String currency;
  final DateTime scheduledStart;
  final DateTime? scheduledEnd;
  final String jobAddress;
  final BookingJobStatus jobStatus;
  final BookingEscrowStatus escrowStatus;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final DateTime createdAt;

  // Joined metadata for UI presentation
  final String providerName;
  final String providerProfession;
  final String providerAvatarUrl;
  final String customerName;
  final String customerPhone;

  const Booking({
    required this.id,
    required this.bookingReference,
    required this.requestId,
    required this.acceptedOfferId,
    required this.customerId,
    required this.providerId,
    required this.serviceTitle,
    required this.agreedPriceMinorUnits,
    this.currency = 'NGN',
    required this.scheduledStart,
    this.scheduledEnd,
    required this.jobAddress,
    this.jobStatus = BookingJobStatus.confirmed,
    this.escrowStatus = BookingEscrowStatus.awaitingPayment,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    required this.createdAt,
    this.providerName = 'Verified Artisan',
    this.providerProfession = 'Trade Specialist',
    this.providerAvatarUrl = 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=400&q=80',
    this.customerName = 'Customer',
    this.customerPhone = '',
  });

  int get agreedPriceNaira => (agreedPriceMinorUnits / 100).round();

  String get agreedPriceFormatted => NumberFormat.currency(
        symbol: '₦',
        decimalDigits: 0,
      ).format(agreedPriceNaira);

  bool get isPendingConfirmation => jobStatus == BookingJobStatus.pendingConfirmation;
  bool get isConfirmed => jobStatus == BookingJobStatus.confirmed;
  bool get isUpcoming => isConfirmed || isPendingConfirmation;
  bool get isInProgress => jobStatus == BookingJobStatus.inProgress;
  bool get isOngoing => isUpcoming || isInProgress;
  bool get isCompleted => jobStatus == BookingJobStatus.completed;
  bool get isCancelled =>
      jobStatus == BookingJobStatus.cancelledByCustomer ||
      jobStatus == BookingJobStatus.cancelledByProvider;

  Booking copyWith({
    String? id,
    String? bookingReference,
    String? requestId,
    String? acceptedOfferId,
    String? customerId,
    String? providerId,
    String? serviceTitle,
    int? agreedPriceMinorUnits,
    String? currency,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    String? jobAddress,
    BookingJobStatus? jobStatus,
    BookingEscrowStatus? escrowStatus,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    DateTime? createdAt,
    String? providerName,
    String? providerProfession,
    String? providerAvatarUrl,
    String? customerName,
    String? customerPhone,
  }) {
    return Booking(
      id: id ?? this.id,
      bookingReference: bookingReference ?? this.bookingReference,
      requestId: requestId ?? this.requestId,
      acceptedOfferId: acceptedOfferId ?? this.acceptedOfferId,
      customerId: customerId ?? this.customerId,
      providerId: providerId ?? this.providerId,
      serviceTitle: serviceTitle ?? this.serviceTitle,
      agreedPriceMinorUnits: agreedPriceMinorUnits ?? this.agreedPriceMinorUnits,
      currency: currency ?? this.currency,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
      jobAddress: jobAddress ?? this.jobAddress,
      jobStatus: jobStatus ?? this.jobStatus,
      escrowStatus: escrowStatus ?? this.escrowStatus,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      createdAt: createdAt ?? this.createdAt,
      providerName: providerName ?? this.providerName,
      providerProfession: providerProfession ?? this.providerProfession,
      providerAvatarUrl: providerAvatarUrl ?? this.providerAvatarUrl,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
    );
  }

  /// Converts a [Booking] into a [ServiceRequest] so existing booking screens
  /// and card components can render real bookings without duplicating UI code.
  ServiceRequest toServiceRequest() {
    String displayStatus;
    NegotiationStatus negStatus;

    if (isCompleted) {
      displayStatus = 'Completed';
      negStatus = NegotiationStatus.priceAgreed;
    } else if (isInProgress) {
      displayStatus = 'Job In Progress';
      negStatus = NegotiationStatus.priceAgreed;
    } else if (isCancelled) {
      displayStatus = 'Request Cancelled';
      negStatus = NegotiationStatus.requestCancelled;
    } else if (isConfirmed) {
      displayStatus = 'Confirmed Appointment';
      negStatus = NegotiationStatus.priceAgreed;
    } else {
      displayStatus = 'Pending Provider Confirmation';
      negStatus = NegotiationStatus.awaitingResponse;
    }

    return ServiceRequest(
      id: id,
      providerId: providerId,
      providerName: providerName,
      providerProfession: providerProfession,
      providerAvatarUrl: providerAvatarUrl,
      serviceId: requestId,
      serviceTitle: serviceTitle,
      servicePrice: agreedPriceFormatted,
      servicePriceAmount: agreedPriceNaira,
      description: 'Booking Ref: $bookingReference',
      address: jobAddress,
      preferredDate: scheduledStart,
      preferredTimeSlot: DateFormat('h:mm a').format(scheduledStart),
      deliveryMode: ServiceDeliveryMode.onSiteVisit,
      createdAt: createdAt,
      status: displayStatus,
      negotiationStatus: negStatus,
      agreedPrice: agreedPriceNaira,
    );
  }

  factory Booking.fromSupabase(Map<String, dynamic> map) {
    final startStr = map['scheduled_start'] as String?;
    final start = startStr != null ? DateTime.tryParse(startStr) ?? DateTime.now() : DateTime.now();

    final endStr = map['scheduled_end'] as String?;
    final end = endStr != null ? DateTime.tryParse(endStr) : null;

    final startedStr = map['started_at'] as String?;
    final started = startedStr != null ? DateTime.tryParse(startedStr) : null;

    final completedStr = map['completed_at'] as String?;
    final completed = completedStr != null ? DateTime.tryParse(completedStr) : null;

    final cancelledStr = map['cancelled_at'] as String?;
    final cancelled = cancelledStr != null ? DateTime.tryParse(cancelledStr) : null;

    final createdStr = map['created_at'] as String?;
    final created = createdStr != null ? DateTime.tryParse(createdStr) ?? DateTime.now() : DateTime.now();

    // Provider details if joined
    String provName = 'Verified Artisan';
    String provProfession = 'Trade Specialist';
    String provAvatar = 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=400&q=80';

    if (map['provider_profiles'] != null) {
      final pp = map['provider_profiles'] as Map<String, dynamic>;
      provName = pp['business_name'] as String? ?? provName;
      provProfession = pp['profession'] as String? ?? provProfession;
      if (pp['profiles'] != null) {
        final prof = pp['profiles'] as Map<String, dynamic>;
        provAvatar = prof['avatar_url'] as String? ?? provAvatar;
      }
    }

    // Customer details if joined
    String custName = 'Customer';
    String custPhone = '';
    if (map['profiles'] != null) {
      final prof = map['profiles'] as Map<String, dynamic>;
      custName = prof['full_name'] as String? ?? custName;
      custPhone = prof['phone'] as String? ?? custPhone;
    }

    final priceMinor = (map['agreed_price_minor_units'] as num?)?.toInt() ?? 0;

    return Booking(
      id: map['id'] as String? ?? '',
      bookingReference: map['booking_reference'] as String? ?? 'BK-${DateTime.now().millisecondsSinceEpoch}',
      requestId: map['request_id'] as String? ?? '',
      acceptedOfferId: map['accepted_offer_id'] as String? ?? '',
      customerId: map['customer_id'] as String? ?? '',
      providerId: map['provider_id'] as String? ?? '',
      serviceTitle: map['service_title'] as String? ?? 'Service Booking',
      agreedPriceMinorUnits: priceMinor,
      currency: map['currency'] as String? ?? 'NGN',
      scheduledStart: start,
      scheduledEnd: end,
      jobAddress: map['job_address'] as String? ?? 'Warri, Delta State',
      jobStatus: BookingJobStatus.fromString(map['job_status'] as String?),
      escrowStatus: BookingEscrowStatus.fromString(map['escrow_status'] as String?),
      startedAt: started,
      completedAt: completed,
      cancelledAt: cancelled,
      cancellationReason: map['cancellation_reason'] as String?,
      createdAt: created,
      providerName: provName,
      providerProfession: provProfession,
      providerAvatarUrl: provAvatar,
      customerName: custName,
      customerPhone: custPhone,
    );
  }
}
