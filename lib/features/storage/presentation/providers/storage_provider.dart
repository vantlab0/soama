import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/storage_repository.dart';

/// Global in-memory storage fallback instance for offline/test environments
final inMemoryStorageInstance = InMemoryStorageRepository();

/// Riverpod provider for the StorageRepository
final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  try {
    final client = Supabase.instance.client;
    return SupabaseStorageRepository(client);
  } catch (_) {
    return inMemoryStorageInstance;
  }
});

/// State for active profile photo upload
class ProfileUploadNotifier extends StateNotifier<AsyncValue<String?>> {
  final StorageRepository _repository;

  ProfileUploadNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<String?> uploadPhoto({
    required String userId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final url = await _repository.uploadProfilePhoto(
        userId: userId,
        bytes: bytes,
        fileName: fileName,
      );
      state = AsyncValue.data(url);
      return url;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> removePhoto({
    required String userId,
    required String currentUrl,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteProfilePhoto(
        userId: userId,
        currentUrl: currentUrl,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

final profileUploadProvider =
    StateNotifierProvider<ProfileUploadNotifier, AsyncValue<String?>>((ref) {
  final repo = ref.watch(storageRepositoryProvider);
  return ProfileUploadNotifier(repo);
});

/// State for active service image upload
class ServiceImageUploadNotifier extends StateNotifier<AsyncValue<String?>> {
  final StorageRepository _repository;

  ServiceImageUploadNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<String?> uploadImage({
    required String providerId,
    required String serviceId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final url = await _repository.uploadServiceImage(
        providerId: providerId,
        serviceId: serviceId,
        bytes: bytes,
        fileName: fileName,
      );
      state = AsyncValue.data(url);
      return url;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> removeImage({
    required String providerId,
    required String serviceId,
    required String currentUrl,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteServiceImage(
        providerId: providerId,
        serviceId: serviceId,
        currentUrl: currentUrl,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

final serviceImageUploadProvider =
    StateNotifierProvider<ServiceImageUploadNotifier, AsyncValue<String?>>((ref) {
  final repo = ref.watch(storageRepositoryProvider);
  return ServiceImageUploadNotifier(repo);
});
