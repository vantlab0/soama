/// Supabase configuration for the Soama services marketplace.
/// Reads credentials securely from environment variables (--dart-define)
/// without exposing private or service-role keys to the client bundle.
class SupabaseConfig {
  SupabaseConfig._();

  // Environment variable keys
  static const String supabaseUrlKey = 'SUPABASE_URL';
  static const String supabaseAnonKey = 'SUPABASE_ANON_KEY';

  /// Read Supabase project URL from environment, defaulting to project itsxgmkhdvivyhmbyblo.
  static String get url => const String.fromEnvironment(
        supabaseUrlKey,
        defaultValue: 'https://itsxgmkhdvivyhmbyblo.supabase.co',
      );

  /// Read Supabase public anonymous key from environment.
  static String get anonKey => const String.fromEnvironment(
        supabaseAnonKey,
        defaultValue:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml0c3hnbWtoZHZpdnlobWJ5YmxvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTExMDgwMzMsImV4cCI6MjEwNjY4NDAzM30.9ggfXLNC7aBLXAIDs7Z6WS7EYUcuzQ8NJxgrP23gWQw',
      );

  /// Whether valid Supabase credentials have been supplied at build/run time.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  // Database table names matching PostgreSQL migrations
  static const String tableProfiles = 'profiles';
  static const String tableSavedAddresses = 'saved_addresses';
  static const String tableServiceCategories = 'service_categories';
  static const String tableProviderProfiles = 'provider_profiles';
  static const String tableProviderServiceAreas = 'provider_service_areas';
  static const String tableProviderServices = 'provider_services';
  static const String tableServiceRequests = 'service_requests';
  static const String tableRequestRecipients = 'request_recipients';
  static const String tablePriceOffers = 'price_offers';
  static const String tableBookings = 'bookings';
  static const String tableConversations = 'conversations';
  static const String tableMessages = 'messages';
  static const String tableReviews = 'reviews';
  static const String tableNotifications = 'notifications';
  static const String tableUserDeviceTokens = 'user_device_tokens';
  static const String tablePushNotificationQueue = 'push_notification_queue';
  static const String tablePayments = 'payments';
  static const String tablePayouts = 'payouts';
  static const String tableDisputes = 'disputes';

  // Storage buckets
  static const String bucketAvatars = 'avatars';
  static const String bucketServicePortfolio = 'service-portfolio';
  static const String bucketVerificationDocs = 'verification-documents';
  static const String bucketChatAttachments = 'chat-attachments';

  // Stored Database Procedures (RPCs)
  static const String rpcCreateServiceRequest = 'create_service_request_with_recipient';
  static const String rpcSubmitPriceOffer = 'submit_price_offer';
  static const String rpcRejectPriceOffer = 'reject_price_offer';
  static const String rpcAcceptPriceOffer = 'accept_price_offer_and_create_booking';
  static const String rpcCancelServiceRequest = 'cancel_service_request';
  static const String rpcUpdateBookingJobStatus = 'update_booking_job_status';
  static const String rpcRegisterDeviceToken = 'register_device_token';
  static const String rpcUnregisterDeviceToken = 'unregister_device_token';
  static const String rpcMarkNotificationRead = 'mark_notification_read';
  static const String rpcMarkAllNotificationsRead = 'mark_all_notifications_read';
  static const String rpcSubmitBookingReview = 'submit_booking_review';
  static const String rpcReplyToBookingReview = 'reply_to_booking_review';
  static const String rpcGetProviderReviews = 'get_provider_reviews';
  static const String rpcGetBookingReview = 'get_booking_review';
}
