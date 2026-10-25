import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_config.dart';
import '../../../shared/models/customer_profile.dart';
import '../../../shared/models/user_account.dart';
import '../domain/image_validator.dart';

/// Abstract storage contract for managing profile avatars, service images,
/// and authenticated private file attachments.
abstract class StorageRepository {
  /// Uploads a profile avatar to the public avatars bucket,
  /// updates `profiles.avatar_url`, and cleans up obsolete avatars.
  Future<String> uploadProfilePhoto({
    required String userId,
    required Uint8List bytes,
    required String fileName,
  });

  /// Deletes the user's current avatar and updates `profiles.avatar_url` to null.
  Future<void> deleteProfilePhoto({
    required String userId,
    required String currentUrl,
  });

  /// Uploads a service offering photo to the service portfolio bucket,
  /// updates `provider_services.image_url`, and cleans up any previous photo.
  Future<String> uploadServiceImage({
    required String providerId,
    required String serviceId,
    required Uint8List bytes,
    required String fileName,
  });

  /// Deletes a service image and updates `provider_services.image_url` to null.
  Future<void> deleteServiceImage({
    required String providerId,
    required String serviceId,
    required String currentUrl,
  });

  /// Uploads a general portfolio/gallery image for the provider.
  Future<String> uploadPortfolioImage({
    required String providerId,
    required Uint8List bytes,
    required String fileName,
  });

  /// Deletes a portfolio/gallery image.
  Future<void> deletePortfolioImage({
    required String providerId,
    required String imageUrl,
  });

  /// Creates an authenticated signed URL for a private bucket (e.g. chat attachments).
  Future<String> getSignedUrl({
    required String bucket,
    required String path,
    int expiresInSeconds = 3600,
  });

  /// Uploads a chat attachment image or PDF to the private chat-attachments bucket.
  Future<String> uploadChatAttachment({
    required String conversationId,
    required String userId,
    required Uint8List bytes,
    required String fileName,
  });

  /// Uploads a provider KYC verification document to the private verification-documents bucket.
  Future<String> uploadVerificationDocument({
    required String providerId,
    required Uint8List bytes,
    required String fileName,
    required String documentType,
  });
}

/// Supabase Storage implementation interacting with real Supabase Storage buckets
/// and synchronized PostgreSQL tables.
class SupabaseStorageRepository implements StorageRepository {
  final SupabaseClient _client;

  SupabaseStorageRepository(this._client);

