import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_config.dart';
import '../../../shared/models/booking.dart';
import '../../../shared/models/service_request.dart';
import '../../../shared/models/user_account.dart';

abstract class BookingsRepository {
  Future<List<Booking>> getCustomerBookings(String customerId, {bool forceRefresh = false});
  Future<List<Booking>> getProviderJobs(String providerId, {bool forceRefresh = false});
  Future<Booking?> getBookingById(String bookingId, {bool forceRefresh = false});
  Future<bool> updateJobStatus({
    required String bookingId,
    required BookingJobStatus newStatus,
    String? reason,
  });
  Future<bool> startJob({required String bookingId});
  Future<bool> completeJob({required String bookingId});
  Future<bool> cancelBooking({required String bookingId, required String reason});
}

class SupabaseBookingsRepository implements BookingsRepository {
  final SupabaseClient _client;
  final InMemoryBookingsRepository _fallback = InMemoryBookingsRepository();

  SupabaseBookingsRepository(this._client);

  @override
  Future<List<Booking>> getCustomerBookings(String customerId, {bool forceRefresh = false}) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return await _fallback.getCustomerBookings(customerId, forceRefresh: forceRefresh);
    }

    try {
      final data = await _client
          .from(SupabaseConfig.tableBookings)
          .select('''
            *,
            ${SupabaseConfig.tableProviderProfiles}(
              business_name,
              profession,
              ${SupabaseConfig.tableProfiles}(avatar_url)
            )
          ''')
          .eq('customer_id', customerId)
          .order('scheduled_start', ascending: false);

      final rows = data as List<dynamic>;
      final list = rows.map((r) => Booking.fromSupabase(r as Map<String, dynamic>)).toList();
      if (list.isNotEmpty) {
        return list;
      }
      return await _fallback.getCustomerBookings(customerId);
    } catch (e) {
      debugPrint('ℹ️ [SupabaseBookingsRepository] getCustomerBookings error ($e). Using fallback.');
      return await _fallback.getCustomerBookings(customerId);
    }
  }

  @override
  Future<List<Booking>> getProviderJobs(String providerId, {bool forceRefresh = false}) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return await _fallback.getProviderJobs(providerId, forceRefresh: forceRefresh);
    }

    try {
      final data = await _client
          .from(SupabaseConfig.tableBookings)
          .select('''
            *,
            ${SupabaseConfig.tableProfiles}!bookings_customer_id_fkey(
              full_name,
              phone,
              avatar_url
            )
          ''')
          .eq('provider_id', providerId)
          .order('scheduled_start', ascending: false);

      final rows = data as List<dynamic>;
      final list = rows.map((r) => Booking.fromSupabase(r as Map<String, dynamic>)).toList();
      if (list.isNotEmpty) {
        return list;
      }
      return await _fallback.getProviderJobs(providerId);
    } catch (e) {
      debugPrint('ℹ️ [SupabaseBookingsRepository] getProviderJobs error ($e). Using fallback.');
      return await _fallback.getProviderJobs(providerId);
    }
  }

  @override
  Future<Booking?> getBookingById(String bookingId, {bool forceRefresh = false}) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return await _fallback.getBookingById(bookingId, forceRefresh: forceRefresh);
    }

    try {
      final data = await _client
          .from(SupabaseConfig.tableBookings)
          .select('''
            *,
            ${SupabaseConfig.tableProviderProfiles}(
              business_name,
              profession,
              ${SupabaseConfig.tableProfiles}(avatar_url)
            ),
            ${SupabaseConfig.tableProfiles}!bookings_customer_id_fkey(
              full_name,
              phone
            )
          ''')
          .eq('id', bookingId)
          .maybeSingle();

      if (data != null) {
        return Booking.fromSupabase(data);
      }
      return await _fallback.getBookingById(bookingId);
    } catch (e) {
      debugPrint('ℹ️ [SupabaseBookingsRepository] getBookingById error ($e). Using fallback.');
      return await _fallback.getBookingById(bookingId);
    }
  }

  @override
  Future<bool> updateJobStatus({
    required String bookingId,
    required BookingJobStatus newStatus,
    String? reason,
  }) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return await _fallback.updateJobStatus(
        bookingId: bookingId,
        newStatus: newStatus,
        reason: reason,
      );
    }

    try {
      await _client.rpc(
        SupabaseConfig.rpcUpdateBookingJobStatus,
        params: {
          'p_booking_id': bookingId,
          'p_new_status': newStatus.toDbString(),
          'p_reason': reason,
        },
      );
      _fallback.updateStatusLocally(bookingId, newStatus, reason: reason);
      return true;
    } catch (e) {
      debugPrint('ℹ️ [SupabaseBookingsRepository] updateJobStatus failed ($e). Using fallback.');
      return await _fallback.updateJobStatus(
        bookingId: bookingId,
        newStatus: newStatus,
        reason: reason,
      );
    }
  }

  @override
  Future<bool> startJob({required String bookingId}) async {
    return updateJobStatus(
      bookingId: bookingId,
      newStatus: BookingJobStatus.inProgress,
    );
  }

  @override
  Future<bool> completeJob({required String bookingId}) async {
    return updateJobStatus(
      bookingId: bookingId,
      newStatus: BookingJobStatus.completed,
    );
  }

  @override
  Future<bool> cancelBooking({required String bookingId, required String reason}) async {
    final isCustomer = UserAccount.current.currentMode == AppMode.customer;
    final cancelStatus = isCustomer
        ? BookingJobStatus.cancelledByCustomer
        : BookingJobStatus.cancelledByProvider;

    return updateJobStatus(
      bookingId: bookingId,
      newStatus: cancelStatus,
      reason: reason,
    );
  }
}

