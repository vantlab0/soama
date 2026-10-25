import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_config.dart';
import '../../../../shared/models/service_provider.dart';
import '../../../../shared/models/user_account.dart';

/// Contract for provider queries, search, and catalog mutations.
abstract class ProviderRepository {
  Future<List<ServiceProvider>> searchProviders({
    String? categoryId,
    String? searchQuery,
    int? maxPrice,
    String? sortBy,
    bool forceRefresh = false,
  });

  Future<ServiceProvider?> getProviderById(String id);

  Future<ProviderProfileData?> getProviderProfile(String userId);

  Future<ProviderProfileData> upsertProviderProfile(
    ProviderProfileData profile,
    String userId,
  );

  Future<List<ProviderServiceOffering>> getProviderServices(String providerId);

  Future<ProviderServiceOffering> addService({
    required String providerId,
    required ProviderServiceOffering service,
    required String categoryId,
  });

  Future<ProviderServiceOffering> updateService(
    String serviceId,
    ProviderServiceOffering service,
  );

  Future<void> deleteService(String serviceId);
}

/// Production implementation querying Supabase PostgreSQL tables.
class SupabaseProviderRepository implements ProviderRepository {
  final SupabaseClient _client;
  List<ServiceProvider>? _cachedPros;

  SupabaseProviderRepository(this._client);

