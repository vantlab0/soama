import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_config.dart';
import '../../../shared/models/customer_profile.dart';
import '../../../shared/models/service_provider.dart';
import '../../../shared/models/user_account.dart';
import '../domain/auth_models.dart';

/// Contract defining all authentication operations.
abstract class AuthRepository {
  Stream<AuthStatus> get authStateChanges;
  UserProfile? get currentUserProfile;
  bool get isAuthenticated;
  String? get currentUserId;

  Future<void> restoreSession();

  Future<UserProfile> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  });

  Future<UserProfile> login({
    required String email,
    required String password,
    bool rememberMe = true,
  });

  Future<void> logout();

  Future<void> sendPasswordResetEmail(String email);

  Future<UserProfile> verifyOtp({
    required String email,
    required String token,
  });

  Future<UserProfile> upsertProfile(UserProfile profile);

  Future<ProviderProfileData?> fetchProviderProfile(String userId);

  Future<void> switchMode(AppMode mode);
}

/// Production implementation backed by Supabase Auth and PostgreSQL.
class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;
  final StreamController<AuthStatus> _statusController =
      StreamController<AuthStatus>.broadcast();

  UserProfile? _currentProfile;
  StreamSubscription<AuthState>? _authSubscription;

  SupabaseAuthRepository(this._client) {
    _initAuthListener();
  }

  void _initAuthListener() {
    _authSubscription = _client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null && session.user.id.isNotEmpty) {
        try {
          await _syncProfileFromBackend(session.user.id);
          _statusController.add(AuthStatus.authenticated);
        } catch (_) {
          _statusController.add(AuthStatus.authenticated);
        }
      } else {
        _currentProfile = null;
        _statusController.add(AuthStatus.unauthenticated);
      }
    });
  }

  @override
  Stream<AuthStatus> get authStateChanges => _statusController.stream;

  @override
  UserProfile? get currentUserProfile => _currentProfile;

  @override
  bool get isAuthenticated => _client.auth.currentSession != null;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<void> restoreSession() async {
    final session = _client.auth.currentSession;
    if (session != null && session.user.id.isNotEmpty) {
      await _syncProfileFromBackend(session.user.id);
      _statusController.add(AuthStatus.authenticated);
    } else {
      _currentProfile = null;
      _statusController.add(AuthStatus.unauthenticated);
    }
  }

  @override
  Future<UserProfile> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        },
      );

      final user = res.user;
      if (user == null) {
        throw const AuthException('Registration failed: no user returned.');
      }

      // Safe client-side upsert to ensure public.profiles record exists
      final newProfile = UserProfile(
        id: user.id,
        fullName: fullName,
        email: email,
        phone: phone,
        selectedAppMode: 'customer',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      await upsertProfile(newProfile);
      _currentProfile = newProfile;
      _syncSharedModels(newProfile, null);

      if (res.session == null) {
        // Project requires email confirmation
        _statusController.add(AuthStatus.needsEmailVerification);
      } else {
        _statusController.add(AuthStatus.authenticated);
      }

      return newProfile;
    } catch (e) {
      debugPrint('❌ [SupabaseAuthRepository] register error: $e');
      rethrow;
    }
  }

  @override
  Future<UserProfile> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = res.user;
      if (user == null) {
        throw const AuthException('Login failed: user session not established.');
      }

      final profile = await _syncProfileFromBackend(user.id);
      _statusController.add(AuthStatus.authenticated);
      return profile;
    } catch (e) {
      debugPrint('❌ [SupabaseAuthRepository] login error: $e');
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('⚠️ [SupabaseAuthRepository] logout exception (continuing): $e');
    } finally {
      _currentProfile = null;
      UserAccount.reset();
      _statusController.add(AuthStatus.unauthenticated);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'soama://auth-callback',
    );
  }

  @override
  Future<UserProfile> verifyOtp({
    required String email,
    required String token,
  }) async {
    final res = await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.signup,
    );

    final user = res.user;
    if (user == null) {
      throw const AuthException('OTP verification failed.');
    }

    final profile = await _syncProfileFromBackend(user.id);
    _statusController.add(AuthStatus.authenticated);
    return profile;
  }

  @override
  Future<UserProfile> upsertProfile(UserProfile profile) async {
    // Retry up to 3 times with exponential backoff
    Object? lastError;
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        await _client
            .from(SupabaseConfig.tableProfiles)
            .upsert(profile.toJson());
        _currentProfile = profile;
        return profile;
      } catch (e) {
        lastError = e;
        await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }
    throw lastError ?? const AuthException('Failed to upsert profile after retries.');
  }

  @override
  Future<ProviderProfileData?> fetchProviderProfile(String userId) async {
    try {
      final data = await _client
          .from(SupabaseConfig.tableProviderProfiles)
          .select('*, ${SupabaseConfig.tableProviderServices}(*)')
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return null;

      final servicesRaw = data[SupabaseConfig.tableProviderServices] as List<dynamic>? ?? [];
      final offerings = servicesRaw.map((s) {
        final map = s as Map<String, dynamic>;
        final minor = map['base_price_minor_units'] as num? ?? 0;
        final major = (minor / 100).round();
        return ProviderServiceOffering(
          id: map['id'] as String,
          title: map['title'] as String,
          description: map['description'] as String? ?? '',
          price: '₦$major',
          priceAmount: major,
          duration: '1-3 hrs',
        );
      }).toList();

      final statusStr = data['verification_status'] as String? ?? 'incomplete';
      ProviderVerificationStatus status;
      switch (statusStr) {
        case 'approved':
          status = ProviderVerificationStatus.verified;
          break;
        case 'pending_verification':
          status = ProviderVerificationStatus.pending;
          break;
        default:
          status = ProviderVerificationStatus.unverified;
          break;
      }

      return ProviderProfileData(
        providerId: data['id'] as String,
        businessName: data['business_name'] as String? ?? 'Provider Business',
        profession: 'Specialist',
        categoryId: 'general',
        categoryTitle: 'General Service',
        bio: data['bio'] as String? ?? '',
        serviceArea: 'Warri / Effurun',
        verificationStatus: status,
        services: offerings,
        rating: (data['rating_avg'] as num?)?.toDouble() ?? 0.0,
        reviewCount: data['rating_count'] as int? ?? 0,
        completedJobsCount: data['completed_jobs_count'] as int? ?? 0,
      );
    } catch (e) {
      debugPrint('ℹ️ [SupabaseAuthRepository] No provider profile found for $userId: $e');
      return null;
    }
  }

  @override
  Future<void> switchMode(AppMode mode) async {
    if (_currentProfile == null) return;
    final modeStr = mode == AppMode.provider ? 'provider' : 'customer';

    try {
      await _client
          .from(SupabaseConfig.tableProfiles)
          .update({'selected_app_mode': modeStr})
          .eq('id', _currentProfile!.id);

      _currentProfile = _currentProfile!.copyWith(selectedAppMode: modeStr);
      UserAccount.switchMode(mode);
    } catch (e) {
      debugPrint('⚠️ [SupabaseAuthRepository] switchMode update failed: $e');
      // Update local preference anyway
      UserAccount.switchMode(mode);
    }
  }

  Future<UserProfile> _syncProfileFromBackend(String userId) async {
    Map<String, dynamic>? data;
    try {
      data = await _client
          .from(SupabaseConfig.tableProfiles)
          .select()
          .eq('id', userId)
          .maybeSingle();
    } catch (e) {
      debugPrint('⚠️ [SupabaseAuthRepository] fetch profile query error: $e');
    }

    UserProfile profile;
    if (data != null) {
      profile = UserProfile.fromJson(data);
    } else {
      // Fallback profile if trigger is still pending
      final authUser = _client.auth.currentUser;
      profile = UserProfile(
        id: userId,
        fullName: authUser?.userMetadata?['full_name'] as String? ?? 'Soama User',
        email: authUser?.email ?? '',
        phone: authUser?.userMetadata?['phone'] as String?,
      );
      await upsertProfile(profile);
    }

    _currentProfile = profile;
    final providerProfile = await fetchProviderProfile(userId);
    _syncSharedModels(profile, providerProfile);
    return profile;
  }

  void _syncSharedModels(UserProfile profile, ProviderProfileData? providerProfile) {
    CustomerProfile.current = CustomerProfile.current.copyWith(
      fullName: profile.fullName,
      email: profile.email,
      phoneNumber: profile.phone ?? CustomerProfile.current.phoneNumber,
      avatarUrl: profile.avatarUrl,
    );

    final appMode = profile.selectedAppMode == 'provider'
        ? AppMode.provider
        : AppMode.customer;

    UserAccount.current = UserAccount(
      id: profile.id,
      fullName: profile.fullName,
      email: profile.email,
      phoneNumber: profile.phone ?? '+234 803 000 0000',
      avatarUrl: profile.avatarUrl,
      hasCustomerCapability: true,
      hasProviderCapability: providerProfile != null,
      currentMode: appMode,
      providerProfile: providerProfile,
    );
  }

  void dispose() {
    _authSubscription?.cancel();
    _statusController.close();
  }
}