/// In-memory repository for unit tests, offline development, and fallback simulation.
class InMemoryBookingsRepository implements BookingsRepository {
  final List<Booking> _bookings = [];

  InMemoryBookingsRepository() {
    _seedDefaults();
  }

  void _seedDefaults() {
    _bookings.clear();
    // Seed initial bookings matching confirmed/ongoing/completed requests
    _bookings.addAll([
      Booking(
        id: 'SOA-3091',
        bookingReference: 'BK-20261025-3091',
        requestId: 'SOA-3091',
        acceptedOfferId: 'off-3091',
        customerId: 'usr-warri-01',
        providerId: 'pro-warri-3',
        serviceTitle: 'Routine Servicing (Oil & Filters)',
        agreedPriceMinorUnits: 1650000,
        currency: 'NGN',
        scheduledStart: DateTime.now().add(const Duration(days: 2)),
        jobAddress: 'Plot 4, Effurun Roundabout, Warri',
        jobStatus: BookingJobStatus.confirmed,
        escrowStatus: BookingEscrowStatus.awaitingPayment,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        providerName: 'Tunde Adeleke',
        providerProfession: 'Industrial & Domestic Generator Technician',
        providerAvatarUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=400&q=80',
        customerName: 'You',
      ),
      Booking(
        id: 'SOA-1042',
        bookingReference: 'BK-20261023-1042',
        requestId: 'SOA-1042',
        acceptedOfferId: 'off-1042',
        customerId: 'usr-warri-01',
        providerId: 'pro-warri-2',
        serviceTitle: 'Deep Home Sanitization (3-Bed Flat)',
        agreedPriceMinorUnits: 1400000,
        currency: 'NGN',
        scheduledStart: DateTime.now().subtract(const Duration(days: 2)),
        jobAddress: '22 Airport Road, GRA Phase 2, Warri',
        jobStatus: BookingJobStatus.completed,
        escrowStatus: BookingEscrowStatus.released,
        completedAt: DateTime.now().subtract(const Duration(days: 1)),
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        providerName: 'Blessing Igbinoba',
        providerProfession: 'Deep Cleaning & Post-Construction Specialist',
        providerAvatarUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=400&q=80',
        customerName: 'You',
      ),
      Booking(
        id: 'SOA-JOB-SEED-01',
        bookingReference: 'BK-20261025-401',
        requestId: 'SOA-PRO-401',
        acceptedOfferId: 'off-pro-401',
        customerId: 'usr-customer-99',
        providerId: 'pro-current-user',
        serviceTitle: 'Emergency Electrical Diagnostics & Fuse Repair',
        agreedPriceMinorUnits: 750000,
        currency: 'NGN',
        scheduledStart: DateTime.now().add(const Duration(days: 1)),
        jobAddress: '7 Refinery Road, Ekpan, Warri',
        jobStatus: BookingJobStatus.confirmed,
        escrowStatus: BookingEscrowStatus.awaitingPayment,
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        providerName: 'Adams Precision Electro-Works',
        providerProfession: 'Certified Electrician & Inverter Specialist',
        customerName: 'Chioma Nnamdi',
        customerPhone: '+234 803 123 4567',
      ),
    ]);
  }