  @override
  Future<List<ServiceProvider>> searchProviders({
    String? categoryId,
    String? searchQuery,
    int? maxPrice,
    String? sortBy,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedPros != null && searchQuery == null && categoryId == null) {
      return _cachedPros!;
    }

    try {
      // Query provider_profiles joined with public.profiles and provider_services
      var query = _client.from(SupabaseConfig.tableProviderProfiles).select('''
        id,
        business_name,
        bio,
        verification_status,
        years_experience,
        is_accepting_jobs,
        rating_avg,
        rating_count,
        completed_jobs_count,
        service_radius_meters,
        ${SupabaseConfig.tableProfiles}!inner(id, full_name, email, phone, avatar_url),
        ${SupabaseConfig.tableProviderServices}(id, category_id, title, description, base_price_minor_units, currency, pricing_type, is_active)
      ''');

      // Filter by approved status
      query = query.eq('verification_status', 'approved').eq('is_accepting_jobs', true);

      final data = await query;
      final rows = data as List<dynamic>;

      final pros = rows.map((row) => mapRowToServiceProvider(row as Map<String, dynamic>)).toList();

      // Client-side criteria filtering
      var filtered = pros;

      if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
        filtered = filtered.where((p) => p.categoryId == categoryId || p.services.any((s) => s.id.contains(categoryId))).toList();
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        filtered = filtered.where((p) {
          final matchesName = p.name.toLowerCase().contains(q) || p.businessName.toLowerCase().contains(q);
          final matchesProfession = p.profession.toLowerCase().contains(q) || p.bio.toLowerCase().contains(q);
          final matchesService = p.services.any((s) => s.title.toLowerCase().contains(q) || s.description.toLowerCase().contains(q));
          return matchesName || matchesProfession || matchesService;
        }).toList();
      }

      if (maxPrice != null && maxPrice > 0) {
        filtered = filtered.where((p) => (p.startingPriceAmount ?? 0) <= maxPrice).toList();
      }

      if (sortBy == 'rating') {
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
      } else if (sortBy == 'price_low') {
        filtered.sort((a, b) => (a.startingPriceAmount ?? 0).compareTo(b.startingPriceAmount ?? 0));
      }

      if (pros.isNotEmpty && searchQuery == null && categoryId == null) {
        _cachedPros = pros;
      }

      if (filtered.isNotEmpty) return filtered;
      return _fallbackProviders(categoryId: categoryId, searchQuery: searchQuery);
    } catch (e) {
      debugPrint('ℹ️ [SupabaseProviderRepository] searchProviders error ($e). Using fallback.');
      return _fallbackProviders(categoryId: categoryId, searchQuery: searchQuery);
    }
  }

  @override
  Future<ServiceProvider?> getProviderById(String id) async {
    try {
      final data = await _client.from(SupabaseConfig.tableProviderProfiles).select('''
        id,
        business_name,
        bio,
        verification_status,
        years_experience,
        is_accepting_jobs,
        rating_avg,
        rating_count,
        completed_jobs_count,
        service_radius_meters,
        ${SupabaseConfig.tableProfiles}!inner(id, full_name, email, phone, avatar_url),
        ${SupabaseConfig.tableProviderServices}(id, category_id, title, description, base_price_minor_units, currency, pricing_type, is_active)
      ''').eq('id', id).maybeSingle();

      if (data != null) {
        return mapRowToServiceProvider(data);
      }
    } catch (e) {
      debugPrint('ℹ️ [SupabaseProviderRepository] getProviderById error ($e)');
    }

    return ServiceProvider.findById(id);
  }

  @override
  Future<ProviderProfileData?> getProviderProfile(String userId) async {
    try {
      final data = await _client
          .from(SupabaseConfig.tableProviderProfiles)
          .select('*, ${SupabaseConfig.tableProviderServices}(*)')
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return null;

      final servicesRaw = data[SupabaseConfig.tableProviderServices] as List<dynamic>? ?? [];
      final offerings = servicesRaw.map((s) => mapRowToOffering(s as Map<String, dynamic>)).toList();

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
      debugPrint('ℹ️ [SupabaseProviderRepository] getProviderProfile error: $e');
      return null;
    }
  }

  @override
  Future<ProviderProfileData> upsertProviderProfile(
    ProviderProfileData profile,
    String userId,
  ) async {
    final payload = {
      'id': userId,
      'business_name': profile.businessName,
      'bio': profile.bio,
      'is_accepting_jobs': true,
      'service_radius_meters': 25000,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    await _client.from(SupabaseConfig.tableProviderProfiles).upsert(payload);
    return profile;
  }

  @override
  Future<List<ProviderServiceOffering>> getProviderServices(String providerId) async {
    try {
      final data = await _client
          .from(SupabaseConfig.tableProviderServices)
          .select()
          .eq('provider_id', providerId)
          .eq('is_active', true);

      final list = (data as List<dynamic>).map((s) => mapRowToOffering(s as Map<String, dynamic>)).toList();

      return list;
    } catch (e) {
      debugPrint('ℹ️ [SupabaseProviderRepository] getProviderServices error: $e');
      return [];
    }
  }

  @override
  Future<ProviderServiceOffering> addService({
    required String providerId,
    required ProviderServiceOffering service,
    required String categoryId,
  }) async {
    final payload = {
      'provider_id': providerId,
      'category_id': categoryId.isNotEmpty ? categoryId : 'repairs',
      'title': service.title,
      'description': service.description,
      'base_price_minor_units': service.priceAmount * 100,
      'currency': 'NGN',
      'pricing_type': 'negotiable',
      'is_active': true,
      if (service.imageUrl != null) 'image_url': service.imageUrl,
    };

    final res = await _client
        .from(SupabaseConfig.tableProviderServices)
        .insert(payload)
        .select()
        .single();

    return ProviderServiceOffering(
      id: res['id'] as String,
      title: res['title'] as String,
      description: res['description'] as String? ?? '',
      price: service.price,
      priceAmount: service.priceAmount,
      duration: service.duration,
      imageUrl: res['image_url'] as String? ?? service.imageUrl,
    );
  }

  @override
  Future<ProviderServiceOffering> updateService(
    String serviceId,
    ProviderServiceOffering service,
  ) async {
    await _client.from(SupabaseConfig.tableProviderServices).update({
      'title': service.title,
      'description': service.description,
      'base_price_minor_units': service.priceAmount * 100,
      'image_url': service.imageUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', serviceId);

    return service;
  }

  @override
  Future<void> deleteService(String serviceId) async {
    await _client
        .from(SupabaseConfig.tableProviderServices)
        .update({'is_active': false})
        .eq('id', serviceId);
  }

  /// Deserializes a single service row from `provider_services`.
  static ProviderServiceOffering mapRowToOffering(Map<String, dynamic> map) {
    final minor = map['base_price_minor_units'] as num? ?? 0;
    final major = (minor / 100).round();
    return ProviderServiceOffering(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      price: '₦${formatAmount(major)}',
      priceAmount: major,
      duration: '1-3 hrs',
      imageUrl: map['image_url'] as String?,
    );
  }

  /// Deserializes a joined provider row from `provider_profiles` with `profiles` and `provider_services`.
  static ServiceProvider mapRowToServiceProvider(Map<String, dynamic> row) {
    final profile = row[SupabaseConfig.tableProfiles] as Map<String, dynamic>? ?? {};
    final servicesRaw = row[SupabaseConfig.tableProviderServices] as List<dynamic>? ?? [];

    final offerings = servicesRaw.map((s) => mapRowToOffering(s as Map<String, dynamic>)).toList();

    int? minPrice;
    if (offerings.isNotEmpty) {
      minPrice = offerings.map((s) => s.priceAmount).reduce((a, b) => a < b ? a : b);
    }

    final isApproved = (row['verification_status'] as String? ?? '') == 'approved';
    final ratingAvg = (row['rating_avg'] as num?)?.toDouble() ?? 0.0;
    final ratingCount = row['rating_count'] as int? ?? 0;

    return ServiceProvider(
      id: row['id'] as String,
      name: profile['full_name'] as String? ?? 'Specialist',
      businessName: row['business_name'] as String? ?? 'Verified Service Pro',
      profession: offerings.isNotEmpty ? offerings.first.title : 'Trade Specialist',
      categoryId: servicesRaw.isNotEmpty ? (servicesRaw.first['category_id'] as String? ?? 'repairs') : 'repairs',
      rating: ratingAvg,
      reviewCount: ratingCount,
      distanceKm: 1.5,
      approximateDistance: 'Warri Central',
      startingPriceAmount: minPrice ?? 7500,
      startingPrice: minPrice != null ? '₦${formatAmount(minPrice)}' : '₦7,500',
      location: 'Airport Road, Warri',
      avatarUrl: profile['avatar_url'] as String? ?? 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=400&q=80',
      isVerified: isApproved,
      badgeTitle: isApproved ? 'Verified Specialist' : 'Pending Review',
      bio: row['bio'] as String? ?? 'Certified local service professional with verified experience across Delta State.',
      services: offerings.isNotEmpty ? offerings : const [
        ProviderServiceOffering(
          id: 'srv-std-1',
          title: 'Standard Consultation & Diagnostic',
          description: 'Comprehensive inspection, fault identification, and quote estimate.',
          price: '₦7,500',
          priceAmount: 7500,
          duration: '1 hr',
        ),
      ],
      gallery: const [
        'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=900&q=80',
        'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?auto=format&fit=crop&w=600&q=80',
      ],
      reviews: const [
        ProviderReview(
          id: 'rev-1',
          userName: 'Precious O.',
          userAvatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
          rating: 5.0,
          date: 'Yesterday',
          comment: 'Extremely professional and punctual. Resolved our emergency within two hours.',
        ),
      ],
    );
  }

  static String formatAmount(int amount) {
    return amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  List<ServiceProvider> _fallbackProviders({String? categoryId, String? searchQuery}) {
    var pros = ServiceProvider.nearbyPros;
    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
      pros = pros.where((p) => p.categoryId == categoryId).toList();
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      pros = pros.where((p) => p.name.toLowerCase().contains(q) || p.businessName.toLowerCase().contains(q) || p.profession.toLowerCase().contains(q)).toList();
    }
    return pros;
  }
}

/// In-memory repository for unit tests and unconfigured offline development.
class InMemoryProviderRepository implements ProviderRepository {
  List<ServiceProvider> _pros = List.from(ServiceProvider.nearbyPros);

  @override
  Future<List<ServiceProvider>> searchProviders({
    String? categoryId,
    String? searchQuery,
    int? maxPrice,
    String? sortBy,
    bool forceRefresh = false,
  }) async {
    var filtered = _pros;
    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
      filtered = filtered.where((p) => p.categoryId == categoryId).toList();
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      filtered = filtered.where((p) => p.name.toLowerCase().contains(q) || p.businessName.toLowerCase().contains(q)).toList();
    }
    if (maxPrice != null && maxPrice > 0) {
      filtered = filtered.where((p) => (p.startingPriceAmount ?? 0) <= maxPrice).toList();
    }
    return filtered;
  }

  @override
  Future<ServiceProvider?> getProviderById(String id) async {
    try {
      return _pros.firstWhere((p) => p.id == id);
    } catch (_) {
      return _pros.isNotEmpty ? _pros.first : null;
    }
  }

  @override
  Future<ProviderProfileData?> getProviderProfile(String userId) async {
    return UserAccount.current.providerProfile;
  }

  @override
  Future<ProviderProfileData> upsertProviderProfile(ProviderProfileData profile, String userId) async {
    UserAccount.current = UserAccount.current.copyWith(providerProfile: profile);
    return profile;
  }

  @override
  Future<List<ProviderServiceOffering>> getProviderServices(String providerId) async {
    return UserAccount.current.providerProfile?.services ?? [];
  }

  @override
  Future<ProviderServiceOffering> addService({
    required String providerId,
    required ProviderServiceOffering service,
    required String categoryId,
  }) async {
    final current = UserAccount.current.providerProfile;
    if (current != null) {
      final updated = List<ProviderServiceOffering>.from(current.services)..add(service);
      UserAccount.current = UserAccount.current.copyWith(
        providerProfile: current.copyWith(services: updated),
      );
    }
    return service;
  }

  @override
  Future<ProviderServiceOffering> updateService(String serviceId, ProviderServiceOffering service) async {
    final current = UserAccount.current.providerProfile;
    if (current != null) {
      final updated = current.services.map((s) => s.id == serviceId ? service : s).toList();
      UserAccount.current = UserAccount.current.copyWith(
        providerProfile: current.copyWith(services: updated),
      );
    }
    return service;
  }

  @override
  Future<void> deleteService(String serviceId) async {
    final current = UserAccount.current.providerProfile;
    if (current != null) {
      final updated = current.services.where((s) => s.id != serviceId).toList();
      UserAccount.current = UserAccount.current.copyWith(
        providerProfile: current.copyWith(services: updated),
      );
    }
  }

  void setProviders(List<ServiceProvider> pros) {
    _pros = pros;
  }
}
