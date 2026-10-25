import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/supabase_config.dart';
import '../../../../shared/models/service_request.dart';
import '../../../../shared/models/user_account.dart';

/// Contract for Service Requests and Price Negotiation workflows.
abstract class RequestsRepository {
  Future<ServiceRequest> createServiceRequest({
    required String categoryId,
    required String title,
    required String description,
    String urgency = 'standard',
    ServiceDeliveryMode deliveryMode = ServiceDeliveryMode.onSiteVisit,
    required String locationArea,
    String? exactAddress,
    double? latitude,
    double? longitude,
    required DateTime preferredDate,
    DateTime? preferredScheduleEnd,
    required int budgetAmount,
    String? targetProviderId,
    String? initialMessage,
    String? targetProviderName,
    String? targetProviderProfession,
    String? targetProviderAvatar,
  });

  Future<List<ServiceRequest>> getCustomerRequests(String customerId, {bool forceRefresh = false});

  Future<List<ServiceRequest>> getProviderInboxRequests(String providerId, {bool forceRefresh = false});

  Future<ServiceRequest?> getRequestById(String requestId, {bool forceRefresh = false});

  Future<NegotiationMessage> submitPriceOffer({
    required String requestId,
    required int amountNaira,
    String? message,
  });

  Future<bool> acceptPriceOffer({
    required String offerId,
    required String callerId,
  });

  Future<bool> rejectPriceOffer(String offerId);

  Future<bool> declineRequest({
    required String requestId,
    required String providerId,
  });

  Future<bool> cancelRequest(String requestId);
}

/// Production implementation querying Supabase PostgreSQL tables and RPC procedures.
class SupabaseRequestsRepository implements RequestsRepository {
  final SupabaseClient _client;
  final InMemoryRequestsRepository _fallback = InMemoryRequestsRepository();

  SupabaseRequestsRepository(this._client);

