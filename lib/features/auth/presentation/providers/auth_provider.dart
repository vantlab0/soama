import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/models/user_account.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_models.dart';

/// State representation for authentication workflows.
class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final UserProfile? userProfile;

  const AuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.userProfile,
  });

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get needsVerification => status == AuthStatus.needsEmailVerification;

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    bool clearError = false,
    UserProfile? userProfile,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      userProfile: userProfile ?? this.userProfile,
    );
  }
}

/// Provider for the active AuthRepository instance.
/// Automatically uses SupabaseAuthRepository when connected to Supabase,
/// or falls back to InMemoryAuthRepository when running tests/unconfigured.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = SupabaseService.client;
  if (client != null) {
    return SupabaseAuthRepository(client);
  }
  return InMemoryAuthRepository();
});

/// Notifier driving authentication mutations and session lifecycle.
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  StreamSubscription<AuthStatus>? _sub;

  AuthNotifier(this._repository)
      : super(
          AuthState(
            status: _repository.isAuthenticated
                ? AuthStatus.authenticated
                : AuthStatus.unauthenticated,
            userProfile: _repository.currentUserProfile,
          ),
        ) {
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _sub = _repository.authStateChanges.listen((status) {
      state = state.copyWith(
        status: status,
        userProfile: _repository.currentUserProfile,
        clearError: true,
      );
    });
  }

  Future<void> restoreSession() async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      await _repository.restoreSession();
      state = state.copyWith(
        status: _repository.isAuthenticated
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        userProfile: _repository.currentUserProfile,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: AuthExceptionHelper.toUserFriendlyMessage(e),
      );
    }
  }

  Future<bool> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final profile = await _repository.login(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        userProfile: profile,
        clearError: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: AuthExceptionHelper.toUserFriendlyMessage(e),
      );
      return false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final profile = await _repository.register(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );
      state = state.copyWith(
        status: _repository.isAuthenticated
            ? AuthStatus.authenticated
            : AuthStatus.needsEmailVerification,
        userProfile: profile,
        clearError: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: AuthExceptionHelper.toUserFriendlyMessage(e),
      );
      return false;
    }
  }

  Future<bool> verifyOtp({
    required String email,
    required String token,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final profile = await _repository.verifyOtp(email: email, token: token);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        userProfile: profile,
        clearError: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: AuthExceptionHelper.toUserFriendlyMessage(e),
      );
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      await _repository.sendPasswordResetEmail(email);
      state = state.copyWith(status: AuthStatus.unauthenticated, clearError: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: AuthExceptionHelper.toUserFriendlyMessage(e),
      );
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      await _repository.logout();
    } finally {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> switchMode(AppMode mode) async {
    await _repository.switchMode(mode);
    state = state.copyWith(userProfile: _repository.currentUserProfile);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Main auth state provider for the UI layer.
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo);
});
