import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/models/service_category.dart';
import '../../data/categories_repository.dart';

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  final client = SupabaseService.client;
  if (client != null) {
    return SupabaseCategoriesRepository(client);
  }
  return InMemoryCategoriesRepository();
});

class CategoriesNotifier extends AsyncNotifier<List<ServiceCategory>> {
  @override
  Future<List<ServiceCategory>> build() async {
    final repo = ref.watch(categoriesRepositoryProvider);
    return repo.getCategories();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(categoriesRepositoryProvider);
      return repo.getCategories(forceRefresh: true);
    });
  }
}

final categoriesProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<ServiceCategory>>(() {
  return CategoriesNotifier();
});