  @override
  Future<ServiceRequest> createServiceRequest({
    required String categoryId,
    required String title,
    required String description,
    String urgency = 'standard',
    ServiceDeliveryMode deliveryMode = ServiceDeliveryMode.onSiteVisit,
    required String locationArea,
    String? exactAddress,
    double? latitude,
    double? longitude,
    required DateTime preferredDate,
    DateTime? preferredScheduleEnd,
    required int budgetAmount,
    String? targetProviderId,
    String? initialMessage,
    String? targetProviderName,
    String? targetProviderProfession,
    String? targetProviderAvatar,
  }) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return _fallback.createServiceRequest(
        categoryId: categoryId,
        title: title,
        description: description,
        urgency: urgency,
        deliveryMode: deliveryMode,
        locationArea: locationArea,
        exactAddress: exactAddress,
        latitude: latitude,
        longitude: longitude,
        preferredDate: preferredDate,
        preferredScheduleEnd: preferredScheduleEnd,
        budgetAmount: budgetAmount,
        targetProviderId: targetProviderId,
        initialMessage: initialMessage,
        targetProviderName: targetProviderName,
        targetProviderProfession: targetProviderProfession,
        targetProviderAvatar: targetProviderAvatar,
      );
    }

    try {
      final dbDeliveryMode = deliveryMode == ServiceDeliveryMode.visitProvider
          ? 'at_provider_workshop'
          : 'at_customer_location';

      final response = await _client.rpc(
        SupabaseConfig.rpcCreateServiceRequest,
        params: {
          'p_category_id': categoryId,
          'p_title': title,
          'p_description': description,
          'p_urgency': urgency,
          'p_delivery_mode': dbDeliveryMode,
          'p_location_area': locationArea,
          'p_exact_address': exactAddress ?? locationArea,
          'p_latitude': latitude ?? 5.52,
          'p_longitude': longitude ?? 5.75,
          'p_preferred_schedule_start': preferredDate.toUtc().toIso8601String(),
          'p_preferred_schedule_end': preferredScheduleEnd?.toUtc().toIso8601String(),
          'p_budget_minor_units': budgetAmount * 100,
          'p_currency': 'NGN',
          'p_target_provider_id': targetProviderId,
          'p_initial_message': initialMessage,
        },
      );

      final createdId = response as String;
      final created = await getRequestById(createdId, forceRefresh: true);
      if (created != null) {
        // Synchronize in-memory snapshot
        _fallback.saveRequestLocally(created);
        return created;
      }

      return await _fallback.createServiceRequest(
        categoryId: categoryId,
        title: title,
        description: description,
        urgency: urgency,
        deliveryMode: deliveryMode,
        locationArea: locationArea,
        exactAddress: exactAddress,
        preferredDate: preferredDate,
        budgetAmount: budgetAmount,
        targetProviderId: targetProviderId,
        targetProviderName: targetProviderName,
      );
    } catch (e) {
      debugPrint('ℹ️ [SupabaseRequestsRepository] createServiceRequest failed ($e). Using local fallback.');
      return await _fallback.createServiceRequest(
        categoryId: categoryId,
        title: title,
        description: description,
        urgency: urgency,
        deliveryMode: deliveryMode,
        locationArea: locationArea,
        exactAddress: exactAddress,
        preferredDate: preferredDate,
        budgetAmount: budgetAmount,
        targetProviderId: targetProviderId,
        targetProviderName: targetProviderName,
      );
    }
  }

  @override
  Future<List<ServiceRequest>> getCustomerRequests(String customerId, {bool forceRefresh = false}) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return _fallback.getCustomerRequests(customerId, forceRefresh: forceRefresh);
    }

    try {
      final data = await _client
          .from(SupabaseConfig.tableServiceRequests)
          .select('''
            *,
            ${SupabaseConfig.tablePriceOffers}(*),
            ${SupabaseConfig.tableRequestRecipients}(
              provider_id,
              status,
              ${SupabaseConfig.tableProviderProfiles}(business_name)
            )
          ''')
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      final rows = data as List<dynamic>;
      final list = rows.map((r) => ServiceRequest.fromSupabase(r as Map<String, dynamic>)).toList();
      if (list.isNotEmpty) {
        return list;
      }
      return await _fallback.getCustomerRequests(customerId);
    } catch (e) {
      debugPrint('ℹ️ [SupabaseRequestsRepository] getCustomerRequests error ($e). Using fallback.');
      return await _fallback.getCustomerRequests(customerId);
    }
  }

  @override
  Future<List<ServiceRequest>> getProviderInboxRequests(String providerId, {bool forceRefresh = false}) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return _fallback.getProviderInboxRequests(providerId, forceRefresh: forceRefresh);
    }

    try {
      final data = await _client
          .from(SupabaseConfig.tableRequestRecipients)
          .select('''
            *,
            ${SupabaseConfig.tableServiceRequests}!inner(
              *,
              ${SupabaseConfig.tablePriceOffers}(*)
            )
          ''')
          .eq('provider_id', providerId)
          .neq('status', 'declined')
          .order('created_at', ascending: false);

      final rows = data as List<dynamic>;
      final list = <ServiceRequest>[];
      for (final row in rows) {
        final reqMap = row[SupabaseConfig.tableServiceRequests] as Map<String, dynamic>?;
        if (reqMap != null) {
          list.add(ServiceRequest.fromSupabase(reqMap));
        }
      }

      if (list.isNotEmpty) {
        return list;
      }
      return await _fallback.getProviderInboxRequests(providerId);
    } catch (e) {
      debugPrint('ℹ️ [SupabaseRequestsRepository] getProviderInboxRequests error ($e). Using fallback.');
      return await _fallback.getProviderInboxRequests(providerId);
    }
  }

  @override
  Future<ServiceRequest?> getRequestById(String requestId, {bool forceRefresh = false}) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return _fallback.getRequestById(requestId, forceRefresh: forceRefresh);
    }

    try {
      final data = await _client
          .from(SupabaseConfig.tableServiceRequests)
          .select('''
            *,
            ${SupabaseConfig.tablePriceOffers}(*),
            ${SupabaseConfig.tableRequestRecipients}(
              provider_id,
              status,
              ${SupabaseConfig.tableProviderProfiles}(business_name)
            )
          ''')
          .eq('id', requestId)
          .maybeSingle();

      if (data != null) {
        return ServiceRequest.fromSupabase(data);
      }
      return await _fallback.getRequestById(requestId);
    } catch (e) {
      debugPrint('ℹ️ [SupabaseRequestsRepository] getRequestById error ($e). Using fallback.');
      return await _fallback.getRequestById(requestId);
    }
  }

  @override
  Future<NegotiationMessage> submitPriceOffer({
    required String requestId,
    required int amountNaira,
    String? message,
  }) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return _fallback.submitPriceOffer(
        requestId: requestId,
        amountNaira: amountNaira,
        message: message,
      );
    }

    try {
      final offerId = await _client.rpc(
        SupabaseConfig.rpcSubmitPriceOffer,
        params: {
          'p_request_id': requestId,
          'p_amount_minor_units': amountNaira * 100,
          'p_message': message,
        },
      ) as String;

      final offerData = await _client
          .from(SupabaseConfig.tablePriceOffers)
          .select()
          .eq('id', offerId)
          .single();

      final created = NegotiationMessage.fromSupabase(offerData);
      _fallback.saveOfferLocally(requestId, created);
      return created;
    } catch (e) {
      debugPrint('ℹ️ [SupabaseRequestsRepository] submitPriceOffer failed ($e). Using fallback.');
      return await _fallback.submitPriceOffer(
        requestId: requestId,
        amountNaira: amountNaira,
        message: message,
      );
    }
  }

  @override
  Future<bool> acceptPriceOffer({
    required String offerId,
    required String callerId,
  }) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return _fallback.acceptPriceOffer(offerId: offerId, callerId: callerId);
    }

    try {
      await _client.rpc(
        SupabaseConfig.rpcAcceptPriceOffer,
        params: {
          'p_offer_id': offerId,
          'p_caller_id': callerId,
        },
      );
      _fallback.markOfferAcceptedLocally(offerId);
      return true;
    } catch (e) {
      debugPrint('ℹ️ [SupabaseRequestsRepository] acceptPriceOffer failed ($e). Using fallback.');
      return await _fallback.acceptPriceOffer(offerId: offerId, callerId: callerId);
    }
  }

  @override
  Future<bool> rejectPriceOffer(String offerId) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return _fallback.rejectPriceOffer(offerId);
    }

    try {
      await _client.rpc(
        SupabaseConfig.rpcRejectPriceOffer,
        params: {'p_offer_id': offerId},
      );
      _fallback.markOfferRejectedLocally(offerId);
      return true;
    } catch (e) {
      debugPrint('ℹ️ [SupabaseRequestsRepository] rejectPriceOffer failed ($e). Using fallback.');
      return await _fallback.rejectPriceOffer(offerId);
    }
  }

  @override
  Future<bool> declineRequest({
    required String requestId,
    required String providerId,
  }) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return _fallback.declineRequest(requestId: requestId, providerId: providerId);
    }

    try {
      await _client
          .from(SupabaseConfig.tableRequestRecipients)
          .update({'status': 'declined'})
          .eq('request_id', requestId)
          .eq('provider_id', providerId);

      _fallback.declineRequest(requestId: requestId, providerId: providerId);
      return true;
    } catch (e) {
      debugPrint('ℹ️ [SupabaseRequestsRepository] declineRequest failed ($e). Using fallback.');
      return await _fallback.declineRequest(requestId: requestId, providerId: providerId);
    }
  }

  @override
  Future<bool> cancelRequest(String requestId) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return _fallback.cancelRequest(requestId);
    }

    try {
      await _client.rpc(
        SupabaseConfig.rpcCancelServiceRequest,
        params: {'p_request_id': requestId},
      );
      _fallback.cancelRequest(requestId);
      return true;
    } catch (e) {
      debugPrint('ℹ️ [SupabaseRequestsRepository] cancelRequest failed ($e). Using fallback.');
      return await _fallback.cancelRequest(requestId);
    }
  }
}

