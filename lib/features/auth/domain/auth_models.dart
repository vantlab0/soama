import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents the high-level authentication status of the application.
enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  needsEmailVerification,
  error,
}

/// Typed model representing a user's record in `public.profiles`.
/// Tied 1:1 with `auth.users(id)`.
class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String selectedAppMode; // 'customer' or 'provider'
  final bool isSuspended;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.selectedAppMode = 'customer',
    this.isSuspended = false,
    this.createdAt,
    this.updatedAt,
  });

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'SO';
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'Soama User',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      selectedAppMode: json['selected_app_mode'] as String? ?? 'customer',
      isSuspended: json['is_suspended'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'selected_app_mode': selectedAppMode,
      'is_suspended': isSuspended,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? avatarUrl,
    String? selectedAppMode,
    bool? isSuspended,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      selectedAppMode: selectedAppMode ?? this.selectedAppMode,
      isSuspended: isSuspended ?? this.isSuspended,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Utility for translating authentication technical errors into user-friendly feedback.
class AuthExceptionHelper {
  AuthExceptionHelper._();

  static String toUserFriendlyMessage(Object error) {
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid_credentials')) {
        return 'Incorrect email address or password. Please verify and try again.';
      }
      if (msg.contains('user already registered') ||
          msg.contains('user_already_exists') ||
          msg.contains('email already in use')) {
        return 'An account with this email address already exists. Please sign in instead.';
      }
      if (msg.contains('email not confirmed') ||
          msg.contains('email_not_confirmed')) {
        return 'Please verify your email address before logging in.';
      }
      if (msg.contains('rate limit') || msg.contains('too many requests')) {
        return 'Too many attempts. Please wait a moment before trying again.';
      }
      if (msg.contains('password should be at least')) {
        return 'Your password must be at least 6 characters long.';
      }
      return error.message;
    }

    final str = error.toString().toLowerCase();
    if (str.contains('socketexception') ||
        str.contains('network') ||
        str.contains('failed to connect')) {
      return 'Unable to connect to the server. Please check your internet connection.';
    }

    return 'An unexpected error occurred. Please try again.';
  }
}
