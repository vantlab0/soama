import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/supabase_config.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/models/service_request.dart';
import '../../../../shared/models/user_account.dart';
import '../../data/requests_repository.dart';

/// Provider exposing the RequestsRepository implementation.
final requestsRepositoryProvider = Provider<RequestsRepository>((ref) {
  final client = SupabaseService.client;
  if (client != null && SupabaseConfig.isConfigured) {
    return SupabaseRequestsRepository(client);
  }
  return InMemoryRequestsRepository();
});

/// Provider for customer's service requests list.
final customerRequestsProvider = FutureProvider.autoDispose<List<ServiceRequest>>((ref) async {
  final repo = ref.watch(requestsRepositoryProvider);
  final userId = UserAccount.current.id;
  return repo.getCustomerRequests(userId, forceRefresh: true);
});

/// Provider for provider's incoming request inbox.
final providerInboxRequestsProvider = FutureProvider.autoDispose<List<ServiceRequest>>((ref) async {
  final repo = ref.watch(requestsRepositoryProvider);
  final providerId = UserAccount.current.providerProfile?.providerId ?? UserAccount.current.id;
  return repo.getProviderInboxRequests(providerId, forceRefresh: true);
});

/// Provider for individual service request details.
final requestDetailsProvider =
    FutureProvider.autoDispose.family<ServiceRequest?, String>((ref, requestId) async {
  final repo = ref.watch(requestsRepositoryProvider);
  return repo.getRequestById(requestId, forceRefresh: true);
});

/// StateNotifier for active price negotiation workflow.
class NegotiationNotifier extends StateNotifier<AsyncValue<ServiceRequest?>> {
  final RequestsRepository _repository;
  final String _requestId;

  NegotiationNotifier(this._repository, this._requestId)
      : super(const AsyncValue.loading()) {
    loadRequest();
  }

  Future<void> loadRequest() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.getRequestById(_requestId, forceRefresh: true));
  }

  Future<bool> sendOffer({required int amountNaira, String? message}) async {
    try {
      final newOffer = await _repository.submitPriceOffer(
        requestId: _requestId,
        amountNaira: amountNaira,
        message: message,
      );

      final current = state.value;
      if (current != null) {
        final updatedMsgs = current.negotiationMessages.map((m) {
          if (m.offerStatus == OfferStatus.pending) {
            return m.copyWith(offerStatus: OfferStatus.replaced);
          }
          return m;
        }).toList()..add(newOffer);

        state = AsyncValue.data(current.copyWith(
          negotiationStatus: NegotiationStatus.counterofferReceived,
          negotiationMessages: updatedMsgs,
        ));
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> acceptOffer(String offerId, String callerId) async {
    try {
      final success = await _repository.acceptPriceOffer(
        offerId: offerId,
        callerId: callerId,
      );

      if (success) {
        final current = state.value;
        if (current != null) {
          final updatedMsgs = current.negotiationMessages.map((m) {
            if (m.id == offerId) {
              return m.copyWith(offerStatus: OfferStatus.accepted);
            } else if (m.offerStatus == OfferStatus.pending) {
              return m.copyWith(offerStatus: OfferStatus.replaced);
            }
            return m;
          }).toList();

          int? agreedPrice;
          for (final m in current.negotiationMessages) {
            if (m.id == offerId) agreedPrice = m.proposedPrice;
          }

          state = AsyncValue.data(current.copyWith(
            status: 'Confirmed Appointment',
            negotiationStatus: NegotiationStatus.priceAgreed,
            agreedPrice: agreedPrice ?? current.servicePriceAmount,
            negotiationMessages: updatedMsgs,
          ));
        }
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  Future<bool> declineOffer(String offerId) async {
    try {
      final success = await _repository.rejectPriceOffer(offerId);
      if (success) {
        final current = state.value;
        if (current != null) {
          final updatedMsgs = current.negotiationMessages.map((m) {
            if (m.id == offerId) {
              return m.copyWith(offerStatus: OfferStatus.declined);
            }
            return m;
          }).toList();

          state = AsyncValue.data(current.copyWith(
            negotiationStatus: NegotiationStatus.awaitingResponse,
            negotiationMessages: updatedMsgs,
          ));
        }
      }
      return success;
    } catch (e) {
      return false;
    }
  }
}

/// Provider family for negotiation notifier.
final negotiationProvider = StateNotifierProvider.autoDispose
    .family<NegotiationNotifier, AsyncValue<ServiceRequest?>, String>((ref, requestId) {
  final repo = ref.watch(requestsRepositoryProvider);
  return NegotiationNotifier(repo, requestId);
});
