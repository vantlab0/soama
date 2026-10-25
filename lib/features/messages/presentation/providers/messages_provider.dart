import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/supabase_config.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../shared/models/chat_conversation.dart';
import '../../../../shared/models/user_account.dart';
import '../../data/messages_repository.dart';

final inMemoryMessagesInstance = InMemoryMessagesRepository();

/// Riverpod provider for the active MessagesRepository
final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  final client = SupabaseService.client;
  if (client != null && SupabaseConfig.isConfigured) {
    return SupabaseMessagesRepository(client);
  }
  return inMemoryMessagesInstance;
});

/// Stream of all active conversations for the authenticated user
final conversationsStreamProvider = StreamProvider.autoDispose<List<ChatConversation>>((ref) {
  final repo = ref.watch(messagesRepositoryProvider);
  final userId = UserAccount.current.id;
  return repo.watchConversations(userId: userId);
});

/// Stream of messages for a single active conversation
final conversationMessagesStreamProvider =
    StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, conversationId) {
  final repo = ref.watch(messagesRepositoryProvider);
  final currentUserId = UserAccount.current.id;
  return repo.watchMessages(conversationId, currentUserId: currentUserId);
});
