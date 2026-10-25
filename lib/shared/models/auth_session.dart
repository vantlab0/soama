import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory session state for onboarding and simulated authentication.
class AuthSession {
  final bool isOnboardingCompleted;
  final bool isAuthenticated;
  final String? userEmail;
  final String? userName;
  final bool rememberMe;

  const AuthSession({
    this.isOnboardingCompleted = false,
    this.isAuthenticated = false,
    this.userEmail,
    this.userName,
    this.rememberMe = false,
  });

  AuthSession copyWith({
    bool? isOnboardingCompleted,
    bool? isAuthenticated,
    String? userEmail,
    String? userName,
    bool? rememberMe,
  }) {
    return AuthSession(
      isOnboardingCompleted:
          isOnboardingCompleted ?? this.isOnboardingCompleted,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userEmail: userEmail ?? this.userEmail,
      userName: userName ?? this.userName,
      rememberMe: rememberMe ?? this.rememberMe,
    );
  }

  /// In-memory singleton representing current session persistence.
  static AuthSession current = const AuthSession();
}

class AuthSessionNotifier extends StateNotifier<AuthSession> {
  AuthSessionNotifier() : super(AuthSession.current);

  void completeOnboarding() {
    state = state.copyWith(isOnboardingCompleted: true);
    AuthSession.current = state;
  }

  void login({
    required String email,
    String? name,
    bool rememberMe = false,
  }) {
    state = state.copyWith(
      isAuthenticated: true,
      userEmail: email,
      userName: name ?? 'Kolawole Adams',
      rememberMe: rememberMe,
    );
    AuthSession.current = state;
  }

  void register({
    required String email,
    required String name,
  }) {
    state = state.copyWith(
      isAuthenticated: false, // Must verify email first
      userEmail: email,
      userName: name,
    );
    AuthSession.current = state;
  }

  void verifyEmail() {
    state = state.copyWith(isAuthenticated: true);
    AuthSession.current = state;
  }

  void logout() {
    state = state.copyWith(
      isAuthenticated: false,
      userEmail: null,
      userName: null,
    );
    AuthSession.current = state;
  }
}

final authSessionProvider =
    StateNotifierProvider<AuthSessionNotifier, AuthSession>((ref) {
  return AuthSessionNotifier();
});
