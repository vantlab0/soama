import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/supabase_config.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/models/service_provider.dart';
import '../../data/reviews_repository.dart';

/// Provider exposing the active ReviewsRepository instance.
final reviewsRepositoryProvider = Provider<ReviewsRepository>((ref) {
  final client = SupabaseService.client;
  if (client != null && SupabaseConfig.isConfigured) {
    return SupabaseReviewsRepository(client);
  }
  return InMemoryReviewsRepository();
});

/// FutureProvider fetching public verified reviews for a specific provider.
final providerReviewsProvider =
    FutureProvider.family<List<ProviderReview>, String>((ref, providerId) async {
  final repo = ref.watch(reviewsRepositoryProvider);
  return repo.getProviderReviews(providerId);
});

/// FutureProvider fetching the existing review for a specific booking (if any).
final bookingReviewProvider =
    FutureProvider.family<ProviderReview?, String>((ref, bookingId) async {
  final repo = ref.watch(reviewsRepositoryProvider);
  return repo.getBookingReview(bookingId);
});
