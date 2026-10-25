import 'package:flutter/material.dart';

enum NotificationCategory {
  all('All', Icons.all_inbox_rounded),
  bookings('Bookings', Icons.calendar_today_rounded),
  messages('Messages', Icons.chat_bubble_outline_rounded),
  payments('Payments', Icons.payments_rounded);

  final String label;
  final IconData icon;

  const NotificationCategory(this.label, this.icon);
}

class AppNotification {
  final String id;
  final String? recipientId;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationCategory category;
  final bool isRead;
  final String? targetRoute;
  final String? targetId;
  final String? notificationType;
  final String? referenceId;
  final String? referenceType;

  const AppNotification({
    required this.id,
    this.recipientId,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.category,
    this.isRead = false,
    this.targetRoute,
    this.targetId,
    this.notificationType,
    this.referenceId,
    this.referenceType,
  });

  /// Factory constructor to parse PostgreSQL / Supabase notifications row.
  factory AppNotification.fromSupabase(Map<String, dynamic> map) {
    final notifType = map['notification_type']?.toString() ?? '';
    final refId = map['reference_id']?.toString();
    final refType = map['reference_type']?.toString();

    // Map notification_type to UI category and navigation target
    NotificationCategory category = NotificationCategory.all;
    String? route;
    String? targetId = refId;

    switch (notifType) {
      case 'service_request_received':
      case 'price_offer_received':
      case 'offer_countered':
        category = NotificationCategory.bookings;
        route = '/negotiation';
        break;

      case 'offer_accepted':
      case 'booking_confirmed':
      case 'job_started':
      case 'job_completed':
      case 'review_received':
      case 'dispute_opened':
        category = NotificationCategory.bookings;
        route = '/bookings';
        break;

      case 'new_chat_message':
        category = NotificationCategory.messages;
        route = '/messages';
        break;

      case 'payment_received':
      case 'escrow_released':
        category = NotificationCategory.payments;
        route = '/bookings';
        break;

      default:
        category = NotificationCategory.all;
        if (refType == 'service_request' || refType == 'price_offer') {
          route = '/negotiation';
        } else if (refType == 'booking') {
          route = '/bookings';
        } else if (refType == 'conversation') {
          route = '/messages';
        }
        break;
    }

    final createdAtStr = map['created_at']?.toString();
    final timestamp = createdAtStr != null
        ? (DateTime.tryParse(createdAtStr) ?? DateTime.now())
        : DateTime.now();

    return AppNotification(
      id: map['id']?.toString() ?? '',
      recipientId: map['recipient_id']?.toString(),
      title: map['title']?.toString() ?? 'Notification',
      message: map['body']?.toString() ?? '',
      timestamp: timestamp,
      category: category,
      isRead: map['is_read'] == true,
      targetRoute: route,
      targetId: targetId,
      notificationType: notifType,
      referenceId: refId,
      referenceType: refType,
    );
  }

  /// Converts this model to a map matching the Supabase notifications table.
  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      if (recipientId != null) 'recipient_id': recipientId,
      'title': title,
      'body': message,
      'is_read': isRead,
      'created_at': timestamp.toIso8601String(),
      if (notificationType != null) 'notification_type': notificationType,
      if (referenceId != null) 'reference_id': referenceId,
      if (referenceType != null) 'reference_type': referenceType,
    };
  }

  AppNotification copyWith({
    String? id,
    String? recipientId,
    String? title,
    String? message,
    DateTime? timestamp,
    NotificationCategory? category,
    bool? isRead,
    String? targetRoute,
    String? targetId,
    String? notificationType,
    String? referenceId,
    String? referenceType,
  }) {
    return AppNotification(
      id: id ?? this.id,
      recipientId: recipientId ?? this.recipientId,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      category: category ?? this.category,
      isRead: isRead ?? this.isRead,
      targetRoute: targetRoute ?? this.targetRoute,
      targetId: targetId ?? this.targetId,
      notificationType: notificationType ?? this.notificationType,
      referenceId: referenceId ?? this.referenceId,
      referenceType: referenceType ?? this.referenceType,
    );
  }

  static int get unreadCount =>
      notifications.where((n) => !n.isRead).length;

  static void markAllAsRead() {
    for (int i = 0; i < notifications.length; i++) {
      notifications[i] = notifications[i].copyWith(isRead: true);
    }
  }

  static void markAsRead(String id) {
    final idx = notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      notifications[idx] = notifications[idx].copyWith(isRead: true);
    }
  }

  static final List<AppNotification> notifications = [
    AppNotification(
      id: 'notif-1',
      title: 'Counteroffer Received from Ochuko Efe',
      message: 'Ochuko proposed ₦8,000 for your Emergency Pipe Leak Repair request.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
      category: NotificationCategory.bookings,
      isRead: false,
      targetRoute: '/negotiation',
      targetId: 'SOA-2084',
      notificationType: 'offer_countered',
      referenceId: 'SOA-2084',
      referenceType: 'service_request',
    ),
    AppNotification(
      id: 'notif-2',
      title: 'New Message from Ochuko Efe',
      message: '"I have packed the 3/4-inch PVC couplings and high-pressure cement..."',
      timestamp: DateTime.now().subtract(const Duration(minutes: 18)),
      category: NotificationCategory.messages,
      isRead: false,
      targetRoute: '/messages',
      targetId: 'conv-ochuko',
      notificationType: 'new_chat_message',
      referenceId: 'conv-ochuko',
      referenceType: 'conversation',
    ),
    AppNotification(
      id: 'notif-3',
      title: 'Escrow Funds Secured (₦16,500)',
      message: 'Payment for Generator Maintenance with Tunde Adeleke is locked safely in escrow.',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      category: NotificationCategory.payments,
      isRead: true,
      targetRoute: '/bookings',
      notificationType: 'payment_received',
      referenceId: 'bk-gen-01',
      referenceType: 'booking',
    ),
    AppNotification(
      id: 'notif-4',
      title: 'Job Completed & Escrow Released',
      message: 'Blessing Igbinoba completed Deep Home Sanitization. Funds released to specialist.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      category: NotificationCategory.payments,
      isRead: true,
      targetRoute: '/bookings',
      notificationType: 'job_completed',
      referenceId: 'bk-sanit-02',
      referenceType: 'booking',
    ),
  ];
}
