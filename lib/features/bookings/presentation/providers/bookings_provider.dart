import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/supabase_config.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/models/booking.dart';
import '../../../../shared/models/user_account.dart';
import '../../data/bookings_repository.dart';
import '../../data/payments_repository.dart';

final inMemoryPaymentsInstance = InMemoryPaymentsRepository();

/// Provider exposing the active PaymentsRepository implementation.
final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  final client = SupabaseService.client;
  if (client != null && SupabaseConfig.isConfigured) {
    return SupabasePaymentsRepository(client);
  }
  return inMemoryPaymentsInstance;
});

/// Provider exposing the active BookingsRepository implementation.
final bookingsRepositoryProvider = Provider<BookingsRepository>((ref) {
  final client = SupabaseService.client;
  if (client != null && SupabaseConfig.isConfigured) {
    return SupabaseBookingsRepository(client);
  }
  return InMemoryBookingsRepository();
});

/// Provider for customer's bookings list.
final customerBookingsProvider = FutureProvider.autoDispose<List<Booking>>((ref) async {
  final repo = ref.watch(bookingsRepositoryProvider);
  final customerId = UserAccount.current.id;
  return repo.getCustomerBookings(customerId, forceRefresh: true);
});

/// Provider for provider's assigned jobs list.
final providerJobsProvider = FutureProvider.autoDispose<List<Booking>>((ref) async {
  final repo = ref.watch(bookingsRepositoryProvider);
  final account = UserAccount.current;
  final providerId = account.providerProfile?.providerId ?? account.id;
  return repo.getProviderJobs(providerId, forceRefresh: true);
});

/// Provider for single booking details.
final bookingDetailsProvider = FutureProvider.autoDispose.family<Booking?, String>((ref, bookingId) async {
  final repo = ref.watch(bookingsRepositoryProvider);
  return repo.getBookingById(bookingId, forceRefresh: true);
});