/// Robust In-Memory repository for unit tests, offline development, and fallback simulation.
class InMemoryRequestsRepository implements RequestsRepository {
  final List<ServiceRequest> _requests = List.from(ServiceRequest.submittedRequests);
  final Set<String> _declinedRequests = {};

  @override
  Future<ServiceRequest> createServiceRequest({
    required String categoryId,
    required String title,
    required String description,
    String urgency = 'standard',
    ServiceDeliveryMode deliveryMode = ServiceDeliveryMode.onSiteVisit,
    required String locationArea,
    String? exactAddress,
    double? latitude,
    double? longitude,
    required DateTime preferredDate,
    DateTime? preferredScheduleEnd,
    required int budgetAmount,
    String? targetProviderId,
    String? initialMessage,
    String? targetProviderName,
    String? targetProviderProfession,
    String? targetProviderAvatar,
  }) async {
    final newId = 'SOA-${DateTime.now().millisecondsSinceEpoch % 100000}';
    final initialOffer = NegotiationMessage(
      id: 'off-${DateTime.now().millisecondsSinceEpoch}',
      sender: OfferSender.customer,
      senderName: UserAccount.current.fullName.isNotEmpty ? UserAccount.current.fullName : 'You',
      text: initialMessage ?? 'Initial service budget for $title',
      timestamp: DateTime.now(),
      proposedPrice: budgetAmount,
      offerStatus: OfferStatus.pending,
    );

    final newRequest = ServiceRequest(
      id: newId,
      providerId: targetProviderId ?? 'pro-warri-1',
      providerName: targetProviderName ?? 'Ochuko Efe',
      providerProfession: targetProviderProfession ?? 'Piping & Water Pump Specialist',
      providerAvatarUrl: targetProviderAvatar ?? 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
      serviceId: categoryId,
      serviceTitle: title,
      servicePrice: '₦$budgetAmount',
      servicePriceAmount: budgetAmount,
      description: description,
      photoAttachments: const [],
      address: exactAddress ?? locationArea,
      locationNote: locationArea,
      preferredDate: preferredDate,
      preferredTimeSlot: 'Morning (8:00 AM – 12:00 PM)',
      deliveryMode: deliveryMode,
      isEstimatedPrice: true,
      createdAt: DateTime.now(),
      status: 'Pending Provider Confirmation',
      negotiationStatus: NegotiationStatus.awaitingResponse,
      negotiationMessages: [initialOffer],
    );

    _requests.insert(0, newRequest);
    saveRequestLocally(newRequest);
    return newRequest;
  }

