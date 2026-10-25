import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:soama/core/services/push_notification_service.dart';
import 'package:soama/features/notifications/data/notifications_repository.dart';
import 'package:soama/features/notifications/presentation/notifications_screen.dart';
import 'package:soama/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:soama/shared/models/app_notification.dart';

void main() {
  group('1. Notification Deserialization & Event Type Mapping', () {
    test('Deserializes service_request_received to negotiation target', () {
      final json = {
        'id': 'notif-req-001',
        'recipient_id': 'prov-100',
        'notification_type': 'service_request_received',
        'title': 'New Service Request: Pipe Leak Repair',
        'body': 'A customer in GRA Phase 2 requested your service.',
        'reference_id': 'req-999',
        'reference_type': 'service_request',
        'is_read': false,
        'created_at': '2026-10-25T10:00:00Z',
      };

      final notif = AppNotification.fromSupabase(json);

      expect(notif.id, equals('notif-req-001'));
      expect(notif.recipientId, equals('prov-100'));
      expect(notif.notificationType, equals('service_request_received'));
      expect(notif.category, equals(NotificationCategory.bookings));
      expect(notif.targetRoute, equals('/negotiation'));
      expect(notif.targetId, equals('req-999'));
      expect(notif.isRead, isFalse);
    });

    test('Deserializes price_offer_received and offer_countered', () {
      final jsonOffer = {
        'id': 'notif-offer-001',
        'recipient_id': 'cust-200',
        'notification_type': 'price_offer_received',
        'title': 'New Offer: ₦15,000',
        'body': 'Specialist offered ₦15,000.',
        'reference_id': 'req-888',
        'reference_type': 'price_offer',
        'is_read': false,
        'created_at': '2026-10-25T10:15:00Z',
      };

      final notifOffer = AppNotification.fromSupabase(jsonOffer);
      expect(notifOffer.category, equals(NotificationCategory.bookings));
      expect(notifOffer.targetRoute, equals('/negotiation'));
      expect(notifOffer.targetId, equals('req-888'));

      final jsonCounter = {
        'id': 'notif-counter-002',
        'recipient_id': 'prov-100',
        'notification_type': 'offer_countered',
        'title': 'Counteroffer: ₦12,500',
        'body': 'Customer countered with ₦12,500.',
        'reference_id': 'req-888',
        'reference_type': 'price_offer',
        'is_read': true,
        'created_at': '2026-10-25T10:30:00Z',
      };

      final notifCounter = AppNotification.fromSupabase(jsonCounter);
      expect(notifCounter.category, equals(NotificationCategory.bookings));
      expect(notifCounter.targetRoute, equals('/negotiation'));
      expect(notifCounter.isRead, isTrue);
    });

    test('Deserializes booking_confirmed, job_started, and job_completed to bookings target', () {
      final jsonConfirmed = {
        'id': 'notif-bk-001',
        'notification_type': 'booking_confirmed',
        'title': 'Appointment Confirmed (BK-20261025-001)',
        'body': 'Appointment is confirmed.',
        'reference_id': 'bk-001',
        'reference_type': 'booking',
        'is_read': false,
        'created_at': '2026-10-25T11:00:00Z',
      };
      final notifConfirmed = AppNotification.fromSupabase(jsonConfirmed);
      expect(notifConfirmed.category, equals(NotificationCategory.bookings));
      expect(notifConfirmed.targetRoute, equals('/bookings'));

      final jsonStarted = {
        'id': 'notif-bk-002',
        'notification_type': 'job_started',
        'title': 'Job In Progress',
        'body': 'Work has started.',
        'reference_id': 'bk-001',
        'reference_type': 'booking',
        'is_read': false,
        'created_at': '2026-10-25T11:30:00Z',
      };
      final notifStarted = AppNotification.fromSupabase(jsonStarted);
      expect(notifStarted.category, equals(NotificationCategory.bookings));
      expect(notifStarted.targetRoute, equals('/bookings'));

      final jsonCompleted = {
        'id': 'notif-bk-003',
        'notification_type': 'job_completed',
        'title': 'Job Completed',
        'body': 'Work completed.',
        'reference_id': 'bk-001',
        'reference_type': 'booking',
        'is_read': false,
        'created_at': '2026-10-25T12:00:00Z',
      };
      final notifCompleted = AppNotification.fromSupabase(jsonCompleted);
      expect(notifCompleted.category, equals(NotificationCategory.bookings));
      expect(notifCompleted.targetRoute, equals('/bookings'));
    });

    test('Deserializes new_chat_message to messages target', () {
      final jsonMsg = {
        'id': 'notif-msg-001',
        'notification_type': 'new_chat_message',
        'title': 'New message from Ochuko Efe',
        'body': 'I am on my way to your location now.',
        'reference_id': 'conv-123',
        'reference_type': 'conversation',
        'is_read': false,
        'created_at': '2026-10-25T12:30:00Z',
      };

      final notifMsg = AppNotification.fromSupabase(jsonMsg);
      expect(notifMsg.category, equals(NotificationCategory.messages));
      expect(notifMsg.targetRoute, equals('/messages'));
      expect(notifMsg.targetId, equals('conv-123'));
    });

    test('Deserializes payment_received and escrow_released to payments category', () {
      final jsonEscrow = {
        'id': 'notif-pay-001',
        'notification_type': 'escrow_released',
        'title': 'Escrow Released (₦25,000)',
        'body': 'Funds released to specialist.',
        'reference_id': 'bk-555',
        'reference_type': 'booking',
        'is_read': true,
        'created_at': '2026-10-25T13:00:00Z',
      };

      final notifPay = AppNotification.fromSupabase(jsonEscrow);
      expect(notifPay.category, equals(NotificationCategory.payments));
      expect(notifPay.targetRoute, equals('/bookings'));
      expect(notifPay.isRead, isTrue);
    });

    test('toSupabase serializes correctly', () {
      final notif = AppNotification(
        id: 'test-1',
        recipientId: 'usr-42',
        title: 'Test Notification',
        message: 'This is a test message.',
        timestamp: DateTime.parse('2026-10-25T12:00:00Z'),
        category: NotificationCategory.bookings,
        isRead: false,
        notificationType: 'booking_confirmed',
        referenceId: 'ref-1',
        referenceType: 'booking',
      );

      final map = notif.toSupabase();
      expect(map['id'], equals('test-1'));
      expect(map['recipient_id'], equals('usr-42'));
      expect(map['title'], equals('Test Notification'));
      expect(map['body'], equals('This is a test message.'));
      expect(map['is_read'], isFalse);
      expect(map['notification_type'], equals('booking_confirmed'));
      expect(map['reference_id'], equals('ref-1'));
    });
  });

  group('2. Notifications Repository & Realtime Stream', () {
    late InMemoryNotificationsRepository repo;

    setUp(() {
      repo = InMemoryNotificationsRepository(seed: [
        AppNotification(
          id: 'n-1',
          recipientId: 'usr-1',
          title: 'Unread Notification 1',
          message: 'Message 1',
          timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
          category: NotificationCategory.bookings,
          isRead: false,
        ),
        AppNotification(
          id: 'n-2',
          recipientId: 'usr-1',
          title: 'Unread Notification 2',
          message: 'Message 2',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          category: NotificationCategory.messages,
          isRead: false,
        ),
        AppNotification(
          id: 'n-3',
          recipientId: 'usr-1',
          title: 'Read Notification 3',
          message: 'Message 3',
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          category: NotificationCategory.payments,
          isRead: true,
        ),
      ]);
    });

    tearDown(() {
      repo.dispose();
    });

    test('getNotifications returns list sorted newest first', () async {
      final list = await repo.getNotifications('usr-1');
      expect(list.length, equals(3));
      expect(list.first.id, equals('n-2')); // 5 min ago is newer than 10 min ago
      expect(list.last.id, equals('n-3')); // 1 hour ago is oldest
    });

    test('getUnreadCount accurately computes unread items', () async {
      final count = await repo.getUnreadCount('usr-1');
      expect(count, equals(2));
    });

    test('markAsRead marks specified notification as read', () async {
      final success = await repo.markAsRead('n-1');
      expect(success, isTrue);

      final unread = await repo.getUnreadCount('usr-1');
      expect(unread, equals(1));
    });

    test('markAllAsRead marks all remaining notifications as read', () async {
      final updated = await repo.markAllAsRead('usr-1');
      expect(updated, equals(2));

      final unread = await repo.getUnreadCount('usr-1');
      expect(unread, equals(0));
    });

    test('watchNotifications emits reactive updates when list mutates', () async {
      final stream = repo.watchNotifications('usr-1');
      expectLater(
        stream,
        emitsInOrder([
          predicate<List<AppNotification>>((l) => l.where((n) => !n.isRead).length == 2),
          predicate<List<AppNotification>>((l) => l.where((n) => !n.isRead).length == 1),
        ]),
      );

      // Trigger mutation
      await Future.delayed(const Duration(milliseconds: 10));
      await repo.markAsRead('n-1');
    });

    test('registerDeviceToken and unregisterDeviceToken track active tokens', () async {
      const token = 'fcm-device-token-abc123xyz';
      expect(repo.isTokenRegistered(token), isFalse);

      final regSuccess = await repo.registerDeviceToken(
        token: token,
        platform: 'android',
        deviceInfo: {'model': 'Pixel 8', 'os': 'Android 14'},
      );
      expect(regSuccess, isTrue);
      expect(repo.isTokenRegistered(token), isTrue);

      final unregSuccess = await repo.unregisterDeviceToken(token);
      expect(unregSuccess, isTrue);
      expect(repo.isTokenRegistered(token), isFalse);
    });
  });

  group('3. Push Notification Service & Deep-Link Resolution', () {
    late InMemoryNotificationsRepository repo;
    late PushNotificationService service;

    setUp(() {
      repo = InMemoryNotificationsRepository();
      service = PushNotificationService(repo);
    });

    tearDown(() {
      repo.dispose();
    });

    test('resolveRouteFromPayload maps service request payloads to negotiation screen', () {
      final payload = {
        'notification_type': 'service_request_received',
        'reference_id': 'req-abc-123',
        'reference_type': 'service_request',
      };
      final route = service.resolveRouteFromPayload(payload);
      expect(route, equals('/negotiation/req-abc-123'));
    });

    test('resolveRouteFromPayload maps price offer payloads to negotiation screen', () {
      final payload = {
        'notification_type': 'price_offer_received',
        'reference_id': 'req-xyz-789',
        'reference_type': 'price_offer',
      };
      final route = service.resolveRouteFromPayload(payload);
      expect(route, equals('/negotiation/req-xyz-789'));
    });

    test('resolveRouteFromPayload maps booking payloads to bookings screen', () {
      final payload = {
        'notification_type': 'booking_confirmed',
        'reference_id': 'bk-001',
        'reference_type': 'booking',
      };
      final route = service.resolveRouteFromPayload(payload);
      expect(route, equals('/bookings'));
    });

    test('resolveRouteFromPayload maps chat message payloads to conversation screen', () {
      final payload = {
        'notification_type': 'new_chat_message',
        'reference_id': 'conv-456',
        'reference_type': 'conversation',
      };
      final route = service.resolveRouteFromPayload(payload);
      expect(route, equals('/messages/conv-456'));
    });

    test('shouldHandleNotificationTap prevents rapid duplicate callback execution', () {
      const notifId = 'notif-duplicate-test';

      // First tap should be handled
      expect(service.shouldHandleNotificationTap(notifId), isTrue);

      // Immediate subsequent tap with same ID should be suppressed
      expect(service.shouldHandleNotificationTap(notifId), isFalse);

      // Different notification ID should be accepted
      expect(service.shouldHandleNotificationTap('notif-different'), isTrue);
    });

    test('handleLogout removes registered token and clears memory', () async {
      await service.registerDeviceToken(
        token: 'token-logout-test',
        platform: 'ios',
      );
      expect(service.currentToken, equals('token-logout-test'));
      expect(repo.isTokenRegistered('token-logout-test'), isTrue);

      await service.handleLogout();
      expect(service.currentToken, isNull);
      expect(repo.isTokenRegistered('token-logout-test'), isFalse);
    });
  });

  group('4. Riverpod StateNotifier & Unread Count Synchronization', () {
    test('Updates state optimistically and computes unread count accurately', () async {
      final testSeed = [
        AppNotification(
          id: 'opt-1',
          title: 'Offer 1',
          message: 'Offer message 1',
          timestamp: DateTime.now(),
          category: NotificationCategory.bookings,
          isRead: false,
        ),
        AppNotification(
          id: 'opt-2',
          title: 'Offer 2',
          message: 'Offer message 2',
          timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
          category: NotificationCategory.bookings,
          isRead: false,
        ),
      ];

      final inMemoryRepo = InMemoryNotificationsRepository(seed: testSeed);

      final container = ProviderContainer(
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(inMemoryRepo),
        ],
      );
      addTearDown(() {
        container.dispose();
        inMemoryRepo.dispose();
      });

      // Initially loaded with 2 unread
      await container.read(notificationsProvider.notifier).loadNotifications();
      expect(container.read(unreadNotificationCountProvider), equals(2));

      // Mark single notification as read
      await container.read(notificationsProvider.notifier).markAsRead('opt-1');
      expect(container.read(unreadNotificationCountProvider), equals(1));
      expect(container.read(notificationsProvider).notifications.firstWhere((n) => n.id == 'opt-1').isRead, isTrue);

      // Mark all as read
      await container.read(notificationsProvider.notifier).markAllAsRead();
      expect(container.read(unreadNotificationCountProvider), equals(0));
      expect(container.read(notificationsProvider).notifications.every((n) => n.isRead), isTrue);
    });
  });

  group('5. NotificationsScreen UI & Tab Filters', () {
    testWidgets('Renders filter tabs and notification items with unread indicators', (tester) async {
      final testSeed = [
        AppNotification(
          id: 'ui-1',
          title: 'Specialist Counteroffer',
          message: 'Ochuko proposed ₦8,000 for repair.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          category: NotificationCategory.bookings,
          isRead: false,
          targetRoute: '/negotiation',
          targetId: 'SOA-2084',
        ),
        AppNotification(
          id: 'ui-2',
          title: 'New Chat Message',
          message: 'I have packed the equipment.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
          category: NotificationCategory.messages,
          isRead: true,
          targetRoute: '/messages',
          targetId: 'conv-1',
        ),
      ];

      final inMemoryRepo = InMemoryNotificationsRepository(seed: testSeed);

      final testRouter = GoRouter(
        initialLocation: '/notifications',
        routes: [
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/negotiation/:id',
            builder: (context, state) => const Scaffold(body: Text('Negotiation Target')),
          ),
          GoRoute(
            path: '/messages/:id',
            builder: (context, state) => const Scaffold(body: Text('Messages Target')),
          ),
          GoRoute(
            path: '/bookings',
            builder: (context, state) => const Scaffold(body: Text('Bookings Target')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsRepositoryProvider.overrideWithValue(inMemoryRepo),
          ],
          child: MaterialApp.router(
            routerConfig: testRouter,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check App bar title and tabs
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.textContaining('All (2)'), findsOneWidget);
      expect(find.textContaining('Bookings (1)'), findsOneWidget);
      expect(find.textContaining('Messages (1)'), findsOneWidget);

      // Check notification items rendered
      expect(find.text('Specialist Counteroffer'), findsOneWidget);
      expect(find.text('New Chat Message'), findsOneWidget);

      // Tap on unread notification and verify navigation
      await tester.tap(find.text('Specialist Counteroffer'));
      await tester.pumpAndSettle();
      expect(find.text('Negotiation Target'), findsOneWidget);

      inMemoryRepo.dispose();
    });
  });
}