/// In-memory repository used when Supabase credentials are not supplied
/// or during automated widget testing.
class InMemoryAuthRepository implements AuthRepository {
  final StreamController<AuthStatus> _statusController =
      StreamController<AuthStatus>.broadcast();

  UserProfile? _currentProfile = const UserProfile(
    id: 'usr-warri-01',
    fullName: 'Kolawole Adams',
    email: 'kolawole.adams@soama.ng',
    phone: '+234 803 123 4567',
    selectedAppMode: 'customer',
  );

  bool _isAuthenticated = true;

  @override
  Stream<AuthStatus> get authStateChanges => _statusController.stream;

  @override
  UserProfile? get currentUserProfile => _currentProfile;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  String? get currentUserId => _currentProfile?.id;

  @override
  Future<void> restoreSession() async {
    _statusController.add(
      _isAuthenticated ? AuthStatus.authenticated : AuthStatus.unauthenticated,
    );
  }

  @override
  Future<UserProfile> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    if (email.contains('existing@soama.ng')) {
      throw const AuthException('An account with this email already exists.');
    }

    final newProfile = UserProfile(
      id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
      fullName: fullName,
      email: email,
      phone: phone,
      selectedAppMode: 'customer',
    );

    _currentProfile = newProfile;
    _isAuthenticated = true;

