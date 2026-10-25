class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String explore = '/explore';
  static const String bookings = '/bookings';
  static const String messages = '/messages';
  static const String profile = '/profile';
  static const String categories = '/categories';
  static const String providerDetails = '/providers/:id';
  static String providerDetailsPath(String id) => '/providers/$id';
  static const String requestService = '/request-service';
  static const String negotiation = '/negotiation/:id';
  static String negotiationPath(String id) => '/negotiation/$id';
  static const String conversation = '/messages/:id';
  static String conversationPath(String id) => '/messages/$id';
  static const String notifications = '/notifications';
  static const String editProfile = '/profile/edit';
  static const String settings = '/settings';
  static const String onboarding = '/onboarding';
  static const String welcome = '/auth/welcome';
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String forgotPassword = '/auth/forgot-password';
  static const String verification = '/auth/verification';

  // Provider Mode Routes
  static const String providerOnboarding = '/provider/onboarding';
  static const String providerServices = '/provider/services';
  static const String providerRequests = '/provider/requests';
  static const String providerJobs = '/provider/jobs';
  static const String providerDashboard = '/provider/dashboard';
}
