import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/models/service_provider.dart';
import '../../../../shared/models/user_account.dart';
import '../../data/provider_repository.dart';

final providerRepositoryProvider = Provider<ProviderRepository>((ref) {
  final client = SupabaseService.client;
  if (client != null) {
    return SupabaseProviderRepository(client);
  }
  return InMemoryProviderRepository();
});

/// Parameter class for provider discovery queries.
class ProviderQueryParams {
  final String? categoryId;
  final String? searchQuery;
  final int? maxPrice;
  final String? sortBy;

  const ProviderQueryParams({
    this.categoryId,
    this.searchQuery,
    this.maxPrice,
    this.sortBy,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProviderQueryParams &&
          runtimeType == other.runtimeType &&
          categoryId == other.categoryId &&
          searchQuery == other.searchQuery &&
          maxPrice == other.maxPrice &&
          sortBy == other.sortBy;

  @override
  int get hashCode =>
      categoryId.hashCode ^
      searchQuery.hashCode ^
      maxPrice.hashCode ^
      sortBy.hashCode;
}

/// Provider for searching marketplace professionals.
final marketplaceProvidersProvider =
    FutureProvider.family<List<ServiceProvider>, ProviderQueryParams>((ref, params) async {
  final repo = ref.watch(providerRepositoryProvider);
  return repo.searchProviders(
    categoryId: params.categoryId,
    searchQuery: params.searchQuery,
    maxPrice: params.maxPrice,
    sortBy: params.sortBy,
  );
});

/// Provider for fetching a single provider's detailed page.
final providerDetailsProvider =
    FutureProvider.family<ServiceProvider?, String>((ref, providerId) async {
  final repo = ref.watch(providerRepositoryProvider);
  return repo.getProviderById(providerId);
});

/// Async notifier managing the active provider's catalog of services.
class ProviderServicesNotifier
    extends StateNotifier<AsyncValue<List<ProviderServiceOffering>>> {
  final ProviderRepository _repository;
  final String _providerId;

  ProviderServicesNotifier(this._repository, this._providerId)
      : super(const AsyncValue.loading()) {
    loadServices();
  }

  Future<void> loadServices() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return _repository.getProviderServices(_providerId);
    });
  }

  Future<bool> addService({
    required String title,
    required String description,
    required int priceAmount,
    required String duration,
    String? imageUrl,
    String categoryId = 'repairs',
  }) async {
    final formattedPrice = '₦${priceAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    final offering = ProviderServiceOffering(
      id: 'pro-srv-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      price: formattedPrice,
      priceAmount: priceAmount,
      duration: duration,
      imageUrl: imageUrl,
    );

    try {
      final created = await _repository.addService(
        providerId: _providerId,
        service: offering,
        categoryId: categoryId,
      );

      final current = state.value ?? [];
      state = AsyncValue.data([...current, created]);

      // Update in-memory UserAccount for immediate local sync
      final account = UserAccount.current;
      if (account.providerProfile != null) {
        UserAccount.current = account.copyWith(
          providerProfile: account.providerProfile!.copyWith(
            services: [...account.providerProfile!.services, created],
          ),
        );
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateService(
    String serviceId, {
    required String title,
    required String description,
    required int priceAmount,
    required String duration,
    String? imageUrl,
  }) async {
    final formattedPrice = '₦${priceAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    final offering = ProviderServiceOffering(
      id: serviceId,
      title: title,
      description: description,
      price: formattedPrice,
      priceAmount: priceAmount,
      duration: duration,
      imageUrl: imageUrl,
    );

    try {
      final updated = await _repository.updateService(serviceId, offering);
      final current = state.value ?? [];
      state = AsyncValue.data(
        current.map((s) => s.id == serviceId ? updated : s).toList(),
      );

      final account = UserAccount.current;
      if (account.providerProfile != null) {
        final updatedList = account.providerProfile!.services
            .map((s) => s.id == serviceId ? updated : s)
            .toList();
        UserAccount.current = account.copyWith(
          providerProfile: account.providerProfile!.copyWith(services: updatedList),
        );
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteService(String serviceId) async {
    try {
      await _repository.deleteService(serviceId);
      final current = state.value ?? [];
      state = AsyncValue.data(current.where((s) => s.id != serviceId).toList());

      final account = UserAccount.current;
      if (account.providerProfile != null) {
        final updatedList = account.providerProfile!.services
            .where((s) => s.id != serviceId)
            .toList();
        UserAccount.current = account.copyWith(
          providerProfile: account.providerProfile!.copyWith(services: updatedList),
        );
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}

final providerServicesProvider = StateNotifierProvider.family<
    ProviderServicesNotifier,
    AsyncValue<List<ProviderServiceOffering>>,
    String>((ref, providerId) {
  final repo = ref.watch(providerRepositoryProvider);
  return ProviderServicesNotifier(repo, providerId);
});