    CustomerProfile.current = CustomerProfile.current.copyWith(
      fullName: fullName,
      email: email,
      phoneNumber: phone ?? CustomerProfile.current.phoneNumber,
    );

    UserAccount.current = UserAccount.current.copyWith(
      fullName: fullName,
      email: email,
      phoneNumber: phone ?? UserAccount.current.phoneNumber,
    );

    _statusController.add(AuthStatus.authenticated);
    return newProfile;
  }

  @override
  Future<UserProfile> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    if (password == 'wrongpassword' || password == 'wrong') {
      throw const AuthException('Invalid login credentials');
    }

    final profile = UserProfile(
      id: 'usr-login-${DateTime.now().millisecondsSinceEpoch}',
      fullName: email.contains('kolawole') ? 'Kolawole Adams' : 'Soama User',
      email: email,
      phone: '+234 803 123 4567',
      selectedAppMode: 'customer',
    );

    _currentProfile = profile;
    _isAuthenticated = true;

    CustomerProfile.current = CustomerProfile.current.copyWith(
      email: email,
      fullName: profile.fullName,
    );

    UserAccount.current = UserAccount.current.copyWith(
      email: email,
      fullName: profile.fullName,
    );

    _statusController.add(AuthStatus.authenticated);
    return profile;
  }

  @override
  Future<void> logout() async {
    _isAuthenticated = false;
    _currentProfile = null;
    UserAccount.reset();
    _statusController.add(AuthStatus.unauthenticated);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    // Simulated successful dispatch
  }

  @override
  Future<UserProfile> verifyOtp({
    required String email,
    required String token,
  }) async {
    if (token != '123456') {
      throw const AuthException('Invalid verification code.');
    }

    _isAuthenticated = true;
    _statusController.add(AuthStatus.authenticated);
    return _currentProfile ??
        UserProfile(
          id: 'usr-verified',
          fullName: 'Kolawole Adams',
          email: email,
        );
  }

  @override
  Future<UserProfile> upsertProfile(UserProfile profile) async {
    _currentProfile = profile;
    return profile;
  }

  @override
  Future<ProviderProfileData?> fetchProviderProfile(String userId) async {
    return UserAccount.current.providerProfile;
  }

  @override
  Future<void> switchMode(AppMode mode) async {
    UserAccount.switchMode(mode);
    if (_currentProfile != null) {
      _currentProfile = _currentProfile!.copyWith(
        selectedAppMode: mode == AppMode.provider ? 'provider' : 'customer',
      );
    }
  }
}
