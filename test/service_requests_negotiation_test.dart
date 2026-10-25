import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soama/features/requests/data/requests_repository.dart';
import 'package:soama/features/requests/presentation/providers/requests_provider.dart';
import 'package:soama/shared/models/service_request.dart';
import 'package:soama/shared/models/user_account.dart';

void main() {
  group('1. ServiceRequest Deserialization & Data Modeling', () {
    test('ServiceRequest.fromSupabase deserializes PostgreSQL schema accurately', () {
      final dbRow = {
        'id': '00000000-0000-0000-0000-000000000001',
        'customer_id': '00000000-0000-0000-0000-000000000099',
        'category_id': 'plumbing',
        'title': 'Fix Leaking Kitchen Sink Pipe',
        'description': 'Water leaks heavily under the basin when tap runs.',
        'urgency': 'high',
        'delivery_mode': 'on_site_visit',
        'location_area': 'Effurun, Warri',
        'exact_address': '14 PTI Road, Warri',
        'preferred_schedule_start': '2026-10-30T10:00:00Z',
        'budget_amount_minor_units': 2500000, // ₦25,000 in kobo
        'status': 'submitted',
        'negotiation_status': 'awaiting_response',
        'created_at': '2026-10-25T08:00:00Z',
        'price_offers': [
          {
            'id': 'off-001',
            'sender_id': '00000000-0000-0000-0000-000000000099',
            'sender_role': 'customer',
            'amount_minor_units': 2500000,
            'message': 'Initial budget for fixing pipe',
            'status': 'pending',
            'created_at': '2026-10-25T08:00:00Z',
          }
        ],
        'request_recipients': [
          {
            'provider_id': 'pro-warri-1',
            'status': 'sent',
            'provider_profiles': {
              'business_name': 'Ochuko Plumbing Solutions',
            }
          }
        ],
      };

      final req = ServiceRequest.fromSupabase(dbRow);

      expect(req.id, equals('00000000-0000-0000-0000-000000000001'));
      expect(req.serviceTitle, equals('Fix Leaking Kitchen Sink Pipe'));
      expect(req.description, equals('Water leaks heavily under the basin when tap runs.'));
      // In the app model, address stores the formatted location / address
      expect(req.address, equals('14 PTI Road, Warri'));
      // Minor units to Naira conversion check
      expect(req.servicePriceAmount, equals(25000));
      expect(req.servicePrice, equals('₦25,000'));
      expect(req.deliveryMode, equals(ServiceDeliveryMode.onSiteVisit));
      expect(req.negotiationStatus, equals(NegotiationStatus.awaitingResponse));
      expect(req.providerId, equals('pro-warri-1'));
      expect(req.providerName, equals('Ochuko Plumbing Solutions'));
      expect(req.negotiationMessages.length, equals(1));

      final firstOffer = req.negotiationMessages.first;
      expect(firstOffer.sender, equals(OfferSender.customer));
      expect(firstOffer.proposedPrice, equals(25000));
      expect(firstOffer.offerStatus, equals(OfferStatus.pending));
    });

    test('ServiceRequest location privacy: uses general location area when exact address is private', () {
      final dbRowForProvider = {
        'id': 'req-privacy-test',
        'title': 'Roof Tile Replacement',
        'description': 'Replace broken tiles',
        'location_area': 'GRA Phase 2, Port Harcourt',
        'budget_amount_minor_units': 5000000, // ₦50,000
        'status': 'open',
        'negotiation_status': 'awaiting_response',
        // Notice exact_address is null or omitted for recipient view before booking
        'exact_address': null,
      };

      final req = ServiceRequest.fromSupabase(dbRowForProvider);
      expect(req.address, equals('GRA Phase 2, Port Harcourt'));
    });
  });

  group('2. NegotiationMessage Deserialization & Currency Math', () {
    test('NegotiationMessage correctly parses minor units (kobo to naira) and sender roles', () {
      final providerOfferRow = {
        'id': 'off-pro-100',
        'sender_role': 'provider',
        'amount_minor_units': 3200000, // ₦32,000
        'message': 'Materials and transportation included in this quote.',
        'status': 'countered',
        'created_at': '2026-10-25T09:30:00Z',
      };

      final msg = NegotiationMessage.fromSupabase(providerOfferRow);
      expect(msg.id, equals('off-pro-100'));
      expect(msg.sender, equals(OfferSender.provider));
      expect(msg.proposedPrice, equals(32000));
      expect(msg.text, equals('Materials and transportation included in this quote.'));
      expect(msg.offerStatus, equals(OfferStatus.replaced));
    });

    test('OfferStatus enum maps all backend negotiation status values safely', () {
      final acceptedRow = {
        'id': 'off-1',
        'sender_role': 'provider',
        'amount_minor_units': 1500000,
        'status': 'accepted',
      };
      final declinedRow = {
        'id': 'off-2',
        'sender_role': 'customer',
        'amount_minor_units': 1200000,
        'status': 'declined',
      };

      expect(NegotiationMessage.fromSupabase(acceptedRow).offerStatus, equals(OfferStatus.accepted));
      expect(NegotiationMessage.fromSupabase(declinedRow).offerStatus, equals(OfferStatus.declined));
    });
  });

  group('3. RequestsRepository Core Operations (InMemory & Fallback)', () {
    late InMemoryRequestsRepository repo;

    setUp(() {
      repo = InMemoryRequestsRepository();
    });

    test('createServiceRequest creates valid request and saves initial negotiation offer', () async {
      final created = await repo.createServiceRequest(
        categoryId: 'electrical',
        title: 'Generator Inverter Installation',
        description: 'Connect 3.5kVA hybrid solar inverter with battery bank.',
        locationArea: 'Airport Road, Warri',
        exactAddress: 'Plot 4, Airport Road',
        preferredDate: DateTime(2026, 11, 1, 10, 0),
        budgetAmount: 45000,
        targetProviderId: 'pro-warri-2',
        targetProviderName: 'Amina Yusuf',
        initialMessage: 'Looking for prompt installation this Saturday',
      );

      expect(created.id, isNotEmpty);
      expect(created.serviceTitle, equals('Generator Inverter Installation'));
      expect(created.servicePriceAmount, equals(45000));
      expect(created.providerId, equals('pro-warri-2'));
      expect(created.providerName, equals('Amina Yusuf'));
      expect(created.negotiationMessages.length, equals(1));
      expect(created.negotiationMessages.first.proposedPrice, equals(45000));

      // Customer can query this created request
      final customerRequests = await repo.getCustomerRequests(UserAccount.current.id);
      expect(customerRequests.any((r) => r.id == created.id), isTrue);
    });

    test('submitPriceOffer appends a new offer and marks previous offers replaced/countered', () async {
      final req = await repo.createServiceRequest(
        categoryId: 'cleaning',
        title: 'Deep Rug Cleaning',
        description: '3 large living room rugs',
        locationArea: 'Enerhen, Warri',
        preferredDate: DateTime.now().add(const Duration(days: 2)),
        budgetAmount: 20000,
        targetProviderId: 'pro-warri-1',
      );

      // Provider submits a counteroffer of ₦26,000
      final counterOffer = await repo.submitPriceOffer(
        requestId: req.id,
        amountNaira: 26000,
        message: 'Includes stain extraction solution and drying machine.',
      );

      expect(counterOffer.id, isNotEmpty);
      expect(counterOffer.proposedPrice, equals(26000));
      expect(counterOffer.offerStatus, equals(OfferStatus.pending));

      // Retrieve updated request
      final updated = await repo.getRequestById(req.id);
      expect(updated, isNotNull);
      expect(updated!.negotiationMessages.length, equals(2));
      // First offer should now be superseded/replaced
      expect(updated.negotiationMessages.first.offerStatus, equals(OfferStatus.replaced));
      // Latest offer is pending
      expect(updated.negotiationMessages.last.offerStatus, equals(OfferStatus.pending));
    });

    test('acceptPriceOffer transitions offer to accepted and locks negotiation atomically', () async {
      final req = await repo.createServiceRequest(
        categoryId: 'mechanic',
        title: 'Brake Pad Replacement',
        description: 'Front and rear brake pads for Toyota Camry',
        locationArea: 'Jeddo, Warri',
        preferredDate: DateTime.now().add(const Duration(days: 1)),
        budgetAmount: 18000,
        targetProviderId: 'pro-warri-1',
      );

      final initialOfferId = req.negotiationMessages.first.id;

      final success = await repo.acceptPriceOffer(
        offerId: initialOfferId,
        callerId: 'pro-warri-1',
      );

      expect(success, isTrue);

      final refreshed = await repo.getRequestById(req.id);
      expect(refreshed, isNotNull);
      expect(refreshed!.negotiationStatus, equals(NegotiationStatus.priceAgreed));
      expect(refreshed.negotiationMessages.first.offerStatus, equals(OfferStatus.accepted));
    });

    test('rejectPriceOffer transitions offer status to declined', () async {
      final req = await repo.createServiceRequest(
        categoryId: 'carpentry',
        title: 'Fix Kitchen Cabinet Hinge',
        description: 'Two cabinet doors hanging loose',
        locationArea: 'Deco Road, Warri',
        preferredDate: DateTime.now().add(const Duration(days: 3)),
        budgetAmount: 10000,
        targetProviderId: 'pro-warri-1',
      );

      final offerId = req.negotiationMessages.first.id;
      final success = await repo.rejectPriceOffer(offerId);
      expect(success, isTrue);

      final refreshed = await repo.getRequestById(req.id);
      expect(refreshed, isNotNull);
      expect(refreshed!.negotiationMessages.first.offerStatus, equals(OfferStatus.declined));
    });

    test('cancelRequest marks service request cancelled and aborts active negotiation', () async {
      final req = await repo.createServiceRequest(
        categoryId: 'painting',
        title: 'Paint Bedroom',
        description: 'Single bedroom interior paint',
        locationArea: 'Ughelli, Delta',
        preferredDate: DateTime.now().add(const Duration(days: 4)),
        budgetAmount: 30000,
        targetProviderId: 'pro-warri-1',
      );

      final cancelled = await repo.cancelRequest(req.id);
      expect(cancelled, isTrue);

      final refreshed = await repo.getRequestById(req.id);
      expect(refreshed, isNotNull);
      expect(refreshed!.negotiationStatus, equals(NegotiationStatus.requestCancelled));
    });

    test('declineRequest hides request from provider inbox', () async {
      final req = await repo.createServiceRequest(
        categoryId: 'plumbing',
        title: 'Borehole Connection',
        description: 'Overhead tank piping',
        locationArea: 'Warri',
        preferredDate: DateTime.now().add(const Duration(days: 2)),
        budgetAmount: 50000,
        targetProviderId: 'pro-warri-1',
      );

      final initialInbox = await repo.getProviderInboxRequests('pro-warri-1');
      expect(initialInbox.any((r) => r.id == req.id), isTrue);

      // Provider declines
      await repo.declineRequest(requestId: req.id, providerId: 'pro-warri-1');

      final updatedInbox = await repo.getProviderInboxRequests('pro-warri-1');
      expect(updatedInbox.any((r) => r.id == req.id), isFalse);
    });
  });

  group('4. Riverpod State Providers & Refresh Flow', () {
    test('customerRequestsProvider and providerInboxRequestsProvider yield lists cleanly', () async {
      final container = ProviderContainer(
        overrides: [
          requestsRepositoryProvider.overrideWithValue(InMemoryRequestsRepository()),
        ],
      );
      addTearDown(container.dispose);

      final customerRequests = await container.read(customerRequestsProvider.future);
      expect(customerRequests, isA<List<ServiceRequest>>());

      final providerInbox = await container.read(providerInboxRequestsProvider.future);
      expect(providerInbox, isA<List<ServiceRequest>>());
    });

    test('negotiationProvider resolves negotiation state and responds to offers', () async {
      final inMemoryRepo = InMemoryRequestsRepository();
      final container = ProviderContainer(
        overrides: [
          requestsRepositoryProvider.overrideWithValue(inMemoryRepo),
        ],
      );
      addTearDown(container.dispose);

      final sampleRequest = (await inMemoryRepo.getCustomerRequests('any')).first;
      final notifier = container.read(negotiationProvider(sampleRequest.id).notifier);
      await notifier.loadRequest();

      final state = container.read(negotiationProvider(sampleRequest.id));
      expect(state.value, isNotNull);
      expect(state.value!.negotiationMessages.isNotEmpty, isTrue);
    });
  });

  group('5. State Invariants & Security Directives', () {
    test('Accepted offer does not claim payment completion prematurely', () {
      final acceptedReq = ServiceRequest.submittedRequests.firstWhere(
        (r) => r.negotiationStatus == NegotiationStatus.priceAgreed,
      );

      // Status is priceAgreed, not paymentCompleted or inEscrow
      expect(acceptedReq.negotiationStatus, equals(NegotiationStatus.priceAgreed));
      expect(acceptedReq.negotiationStatus.label, equals('Price Agreed'));
    });

    test('Dual-role account identity remains intact across requests and offers', () {
      final account = UserAccount.current;
      expect(account.id, isNotEmpty);
      expect(account.currentMode, equals(AppMode.customer));

      // Dual-role capabilities supported in single account
      expect(account.hasCustomerCapability, isTrue);

      // Single account can enable provider capability and switch modes
      final dualRoleAccount = account.copyWith(
        hasProviderCapability: true,
        currentMode: AppMode.provider,
      );
      expect(dualRoleAccount.id, equals(account.id));
      expect(dualRoleAccount.hasCustomerCapability, isTrue);
      expect(dualRoleAccount.hasProviderCapability, isTrue);
      expect(dualRoleAccount.currentMode, equals(AppMode.provider));
    });
  });
}
