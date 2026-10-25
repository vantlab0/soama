import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_config.dart';
import '../../../shared/models/app_notification.dart';

abstract class NotificationsRepository {
  Future<List<AppNotification>> getNotifications(String userId, {bool forceRefresh = false});
  Future<int> getUnreadCount(String userId);
  Future<bool> markAsRead(String notificationId);
  Future<int> markAllAsRead(String userId);
  Stream<List<AppNotification>> watchNotifications(String userId);
  Future<bool> registerDeviceToken({
    required String token,
    required String platform,
    Map<String, dynamic>? deviceInfo,
  });
  Future<bool> unregisterDeviceToken(String token);
}

class SupabaseNotificationsRepository implements NotificationsRepository {
  final SupabaseClient _client;
  final InMemoryNotificationsRepository _fallback = InMemoryNotificationsRepository();

  SupabaseNotificationsRepository(this._client);

  @override
  Future<List<AppNotification>> getNotifications(String userId, {bool forceRefresh = false}) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return await _fallback.getNotifications(userId, forceRefresh: forceRefresh);
    }

    try {
      final response = await _client
          .from(SupabaseConfig.tableNotifications)
          .select()
          .eq('recipient_id', userId)
          .order('created_at', ascending: false);

      final rows = response as List<dynamic>;
      final list = rows.map((r) => AppNotification.fromSupabase(r as Map<String, dynamic>)).toList();
      return list;
    } catch (e) {
      debugPrint('ℹ️ [SupabaseNotificationsRepository] getNotifications error ($e). Using fallback.');
      return await _fallback.getNotifications(userId);
    }
  }

  @override
  Future<int> getUnreadCount(String userId) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return await _fallback.getUnreadCount(userId);
    }

    try {
      final count = await _client
          .from(SupabaseConfig.tableNotifications)
          .count(CountOption.exact)
          .eq('recipient_id', userId)
          .eq('is_read', false);

      return count;
    } catch (e) {
      debugPrint('ℹ️ [SupabaseNotificationsRepository] getUnreadCount error ($e). Using fallback.');
      return await _fallback.getUnreadCount(userId);
    }
  }

  @override
  Future<bool> markAsRead(String notificationId) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return await _fallback.markAsRead(notificationId);
    }

    try {
      await _client.rpc(
        SupabaseConfig.rpcMarkNotificationRead,
        params: {'p_notification_id': notificationId},
      );
      return true;
    } catch (e) {
      debugPrint('⚠️ [SupabaseNotificationsRepository] markAsRead RPC failed ($e). Attempting direct update.');
      try {
        await _client
            .from(SupabaseConfig.tableNotifications)
            .update({'is_read': true})
            .eq('id', notificationId);
        return true;
      } catch (fallbackError) {
        debugPrint('❌ [SupabaseNotificationsRepository] Direct update failed: $fallbackError');
        return false;
      }
    }
  }

  @override
  Future<int> markAllAsRead(String userId) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return await _fallback.markAllAsRead(userId);
    }

    try {
      final result = await _client.rpc(SupabaseConfig.rpcMarkAllNotificationsRead);
      if (result is int) return result;
      return 1;
    } catch (e) {
      debugPrint('⚠️ [SupabaseNotificationsRepository] markAllAsRead RPC failed ($e). Attempting direct update.');
      try {
        await _client
            .from(SupabaseConfig.tableNotifications)
            .update({'is_read': true})
            .eq('recipient_id', userId)
            .eq('is_read', false);
        return 1;
      } catch (fallbackError) {
        debugPrint('❌ [SupabaseNotificationsRepository] Direct mark all read failed: $fallbackError');
        return 0;
      }
    }
  }

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return _fallback.watchNotifications(userId);
    }

    try {
      return _client
          .from(SupabaseConfig.tableNotifications)
          .stream(primaryKey: ['id'])
          .eq('recipient_id', userId)
          .order('created_at', ascending: false)
          .map((rows) => rows.map((r) => AppNotification.fromSupabase(r)).toList());
    } catch (e) {
      debugPrint('ℹ️ [SupabaseNotificationsRepository] Realtime stream failed ($e). Using polling fallback stream.');
      return _fallback.watchNotifications(userId);
    }
  }

  @override
  Future<bool> registerDeviceToken({
    required String token,
    required String platform,
    Map<String, dynamic>? deviceInfo,
  }) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return await _fallback.registerDeviceToken(token: token, platform: platform, deviceInfo: deviceInfo);
    }

    try {
      await _client.rpc(
        SupabaseConfig.rpcRegisterDeviceToken,
        params: {
          'p_token': token.trim(),
          'p_platform': platform,
          'p_device_info': deviceInfo ?? {},
        },
      );
      return true;
    } catch (e) {
      debugPrint('ℹ️ [SupabaseNotificationsRepository] registerDeviceToken error ($e). Using direct upsert fallback.');
      try {
        final userId = _client.auth.currentUser!.id;
        await _client.from(SupabaseConfig.tableUserDeviceTokens).upsert({
          'user_id': userId,
          'token': token.trim(),
          'platform': platform,
          'device_info': deviceInfo ?? {},
          'is_active': true,
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        return true;
      } catch (upsertError) {
        debugPrint('❌ [SupabaseNotificationsRepository] Upsert device token failed: $upsertError');
        return false;
      }
    }
  }

  @override
  Future<bool> unregisterDeviceToken(String token) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return await _fallback.unregisterDeviceToken(token);
    }

    try {
      await _client.rpc(
        SupabaseConfig.rpcUnregisterDeviceToken,
        params: {'p_token': token.trim()},
      );
      return true;
    } catch (e) {
      debugPrint('ℹ️ [SupabaseNotificationsRepository] unregisterDeviceToken error ($e). Using direct update.');
      try {
        await _client
            .from(SupabaseConfig.tableUserDeviceTokens)
            .update({'is_active': false})
            .eq('token', token.trim());
        return true;
      } catch (updateError) {
        debugPrint('❌ [SupabaseNotificationsRepository] Direct unregister token failed: $updateError');
        return false;
      }
    }
  }
}

