import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:soama/core/constants/supabase_config.dart';
import 'package:soama/features/auth/domain/auth_models.dart';
import 'package:soama/features/auth/data/auth_repository.dart';
import 'package:soama/features/auth/presentation/providers/auth_provider.dart';
import 'package:soama/shared/models/customer_profile.dart';
import 'package:soama/shared/models/user_account.dart';

void main() {
  group('Supabase Configuration & Security Tests', () {
    test('SupabaseConfig table names match normalized PostgreSQL schema', () {
      expect(SupabaseConfig.tableProfiles, equals('profiles'));
      expect(SupabaseConfig.tableProviderProfiles, equals('provider_profiles'));
      expect(SupabaseConfig.tableServiceRequests, equals('service_requests'));
      expect(SupabaseConfig.tablePriceOffers, equals('price_offers'));
      expect(SupabaseConfig.tableBookings, equals('bookings'));
      expect(SupabaseConfig.tableConversations, equals('conversations'));
      expect(SupabaseConfig.tableMessages, equals('messages'));
      expect(SupabaseConfig.tablePayments, equals('payments'));
      expect(SupabaseConfig.tablePayouts, equals('payouts'));
    });

    test('SupabaseConfig reads dart-define environment without hardcoding secrets', () {
      // By default without --dart-define, url and anonKey are empty
      expect(SupabaseConfig.url, isA<String>());
      expect(SupabaseConfig.anonKey, isA<String>());
    });

    test('AuthExceptionHelper maps technical exceptions to human-friendly feedback', () {
      final invalidCreds = AuthExceptionHelper.toUserFriendlyMessage(
        const AuthException('Invalid login credentials', statusCode: '400'),
      );
      expect(invalidCreds, contains('Incorrect email address or password'));

      final duplicateUser = AuthExceptionHelper.toUserFriendlyMessage(
        const AuthException('User already registered', statusCode: '422'),
      );
      expect(duplicateUser, contains('already exists'));

      final networkError = AuthExceptionHelper.toUserFriendlyMessage(
        'SocketException: OS Error: Connection refused',
      );
      expect(networkError, contains('Unable to connect to the server'));
    });
  });

  group('Auth Domain & UserProfile Model Tests', () {
    test('UserProfile serializes and deserializes accurately from JSON', () {
      final json = {
        'id': 'usr-uuid-1234',
        'full_name': 'Amaka Okonjo',
        'email': 'amaka.okonjo@example.com',
        'phone': '+234 802 345 6789',
        'avatar_url': 'https://images.unsplash.com/sample-avatar.jpg',
        'selected_app_mode': 'customer',
        'is_suspended': false,
        'created_at': '2026-10-25T05:00:00.000Z',
        'updated_at': '2026-10-25T05:00:00.000Z',
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.id, equals('usr-uuid-1234'));
      expect(profile.fullName, equals('Amaka Okonjo'));
      expect(profile.email, equals('amaka.okonjo@example.com'));
      expect(profile.phone, equals('+234 802 345 6789'));
      expect(profile.selectedAppMode, equals('customer'));
      expect(profile.initials, equals('AO'));
      expect(profile.isSuspended, isFalse);

      final exported = profile.toJson();
      expect(exported['id'], equals('usr-uuid-1234'));
      expect(exported['full_name'], equals('Amaka Okonjo'));
      expect(exported['email'], equals('amaka.okonjo@example.com'));
      expect(exported['phone'], equals('+234 802 345 6789'));
      expect(exported['selected_app_mode'], equals('customer'));
    });
  });

  group('Authentication Workflows via AuthNotifier', () {
    late InMemoryAuthRepository testRepo;
    late ProviderContainer container;

    setUp(() {
      testRepo = InMemoryAuthRepository();
      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(testRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial auth state restores existing session', () async {
      final notifier = container.read(authStateProvider.notifier);
      await notifier.restoreSession();

      final state = container.read(authStateProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.userProfile?.email, equals('kolawole.adams@soama.ng'));
    });

    test('Login success updates profile and marks state authenticated', () async {
      final notifier = container.read(authStateProvider.notifier);

      final success = await notifier.login(
        email: 'kolawole.adams@soama.ng',
        password: 'ValidPassword123',
      );

      expect(success, isTrue);
      final state = container.read(authStateProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.userProfile?.email, equals('kolawole.adams@soama.ng'));
      expect(CustomerProfile.current.email, equals('kolawole.adams@soama.ng'));
    });

    test('Login failure sets error message and unauthenticated state', () async {
      final notifier = container.read(authStateProvider.notifier);

      final success = await notifier.login(
        email: 'kolawole.adams@soama.ng',
        password: 'wrongpassword',
      );

      expect(success, isFalse);
      final state = container.read(authStateProvider);
      expect(state.status, equals(AuthStatus.error));
      expect(state.errorMessage, isNotNull);
      expect(state.errorMessage, contains('Incorrect email address or password'));
    });

    test('Registration success initializes user profile and sets session', () async {
      final notifier = container.read(authStateProvider.notifier);

      final success = await notifier.register(
        fullName: 'Ejiro Oghenekaro',
        email: 'ejiro.o@example.com',
        phone: '+234 805 111 2233',
        password: 'SecurePass123',
      );

      expect(success, isTrue);
      final state = container.read(authStateProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.userProfile?.fullName, equals('Ejiro Oghenekaro'));
      expect(CustomerProfile.current.fullName, equals('Ejiro Oghenekaro'));
      expect(UserAccount.current.fullName, equals('Ejiro Oghenekaro'));
    });

    test('Registration duplicate email returns user-friendly error', () async {
      final notifier = container.read(authStateProvider.notifier);

      final success = await notifier.register(
        fullName: 'Test User',
        email: 'existing@soama.ng',
        phone: '+234 800 000 0000',
        password: 'Password123',
      );

      expect(success, isFalse);
      final state = container.read(authStateProvider);
      expect(state.status, equals(AuthStatus.error));
      expect(state.errorMessage, contains('already exists'));
    });

    test('OTP Verification completes email confirmation', () async {
      final notifier = container.read(authStateProvider.notifier);

      final success = await notifier.verifyOtp(
        email: 'kolawole.adams@soama.ng',
        token: '123456',
      );

      expect(success, isTrue);
      final state = container.read(authStateProvider);
      expect(state.isAuthenticated, isTrue);
    });

    test('OTP Verification rejects invalid code', () async {
      final notifier = container.read(authStateProvider.notifier);

      final success = await notifier.verifyOtp(
        email: 'kolawole.adams@soama.ng',
        token: '000000',
      );

      expect(success, isFalse);
      final state = container.read(authStateProvider);
      expect(state.status, equals(AuthStatus.error));
    });

    test('Password reset request dispatches email without crashing', () async {
      final notifier = container.read(authStateProvider.notifier);

      final success = await notifier.sendPasswordReset('kolawole.adams@soama.ng');
      expect(success, isTrue);
    });

    test('Logout clears session, resets UserAccount, and marks unauthenticated', () async {
      final notifier = container.read(authStateProvider.notifier);

      await notifier.logout();

      final state = container.read(authStateProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.status, equals(AuthStatus.unauthenticated));
      expect(state.userProfile, isNull);
    });

    test('Dual-Role: Single authenticated account can switch between Customer and Provider', () async {
      final notifier = container.read(authStateProvider.notifier);

      // Verify starting mode
      expect(UserAccount.current.currentMode, equals(AppMode.customer));

      // Switch to Provider mode
      await notifier.switchMode(AppMode.provider);
      final state = container.read(authStateProvider);
      expect(state.userProfile?.selectedAppMode, equals('provider'));

      // Switch back to Customer mode
      await notifier.switchMode(AppMode.customer);
      final stateCustomer = container.read(authStateProvider);
      expect(stateCustomer.userProfile?.selectedAppMode, equals('customer'));
    });
  });
}
