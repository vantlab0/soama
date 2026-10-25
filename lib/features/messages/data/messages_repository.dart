import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_config.dart';
import '../../../shared/models/chat_conversation.dart';

abstract class MessagesRepository {
  Future<List<ChatConversation>> getConversations({required String userId});
  Stream<List<ChatConversation>> watchConversations({required String userId});
  Future<List<ChatMessage>> getMessages(String conversationId, {required String currentUserId});
  Stream<List<ChatMessage>> watchMessages(String conversationId, {required String currentUserId});
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
    String? attachmentUrl,
  });
  Future<ChatConversation> getOrCreateConversation({
    required String customerId,
    required String providerId,
    String? bookingId,
  });
  Future<void> markConversationAsRead({
    required String conversationId,
    required bool isCustomer,
  });
}

class SupabaseMessagesRepository implements MessagesRepository {
  final SupabaseClient _client;
  final InMemoryMessagesRepository _fallback = InMemoryMessagesRepository();

  SupabaseMessagesRepository(this._client);

  @override
  Future<List<ChatConversation>> getConversations({required String userId}) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return await _fallback.getConversations(userId: userId);
    }

    try {
      final data = await _client
          .from(SupabaseConfig.tableConversations)
          .select('''
            *,
            customer_profile:customer_id(full_name, avatar_url, first_name, last_name),
            provider_profile:provider_id(
              business_name,
              profession,
              profiles:id(full_name, avatar_url)
            )
          ''')
          .or('customer_id.eq.$userId,provider_id.eq.$userId')
          .order('last_message_at', ascending: false);

      final rows = data as List<dynamic>;
      return rows.map((r) => ChatConversation.fromSupabase(r as Map<String, dynamic>, currentUserId: userId)).toList();
    } catch (e) {
      debugPrint('ℹ️ [SupabaseMessagesRepository] getConversations error ($e). Using fallback.');
      return await _fallback.getConversations(userId: userId);
    }
  }

  @override
  Stream<List<ChatConversation>> watchConversations({required String userId}) {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return _fallback.watchConversations(userId: userId);
    }

    try {
      return _client
          .from(SupabaseConfig.tableConversations)
          .stream(primaryKey: ['id'])
          .order('last_message_at', ascending: false)
          .asyncMap((_) => getConversations(userId: userId));
    } catch (e) {
      debugPrint('ℹ️ [SupabaseMessagesRepository] watchConversations error ($e). Falling back.');
      return _fallback.watchConversations(userId: userId);
    }
  }

  @override
  Future<List<ChatMessage>> getMessages(String conversationId, {required String currentUserId}) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return await _fallback.getMessages(conversationId, currentUserId: currentUserId);
    }

    try {
      final data = await _client
          .from(SupabaseConfig.tableMessages)
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      final rows = data as List<dynamic>;
      return rows.map((r) => ChatMessage.fromSupabase(r as Map<String, dynamic>, currentUserId: currentUserId)).toList();
    } catch (e) {
      debugPrint('ℹ️ [SupabaseMessagesRepository] getMessages error ($e). Using fallback.');
      return await _fallback.getMessages(conversationId, currentUserId: currentUserId);
    }
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId, {required String currentUserId}) {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return _fallback.watchMessages(conversationId, currentUserId: currentUserId);
    }

    try {
      return _client
          .from(SupabaseConfig.tableMessages)
          .stream(primaryKey: ['id'])
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true)
          .map((rows) {
            return rows.map((r) => ChatMessage.fromSupabase(r, currentUserId: currentUserId)).toList();
          });
    } catch (e) {
      debugPrint('ℹ️ [SupabaseMessagesRepository] watchMessages error ($e). Falling back.');
      return _fallback.watchMessages(conversationId, currentUserId: currentUserId);
    }
  }

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
    String? attachmentUrl,
  }) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return await _fallback.sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        text: text,
        attachmentUrl: attachmentUrl,
      );
    }

    try {
      final inserted = await _client.from(SupabaseConfig.tableMessages).insert({
        'conversation_id': conversationId,
        'sender_id': senderId,
        'body': text,
        if (attachmentUrl != null) 'attachment_url': attachmentUrl,
        'is_read': false,
      }).select().single();

      // Update conversation last message timestamp & increment unread counter
      final convRow = await _client
          .from(SupabaseConfig.tableConversations)
          .select('customer_id, provider_id, unread_customer_count, unread_provider_count')
          .eq('id', conversationId)
          .maybeSingle();

      if (convRow != null) {
        final isCustomerSender = senderId == convRow['customer_id'];
        await _client.from(SupabaseConfig.tableConversations).update({
          'last_message': text,
          'last_message_at': DateTime.now().toUtc().toIso8601String(),
          if (isCustomerSender)
            'unread_provider_count': ((convRow['unread_provider_count'] as num?)?.toInt() ?? 0) + 1
          else
            'unread_customer_count': ((convRow['unread_customer_count'] as num?)?.toInt() ?? 0) + 1,
        }).eq('id', conversationId);
      }

      return ChatMessage.fromSupabase(inserted, currentUserId: senderId);
    } catch (e) {
      debugPrint('⚠️ [SupabaseMessagesRepository] sendMessage error ($e). Falling back.');
      return await _fallback.sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        text: text,
        attachmentUrl: attachmentUrl,
      );
    }
  }

  @override
  Future<ChatConversation> getOrCreateConversation({
    required String customerId,
    required String providerId,
    String? bookingId,
  }) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      return await _fallback.getOrCreateConversation(
        customerId: customerId,
        providerId: providerId,
        bookingId: bookingId,
      );
    }

    try {
      var query = _client
          .from(SupabaseConfig.tableConversations)
          .select('''
            *,
            customer_profile:customer_id(full_name, avatar_url, first_name, last_name),
            provider_profile:provider_id(
              business_name,
              profession,
              profiles:id(full_name, avatar_url)
            )
          ''')
          .eq('customer_id', customerId)
          .eq('provider_id', providerId);

      if (bookingId != null) {
        query = query.eq('booking_id', bookingId);
      }

      final existing = await query.maybeSingle();
      if (existing != null) {
        return ChatConversation.fromSupabase(existing, currentUserId: customerId);
      }

      final created = await _client.from(SupabaseConfig.tableConversations).insert({
        'customer_id': customerId,
        'provider_id': providerId,
        if (bookingId != null) 'booking_id': bookingId,
        'last_message': 'Conversation initialized',
        'last_message_at': DateTime.now().toUtc().toIso8601String(),
      }).select('''
        *,
        customer_profile:customer_id(full_name, avatar_url, first_name, last_name),
        provider_profile:provider_id(
          business_name,
          profession,
          profiles:id(full_name, avatar_url)
        )
      ''').single();

      return ChatConversation.fromSupabase(created, currentUserId: customerId);
    } catch (e) {
      debugPrint('⚠️ [SupabaseMessagesRepository] getOrCreateConversation error ($e). Falling back.');
      return await _fallback.getOrCreateConversation(
        customerId: customerId,
        providerId: providerId,
        bookingId: bookingId,
      );
    }
  }

  @override
  Future<void> markConversationAsRead({
    required String conversationId,
    required bool isCustomer,
  }) async {
    if (!SupabaseConfig.isConfigured || _client.auth.currentUser == null) {
      await _fallback.markConversationAsRead(
        conversationId: conversationId,
        isCustomer: isCustomer,
      );
      return;
    }

    try {
      await _client.from(SupabaseConfig.tableConversations).update({
        if (isCustomer) 'unread_customer_count': 0 else 'unread_provider_count': 0,
      }).eq('id', conversationId);

      await _client
          .from(SupabaseConfig.tableMessages)
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .neq('sender_id', _client.auth.currentUser!.id);
    } catch (e) {
      debugPrint('ℹ️ [SupabaseMessagesRepository] markConversationAsRead error: $e');
      await _fallback.markConversationAsRead(
        conversationId: conversationId,
        isCustomer: isCustomer,
      );
    }
  }
}