  @override
  Future<String> uploadProfilePhoto({
    required String userId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    // 1. Client-side validation: format, magic bytes, and 5MB limit
    final mimeType = ImageValidator.validateImage(
      bytes: bytes,
      fileName: fileName,
      maxSizeBytes: ImageValidator.maxAvatarSizeBytes,
    );

    // 2. Generate isolated collision-resistant path: `{userId}/avatar_{timestamp}_{hex}.{ext}`
    final objectPath = ImageValidator.generateObjectPath(
      userId: userId,
      prefix: 'avatar',
      mimeType: mimeType,
    );

    String? uploadedPath;
    try {
      // 3. Upload binary to avatars bucket
      await _client.storage.from(SupabaseConfig.bucketAvatars).uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ),
          );
      uploadedPath = objectPath;

      // 4. Retrieve public URL
      final publicUrl = _client.storage.from(SupabaseConfig.bucketAvatars).getPublicUrl(objectPath);

      // 5. Update user profile record in database
      await _client.from(SupabaseConfig.tableProfiles).update({
        'avatar_url': publicUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);

      // 6. Update local memory states
      if (CustomerProfile.current.id == userId) {
        CustomerProfile.current = CustomerProfile.current.copyWith(avatarUrl: publicUrl);
      }
      if (UserAccount.current.id == userId) {
        UserAccount.current = UserAccount.current.copyWith(avatarUrl: publicUrl);
      }

      return publicUrl;
    } catch (e) {
      debugPrint('❌ [SupabaseStorageRepository] uploadProfilePhoto error: $e');
      // Prevent orphaned storage objects: cleanup newly uploaded file if database update failed
      if (uploadedPath != null) {
        try {
          await _client.storage.from(SupabaseConfig.bucketAvatars).remove([uploadedPath]);
        } catch (_) {}
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteProfilePhoto({
    required String userId,
    required String currentUrl,
  }) async {
    try {
      final path = _extractPathFromUrl(currentUrl, SupabaseConfig.bucketAvatars);
      if (path != null && path.startsWith('$userId/')) {
        await _client.storage.from(SupabaseConfig.bucketAvatars).remove([path]);
      }

      await _client.from(SupabaseConfig.tableProfiles).update({
        'avatar_url': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);

      if (CustomerProfile.current.id == userId) {
        CustomerProfile.current = CustomerProfile.current.copyWith(avatarUrl: null);
      }
      if (UserAccount.current.id == userId) {
        UserAccount.current = UserAccount.current.copyWith(avatarUrl: null);
      }
    } catch (e) {
      debugPrint('❌ [SupabaseStorageRepository] deleteProfilePhoto error: $e');
      rethrow;
    }
  }

  @override
  Future<String> uploadServiceImage({
    required String providerId,
    required String serviceId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    // 1. Validation (max 10MB)
    final mimeType = ImageValidator.validateImage(
      bytes: bytes,
      fileName: fileName,
      maxSizeBytes: ImageValidator.maxPortfolioSizeBytes,
    );

    // 2. Path: `{providerId}/service_{serviceId}_{timestamp}_{hex}.{ext}`
    final objectPath = ImageValidator.generateObjectPath(
      userId: providerId,
      prefix: 'service_${serviceId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}',
      mimeType: mimeType,
    );

    String? uploadedPath;
    try {
      await _client.storage.from(SupabaseConfig.bucketServicePortfolio).uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ),
          );
      uploadedPath = objectPath;

      final publicUrl = _client.storage
          .from(SupabaseConfig.bucketServicePortfolio)
          .getPublicUrl(objectPath);

      // Verify provider ownership before updating service
      await _client
          .from(SupabaseConfig.tableProviderServices)
          .update({
            'image_url': publicUrl,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', serviceId)
          .eq('provider_id', providerId);

      return publicUrl;
    } catch (e) {
      debugPrint('❌ [SupabaseStorageRepository] uploadServiceImage error: $e');
      if (uploadedPath != null) {
        try {
          await _client.storage.from(SupabaseConfig.bucketServicePortfolio).remove([uploadedPath]);
        } catch (_) {}
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteServiceImage({
    required String providerId,
    required String serviceId,
    required String currentUrl,
  }) async {
    try {
      final path = _extractPathFromUrl(currentUrl, SupabaseConfig.bucketServicePortfolio);
      if (path != null && path.startsWith('$providerId/')) {
        await _client.storage.from(SupabaseConfig.bucketServicePortfolio).remove([path]);
      }

      await _client
          .from(SupabaseConfig.tableProviderServices)
          .update({
            'image_url': null,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', serviceId)
          .eq('provider_id', providerId);
    } catch (e) {
      debugPrint('❌ [SupabaseStorageRepository] deleteServiceImage error: $e');
      rethrow;
    }
  }

  @override
  Future<String> uploadPortfolioImage({
    required String providerId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final mimeType = ImageValidator.validateImage(
      bytes: bytes,
      fileName: fileName,
      maxSizeBytes: ImageValidator.maxPortfolioSizeBytes,
    );

    final objectPath = ImageValidator.generateObjectPath(
      userId: providerId,
      prefix: 'portfolio',
      mimeType: mimeType,
    );

    await _client.storage.from(SupabaseConfig.bucketServicePortfolio).uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: true,
          ),
        );

    final publicUrl = _client.storage
        .from(SupabaseConfig.bucketServicePortfolio)
        .getPublicUrl(objectPath);

    return publicUrl;
  }

  @override
  Future<void> deletePortfolioImage({
    required String providerId,
    required String imageUrl,
  }) async {
    final path = _extractPathFromUrl(imageUrl, SupabaseConfig.bucketServicePortfolio);
    if (path != null && path.startsWith('$providerId/')) {
      await _client.storage.from(SupabaseConfig.bucketServicePortfolio).remove([path]);
    }
  }

  @override
  Future<String> getSignedUrl({
    required String bucket,
    required String path,
    int expiresInSeconds = 3600,
  }) async {
    return await _client.storage.from(bucket).createSignedUrl(path, expiresInSeconds);
  }

  @override
  Future<String> uploadChatAttachment({
    required String conversationId,
    required String userId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final mimeType = ImageValidator.validateAttachment(
      bytes: bytes,
      fileName: fileName,
      maxSizeBytes: 10 * 1024 * 1024,
    );

    final cleanConvId = conversationId.replaceAll(RegExp(r'[^a-zA-Z0-9\-_]'), '');
    final cleanUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9\-_]'), '');
    final ext = ImageValidator.extensionFromMime(mimeType);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final objectPath = '$cleanConvId/$cleanUserId/attach_$timestamp.$ext';

    await _client.storage.from(SupabaseConfig.bucketChatAttachments).uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );

    // Default 7 days signed URL for secure in-app preview
    return await _client.storage.from(SupabaseConfig.bucketChatAttachments).createSignedUrl(
          objectPath,
          60 * 60 * 24 * 7,
        );
  }

  @override
  Future<String> uploadVerificationDocument({
    required String providerId,
    required Uint8List bytes,
    required String fileName,
    required String documentType,
  }) async {
    final mimeType = ImageValidator.validateAttachment(
      bytes: bytes,
      fileName: fileName,
      maxSizeBytes: 15 * 1024 * 1024,
    );

    final cleanProviderId = providerId.replaceAll(RegExp(r'[^a-zA-Z0-9\-_]'), '');
    final cleanDocType = documentType.replaceAll(RegExp(r'[^a-zA-Z0-9\-_]'), '');
    final ext = ImageValidator.extensionFromMime(mimeType);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final objectPath = '$cleanProviderId/kyc_${cleanDocType}_$timestamp.$ext';

    await _client.storage.from(SupabaseConfig.bucketVerificationDocs).uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );

    return await _client.storage.from(SupabaseConfig.bucketVerificationDocs).createSignedUrl(
          objectPath,
          60 * 60 * 24 * 30, // 30 days
        );
  }

  String? _extractPathFromUrl(String url, String bucket) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final bucketIdx = segments.indexOf(bucket);
      if (bucketIdx != -1 && bucketIdx + 1 < segments.length) {
        return segments.sublist(bucketIdx + 1).join('/');
      }
    } catch (_) {}
    return null;
  }
}

/// In-memory mock storage repository for automated tests, offline support,
/// and local verification.
class InMemoryStorageRepository implements StorageRepository {
  final Map<String, Map<String, Uint8List>> _bucketStorage = {
    SupabaseConfig.bucketAvatars: {},
    SupabaseConfig.bucketServicePortfolio: {},
    SupabaseConfig.bucketVerificationDocs: {},
    SupabaseConfig.bucketChatAttachments: {},
  };

  /// Tracks active user avatars
  final Map<String, String> userAvatars = {};

  /// Tracks active service images: `serviceId -> imageUrl`
  final Map<String, String> serviceImages = {};

  /// Tracks provider gallery images: `providerId -> [imageUrl]`
  final Map<String, List<String>> providerGalleries = {};

  bool shouldSimulateFailure = false;

  @override
  Future<String> uploadProfilePhoto({
    required String userId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (shouldSimulateFailure) {
      throw const StorageException('Simulated storage upload network failure.');
    }

    // Validation
    final mimeType = ImageValidator.validateImage(
      bytes: bytes,
      fileName: fileName,
      maxSizeBytes: ImageValidator.maxAvatarSizeBytes,
    );

    final objectPath = ImageValidator.generateObjectPath(
      userId: userId,
      prefix: 'avatar',
      mimeType: mimeType,
    );

    // Save in bucket
    _bucketStorage[SupabaseConfig.bucketAvatars]![objectPath] = bytes;

    final fakeUrl = 'https://supabase.local/storage/v1/object/public/avatars/$objectPath';

    // Cleanup previous avatar to prevent orphaned files
    final prevUrl = userAvatars[userId];
    if (prevUrl != null) {
      final oldPath = _extractMockPath(prevUrl);
      if (oldPath != null) {
        _bucketStorage[SupabaseConfig.bucketAvatars]!.remove(oldPath);
      }
    }

    userAvatars[userId] = fakeUrl;

    if (CustomerProfile.current.id == userId) {
      CustomerProfile.current = CustomerProfile.current.copyWith(avatarUrl: fakeUrl);
    }
    if (UserAccount.current.id == userId) {
      UserAccount.current = UserAccount.current.copyWith(avatarUrl: fakeUrl);
    }

    return fakeUrl;
  }

  @override
  Future<void> deleteProfilePhoto({
    required String userId,
    required String currentUrl,
  }) async {
    final path = _extractMockPath(currentUrl);
    if (path != null) {
      if (!path.startsWith('$userId/')) {
        throw const StorageException('Unauthorized: Cannot delete files owned by another user.');
      }
      _bucketStorage[SupabaseConfig.bucketAvatars]!.remove(path);
    }
    userAvatars.remove(userId);

    if (CustomerProfile.current.id == userId) {
      CustomerProfile.current = CustomerProfile.current.copyWith(avatarUrl: null);
    }
    if (UserAccount.current.id == userId) {
      UserAccount.current = UserAccount.current.copyWith(avatarUrl: null);
    }
  }

  @override
  Future<String> uploadServiceImage({
    required String providerId,
    required String serviceId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (shouldSimulateFailure) {
      throw const StorageException('Network error uploading service image.');
    }

    final mimeType = ImageValidator.validateImage(
      bytes: bytes,
      fileName: fileName,
      maxSizeBytes: ImageValidator.maxPortfolioSizeBytes,
    );

    final objectPath = ImageValidator.generateObjectPath(
      userId: providerId,
      prefix: 'service_$serviceId',
      mimeType: mimeType,
    );

    _bucketStorage[SupabaseConfig.bucketServicePortfolio]![objectPath] = bytes;

    final fakeUrl = 'https://supabase.local/storage/v1/object/public/service-portfolio/$objectPath';

    final prevUrl = serviceImages[serviceId];
    if (prevUrl != null) {
      final oldPath = _extractMockPath(prevUrl);
      if (oldPath != null) {
        _bucketStorage[SupabaseConfig.bucketServicePortfolio]!.remove(oldPath);
      }
    }

    serviceImages[serviceId] = fakeUrl;
    return fakeUrl;
  }

  @override
  Future<void> deleteServiceImage({
    required String providerId,
    required String serviceId,
    required String currentUrl,
  }) async {
    final path = _extractMockPath(currentUrl);
    if (path != null) {
      if (!path.startsWith('$providerId/')) {
        throw const StorageException('Unauthorized: Cannot delete images for another provider.');
      }
      _bucketStorage[SupabaseConfig.bucketServicePortfolio]!.remove(path);
    }
    serviceImages.remove(serviceId);
  }

  @override
  Future<String> uploadPortfolioImage({
    required String providerId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final mimeType = ImageValidator.validateImage(
      bytes: bytes,
      fileName: fileName,
      maxSizeBytes: ImageValidator.maxPortfolioSizeBytes,
    );

    final objectPath = ImageValidator.generateObjectPath(
      userId: providerId,
      prefix: 'portfolio',
      mimeType: mimeType,
    );

    _bucketStorage[SupabaseConfig.bucketServicePortfolio]![objectPath] = bytes;

    final fakeUrl = 'https://supabase.local/storage/v1/object/public/service-portfolio/$objectPath';
    providerGalleries.putIfAbsent(providerId, () => []).add(fakeUrl);
    return fakeUrl;
  }

  @override
  Future<void> deletePortfolioImage({
    required String providerId,
    required String imageUrl,
  }) async {
    final path = _extractMockPath(imageUrl);
    if (path != null) {
      if (!path.startsWith('$providerId/')) {
        throw const StorageException('Unauthorized: Cannot delete portfolio belonging to another.');
      }
      _bucketStorage[SupabaseConfig.bucketServicePortfolio]!.remove(path);
    }
    providerGalleries[providerId]?.remove(imageUrl);
  }

  @override
  Future<String> getSignedUrl({
    required String bucket,
    required String path,
    int expiresInSeconds = 3600,
  }) async {
    return 'https://supabase.local/storage/v1/object/authenticated/$bucket/$path?token=mock_signature_$expiresInSeconds';
  }

  @override
  Future<String> uploadChatAttachment({
    required String conversationId,
    required String userId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final mimeType = ImageValidator.validateAttachment(
      bytes: bytes,
      fileName: fileName,
      maxSizeBytes: 10 * 1024 * 1024,
    );
    final ext = ImageValidator.extensionFromMime(mimeType);
    final objectPath = '$conversationId/$userId/attach_${DateTime.now().millisecondsSinceEpoch}.$ext';
    _bucketStorage[SupabaseConfig.bucketChatAttachments]![objectPath] = bytes;
    return 'https://supabase.local/storage/v1/object/authenticated/${SupabaseConfig.bucketChatAttachments}/$objectPath?token=mock_chat_token';
  }

  @override
  Future<String> uploadVerificationDocument({
    required String providerId,
    required Uint8List bytes,
    required String fileName,
    required String documentType,
  }) async {
    final mimeType = ImageValidator.validateAttachment(
      bytes: bytes,
      fileName: fileName,
      maxSizeBytes: 15 * 1024 * 1024,
    );
    final ext = ImageValidator.extensionFromMime(mimeType);
    final objectPath = '$providerId/kyc_${documentType}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    _bucketStorage[SupabaseConfig.bucketVerificationDocs]![objectPath] = bytes;
    return 'https://supabase.local/storage/v1/object/authenticated/${SupabaseConfig.bucketVerificationDocs}/$objectPath?token=mock_kyc_token';
  }

  String? _extractMockPath(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.length >= 2) {
        return segments.sublist(segments.length - 2).join('/');
      }
    } catch (_) {}
    return null;
  }
}