  void reset() {
    _seedDefaults();
  }

  @override
  Future<List<Booking>> getCustomerBookings(String customerId, {bool forceRefresh = false}) async {
    return List.unmodifiable(_bookings);
  }

  @override
  Future<List<Booking>> getProviderJobs(String providerId, {bool forceRefresh = false}) async {
    final matched = _bookings.where((b) => b.providerId == providerId).toList();
    if (matched.isNotEmpty) return matched;
    return List.unmodifiable(_bookings);
  }

  @override
  Future<Booking?> getBookingById(String bookingId, {bool forceRefresh = false}) async {
    try {
      return _bookings.firstWhere((b) => b.id == bookingId);
    } catch (_) {
      return _bookings.isNotEmpty ? _bookings.first : null;
    }
  }

  @override
  Future<bool> updateJobStatus({
    required String bookingId,
    required BookingJobStatus newStatus,
    String? reason,
  }) async {
    final idx = _bookings.indexWhere((b) => b.id == bookingId);
    if (idx != -1) {
      final current = _bookings[idx];
      final updated = current.copyWith(
        jobStatus: newStatus,
        startedAt: newStatus == BookingJobStatus.inProgress ? DateTime.now() : current.startedAt,
        completedAt: newStatus == BookingJobStatus.completed ? DateTime.now() : current.completedAt,
        cancelledAt: (newStatus == BookingJobStatus.cancelledByCustomer ||
                newStatus == BookingJobStatus.cancelledByProvider)
            ? DateTime.now()
            : current.cancelledAt,
        cancellationReason: reason ?? current.cancellationReason,
      );
      _bookings[idx] = updated;

      // Sync local ServiceRequest static list
      String requestStatus = 'Confirmed Appointment';
      if (newStatus == BookingJobStatus.inProgress) {
        requestStatus = 'Job In Progress';
      } else if (newStatus == BookingJobStatus.completed) {
        requestStatus = 'Completed';
      } else if (newStatus == BookingJobStatus.cancelledByCustomer ||
          newStatus == BookingJobStatus.cancelledByProvider) {
        requestStatus = 'Request Cancelled';
      }
      ServiceRequest.updateJobStatus(current.requestId, requestStatus);
      ServiceRequest.updateJobStatus(bookingId, requestStatus);

      return true;
    }
    return false;
  }

  @override
  Future<bool> startJob({required String bookingId}) async {
    return updateJobStatus(
      bookingId: bookingId,
      newStatus: BookingJobStatus.inProgress,
    );
  }

  @override
  Future<bool> completeJob({required String bookingId}) async {
    return updateJobStatus(
      bookingId: bookingId,
      newStatus: BookingJobStatus.completed,
    );
  }

  @override
  Future<bool> cancelBooking({required String bookingId, required String reason}) async {
    final isCustomer = UserAccount.current.currentMode == AppMode.customer;
    return updateJobStatus(
      bookingId: bookingId,
      newStatus: isCustomer
          ? BookingJobStatus.cancelledByCustomer
          : BookingJobStatus.cancelledByProvider,
      reason: reason,
    );
  }

  void updateStatusLocally(String bookingId, BookingJobStatus status, {String? reason}) {
    updateJobStatus(bookingId: bookingId, newStatus: status, reason: reason);
  }
}
