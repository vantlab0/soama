import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_config.dart';
import '../../../../shared/models/service_category.dart';

/// Helper mapping string icon identifiers from PostgreSQL to Flutter IconData.
class CategoryIconHelper {
  CategoryIconHelper._();

  static IconData fromString(String? iconName) {
    switch (iconName?.toLowerCase().trim()) {
      case 'cleaning_services_outlined':
      case 'cleaning':
        return Icons.cleaning_services_outlined;
      case 'plumbing_outlined':
      case 'plumbing':
        return Icons.plumbing_outlined;
      case 'electrical_services_outlined':
      case 'electrical':
      case 'bolt_outlined':
        return Icons.bolt_outlined;
      case 'carpenter_outlined':
      case 'carpentry':
        return Icons.carpenter_outlined;
      case 'format_paint_outlined':
      case 'painting':
        return Icons.format_paint_outlined;
      case 'home_repair_service_outlined':
      case 'appliance':
      case 'repairs':
      case 'handyman_outlined':
        return Icons.handyman_outlined;
      case 'ac_unit_outlined':
      case 'hvac':
        return Icons.ac_unit_outlined;
      case 'pest_control_outlined':
      case 'pest_control':
        return Icons.pest_control_outlined;
      case 'local_shipping_outlined':
      case 'moving':
        return Icons.local_shipping_outlined;
      case 'build_outlined':
      case 'mechanic':
        return Icons.build_outlined;
      case 'yard_outlined':
      case 'gardening':
        return Icons.yard_outlined;
      case 'spa_outlined':
      case 'beauty':
        return Icons.spa_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  static String getDefaultImageUrl(String categoryId) {
    switch (categoryId.toLowerCase()) {
      case 'cleaning':
        return 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?auto=format&fit=crop&w=600&q=80';
      case 'plumbing':
        return 'https://images.unsplash.com/photo-1607472586893-edb57bdc0e39?auto=format&fit=crop&w=600&q=80';
      case 'electrical':
        return 'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?auto=format&fit=crop&w=600&q=80';
      case 'repairs':
      case 'appliance':
      case 'hvac':
        return 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=600&q=80';
      case 'carpentry':
        return 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?auto=format&fit=crop&w=600&q=80';
      case 'painting':
        return 'https://images.unsplash.com/photo-1562259949-e8e7689d7828?auto=format&fit=crop&w=600&q=80';
      case 'moving':
        return 'https://images.unsplash.com/photo-1600518464441-9154a4dea21b?auto=format&fit=crop&w=600&q=80';
      case 'beauty':
        return 'https://images.unsplash.com/photo-1560066984-138dadb4c035?auto=format&fit=crop&w=600&q=80';
      default:
        return 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?auto=format&fit=crop&w=600&q=80';
    }
  }
}

/// Abstract contract for fetching service categories.
abstract class CategoriesRepository {
  Future<List<ServiceCategory>> getCategories({bool forceRefresh = false});
}

/// Production implementation backed by Supabase `service_categories` table.
class SupabaseCategoriesRepository implements CategoriesRepository {
  final SupabaseClient _client;
  List<ServiceCategory>? _cached;

  SupabaseCategoriesRepository(this._client);

  @override
  Future<List<ServiceCategory>> getCategories({bool forceRefresh = false}) async {
    if (!forceRefresh && _cached != null && _cached!.isNotEmpty) {
      return _cached!;
    }

    try {
      final data = await _client
          .from(SupabaseConfig.tableServiceCategories)
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);

      final list = (data as List<dynamic>).map((row) {
        return mapRowToCategory(row as Map<String, dynamic>);
      }).toList();

      if (list.isNotEmpty) {
        _cached = list;
        return list;
      }
      return _fallbackCategories();
    } catch (e) {
      debugPrint('ℹ️ [SupabaseCategoriesRepository] Database query error ($e). Using cached/fallback.');
      return _fallbackCategories();
    }
  }

  /// Deserializes a PostgreSQL `service_categories` row into a `ServiceCategory` entity.
  static ServiceCategory mapRowToCategory(Map<String, dynamic> map) {
    final id = map['id'] as String;
    return ServiceCategory(
      id: id,
      title: map['name'] as String? ?? id,
      subtitle: map['description'] as String? ?? 'Verified specialists',
      icon: CategoryIconHelper.fromString(map['icon_name'] as String?),
      imageUrl: CategoryIconHelper.getDefaultImageUrl(id),
      providerCount: 15,
    );
  }

  List<ServiceCategory> _fallbackCategories() {
    return _cached ?? ServiceCategory.mockCategories;
  }
}

/// In-memory repository for test suites or when unconfigured.
class InMemoryCategoriesRepository implements CategoriesRepository {
  List<ServiceCategory> _categories;

  InMemoryCategoriesRepository({List<ServiceCategory>? initialCategories})
      : _categories = initialCategories ?? List.from(ServiceCategory.mockCategories);

  @override
  Future<List<ServiceCategory>> getCategories({bool forceRefresh = false}) async {
    return _categories;
  }

  void setCategories(List<ServiceCategory> categories) {
    _categories = categories;
  }
}
