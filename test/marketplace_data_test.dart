import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soama/core/constants/supabase_config.dart';
import 'package:soama/features/categories/data/categories_repository.dart';
import 'package:soama/features/categories/presentation/providers/categories_provider.dart';
import 'package:soama/features/providers/data/provider_repository.dart';
import 'package:soama/features/providers/presentation/providers/provider_provider.dart';
import 'package:soama/shared/models/service_category.dart';
import 'package:soama/shared/models/service_provider.dart';
import 'package:soama/shared/models/user_account.dart';

void main() {
  group('Section 1 & 3: Service Categories Tests', () {
    test('CategoryIconHelper maps database icon string identifiers correctly', () {
      expect(CategoryIconHelper.fromString('cleaning'), equals(Icons.cleaning_services_outlined));
      expect(CategoryIconHelper.fromString('plumbing'), equals(Icons.plumbing_outlined));
      expect(CategoryIconHelper.fromString('electrical'), equals(Icons.bolt_outlined));
      expect(CategoryIconHelper.fromString('mechanic'), equals(Icons.build_outlined));
      expect(CategoryIconHelper.fromString('carpentry'), equals(Icons.carpenter_outlined));
      expect(CategoryIconHelper.fromString('painting'), equals(Icons.format_paint_outlined));
      expect(CategoryIconHelper.fromString('pest_control'), equals(Icons.pest_control_outlined));
      expect(CategoryIconHelper.fromString('gardening'), equals(Icons.yard_outlined));
      // Fallback for unknown/null icon
      expect(CategoryIconHelper.fromString('unknown_icon'), equals(Icons.category_outlined));
      expect(CategoryIconHelper.fromString(null), equals(Icons.category_outlined));
    });

    test('ServiceCategory deserializes correctly from PostgreSQL row via SupabaseCategoriesRepository', () {
      final row = {
        'id': 'cleaning',
        'name': 'Home & Office Cleaning',
        'description': 'Air conditioner installation, maintenance, and gas refill',
        'icon_name': 'cleaning',
        'display_order': 1,
        'is_active': true,
      };

      final category = SupabaseCategoriesRepository.mapRowToCategory(row);
      expect(category.id, equals('cleaning'));
      expect(category.title, equals('Home & Office Cleaning'));
      expect(category.subtitle, equals('Air conditioner installation, maintenance, and gas refill'));
      expect(category.icon, equals(Icons.cleaning_services_outlined));
    });

    test('CategoriesRepository returns active categories and handles empty states', () async {
      final customList = [
        const ServiceCategory(
          id: 'cat-1',
          title: 'Cleaning',
          subtitle: 'Home and deep cleaning',
          icon: Icons.cleaning_services_outlined,
          imageUrl: '',
          providerCount: 10,
        ),
        const ServiceCategory(
          id: 'cat-2',
          title: 'Electrical',
          subtitle: 'Wiring and solar',
          icon: Icons.bolt_outlined,
          imageUrl: '',
          providerCount: 8,
        ),
      ];

      final repo = InMemoryCategoriesRepository(initialCategories: customList);
      final categories = await repo.getCategories();
      expect(categories.length, equals(2));
      expect(categories.first.id, equals('cat-1'));
      expect(categories.last.id, equals('cat-2'));

      // Empty categories scenario
      final emptyRepo = InMemoryCategoriesRepository(initialCategories: []);
      final emptyResult = await emptyRepo.getCategories();
      expect(emptyResult, isEmpty);
    });

    test('categoriesProvider async notifier emits and refreshes active categories', () async {
      final container = ProviderContainer(
        overrides: [
          categoriesRepositoryProvider.overrideWithValue(
            InMemoryCategoriesRepository(
              initialCategories: [
                const ServiceCategory(
                  id: 'cat-test',
                  title: 'Test Category',
                  subtitle: 'Description',
                  icon: Icons.star,
                  imageUrl: '',
                  providerCount: 5,
                ),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Verify initial state
      final categories = await container.read(categoriesProvider.future);
      expect(categories.length, equals(1));
      expect(categories.first.id, equals('cat-test'));

      // Invalidate / refresh
      container.invalidate(categoriesProvider);
      final refreshed = await container.read(categoriesProvider.future);
      expect(refreshed.length, equals(1));
    });
  });

  group('Section 4 & 6: Provider Profiles & Services Repository Tests', () {
    test('ProviderServiceOffering serializes to and from Supabase provider_services schema', () {
      final serviceRow = {
        'id': 'svc-uuid-001',
        'provider_id': 'prov-uuid-999',
        'category_id': 'cleaning',
        'title': 'Deep Post-Construction Cleaning',
        'description': 'Full industrial sweep and sanitization',
        'base_price_minor_units': 3500000, // 35,000 NGN in kobo
        'price_unit': 'fixed',
        'duration_minutes': 240,
        'is_active': true,
      };

      final service = SupabaseProviderRepository.mapRowToOffering(serviceRow);
      expect(service.id, equals('svc-uuid-001'));
      expect(service.title, equals('Deep Post-Construction Cleaning'));
      expect(service.priceAmount, equals(35000)); // Converted from minor units (kobo / 100)
      expect(service.price, equals('₦35,000'));
      expect(service.duration, equals('1-3 hrs'));
    });

    test('ServiceProvider model parses combined provider_profiles and profiles data', () {
      final joinedRow = {
        'id': 'prov-uuid-101',
        'business_name': 'Lagos Apex Plumbing & Drainage',
        'bio': 'Certified master plumbers with 12+ years experience in Victoria Island and Lekki.',
        'rating_avg': 4.95,
        'rating_count': 64,
        'jobs_completed_count': 118,
        'years_experience': 12,
        'service_radius_meters': 25000,
        'verification_status': 'approved',
        'is_active': true,
        'profiles': {
          'id': 'prov-uuid-101',
          'full_name': 'Babatunde Fashola',
          'email': 'tunde@apexplumbing.ng',
          'phone': '+234 803 111 2233',
          'avatar_url': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2',
        },
        'provider_services': [
          {
            'id': 'svc-1',
            'title': 'Pipe Leak Detection',
            'description': 'Acoustic leak inspection',
            'base_price_minor_units': 1500000, // 15,000 NGN
            'price_unit': 'fixed',
            'duration_minutes': 60,
            'is_active': true,
          }
        ],
      };

      final provider = SupabaseProviderRepository.mapRowToServiceProvider(joinedRow);
      expect(provider.id, equals('prov-uuid-101'));
      expect(provider.name, equals('Babatunde Fashola'));
      expect(provider.businessName, equals('Lagos Apex Plumbing & Drainage'));
      expect(provider.rating, equals(4.95));
      expect(provider.reviewCount, equals(64));
      expect(provider.services.length, equals(1));
      expect(provider.services.first.title, equals('Pipe Leak Detection'));
      expect(provider.services.first.priceAmount, equals(15000));
      expect(provider.startingPriceAmount, equals(15000));
      expect(provider.isVerified, isTrue);
    });

    test('ProviderRepository can add, update, and delete provider services', () async {
      final repo = InMemoryProviderRepository();
      const testProviderId = 'test-provider-abc';

      // Ensure UserAccount has a provider profile initialized
      UserAccount.current = UserAccount.current.copyWith(
        providerProfile: const ProviderProfileData(
          providerId: testProviderId,
          businessName: 'Test Tech Services',
          profession: 'Electrician',
          categoryId: 'electrical',
          categoryTitle: 'Electrical & Power',
          bio: 'Quality engineering',
          serviceArea: 'Warri Central',
          services: [],
        ),
      );

      // 1. Initial services count
      final initialServices = await repo.getProviderServices(testProviderId);
      expect(initialServices, isEmpty);

      // 2. Add a new service
      const newService = ProviderServiceOffering(
        id: 'new-svc-1',
        title: 'Emergency Generator Repair',
        description: '24/7 on-site diesel generator troubleshooting',
        price: '₦20,000',
        priceAmount: 20000,
        duration: '1-2 hrs',
      );
      await repo.addService(
        providerId: testProviderId,
        service: newService,
        categoryId: 'electrical',
      );

      final servicesAfterAdd = await repo.getProviderServices(testProviderId);
      expect(servicesAfterAdd.length, equals(1));
      expect(servicesAfterAdd.any((s) => s.id == 'new-svc-1'), isTrue);

      // 3. Update the service price
      const updatedService = ProviderServiceOffering(
        id: 'new-svc-1',
        title: 'Emergency Generator Repair',
        description: 'Updated generator diagnosis and filter change',
        price: '₦25,000',
        priceAmount: 25000,
        duration: '2 hrs',
      );
      await repo.updateService('new-svc-1', updatedService);

      final servicesAfterUpdate = await repo.getProviderServices(testProviderId);
      final found = servicesAfterUpdate.firstWhere((s) => s.id == 'new-svc-1');
      expect(found.priceAmount, equals(25000));
      expect(found.description, equals('Updated generator diagnosis and filter change'));

      // 4. Delete service
      await repo.deleteService('new-svc-1');
      final servicesAfterDelete = await repo.getProviderServices(testProviderId);
      expect(servicesAfterDelete.any((s) => s.id == 'new-svc-1'), isFalse);
    });

    test('ProviderRepository handles getProviderById and returns provider record', () async {
      final repo = InMemoryProviderRepository();

      // Existing provider from default pool
      final existing = await repo.getProviderById('1');
      expect(existing, isNotNull);
      expect(existing!.name, isNotEmpty);
    });
  });

  group('Section 5: Explore & Provider Discovery Filtering Tests', () {
    test('Filtering by category returns only providers offering that category', () async {
      final repo = InMemoryProviderRepository();

      final cleaningPros = await repo.searchProviders(categoryId: 'cleaning');
      expect(cleaningPros, isNotEmpty);
      for (final pro in cleaningPros) {
        expect(pro.categoryId, equals('cleaning'));
      }

      final plumbingPros = await repo.searchProviders(categoryId: 'plumbing');
      expect(plumbingPros, isNotEmpty);
      for (final pro in plumbingPros) {
        expect(pro.categoryId, equals('plumbing'));
      }
    });

    test('Search by query matches provider name or business name accurately', () async {
      final repo = InMemoryProviderRepository();

      // Search by provider name keyword
      final nameMatches = await repo.searchProviders(searchQuery: 'Ochuko');
      expect(nameMatches, isNotEmpty);
      expect(nameMatches.first.name, contains('Ochuko'));

      // Search with non-matching term returns empty list gracefully
      final noMatches = await repo.searchProviders(searchQuery: 'NonExistentServiceXYZ1234');
      expect(noMatches, isEmpty);
    });

    test('Provider discovery correctly integrates with marketplaceProvidersProvider', () async {
      final container = ProviderContainer(
        overrides: [
          providerRepositoryProvider.overrideWithValue(InMemoryProviderRepository()),
        ],
      );
      addTearDown(container.dispose);

      const params = ProviderQueryParams(categoryId: 'cleaning');
      final providers = await container.read(marketplaceProvidersProvider(params).future);
      expect(providers, isNotEmpty);
      expect(providers.every((p) => p.categoryId == 'cleaning'), isTrue);
    });
  });

  group('Section 8: Security & Architecture Invariants', () {
    test('Supabase table constants match the database migration schema', () {
      expect(SupabaseConfig.tableServiceCategories, equals('service_categories'));
      expect(SupabaseConfig.tableProviderProfiles, equals('provider_profiles'));
      expect(SupabaseConfig.tableProviderServices, equals('provider_services'));
    });

    test('ProviderServicesNotifier properly manages services and state mutations', () async {
      final container = ProviderContainer(
        overrides: [
          providerRepositoryProvider.overrideWithValue(InMemoryProviderRepository()),
        ],
      );
      addTearDown(container.dispose);

      const testId = 'test-provider-write';
      final notifier = container.read(providerServicesProvider(testId).notifier);

      final success = await notifier.addService(
        title: 'AC Gas Refill',
        description: 'R410A refrigerant recharge',
        priceAmount: 18000,
        duration: '1 hr',
      );

      expect(success, isTrue);
      final services = container.read(providerServicesProvider(testId)).value;
      expect(services, isNotNull);
      expect(services!.any((s) => s.title == 'AC Gas Refill'), isTrue);
    });
  });
}