  @override
  Future<List<ServiceRequest>> getCustomerRequests(String customerId, {bool forceRefresh = false}) async {
    return List.unmodifiable(_requests);
  }

  @override
  Future<List<ServiceRequest>> getProviderInboxRequests(String providerId, {bool forceRefresh = false}) async {
    final matched = _requests
        .where((r) => r.providerId == providerId && !_declinedRequests.contains('${r.id}:$providerId'))
        .toList();
    if (matched.isNotEmpty) return matched;
    return _requests
        .where((r) => !_declinedRequests.contains('${r.id}:$providerId'))
        .toList();
  }

  @override
  Future<ServiceRequest?> getRequestById(String requestId, {bool forceRefresh = false}) async {
    try {
      return _requests.firstWhere((r) => r.id == requestId);
    } catch (_) {
      return _requests.isNotEmpty ? _requests.first : null;
    }
  }

  @override
  Future<NegotiationMessage> submitPriceOffer({
    required String requestId,
    required int amountNaira,
    String? message,
  }) async {
    final idx = _requests.indexWhere((r) => r.id == requestId);
    final isCustomer = UserAccount.current.currentMode == AppMode.customer;
    final senderRole = isCustomer ? OfferSender.customer : OfferSender.provider;
    final senderName = isCustomer
        ? (UserAccount.current.fullName.isNotEmpty ? UserAccount.current.fullName : 'You')
        : 'Adams Electro-Works (You)';

    final newMsg = NegotiationMessage(
      id: 'off-${DateTime.now().millisecondsSinceEpoch}',
      sender: senderRole,
      senderName: senderName,
      text: message ?? 'Counteroffer proposed: ₦$amountNaira',
      timestamp: DateTime.now(),
      proposedPrice: amountNaira,
      offerStatus: OfferStatus.pending,
    );

    if (idx != -1) {
      final req = _requests[idx];
      final updatedMsgs = req.negotiationMessages.map((m) {
        if (m.offerStatus == OfferStatus.pending) {
          return m.copyWith(offerStatus: OfferStatus.replaced);
        }
        return m;
      }).toList()..add(newMsg);

      final updated = req.copyWith(
        negotiationStatus: NegotiationStatus.counterofferReceived,
        negotiationMessages: updatedMsgs,
      );
      _requests[idx] = updated;
      saveRequestLocally(updated);
    }

    return newMsg;
  }

