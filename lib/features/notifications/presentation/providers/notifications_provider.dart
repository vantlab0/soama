import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/supabase_config.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/models/app_notification.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/notifications_repository.dart';

/// Provider exposing the active NotificationsRepository instance.
final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  final client = SupabaseService.client;
  if (client != null && SupabaseConfig.isConfigured) {
    return SupabaseNotificationsRepository(client);
  }
  return InMemoryNotificationsRepository();
});

/// State of the Notifications screen and badge indicators.
class NotificationsState {
  final bool isLoading;
  final List<AppNotification> notifications;
  final int unreadCount;
  final String? errorMessage;

  const NotificationsState({
    this.isLoading = false,
    this.notifications = const [],
    this.unreadCount = 0,
    this.errorMessage,
  });

  NotificationsState copyWith({
    bool? isLoading,
    List<AppNotification>? notifications,
    int? unreadCount,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotificationsState(
      isLoading: isLoading ?? this.isLoading,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// StateNotifier orchestrating notification fetching, realtime synchronization,
/// and mark-as-read mutations.
class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final NotificationsRepository _repository;
  final Ref _ref;
  StreamSubscription<List<AppNotification>>? _subscription;

  NotificationsNotifier(this._repository, this._ref)
      : super(const NotificationsState(isLoading: true)) {
    loadNotifications();
    _subscribeToRealtime();
  }

  String get _currentUserId {
    return _ref.read(authStateProvider).userProfile?.id ?? 'usr-001';
  }

  void _subscribeToRealtime() {
    _subscription?.cancel();
    final userId = _currentUserId;
    _subscription = _repository.watchNotifications(userId).listen(
      (items) {
        final sorted = List<AppNotification>.from(items)
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final unread = sorted.where((n) => !n.isRead).length;
        state = state.copyWith(
          notifications: sorted,
          unreadCount: unread,
          isLoading: false,
          clearError: true,
        );
      },
      onError: (err) {
        debugPrint('⚠️ [NotificationsNotifier] Stream subscription error: $err');
      },
    );
  }

  Future<void> loadNotifications({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final userId = _currentUserId;
      final list = await _repository.getNotifications(userId, forceRefresh: forceRefresh);
      final sorted = List<AppNotification>.from(list)
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final unread = sorted.where((n) => !n.isRead).length;

      state = state.copyWith(
        isLoading: false,
        notifications: sorted,
        unreadCount: unread,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load notifications. Please try again.',
      );
    }
  }

  Future<void> markAsRead(String notificationId) async {
    // Optimistic UI update
    final currentList = state.notifications;
    final updatedList = currentList.map((n) {
      if (n.id == notificationId) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    state = state.copyWith(
      notifications: updatedList,
      unreadCount: updatedList.where((n) => !n.isRead).length,
    );

    try {
      final success = await _repository.markAsRead(notificationId);
      if (!success) {
        // Rollback on failure
        state = state.copyWith(
          notifications: currentList,
          unreadCount: currentList.where((n) => !n.isRead).length,
        );
      }
    } catch (e) {
      // Rollback on error
      state = state.copyWith(
        notifications: currentList,
        unreadCount: currentList.where((n) => !n.isRead).length,
        errorMessage: 'Failed to update notification status.',
      );
    }
  }

  Future<void> markAllAsRead() async {
    final currentList = state.notifications;
    final updatedList = currentList.map((n) => n.copyWith(isRead: true)).toList();

    state = state.copyWith(
      notifications: updatedList,
      unreadCount: 0,
    );

    try {
      final userId = _currentUserId;
      await _repository.markAllAsRead(userId);
    } catch (e) {
      state = state.copyWith(
        notifications: currentList,
        unreadCount: currentList.where((n) => !n.isRead).length,
        errorMessage: 'Failed to mark all as read.',
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Main Riverpod provider for notifications state.
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  final repo = ref.watch(notificationsRepositoryProvider);
  return NotificationsNotifier(repo, ref);
});

/// Authoritative provider for unread notification count across the app.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final state = ref.watch(notificationsProvider);
  return state.unreadCount;
});

/// Provider for client push notification lifecycle service.
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  final repo = ref.watch(notificationsRepositoryProvider);
  return PushNotificationService(repo);
});

