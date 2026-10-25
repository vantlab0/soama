import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_config.dart';
import '../../../shared/models/service_provider.dart';

abstract class ReviewsRepository {
  Future<List<ProviderReview>> getProviderReviews(String providerId, {bool forceRefresh = false});
  Future<ProviderReview?> getBookingReview(String bookingId);
  Future<ProviderReview> submitBookingReview({
    required String bookingId,
    required int rating,
    String? comment,
  });
  Future<bool> replyToReview({
    required String reviewId,
    required String reply,
  });
}

class SupabaseReviewsRepository implements ReviewsRepository {
  final SupabaseClient _client;
  final InMemoryReviewsRepository _fallback = InMemoryReviewsRepository();

  SupabaseReviewsRepository(this._client);

  @override
  Future<List<ProviderReview>> getProviderReviews(String providerId, {bool forceRefresh = false}) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return await _fallback.getProviderReviews(providerId, forceRefresh: forceRefresh);
    }

    try {
      final data = await _client.rpc(
        SupabaseConfig.rpcGetProviderReviews,
        params: {'p_provider_id': providerId},
      );

      final rows = data as List<dynamic>;
      final list = rows.map((r) => ProviderReview.fromSupabase(r as Map<String, dynamic>)).toList();
      return list;
    } catch (e) {
      debugPrint('ℹ️ [SupabaseReviewsRepository] getProviderReviews RPC failed ($e). Attempting direct select.');
      try {
        final data = await _client
            .from(SupabaseConfig.tableReviews)
            .select('''
              id,
              booking_id,
              customer_id,
              provider_id,
              rating,
              comment,
              provider_reply,
              provider_reply_at,
              created_at,
              ${SupabaseConfig.tableProfiles}(full_name, avatar_url)
            ''')
            .eq('provider_id', providerId)
            .order('created_at', ascending: false);

        final rows = data as List<dynamic>;
        return rows.map((r) {
          final map = Map<String, dynamic>.from(r as Map<String, dynamic>);
          final profile = map[SupabaseConfig.tableProfiles] as Map<String, dynamic>?;
          if (profile != null) {
            map['reviewer_name'] = profile['full_name'];
            map['reviewer_avatar_url'] = profile['avatar_url'];
          }
          return ProviderReview.fromSupabase(map);
        }).toList();
      } catch (fallbackErr) {
        debugPrint('⚠️ [SupabaseReviewsRepository] Direct select failed ($fallbackErr). Using fallback.');
        return await _fallback.getProviderReviews(providerId);
      }
    }
  }

  @override
  Future<ProviderReview?> getBookingReview(String bookingId) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return await _fallback.getBookingReview(bookingId);
    }

    try {
      final data = await _client.rpc(
        SupabaseConfig.rpcGetBookingReview,
        params: {'p_booking_id': bookingId},
      );

      final rows = data as List<dynamic>;
      if (rows.isNotEmpty) {
        return ProviderReview.fromSupabase(rows.first as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('ℹ️ [SupabaseReviewsRepository] getBookingReview RPC error ($e). Attempting direct select.');
      try {
        final row = await _client
            .from(SupabaseConfig.tableReviews)
            .select()
            .eq('booking_id', bookingId)
            .maybeSingle();

        if (row != null) {
          return ProviderReview.fromSupabase(row);
        }
        return null;
      } catch (fallbackErr) {
        debugPrint('⚠️ [SupabaseReviewsRepository] Direct select failed ($fallbackErr). Using fallback.');
        return await _fallback.getBookingReview(bookingId);
      }
    }
  }

  @override
  Future<ProviderReview> submitBookingReview({
    required String bookingId,
    required int rating,
    String? comment,
  }) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return await _fallback.submitBookingReview(
        bookingId: bookingId,
        rating: rating,
        comment: comment,
      );
    }

    try {
      final reviewId = await _client.rpc(
        SupabaseConfig.rpcSubmitBookingReview,
        params: {
          'p_booking_id': bookingId,
          'p_rating': rating,
          'p_comment': comment?.trim(),
        },
      );

      final created = await getBookingReview(bookingId);
      if (created != null) return created;

      return ProviderReview(
        id: reviewId.toString(),
        bookingId: bookingId,
        userName: _client.auth.currentUser?.userMetadata?['full_name'] ?? 'Verified Customer',
        userAvatarUrl: _client.auth.currentUser?.userMetadata?['avatar_url'] ?? '',
        rating: rating.toDouble(),
        date: 'Today',
        comment: comment?.trim() ?? '',
      );
    } catch (e) {
      debugPrint('⚠️ [SupabaseReviewsRepository] submitBookingReview RPC failed: $e');
      rethrow;
    }
  }

  @override
  Future<bool> replyToReview({
    required String reviewId,
    required String reply,
  }) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return await _fallback.replyToReview(reviewId: reviewId, reply: reply);
    }

    try {
      await _client.rpc(
        SupabaseConfig.rpcReplyToBookingReview,
        params: {
          'p_review_id': reviewId,
          'p_reply': reply.trim(),
        },
      );
      return true;
    } catch (e) {
      debugPrint('⚠️ [SupabaseReviewsRepository] replyToReview failed: $e');
      return false;
    }
  }
}