class InMemoryNotificationsRepository implements NotificationsRepository {
  final List<AppNotification> _notifications = [];
  final Set<String> _registeredTokens = {};
  late final StreamController<List<AppNotification>> _controller;

  InMemoryNotificationsRepository({List<AppNotification>? seed}) {
    if (seed != null) {
      _notifications.addAll(seed);
    } else {
      _notifications.addAll(AppNotification.notifications);
    }
    _controller = StreamController<List<AppNotification>>.broadcast(
      onListen: () => _notifyListeners(),
    );
  }

  void _notifyListeners() {
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_notifications));
    }
  }

  @override
  Future<List<AppNotification>> getNotifications(String userId, {bool forceRefresh = false}) async {
    // Return sorted newest first
    _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return List.unmodifiable(_notifications);
  }

  @override
  Future<int> getUnreadCount(String userId) async {
    return _notifications.where((n) => !n.isRead).length;
  }

  @override
  Future<bool> markAsRead(String notificationId) async {
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      _notifyListeners();
      return true;
    }
    return false;
  }

  @override
  Future<int> markAllAsRead(String userId) async {
    int updated = 0;
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        updated++;
      }
    }
    _notifyListeners();
    return updated;
  }

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) {
    return _controller.stream;
  }

  @override
  Future<bool> registerDeviceToken({
    required String token,
    required String platform,
    Map<String, dynamic>? deviceInfo,
  }) async {
    _registeredTokens.add(token.trim());
    return true;
  }

  @override
  Future<bool> unregisterDeviceToken(String token) async {
    _registeredTokens.remove(token.trim());
    return true;
  }

  /// Helper for tests to add a mock notification
  void addNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    _notifyListeners();
  }

  bool isTokenRegistered(String token) => _registeredTokens.contains(token.trim());

  void dispose() {
    _controller.close();
  }
}
