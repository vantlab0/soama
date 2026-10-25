import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soama/features/bookings/presentation/bookings_screen.dart';
import 'package:soama/features/providers/presentation/provider_details_screen.dart';
import 'package:soama/features/reviews/data/reviews_repository.dart';
import 'package:soama/features/reviews/presentation/providers/reviews_provider.dart';
import 'package:soama/shared/models/service_provider.dart';
import 'package:soama/shared/models/service_request.dart';
import 'package:soama/shared/models/user_account.dart';

void main() {
  setUp(() {
    UserAccount.reset();
    ServiceRequest.reset();
  });

  group('1. Review Data Modeling & Genuine Rating Labels', () {
    test('ProviderReview.fromSupabase deserializes PostgreSQL row correctly', () {
      final dbRow = {
        'id': 'rev-001',
        'booking_id': 'bk-001',
        'customer_id': 'usr-cust-01',
        'provider_id': 'usr-prov-01',
        'reviewer_name': 'Amara Okonkwo',
        'reviewer_avatar_url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
        'rating': 5,
        'comment': 'Exceptional plumbing diagnosis. Solved leak within 45 minutes.',
        'created_at': '2026-10-24T14:30:00Z',
        'provider_reply': 'Thank you Amara! Glad we could solve the pipe pressure issue.',
        'provider_reply_at': '2026-10-24T16:00:00Z',
      };

      final review = ProviderReview.fromSupabase(dbRow);

      expect(review.id, equals('rev-001'));
      expect(review.bookingId, equals('bk-001'));
      expect(review.customerId, equals('usr-cust-01'));
      expect(review.providerId, equals('usr-prov-01'));
      expect(review.userName, equals('Amara Okonkwo'));
      expect(review.userAvatarUrl, equals('https://images.unsplash.com/photo-1534528741775-53994a69daeb'));
      expect(review.rating, equals(5.0));
      expect(review.comment, equals('Exceptional plumbing diagnosis. Solved leak within 45 minutes.'));
      expect(review.providerReply, equals('Thank you Amara! Glad we could solve the pipe pressure issue.'));
      expect(review.providerReplyDate, isNotNull);
    });

    test('ServiceProvider.formattedRatingLabel displays genuine rating without fabricated defaults', () {
      // Provider with valid reviews
      const proWithReviews = ServiceProvider(
        id: 'pro-1',
        name: 'Ochuko Efe',
        businessName: 'Ochuko Plumbing',
        profession: 'Licensed Plumber',
        categoryId: 'plumbing',
        rating: 4.85,
        reviewCount: 32,
        distanceKm: 2.0,
        approximateDistance: '2.0 km',
        startingPriceAmount: 8000,
        startingPrice: '₦8,000',
        location: 'Warri',
        avatarUrl: '',
        isVerified: true,
        badgeTitle: 'Verified Specialist',
      );

      expect(proWithReviews.hasReviews, isTrue);
      expect(proWithReviews.formattedRatingLabel, equals('4.8 (32)'));

      // New provider with 0 reviews
      final proNew = proWithReviews.copyWith(
        rating: 0.0,
        reviewCount: 0,
        reviews: [],
      );

      expect(proNew.hasReviews, isFalse);
      expect(proNew.formattedRatingLabel, equals('New'));
    });
  });

  group('2. Reviews Repository & Business Rule Validation', () {
    late InMemoryReviewsRepository repo;

    setUp(() {
      repo = InMemoryReviewsRepository();
    });

    test('Submitting valid review succeeds and associates with booking', () async {
      final review = await repo.submitBookingReview(
        bookingId: 'bk-test-100',
        rating: 5,
        comment: 'Great work on the AC servicing!',
      );

      expect(review.id, isNotEmpty);
      expect(review.bookingId, equals('bk-test-100'));
      expect(review.rating, equals(5.0));
      expect(review.comment, equals('Great work on the AC servicing!'));

      // Verify retrieval
      final fetched = await repo.getBookingReview('bk-test-100');
      expect(fetched, isNotNull);
      expect(fetched!.id, equals(review.id));
    });

    test('Rejects invalid rating values outside 1-5 star range', () async {
      expect(
        () => repo.submitBookingReview(bookingId: 'bk-1', rating: 0),
        throwsArgumentError,
      );

      expect(
        () => repo.submitBookingReview(bookingId: 'bk-1', rating: 6),
        throwsArgumentError,
      );
    });

    test('Rejects comments with less than 3 or more than 1000 characters', () async {
      expect(
        () => repo.submitBookingReview(bookingId: 'bk-1', rating: 4, comment: 'Hi'),
        throwsArgumentError,
      );

      final excessiveComment = 'a' * 1001;
      expect(
        () => repo.submitBookingReview(bookingId: 'bk-1', rating: 4, comment: excessiveComment),
        throwsArgumentError,
      );
    });

    test('Enforces one review per booking through idempotent editing update', () async {
      // First submission
      final review1 = await repo.submitBookingReview(
        bookingId: 'bk-unique-01',
        rating: 4,
        comment: 'Initial good rating.',
      );

      expect(review1.rating, equals(4.0));

      // Second submission for the same booking edits the existing review
      final review2 = await repo.submitBookingReview(
        bookingId: 'bk-unique-01',
        rating: 5,
        comment: 'Updated to 5 stars after follow-up check.',
      );

      expect(review2.id, equals(review1.id));
      expect(review2.rating, equals(5.0));
      expect(review2.comment, equals('Updated to 5 stars after follow-up check.'));

      // List length for this booking remains exactly 1
      final bookingReview = await repo.getBookingReview('bk-unique-01');
      expect(bookingReview!.rating, equals(5.0));
    });

    test('Provider reply validation and update', () async {
      final review = await repo.submitBookingReview(
        bookingId: 'bk-reply-01',
        rating: 5,
        comment: 'Fantastic electrical work.',
      );

      // Reply too short
      final shortFail = await repo.replyToReview(reviewId: review.id, reply: 'Ok');
      expect(shortFail, isFalse);

      // Valid reply
      final success = await repo.replyToReview(
        reviewId: review.id,
        reply: 'Thank you for your business! Glad to help.',
      );
      expect(success, isTrue);

      final updated = await repo.getBookingReview('bk-reply-01');
      expect(updated!.providerReply, equals('Thank you for your business! Glad to help.'));
      expect(updated.providerReplyDate, equals('Today'));
    });
  });

  group('3. Riverpod Providers & Async Reviews', () {
    test('providerReviewsProvider and bookingReviewProvider retrieve data cleanly', () async {
      final seed = [
        const ProviderReview(
          id: 'rev-seeded-1',
          bookingId: 'bk-seeded-1',
          providerId: 'pro-seeded',
          userName: 'Blessing I.',
          userAvatarUrl: '',
          rating: 5.0,
          date: 'Yesterday',
          comment: 'Very polite and knowledgeable.',
        ),
      ];

      final inMemoryRepo = InMemoryReviewsRepository(seed: seed);

      final container = ProviderContainer(
        overrides: [
          reviewsRepositoryProvider.overrideWithValue(inMemoryRepo),
        ],
      );
      addTearDown(container.dispose);

      final bookingReview = await container.read(bookingReviewProvider('bk-seeded-1').future);
      expect(bookingReview, isNotNull);
      expect(bookingReview!.userName, equals('Blessing I.'));

      final nonExistentBooking = await container.read(bookingReviewProvider('bk-non-existent').future);
      expect(nonExistentBooking, isNull);

      final proReviews = await container.read(providerReviewsProvider('pro-seeded').future);
      expect(proReviews.length, equals(1));
      expect(proReviews.first.id, equals('rev-seeded-1'));
    });
  });

  group('4. BookingsScreen Review Flow UI', () {
    testWidgets('Completed tab shows Leave Review button and opens rating dialog', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final inMemoryRepo = InMemoryReviewsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewsRepositoryProvider.overrideWithValue(inMemoryRepo),
          ],
          child: const MaterialApp(
            home: BookingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Completed tab
      await tester.tap(find.textContaining('Completed ('));
      await tester.pumpAndSettle();

      // Verify "Leave Review" button is present on completed booking
      expect(find.text('Leave Review'), findsWidgets);

      // Tap "Leave Review"
      await tester.tap(find.text('Leave Review').first);
      await tester.pumpAndSettle();

      // Verify Review Dialog appears
      expect(find.textContaining('Rate '), findsOneWidget);
      expect(find.text('Submit Review'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Submit review
      await tester.tap(find.text('Submit Review'));
      await tester.pumpAndSettle();

      // Dialog closes and shows success feedback
      expect(find.textContaining('review has been recorded'), findsOneWidget);
    });
  });

  group('5. ProviderDetailsScreen Genuine Reviews & Replies Display', () {
    testWidgets('Displays customer review, star rating, and provider reply', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testReviews = [
        const ProviderReview(
          id: 'rev-ui-test-1',
          providerId: 'pro-ochuko',
          userName: 'Precious O.',
          userAvatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
          rating: 5.0,
          date: 'Yesterday',
          comment: 'Extremely professional and punctual.',
          providerReply: 'Thank you for trusting our service!',
          providerReplyDate: 'Today',
        ),
      ];

      final inMemoryRepo = InMemoryReviewsRepository(seed: testReviews);

      final testProvider = ServiceProvider(
        id: 'pro-ochuko',
        name: 'Ochuko Efe',
        businessName: 'Ochuko Plumbing',
        profession: 'Licensed Plumber',
        categoryId: 'plumbing',
        rating: 5.0,
        reviewCount: 1,
        distanceKm: 1.5,
        approximateDistance: '1.5 km',
        startingPriceAmount: 8000,
        startingPrice: '₦8,000',
        location: 'Warri',
        avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2',
        isVerified: true,
        badgeTitle: 'Verified Specialist',
        reviews: testReviews,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewsRepositoryProvider.overrideWithValue(inMemoryRepo),
          ],
          child: MaterialApp(
            home: ProviderDetailsScreen(
              providerId: 'pro-ochuko',
              initialProvider: testProvider,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check review section heading & rating
      expect(find.text('Customer Reviews'), findsOneWidget);
      expect(find.text('Precious O.'), findsOneWidget);
      expect(find.text('Extremely professional and punctual.'), findsOneWidget);

      // Check provider response card
      expect(find.textContaining('Response from Ochuko Efe'), findsOneWidget);
      expect(find.text('Thank you for trusting our service!'), findsOneWidget);
    });
  });
}
