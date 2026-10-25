import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/theme/soama_colors.dart';
import '../../../../shared/models/chat_conversation.dart';
import '../../../../shared/models/user_account.dart';
import '../../../../shared/widgets/glass_surface.dart';
import '../../storage/presentation/providers/storage_provider.dart';
import '../../storage/presentation/widgets/image_picker_sheet.dart';
import 'providers/messages_provider.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final ChatConversation? initialConversation;

  const ConversationScreen({
    super.key,
    required this.conversationId,
    this.initialConversation,
  });

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  late ChatConversation _conversation;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final bool _isArtisanTyping = false;
  bool _isUploadingAttachment = false;

  @override
  void initState() {
    super.initState();
    _conversation = widget.initialConversation ??
        ChatConversation.findById(widget.conversationId) ??
        ChatConversation.activeConversations.first;

    // Mark as read upon opening
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(messagesRepositoryProvider).markConversationAsRead(
            conversationId: widget.conversationId,
            isCustomer: true,
          );
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    _textController.clear();

    final userId = UserAccount.current.id;
    try {
      await ref.read(messagesRepositoryProvider).sendMessage(
            conversationId: widget.conversationId,
            senderId: userId,
            text: text,
          );
      _scrollToBottom();
    } catch (e) {
      debugPrint('⚠️ [ConversationScreen] Send message failed: $e');
    }
  }

  Future<void> _pickAndSendAttachment() async {
    HapticFeedback.lightImpact();
    final payload = await ImagePickerSheet.show(
      context,
      title: 'Attach Photo to Chat',
    );

    if (payload == null) return;

    setState(() => _isUploadingAttachment = true);
    final userId = UserAccount.current.id;

    try {
      final storageRepo = ref.read(storageRepositoryProvider);
      final signedUrl = await storageRepo.uploadChatAttachment(
        conversationId: widget.conversationId,
        userId: userId,
        bytes: payload.bytes,
        fileName: payload.fileName,
      );

      await ref.read(messagesRepositoryProvider).sendMessage(
            conversationId: widget.conversationId,
            senderId: userId,
            text: '📷 Photo attachment',
            attachmentUrl: signedUrl,
          );

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attachment upload failed: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAttachment = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final messagesAsync = ref.watch(conversationMessagesStreamProvider(widget.conversationId));
    final liveMessages = messagesAsync.valueOrNull ?? _conversation.messages;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas.withOpacity(0.92),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: colors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: SoamaRadii.radiusMd,
              child: SizedBox(
                width: 36,
                height: 36,
                child: Image(
                  image: ResizeImage(
                    NetworkImage(_conversation.providerAvatarUrl),
                    width: 90,
                    height: 90,
                  ),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: colors.surfaceSubtle,
                    child: Icon(Icons.person_rounded, color: colors.textTertiary, size: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: SoamaSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _conversation.providerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SoamaTypography.titleSmall.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Online • ${_conversation.providerProfession.split('&').first.trim()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SoamaTypography.labelSmall.copyWith(
                          color: colors.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Contextual Booking Banner if linked to a request
            if (_conversation.serviceTitle != null) _buildBookingHeader(context),

            // Message Bubble Feed
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                itemCount: liveMessages.length + (_isArtisanTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == liveMessages.length && _isArtisanTyping) {
                    return _buildTypingIndicator(context);
                  }
                  final msg = liveMessages[index];
                  return _buildMessageItem(context, msg);
                },
              ),
            ),

            if (_isUploadingAttachment)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Uploading photo attachment to secure storage...',
                      style: SoamaTypography.labelSmall.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),

            // Bottom Message Composer
            _buildMessageComposer(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingHeader(BuildContext context) {
    final colors = context.soamaColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: GlassSurface(
        borderRadius: SoamaRadii.radiusLg,
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        blurIntensity: GlassBlurIntensity.none,
        child: Row(
          children: [
            Icon(Icons.handyman_outlined, color: colors.accent, size: 20),
            const SizedBox(width: SoamaSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _conversation.serviceTitle ?? 'Service Discussion',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SoamaTypography.labelMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_conversation.serviceRequestId != null)
                    Text(
                      'Ref: ${_conversation.serviceRequestId}',
                      style: SoamaTypography.labelSmall.copyWith(
                        color: colors.textTertiary,
                        fontSize: 10.5,
                      ),
                    ),
                ],
              ),
            ),
            if (_conversation.agreedPrice != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: colors.accent.withOpacity(0.12),
                  borderRadius: SoamaRadii.radiusSm,
                ),
                child: Text(
                  'Rate: ${_conversation.agreedPrice} in Escrow',
                  style: SoamaTypography.labelSmall.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(BuildContext context, ChatMessage msg) {
    final colors = context.soamaColors;
    final isCustomer = msg.isFromCustomer;
    final timeFormatter = DateFormat('h:mm a');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: isCustomer ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (msg.isSimulatedProvider)
            Padding(
              padding: const EdgeInsets.only(left: 6.0, bottom: 2.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: colors.textTertiary.withOpacity(0.15),
                  borderRadius: SoamaRadii.radiusPill,
                ),
                child: Text(
                  'Simulated Artisan',
                  style: TextStyle(
                    color: colors.textTertiary,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.76,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: isCustomer
                  ? (context.isDarkMode ? const Color(0xFF272D3B) : const Color(0xFFE4DFD5))
                  : (context.isDarkMode ? const Color(0xFF1B1E26) : colors.surface),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isCustomer ? 16 : 4),
                bottomRight: Radius.circular(isCustomer ? 4 : 16),
              ),
              border: Border.all(
                color: isCustomer ? colors.accent.withOpacity(0.3) : colors.glassBorder,
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (msg.attachmentUrl != null && msg.attachmentUrl!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      color: colors.surfaceSubtle,
                      child: Image.network(
                        msg.attachmentUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          padding: const EdgeInsets.all(12),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.insert_drive_file_rounded, color: colors.accent, size: 24),
                              const SizedBox(width: 8),
                              Text('Document / Attachment', style: TextStyle(color: colors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  msg.text,
                  style: SoamaTypography.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Text(
              timeFormatter.format(msg.timestamp),
              style: SoamaTypography.labelSmall.copyWith(
                color: colors.textTertiary.withOpacity(0.65),
                fontSize: 9.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(BuildContext context) {
    final colors = context.soamaColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: colors.surfaceSubtle,
              borderRadius: SoamaRadii.radiusPill,
              border: Border.all(color: colors.glassBorder, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(strokeWidth: 1.8, color: colors.accent),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_conversation.providerName} is typing...',
                  style: SoamaTypography.labelSmall.copyWith(color: colors.textSecondary, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageComposer(BuildContext context) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.fromLTRB(12.0, 8.0, 16.0, 14.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13151A) : colors.surface,
        border: Border(top: BorderSide(color: colors.glassBorder, width: 1.0)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.attach_file_rounded, color: colors.accent, size: 22),
            tooltip: 'Attach photo or document',
            onPressed: _isUploadingAttachment ? null : _pickAndSendAttachment,
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              maxLines: 3,
              minLines: 1,
              style: SoamaTypography.bodyMedium.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Type a message to ${_conversation.providerName}...',
                hintStyle: SoamaTypography.bodySmall.copyWith(color: colors.textTertiary),
                filled: true,
                fillColor: colors.surfaceSubtle,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                border: OutlineInputBorder(
                  borderRadius: SoamaRadii.radiusLg,
                  borderSide: BorderSide(color: colors.glassBorder, width: 0.8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: SoamaRadii.radiusLg,
                  borderSide: BorderSide(color: colors.accent, width: 1.2),
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: colors.accent,
            borderRadius: SoamaRadii.radiusLg,
            child: InkWell(
              onTap: _sendMessage,
              borderRadius: SoamaRadii.radiusLg,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: colors.onAccent,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
