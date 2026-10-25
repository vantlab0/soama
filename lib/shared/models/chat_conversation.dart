class ChatMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isFromCustomer;
  final bool isSimulatedProvider;
  final String? senderId;
  final String? attachmentUrl;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isFromCustomer,
    this.isSimulatedProvider = false,
    this.senderId,
    this.attachmentUrl,
    this.isRead = true,
  });

  factory ChatMessage.fromSupabase(Map<String, dynamic> json, {required String currentUserId}) {
    final sender = (json['sender_id'] as String?) ?? '';
    final createdAt = json['created_at'] != null
        ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
        : DateTime.now();

    return ChatMessage(
      id: (json['id'] as String?) ?? '',
      text: (json['body'] as String?) ?? '',
      timestamp: createdAt.toLocal(),
      isFromCustomer: sender == currentUserId,
      senderId: sender,
      attachmentUrl: json['attachment_url'] as String?,
      isRead: (json['is_read'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toSupabase({required String conversationId}) {
    return {
      'conversation_id': conversationId,
      if (senderId != null) 'sender_id': senderId,
      'body': text,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      'is_read': isRead,
    };
  }
}

class ChatConversation {
  final String id;
  final String providerId;
  final String providerName;
  final String providerProfession;
  final String providerAvatarUrl;
  final String? customerId;
  final String? customerName;
  final String? customerAvatarUrl;
  final String? bookingId;
  final String? serviceRequestId;
  final String? serviceTitle;
  final String? agreedPrice;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final List<ChatMessage> messages;

  const ChatConversation({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.providerProfession,
    required this.providerAvatarUrl,
    this.customerId,
    this.customerName,
    this.customerAvatarUrl,
    this.bookingId,
    this.serviceRequestId,
    this.serviceTitle,
    this.agreedPrice,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    required this.messages,
  });

  ChatConversation copyWith({
    String? providerName,
    String? providerProfession,
    String? providerAvatarUrl,
    String? customerName,
    String? customerAvatarUrl,
    String? bookingId,
    String? serviceRequestId,
    String? serviceTitle,
    String? agreedPrice,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    List<ChatMessage>? messages,
  }) {
    return ChatConversation(
      id: id,
      providerId: providerId,
      providerName: providerName ?? this.providerName,
      providerProfession: providerProfession ?? this.providerProfession,
      providerAvatarUrl: providerAvatarUrl ?? this.providerAvatarUrl,
      customerId: customerId,
      customerName: customerName ?? this.customerName,
      customerAvatarUrl: customerAvatarUrl ?? this.customerAvatarUrl,
      bookingId: bookingId ?? this.bookingId,
      serviceRequestId: serviceRequestId ?? this.serviceRequestId,
      serviceTitle: serviceTitle ?? this.serviceTitle,
      agreedPrice: agreedPrice ?? this.agreedPrice,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      messages: messages ?? this.messages,
    );
  }

  factory ChatConversation.fromSupabase(
    Map<String, dynamic> json, {
    required String currentUserId,
    List<ChatMessage>? messages,
  }) {
    final customerId = json['customer_id'] as String? ?? '';
    final providerId = json['provider_id'] as String? ?? '';
    final isCustomer = currentUserId == customerId;

    final customerProfile = json['customer_profile'] as Map<String, dynamic>?;
    final providerProfile = json['provider_profile'] as Map<String, dynamic>?;
    final providerUserData = providerProfile?['profiles'] as Map<String, dynamic>?;

    final customerName = (customerProfile?['full_name'] as String?) ??
        (customerProfile?['first_name'] != null ? '${customerProfile?['first_name']} ${customerProfile?['last_name'] ?? ''}'.trim() : 'Customer');
    final customerAvatar = (customerProfile?['avatar_url'] as String?) ?? '';

    final providerBusinessName = (providerProfile?['business_name'] as String?) ??
        (providerUserData?['full_name'] as String?) ??
        'Service Provider';
    final providerProfession = (providerProfile?['profession'] as String?) ?? 'Verified Specialist';
    final providerAvatar = (providerUserData?['avatar_url'] as String?) ?? '';

    final lastMsgTime = json['last_message_at'] != null
        ? DateTime.tryParse(json['last_message_at'].toString()) ?? DateTime.now()
        : DateTime.now();

    final unread = isCustomer
        ? ((json['unread_customer_count'] as num?)?.toInt() ?? 0)
        : ((json['unread_provider_count'] as num?)?.toInt() ?? 0);

    return ChatConversation(
      id: (json['id'] as String?) ?? '',
      providerId: providerId,
      providerName: isCustomer ? providerBusinessName : customerName,
      providerProfession: isCustomer ? providerProfession : 'Customer',
      providerAvatarUrl: isCustomer ? providerAvatar : customerAvatar,
      customerId: customerId,
      customerName: customerName,
      customerAvatarUrl: customerAvatar,
      bookingId: json['booking_id'] as String?,
      lastMessage: (json['last_message'] as String?) ?? '',
      lastMessageTime: lastMsgTime.toLocal(),
      unreadCount: unread,
      messages: messages ?? const [],
    );
  }

  static ChatConversation? findById(String id) {
    try {
      return activeConversations.firstWhere((c) => c.id == id);
    } catch (_) {
      return activeConversations.isNotEmpty ? activeConversations.first : null;
    }
  }

  static List<ChatConversation> get mockConversations => activeConversations;

  static ChatConversation findOrCreateForProvider({
    required String providerId,
    required String providerName,
    required String providerProfession,
    required String providerAvatarUrl,
    String? serviceRequestId,
    String? serviceTitle,
    String? agreedPrice,
  }) {
    final existingIdx = activeConversations.indexWhere(
      (c) => (serviceRequestId != null && c.serviceRequestId == serviceRequestId) ||
             c.providerId == providerId,
    );
    if (existingIdx != -1) {
      return activeConversations[existingIdx];
    }
    final newConv = ChatConversation(
      id: 'conv-${DateTime.now().millisecondsSinceEpoch % 100000}',
      providerId: providerId,
      providerName: providerName,
      providerProfession: providerProfession,
      providerAvatarUrl: providerAvatarUrl,
      serviceRequestId: serviceRequestId,
      serviceTitle: serviceTitle,
      agreedPrice: agreedPrice,
      lastMessage: serviceTitle != null
          ? 'Discussing request: $serviceTitle'
          : 'Conversation started',
      lastMessageTime: DateTime.now(),
      unreadCount: 0,
      messages: [
        ChatMessage(
          id: 'init-${DateTime.now().millisecondsSinceEpoch}',
          text: 'Hello $providerName, I am contacting you regarding ${serviceTitle ?? 'services'}.',
          timestamp: DateTime.now(),
          isFromCustomer: true,
        ),
      ],
    );
    activeConversations.insert(0, newConv);
    return newConv;
  }

  static final List<ChatConversation> activeConversations = [
    ChatConversation(
      id: 'conv-ochuko',
      providerId: 'pro-warri-1',
      providerName: 'Ochuko Efe',
      providerProfession: 'Piping & Water Pump Specialist',
      providerAvatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
      serviceRequestId: 'SOA-2084',
      serviceTitle: 'Emergency Pipe Leak Repair',
      agreedPrice: '₦8,000',
      lastMessage: 'I have packed the 3/4-inch PVC couplings and high-pressure cement. See you soon.',
      lastMessageTime: DateTime.now().subtract(const Duration(minutes: 18)),
      unreadCount: 1,
      messages: [
        ChatMessage(
          id: 'm1',
          text: 'Good day Ochuko, could you come by Airport Road for the pipe inspection?',
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          isFromCustomer: true,
        ),
        ChatMessage(
          id: 'm2',
          text: 'Hello! Yes, I am wrapping up a nearby plumbing job in Effurun.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 40)),
          isFromCustomer: false,
          isSimulatedProvider: true,
        ),
        ChatMessage(
          id: 'm3',
          text: 'I have packed the 3/4-inch PVC couplings and high-pressure cement. See you soon.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 18)),
          isFromCustomer: false,
          isSimulatedProvider: true,
        ),
      ],
    ),
    ChatConversation(
      id: 'conv-tunde',
      providerId: 'pro-warri-3',
      providerName: 'Tunde Adeleke',
      providerProfession: 'Generator Specialist',
      providerAvatarUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=400&q=80',
      serviceRequestId: 'SOA-3091',
      serviceTitle: 'Mikano 20kVA Generator Maintenance',
      agreedPrice: '₦16,500',
      lastMessage: 'I will arrive at the Effurun site with the diagnostic kit by 10:00 AM.',
      lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)),
      unreadCount: 0,
      messages: [
        ChatMessage(
          id: 't1',
          text: 'Hello Tunde, confirming our scheduled appointment for tomorrow.',
          timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 15)),
          isFromCustomer: true,
        ),
        ChatMessage(
          id: 't2',
          text: 'I will arrive at the Effurun site with the diagnostic kit by 10:00 AM.',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          isFromCustomer: false,
          isSimulatedProvider: true,
        ),
      ],
    ),
    ChatConversation(
      id: 'conv-blessing',
      providerId: 'pro-warri-2',
      providerName: 'Blessing Igbinoba',
      providerProfession: 'Deep Cleaning Specialist',
      providerAvatarUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=400&q=80',
      serviceRequestId: 'SOA-1042',
      serviceTitle: 'Deep Home Sanitization (3-Bed Flat)',
      agreedPrice: '₦14,000',
      lastMessage: 'Thank you! The post-cleaning sanitization report has been submitted.',
      lastMessageTime: DateTime.now().subtract(const Duration(days: 1)),
      unreadCount: 0,
      messages: [
        ChatMessage(
          id: 'b1',
          text: 'Everything looks sparkling clean in the 3-bed flat, thank you Blessing!',
          timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
          isFromCustomer: true,
        ),
        ChatMessage(
          id: 'b2',
          text: 'Thank you! The post-cleaning sanitization report has been submitted.',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          isFromCustomer: false,
          isSimulatedProvider: true,
        ),
      ],
    ),
  ];
}