class InMemoryReviewsRepository implements ReviewsRepository {
  final Map<String, ProviderReview> _reviewsByBooking = {};
  final List<ProviderReview> _allReviews = [];

  InMemoryReviewsRepository({List<ProviderReview>? seed}) {
    if (seed != null) {
      _allReviews.addAll(seed);
      for (final r in seed) {
        if (r.bookingId != null) {
          _reviewsByBooking[r.bookingId!] = r;
        }
      }
    }
  }

  @override
  Future<List<ProviderReview>> getProviderReviews(String providerId, {bool forceRefresh = false}) async {
    final list = _allReviews.where((r) => r.providerId == null || r.providerId == providerId).toList();
    list.sort((a, b) {
      if (a.createdAt != null && b.createdAt != null) {
        return b.createdAt!.compareTo(a.createdAt!);
      }
      return 0;
    });
    return List.unmodifiable(list);
  }

  @override
  Future<ProviderReview?> getBookingReview(String bookingId) async {
    return _reviewsByBooking[bookingId];
  }

  @override
  Future<ProviderReview> submitBookingReview({
    required String bookingId,
    required int rating,
    String? comment,
  }) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError('Rating must be between 1 and 5 stars.');
    }

    final cleanComment = comment?.trim();
    if (cleanComment != null && cleanComment.isNotEmpty) {
      if (cleanComment.length < 3) {
        throw ArgumentError('Review comment must be at least 3 characters.');
      }
      if (cleanComment.length > 1000) {
        throw ArgumentError('Review comment cannot exceed 1000 characters.');
      }
    }

    final existing = _reviewsByBooking[bookingId];
    final review = ProviderReview(
      id: existing?.id ?? 'rev-${DateTime.now().millisecondsSinceEpoch}',
      bookingId: bookingId,
      customerId: 'usr-customer-01',
      providerId: 'usr-provider-01',
      userName: 'Amara Okonkwo',
      userAvatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
      rating: rating.toDouble(),
      date: 'Today',
      comment: cleanComment ?? '',
      createdAt: DateTime.now(),
    );

    _reviewsByBooking[bookingId] = review;
    _allReviews.removeWhere((r) => r.id == review.id || r.bookingId == bookingId);
    _allReviews.insert(0, review);

    return review;
  }

  @override
  Future<bool> replyToReview({
    required String reviewId,
    required String reply,
  }) async {
    final cleanReply = reply.trim();
    if (cleanReply.length < 3 || cleanReply.length > 1000) {
      return false;
    }

    final idx = _allReviews.indexWhere((r) => r.id == reviewId);
    if (idx != -1) {
      final updated = _allReviews[idx].copyWith(
        providerReply: cleanReply,
        providerReplyDate: 'Today',
      );
      _allReviews[idx] = updated;
      if (updated.bookingId != null) {
        _reviewsByBooking[updated.bookingId!] = updated;
      }
      return true;
    }
    return false;
  }
}