  @override
  Future<bool> acceptPriceOffer({
    required String offerId,
    required String callerId,
  }) async {
    for (int i = 0; i < _requests.length; i++) {
      final req = _requests[i];
      final offerIdx = req.negotiationMessages.indexWhere((m) => m.id == offerId);
      if (offerIdx != -1) {
        final offer = req.negotiationMessages[offerIdx];
        final updatedMsgs = req.negotiationMessages.map((m) {
          if (m.id == offerId) {
            return m.copyWith(offerStatus: OfferStatus.accepted);
          } else if (m.offerStatus == OfferStatus.pending) {
            return m.copyWith(offerStatus: OfferStatus.replaced);
          }
          return m;
        }).toList();

        final updated = req.copyWith(
          status: 'Confirmed Appointment',
          negotiationStatus: NegotiationStatus.priceAgreed,
          agreedPrice: offer.proposedPrice ?? req.servicePriceAmount,
          negotiationMessages: updatedMsgs,
        );
        _requests[i] = updated;
        saveRequestLocally(updated);
        return true;
      }
    }
    return false;
  }

  @override
  Future<bool> rejectPriceOffer(String offerId) async {
    for (int i = 0; i < _requests.length; i++) {
      final req = _requests[i];
      final offerIdx = req.negotiationMessages.indexWhere((m) => m.id == offerId);
      if (offerIdx != -1) {
        final updatedMsgs = req.negotiationMessages.map((m) {
          if (m.id == offerId) {
            return m.copyWith(offerStatus: OfferStatus.declined);
          }
          return m;
        }).toList();

        final updated = req.copyWith(
          negotiationStatus: NegotiationStatus.awaitingResponse,
          negotiationMessages: updatedMsgs,
        );
        _requests[i] = updated;
        saveRequestLocally(updated);
        return true;
      }
    }
    return false;
  }

  @override
  Future<bool> declineRequest({
    required String requestId,
    required String providerId,
  }) async {
    _declinedRequests.add('$requestId:$providerId');
    final idx = _requests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      final updated = _requests[idx].copyWith(
        status: 'Request Declined',
        negotiationStatus: NegotiationStatus.requestCancelled,
      );
      _requests[idx] = updated;
      saveRequestLocally(updated);
      return true;
    }
    return true;
  }

  @override
  Future<bool> cancelRequest(String requestId) async {
    final idx = _requests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      final updated = _requests[idx].copyWith(
        status: 'Request Cancelled',
        negotiationStatus: NegotiationStatus.requestCancelled,
      );
      _requests[idx] = updated;
      saveRequestLocally(updated);
      return true;
    }
    return false;
  }

  void saveRequestLocally(ServiceRequest req) {
    final idx = ServiceRequest.submittedRequests.indexWhere((r) => r.id == req.id);
    if (idx != -1) {
      ServiceRequest.submittedRequests[idx] = req;
    } else {
      ServiceRequest.submittedRequests.insert(0, req);
    }
  }

  void saveOfferLocally(String requestId, NegotiationMessage offer) {
    final idx = ServiceRequest.submittedRequests.indexWhere((r) => r.id == requestId);
    if (idx != -1) {
      final req = ServiceRequest.submittedRequests[idx];
      final updated = req.copyWith(
        negotiationMessages: [...req.negotiationMessages, offer],
      );
      ServiceRequest.submittedRequests[idx] = updated;
    }
  }

  void markOfferAcceptedLocally(String offerId) {
    for (int i = 0; i < ServiceRequest.submittedRequests.length; i++) {
      final req = ServiceRequest.submittedRequests[i];
      final offerIdx = req.negotiationMessages.indexWhere((m) => m.id == offerId);
      if (offerIdx != -1) {
        final offer = req.negotiationMessages[offerIdx];
        final updated = req.copyWith(
          status: 'Confirmed Appointment',
          negotiationStatus: NegotiationStatus.priceAgreed,
          agreedPrice: offer.proposedPrice ?? req.servicePriceAmount,
        );
        ServiceRequest.submittedRequests[i] = updated;
        break;
      }
    }
  }

  void markOfferRejectedLocally(String offerId) {
    for (int i = 0; i < ServiceRequest.submittedRequests.length; i++) {
      final req = ServiceRequest.submittedRequests[i];
      final offerIdx = req.negotiationMessages.indexWhere((m) => m.id == offerId);
      if (offerIdx != -1) {
        final updated = req.copyWith(
          negotiationStatus: NegotiationStatus.awaitingResponse,
        );
        ServiceRequest.submittedRequests[i] = updated;
        break;
      }
    }
  }
}
