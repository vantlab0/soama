import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/soama_colors.dart';
import '../../../shared/models/chat_conversation.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glass_search_field.dart';
import 'providers/messages_provider.dart';

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final conversationsAsync = ref.watch(conversationsStreamProvider);
    final rawConversations = conversationsAsync.valueOrNull ?? ChatConversation.activeConversations;

    final conversations = rawConversations.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return c.providerName.toLowerCase().contains(q) ||
          c.providerProfession.toLowerCase().contains(q) ||
          c.lastMessage.toLowerCase().contains(q);
    }).toList();

    final timeFormatter = DateFormat('h:mm a');
    final dateFormatter = DateFormat('MMM d');

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: colors.accent,
          backgroundColor: colors.surface,
          onRefresh: () async {
            HapticFeedback.lightImpact();
            await Future.delayed(const Duration(milliseconds: 300));
            if (mounted) setState(() {});
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 4.0),
                child: Text(
                  'Messages',
                  style: SoamaTypography.displayMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'Chat directly with verified artisans and specialists',
                  style: SoamaTypography.bodyMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: SoamaSpacing.md),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: GlassSearchField(
                  controller: _searchController,
                  hintText: 'Search chats or specialists...',
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim());
                  },
                ),
              ),

              const SizedBox(height: SoamaSpacing.md),

              // Conversations List
              Expanded(
                child: conversations.isEmpty
                    ? EmptyState(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: _searchQuery.isEmpty ? 'No Messages Yet' : 'No Results Found',
                        message: _searchQuery.isEmpty
                            ? 'Conversations with artisans will appear here when you book or inquire about services.'
                            : 'No messages match "$_searchQuery". Try another specialist name.',
                        actionLabel: _searchQuery.isNotEmpty ? 'Clear Search' : null,
                        onActionPressed: _searchQuery.isNotEmpty
                            ? () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              }
                            : null,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20.0, 4.0, 20.0, 120.0),
                        physics: const BouncingScrollPhysics(),
                        itemCount: conversations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: SoamaSpacing.sm),
                        itemBuilder: (context, index) {
                          final item = conversations[index];
                          final hasUnread = item.unreadCount > 0;

                          // Time display
                          final isToday = DateTime.now().difference(item.lastMessageTime).inDays == 0;
                          final formattedTime = isToday
                              ? timeFormatter.format(item.lastMessageTime)
                              : dateFormatter.format(item.lastMessageTime);

                          return GlassCard(
                            borderRadius: SoamaRadii.radiusXl,
                            padding: const EdgeInsets.all(14.0),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              context.push(
                                AppRoutes.conversationPath(item.id),
                                extra: item,
                              );
                            },
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: SoamaRadii.radiusLg,
                                  child: SizedBox(
                                    width: 52,
                                    height: 52,
                                    child: Image(
                                      image: ResizeImage(
                                        NetworkImage(item.providerAvatarUrl),
                                        width: 120,
                                        height: 120,
                                      ),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: colors.surfaceSubtle,
                                        child: Icon(Icons.person_rounded, color: colors.textTertiary),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: SoamaSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              item.providerName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: SoamaTypography.titleSmall.copyWith(
                                                color: colors.textPrimary,
                                                fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            formattedTime,
                                            style: SoamaTypography.labelSmall.copyWith(
                                              color: hasUnread ? colors.accent : colors.textTertiary,
                                              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.providerProfession,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: SoamaTypography.labelSmall.copyWith(
                                          color: colors.textTertiary,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.lastMessage,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: SoamaTypography.bodySmall.copyWith(
                                          color: hasUnread ? colors.textPrimary : colors.textSecondary,
                                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (hasUnread) ...[
                                  const SizedBox(width: SoamaSpacing.xs),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: colors.accent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${item.unreadCount}',
                                      style: TextStyle(
                                        color: colors.onAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
