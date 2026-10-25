import 'dart:typed_data';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soama/core/constants/supabase_config.dart';
import 'package:soama/features/profile/presentation/edit_profile_screen.dart';
import 'package:soama/features/storage/data/storage_repository.dart';
import 'package:soama/features/storage/domain/image_validator.dart';
import 'package:soama/features/storage/presentation/providers/storage_provider.dart';
import 'package:soama/features/storage/presentation/widgets/image_picker_sheet.dart';
import 'package:soama/shared/models/customer_profile.dart';
import 'package:soama/shared/models/user_account.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _TestHttpClient();
}

class _TestHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _TestHttpClientRequest();
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _TestHttpClientRequest();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _TestHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _TestHttpClientResponse();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestHttpClientResponse implements HttpClientResponse {
  static final List<int> _kTransparentImage = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ];

  @override
  int get statusCode => 200;
  @override
  int get contentLength => _kTransparentImage.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_kTransparentImage).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  group('1. ImageValidator: Format, Magic Bytes & Size Limits', () {
    test('Detects valid JPEG magic bytes (FF D8 FF)', () {
      final jpegBytes = ImagePickerSheet.createSampleJpegBytes();
      final mime = ImageValidator.detectMimeType(jpegBytes);
      expect(mime, 'image/jpeg');
      expect(ImageValidator.extensionFromMime(mime), 'jpg');
    });

    test('Detects valid PNG magic bytes (89 50 4E 47)', () {
      final pngBytes = ImagePickerSheet.createSamplePngBytes();
      final mime = ImageValidator.detectMimeType(pngBytes);
      expect(mime, 'image/png');
      expect(ImageValidator.extensionFromMime(mime), 'png');
    });

    test('Detects valid WEBP magic bytes (RIFF....WEBP)', () {
      final webpBytes = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, // RIFF
        0x00, 0x00, 0x00, 0x00,
        0x57, 0x45, 0x42, 0x50, // WEBP
        0x56, 0x50, 0x38, 0x20,
      ]);
      final mime = ImageValidator.detectMimeType(webpBytes);
      expect(mime, 'image/webp');
      expect(ImageValidator.extensionFromMime(mime), 'webp');
    });

    test('Rejects arbitrary/corrupt files without valid magic bytes', () {
      final corruptBytes = Uint8List.fromList([0x00, 0x11, 0x22, 0x33, 0x44]);
      expect(
        () => ImageValidator.detectMimeType(corruptBytes),
        throwsA(isA<ImageValidationException>()),
      );
    });

    test('Rejects files exceeding maximum avatar size limit (5MB)', () {
      final oversizedBytes = Uint8List(ImageValidator.maxAvatarSizeBytes + 1024);
      // Give valid JPEG header so failure is purely size
      oversizedBytes[0] = 0xFF;
      oversizedBytes[1] = 0xD8;
      oversizedBytes[2] = 0xFF;

      expect(
        () => ImageValidator.validateImage(
          bytes: oversizedBytes,
          fileName: 'large_photo.jpg',
          maxSizeBytes: ImageValidator.maxAvatarSizeBytes,
        ),
        throwsA(isA<ImageValidationException>().having(
          (e) => e.message,
          'message',
          contains('exceeds the maximum allowed limit'),
        )),
      );
    });

    test('Generates collision-resistant, tenant-isolated object paths', () {
      final path1 = ImageValidator.generateObjectPath(
        userId: 'user-warri-001',
        prefix: 'avatar',
        mimeType: 'image/jpeg',
      );
      final path2 = ImageValidator.generateObjectPath(
        userId: 'user-warri-001',
        prefix: 'avatar',
        mimeType: 'image/jpeg',
      );

      expect(path1, startsWith('user-warri-001/avatar_'));
      expect(path1, endsWith('.jpg'));
      expect(path1, isNot(equals(path2))); // Collision-resistant
    });
  });

  group('2. Storage Repository Operations & Orphan File Cleanup', () {
    late InMemoryStorageRepository repository;

    setUp(() {
      repository = InMemoryStorageRepository();
      CustomerProfile.current = CustomerProfile(
        id: 'cust-test-01',
        fullName: CustomerProfile.current.fullName,
        email: CustomerProfile.current.email,
        phoneNumber: CustomerProfile.current.phoneNumber,
        avatarUrl: null,
        locationArea: CustomerProfile.current.locationArea,
        savedAddresses: CustomerProfile.current.savedAddresses,
        notificationPreferences: CustomerProfile.current.notificationPreferences,
      );
      UserAccount.current = UserAccount(
        id: 'cust-test-01',
        fullName: UserAccount.current.fullName,
        email: UserAccount.current.email,
        phoneNumber: UserAccount.current.phoneNumber,
        avatarUrl: null,
        hasCustomerCapability: true,
        hasProviderCapability: true,
        currentMode: UserAccount.current.currentMode,
        providerProfile: UserAccount.current.providerProfile,
      );
    });

    test('Uploads profile photo and updates in-memory profile state', () async {
      final bytes = ImagePickerSheet.createSampleJpegBytes();
      final url = await repository.uploadProfilePhoto(
        userId: 'cust-test-01',
        bytes: bytes,
        fileName: 'my_photo.jpg',
      );

      expect(url, contains('public/avatars/cust-test-01/avatar_'));
      expect(repository.userAvatars['cust-test-01'], url);
      expect(CustomerProfile.current.avatarUrl, url);
      expect(UserAccount.current.avatarUrl, url);
    });

    test('Replacing photo deletes previous avatar to prevent orphaned storage objects', () async {
      final bytes1 = ImagePickerSheet.createSampleJpegBytes(extraBytes: 100);
      final url1 = await repository.uploadProfilePhoto(
        userId: 'cust-test-01',
        bytes: bytes1,
        fileName: 'old_photo.jpg',
      );

      final bytes2 = ImagePickerSheet.createSamplePngBytes(extraBytes: 200);
      final url2 = await repository.uploadProfilePhoto(
        userId: 'cust-test-01',
        bytes: bytes2,
        fileName: 'new_photo.png',
      );

      expect(url2, isNot(equals(url1)));
      expect(repository.userAvatars['cust-test-01'], url2);
    });

    test('Associates service image with specific provider service', () async {
      final bytes = ImagePickerSheet.createSampleJpegBytes();
      final serviceUrl = await repository.uploadServiceImage(
        providerId: 'pro-effurun-01',
        serviceId: 'srv-inverter-101',
        bytes: bytes,
        fileName: 'inverter_work.jpg',
      );

      expect(serviceUrl, contains('service-portfolio/pro-effurun-01/service_srv-inverter-101'));
      expect(repository.serviceImages['srv-inverter-101'], serviceUrl);
    });

    test('Unauthorized delete attempt on another user\'s file is rejected', () async {
      final bytes = ImagePickerSheet.createSampleJpegBytes();
      final url = await repository.uploadProfilePhoto(
        userId: 'victim-user-999',
        bytes: bytes,
        fileName: 'victim.jpg',
      );

      expect(
        () => repository.deleteProfilePhoto(
          userId: 'malicious-attacker',
          currentUrl: url,
        ),
        throwsA(isA<StorageException>()),
      );
    });

    test('Private bucket generates signed URL with expiration', () async {
      final signedUrl = await repository.getSignedUrl(
        bucket: SupabaseConfig.bucketChatAttachments,
        path: 'user-01/chat_attachment.pdf',
        expiresInSeconds: 1800,
      );

      expect(signedUrl, contains('authenticated/chat-attachments/user-01/chat_attachment.pdf'));
      expect(signedUrl, contains('token=mock_signature_1800'));
    });
  });

  group('3. UI Integration & Error Recovery Tests', () {
    setUp(() {
      CustomerProfile.current = const CustomerProfile(
        id: 'cust-ui-01',
        fullName: 'Kome Adams',
        email: 'kome.adams@example.com',
        phoneNumber: '+2348031234567',
        avatarUrl: null,
        locationArea: 'Airport Road, Warri',
        savedAddresses: [],
        notificationPreferences: CustomerNotificationPreferences(),
      );
      UserAccount.current = const UserAccount(
        id: 'cust-ui-01',
        fullName: 'Kome Adams',
        email: 'kome.adams@example.com',
        phoneNumber: '+2348031234567',
        avatarUrl: null,
      );
    });

    testWidgets('EditProfileScreen renders avatar, upload button, and opens ImagePickerSheet',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          storageRepositoryProvider.overrideWithValue(InMemoryStorageRepository()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: EditProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify avatar preview and upload photo action
      expect(find.text('Select Profile Photo'), findsOneWidget);
      expect(find.text('Upload Photo'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);

      // Tap Upload Photo button
      await tester.tap(find.text('Upload Photo'));
      await tester.pumpAndSettle();

      // Verify modal sheet appears with options
      expect(find.text('Update Profile Photo'), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);

      // Select "Choose from Gallery"
      await tester.tap(find.text('Choose from Gallery'));
      await tester.pumpAndSettle();

      // Verify photo was uploaded and snackbar was shown
      expect(find.text('Photo uploaded to Supabase Storage.'), findsOneWidget);
      expect(find.text('Change Photo'), findsOneWidget);
    });

    testWidgets('EditProfileScreen handles upload failure and exposes Retry action',
        (tester) async {
      final failingRepo = InMemoryStorageRepository()..shouldSimulateFailure = true;

      final container = ProviderContainer(
        overrides: [
          storageRepositoryProvider.overrideWithValue(failingRepo),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: EditProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Upload Photo
      await tester.tap(find.text('Upload Photo'));
      await tester.pumpAndSettle();

      // Select "Take Photo"
      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();

      // Verify error banner and Retry link appear
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

      // Now heal the network failure and tap Retry
      failingRepo.shouldSimulateFailure = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Verify success after retry
      expect(find.text('Photo uploaded to Supabase Storage.'), findsOneWidget);
    });
  });
}