class InMemoryMessagesRepository implements MessagesRepository {
  final List<ChatConversation> _conversations = List.from(ChatConversation.activeConversations);
  final StreamController<List<ChatConversation>> _convStreamController =
      StreamController<List<ChatConversation>>.broadcast();
  final Map<String, StreamController<List<ChatMessage>>> _messageStreamControllers = {};

  InMemoryMessagesRepository() {
    _convStreamController.add(List.unmodifiable(_conversations));
  }

  @override
  Future<List<ChatConversation>> getConversations({required String userId}) async {
    return List.unmodifiable(_conversations);
  }

  @override
  Stream<List<ChatConversation>> watchConversations({required String userId}) async* {
    yield List.unmodifiable(_conversations);
    yield* _convStreamController.stream;
  }

  @override
  Future<List<ChatMessage>> getMessages(String conversationId, {required String currentUserId}) async {
    final conv = _findConv(conversationId);
    return conv != null ? List.unmodifiable(conv.messages) : const [];
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId, {required String currentUserId}) async* {
    final conv = _findConv(conversationId);
    yield conv != null ? List.unmodifiable(conv.messages) : const [];
    final controller = _getOrCreateMsgController(conversationId);
    yield* controller.stream;
  }

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
    String? attachmentUrl,
  }) async {
    final newMsg = ChatMessage(
      id: 'm-${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      timestamp: DateTime.now(),
      isFromCustomer: true,
      senderId: senderId,
      attachmentUrl: attachmentUrl,
      isRead: false,
    );

    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      final current = _conversations[idx];
      final updatedMessages = List<ChatMessage>.from(current.messages)..add(newMsg);
      final updated = current.copyWith(
        messages: updatedMessages,
        lastMessage: text,
        lastMessageTime: DateTime.now(),
      );
      _conversations[idx] = updated;
      _getOrCreateMsgController(conversationId).add(List.unmodifiable(updatedMessages));
      _convStreamController.add(List.unmodifiable(_conversations));
    }

    return newMsg;
  }

  @override
  Future<ChatConversation> getOrCreateConversation({
    required String customerId,
    required String providerId,
    String? bookingId,
  }) async {
    final existing = _conversations.where((c) => c.providerId == providerId).firstOrNull;
    if (existing != null) return existing;

    final newConv = ChatConversation(
      id: 'conv-${DateTime.now().millisecondsSinceEpoch % 100000}',
      providerId: providerId,
      providerName: 'Specialist $providerId',
      providerProfession: 'Verified Specialist',
      providerAvatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
      customerId: customerId,
      bookingId: bookingId,
      lastMessage: 'Conversation opened',
      lastMessageTime: DateTime.now(),
      unreadCount: 0,
      messages: const [],
    );

    _conversations.insert(0, newConv);
    _convStreamController.add(List.unmodifiable(_conversations));
    return newConv;
  }

  @override
  Future<void> markConversationAsRead({
    required String conversationId,
    required bool isCustomer,
  }) async {
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      _conversations[idx] = _conversations[idx].copyWith(unreadCount: 0);
      _convStreamController.add(List.unmodifiable(_conversations));
    }
  }

  ChatConversation? _findConv(String id) {
    try {
      return _conversations.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  StreamController<List<ChatMessage>> _getOrCreateMsgController(String convId) {
    return _messageStreamControllers.putIfAbsent(
      convId,
      () => StreamController<List<ChatMessage>>.broadcast(),
    );
  }
}
