import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../features/notifications/data/notifications_repository.dart';
import '../routing/app_routes.dart';

/// Service managing device push token registration, notification permissions,
/// logout cleanup, and deep-link payload routing.
class PushNotificationService {
  final NotificationsRepository _notificationsRepository;
  String? _lastRegisteredToken;
  String? _lastHandledNotificationId;
  DateTime? _lastHandledTapTime;

  PushNotificationService(this._notificationsRepository);

  /// Current device push token in memory (if registered).
  String? get currentToken => _lastRegisteredToken;

  /// Registers a device push token for the currently authenticated user.
  /// Validates token format and sends to backend via secure RPC.
  Future<bool> registerDeviceToken({
    required String token,
    required String platform,
    Map<String, dynamic>? deviceInfo,
  }) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) return false;

    try {
      final success = await _notificationsRepository.registerDeviceToken(
        token: cleanToken,
        platform: platform,
        deviceInfo: deviceInfo,
      );

      if (success) {
        _lastRegisteredToken = cleanToken;
        debugPrint('🔔 [PushNotificationService] Device token registered successfully (${cleanToken.substring(0, (cleanToken.length > 8 ? 8 : cleanToken.length))}...).');
      }
      return success;
    } catch (e) {
      debugPrint('⚠️ [PushNotificationService] Token registration failed: $e');
      return false;
    }
  }

  /// Removes the device token during logout so the device stops receiving
  /// push notifications for this account.
  Future<bool> handleLogout() async {
    final token = _lastRegisteredToken;
    if (token == null || token.isEmpty) return true;

    try {
      final success = await _notificationsRepository.unregisterDeviceToken(token);
      _lastRegisteredToken = null;
      debugPrint('🔔 [PushNotificationService] Device token unregistered on logout.');
      return success;
    } catch (e) {
      debugPrint('⚠️ [PushNotificationService] Token unregistration failed on logout: $e');
      _lastRegisteredToken = null;
      return false;
    }
  }

  /// Resolves the target route path from a push notification payload.
  /// Supports:
  /// - `service_request_received` / `price_offer_received` / `offer_countered` -> negotiationPath(requestId)
  /// - `offer_accepted` / `booking_confirmed` / `job_started` / `job_completed` -> /bookings
  /// - `new_chat_message` -> conversationPath(conversationId)
  /// - fallback: AppRoutes.notifications
  String resolveRouteFromPayload(Map<String, dynamic> payload) {
    final notifType = payload['notification_type']?.toString();
    final refId = payload['reference_id']?.toString();
    final refType = payload['reference_type']?.toString();

    if (notifType == 'service_request_received' ||
        notifType == 'price_offer_received' ||
        notifType == 'offer_countered' ||
        refType == 'service_request' ||
        refType == 'price_offer') {
      if (refId != null && refId.isNotEmpty) {
        return AppRoutes.negotiationPath(refId);
      }
    }

    if (notifType == 'offer_accepted' ||
        notifType == 'booking_confirmed' ||
        notifType == 'job_started' ||
        notifType == 'job_completed' ||
        notifType == 'payment_received' ||
        notifType == 'escrow_released' ||
        refType == 'booking') {
      return AppRoutes.bookings;
    }

    if (notifType == 'new_chat_message' || refType == 'conversation') {
      if (refId != null && refId.isNotEmpty) {
        return AppRoutes.conversationPath(refId);
      }
      return AppRoutes.messages;
    }

    return AppRoutes.notifications;
  }

  /// Determines whether a notification tap is a duplicate event delivered
  /// simultaneously via cold-start and background callbacks.
  bool shouldHandleNotificationTap(String? notificationId) {
    if (notificationId == null) return true;

    final now = DateTime.now();
    if (_lastHandledNotificationId == notificationId &&
        _lastHandledTapTime != null &&
        now.difference(_lastHandledTapTime!).inMilliseconds < 1500) {
      debugPrint('ℹ️ [PushNotificationService] Suppressing duplicate tap callback for $notificationId.');
      return false;
    }

    _lastHandledNotificationId = notificationId;
    _lastHandledTapTime = now;
    return true;
  }
}
