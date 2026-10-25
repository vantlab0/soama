import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soama/app/app.dart';
import 'package:soama/core/routing/app_router.dart';
import 'package:soama/core/routing/app_routes.dart';
import 'package:soama/core/theme/soama_theme.dart';
import 'package:soama/features/bookings/presentation/bookings_screen.dart';
import 'package:soama/features/messages/presentation/conversation_screen.dart';
import 'package:soama/features/messages/presentation/messages_screen.dart';
import 'package:soama/features/notifications/presentation/notifications_screen.dart';
import 'package:soama/features/negotiation/presentation/negotiation_screen.dart';
import 'package:soama/features/auth/presentation/forgot_password_screen.dart';
import 'package:soama/features/auth/presentation/login_screen.dart';
import 'package:soama/features/auth/presentation/register_screen.dart';
import 'package:soama/features/auth/presentation/verification_screen.dart';
import 'package:soama/features/auth/presentation/welcome_screen.dart';
import 'package:soama/features/onboarding/presentation/onboarding_screen.dart';
import 'package:soama/features/profile/presentation/edit_profile_screen.dart';
import 'package:soama/features/profile/presentation/profile_screen.dart';
import 'package:soama/features/profile/presentation/settings_screen.dart';
import 'package:soama/features/providers/presentation/provider_details_screen.dart';
import 'package:soama/features/providers/presentation/request_service_screen.dart';
import 'package:soama/shared/models/chat_conversation.dart';
import 'package:soama/shared/models/customer_profile.dart';
import 'package:soama/shared/models/service_provider.dart';
import 'package:soama/shared/models/service_request.dart';
import 'package:soama/shared/models/user_account.dart';
import 'package:soama/features/provider/presentation/provider_onboarding_screen.dart';
import 'package:soama/shared/widgets/empty_state.dart';
import 'package:soama/shared/widgets/glass_search_field.dart';
import 'package:soama/shared/widgets/glass_surface.dart';
import 'package:soama/shared/widgets/loading_placeholder.dart';
import 'package:soama/shared/widgets/provider_card.dart';
import 'package:soama/shared/widgets/section_header.dart';
import 'package:soama/shared/widgets/glass_bottom_navigation.dart';
import 'package:soama/shared/widgets/service_category_item.dart';
import 'package:soama/shared/widgets/soama_buttons.dart';

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _TestHttpClient();
}

class _TestHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _TestHttpClientRequest();
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _TestHttpClientRequest();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _TestHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _TestHttpClientResponse();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestHttpClientResponse implements HttpClientResponse {
  static final List<int> _kTransparentImage = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ];

  @override
  int get statusCode => 200;
  @override
  int get contentLength => _kTransparentImage.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_kTransparentImage).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  setUp(() {
    UserAccount.reset();
    ServiceRequest.reset();
    AppRouter.router.go(AppRoutes.home);
  });
  Widget wrapWithTheme(Widget child, {bool isDark = false}) {
    return ProviderScope(
      child: MaterialApp(
        theme: isDark ? SoamaTheme.dark() : SoamaTheme.light(),
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  void setMobileViewport(WidgetTester tester, {double width = 800, double height = 1600}) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('SoamaApp customer home screen smoke test', (WidgetTester tester) async {
    setMobileViewport(tester);

    await tester.pumpWidget(
      const ProviderScope(
        child: SoamaApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(SoamaApp), findsOneWidget);
    expect(find.textContaining('Who do you need'), findsOneWidget);
    expect(find.text('YOUR LOCATION'), findsOneWidget);
    expect(find.text('What service do you need?'), findsOneWidget);
    expect(find.text('Near you'), findsOneWidget);
  });

  testWidgets('Explore and Search live filtering & sorting test', (WidgetTester tester) async {
    setMobileViewport(tester);
    await tester.pumpWidget(
      const ProviderScope(
        child: SoamaApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Navigate to Explore Tab
    await tester.tap(find.byIcon(Icons.explore_outlined));
    await tester.pumpAndSettle();

    // Verify Explore screen loaded
    expect(find.text('Explore Services'), findsOneWidget);
    expect(find.textContaining('artisans found'), findsOneWidget);

    // 1. Test live search filtering by trade name
    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);

    await tester.enterText(searchField, 'plumbing');
    await tester.pumpAndSettle();

    expect(find.text('Ochuko Efe'), findsOneWidget);
    expect(find.text('Blessing Igbinoba'), findsNothing);

    // 2. Test search by provider name
    await tester.enterText(searchField, 'Blessing');
    await tester.pumpAndSettle();

    expect(find.text('Blessing Igbinoba'), findsOneWidget);
    expect(find.text('Ochuko Efe'), findsNothing);

    // 3. Test empty results & reset button
    await tester.enterText(searchField, 'AstronautNonexistent');
    await tester.pumpAndSettle();

    expect(find.text('No matching artisans found'), findsOneWidget);
    expect(find.text('Reset All Filters'), findsOneWidget);

    await tester.tap(find.text('Reset All Filters'));
    await tester.pumpAndSettle();

    // After reset, providers return
    expect(find.text('Ochuko Efe'), findsOneWidget);
    expect(find.text('Blessing Igbinoba'), findsOneWidget);

    // 4. Test Category filter selection
    await tester.tap(find.text('Cleaning').first);
    await tester.pumpAndSettle();

    expect(find.text('Blessing Igbinoba'), findsOneWidget);
    expect(find.text('Ochuko Efe'), findsNothing);

    // Reset to All Trades
    await tester.tap(find.text('All Trades'));
    await tester.pumpAndSettle();

    expect(find.text('Ochuko Efe'), findsOneWidget);

    // 5. Test Provider preview sheet modal on Book button tap
    await tester.tap(find.text('Book').first);
    await tester.pumpAndSettle();

    expect(find.text('View Full Profile'), findsOneWidget);
    expect(find.text('Delta Flow Precision Plumbing'), findsOneWidget);

    // Dismiss sheet
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
  });

  testWidgets('ProviderDetailsScreen displays specific provider information', (WidgetTester tester) async {
    setMobileViewport(tester);
    final pro = ServiceProvider.nearbyPros.first; // Ochuko Efe

    await tester.pumpWidget(
      wrapWithTheme(
        ProviderDetailsScreen(
          providerId: pro.id,
          initialProvider: pro,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Name, Business & Profession
    expect(find.text('Ochuko Efe'), findsOneWidget);
    expect(find.text('Delta Flow Precision Plumbing'), findsOneWidget);
    expect(find.text('About the Specialist'), findsOneWidget);

    // Verify Services & Pricing
    expect(find.text('Services & Pricing'), findsOneWidget);
    expect(find.text('Borehole Submersible Pump Repair'), findsOneWidget);
    expect(find.text('₦15,000'), findsOneWidget);

    // Verify Availability & Working Hours
    expect(find.text('Available Today'), findsWidgets);
    expect(find.text('Mon – Sat: 7:30 AM – 6:30 PM'), findsOneWidget);

    // Verify Customer Reviews
    expect(find.text('Customer Reviews'), findsOneWidget);
    expect(find.text('Dr. Tariye Briggs'), findsOneWidget);

    // Verify Persistent Bottom Actions
    expect(find.text('Request Service'), findsOneWidget);
  });

  testWidgets('ProviderDetailsScreen interactive service selection updates CTA', (WidgetTester tester) async {
    setMobileViewport(tester);
    final pro = ServiceProvider.nearbyPros.first; // Ochuko Efe

    await tester.pumpWidget(
      wrapWithTheme(
        ProviderDetailsScreen(
          providerId: pro.id,
          initialProvider: pro,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Initially CTA says 'Request Service'
    expect(find.text('Request Service'), findsOneWidget);

    // Tap on the first service offering ('Borehole Submersible Pump Repair')
    await tester.tap(find.text('Borehole Submersible Pump Repair'));
    await tester.pumpAndSettle();

    // CTA now dynamically includes the selected service name and price
    expect(find.text('Request Borehole Submersible Pump Repair • ₦15,000'), findsOneWidget);
    expect(find.text('Clear selection'), findsOneWidget);

    // Clear selection
    await tester.tap(find.text('Clear selection'));
    await tester.pumpAndSettle();

    expect(find.text('Request Service'), findsOneWidget);
  });

  testWidgets('Navigation: Tapping different providers displays their own distinct data', (WidgetTester tester) async {
    setMobileViewport(tester);
    await tester.pumpWidget(
      const ProviderScope(
        child: SoamaApp(),
      ),
    );

    await tester.pumpAndSettle();

    // 1. From Home Screen, tap Ochuko Efe card
    final ochukoCard = find.widgetWithText(ProviderCard, 'Ochuko Efe');
    expect(ochukoCard, findsOneWidget);
    await tester.ensureVisible(ochukoCard);
    await tester.tap(ochukoCard);
    await tester.pumpAndSettle();

    // Details for Ochuko Efe are visible
    expect(find.text('Delta Flow Precision Plumbing'), findsOneWidget);
    expect(find.text('Borehole Submersible Pump Repair'), findsOneWidget);
    expect(find.text('Blessing Igbinoba'), findsNothing);

    // Pop back to Home
    final backButton = find.byIcon(Icons.arrow_back_ios_new_rounded);
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    // 2. From Home Screen, tap Blessing Igbinoba card
    final blessingCard = find.widgetWithText(ProviderCard, 'Blessing Igbinoba');
    expect(blessingCard, findsOneWidget);
    await tester.ensureVisible(blessingCard);
    await tester.tap(blessingCard);
    await tester.pumpAndSettle();

    // Details for Blessing Igbinoba are visible
    expect(find.text('SparkleClean Prestige Care'), findsOneWidget);
    expect(find.text('3-Bedroom Apartment Deep Sanitization'), findsOneWidget);
    expect(find.text('Delta Flow Precision Plumbing'), findsNothing);
  });

  testWidgets('Narrow screen (320px width) overflow test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: SoamaApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('YOUR LOCATION'), findsOneWidget);
    expect(find.text('What service do you need?'), findsOneWidget);
    expect(find.text('Near you'), findsOneWidget);
  });

  testWidgets('AppShell 5-destination navigation test', (WidgetTester tester) async {
    setMobileViewport(tester);
    await tester.pumpWidget(
      const ProviderScope(
        child: SoamaApp(),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Initial tab: Home
    expect(find.textContaining('Who do you need'), findsOneWidget);

    // 2. Switch to Explore tab
    await tester.tap(find.descendant(of: find.byType(GlassBottomNavigation), matching: find.byIcon(Icons.explore_outlined)));
    await tester.pumpAndSettle();
    expect(find.text('Explore Services'), findsOneWidget);

    // 3. Switch to Bookings tab
    await tester.tap(find.descendant(of: find.byType(GlassBottomNavigation), matching: find.byIcon(Icons.calendar_today_outlined)));
    await tester.pumpAndSettle();
    expect(find.text('My Bookings'), findsOneWidget);

    // 4. Switch to Messages tab
    await tester.tap(find.descendant(of: find.byType(GlassBottomNavigation), matching: find.byIcon(Icons.chat_bubble_outline_rounded)));
    await tester.pumpAndSettle();
    expect(find.text('Messages'), findsWidgets);

    // 5. Switch to Profile tab
    await tester.tap(find.descendant(of: find.byType(GlassBottomNavigation), matching: find.byIcon(Icons.person_outline_rounded)));
    await tester.pumpAndSettle();
    expect(find.text('Customer Profile'), findsOneWidget);

    // 6. Return to Home tab
    await tester.tap(find.descendant(of: find.byType(GlassBottomNavigation), matching: find.byIcon(Icons.home_outlined)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Who do you need'), findsOneWidget);
  });

  testWidgets('PrimaryButton & SecondaryButton test', (WidgetTester tester) async {
    bool primaryTapped = false;
    bool secondaryTapped = false;

    await tester.pumpWidget(
      wrapWithTheme(
        Column(
          children: [
            PrimaryButton(
              label: 'Book Now',
              onPressed: () => primaryTapped = true,
            ),
            SecondaryButton(
              label: 'Details',
              onPressed: () => secondaryTapped = true,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Book Now'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);

    await tester.tap(find.text('Book Now'));
    expect(primaryTapped, isTrue);

    await tester.tap(find.text('Details'));
    expect(secondaryTapped, isTrue);
  });

  testWidgets('EmptyState & LoadingPlaceholder test', (WidgetTester tester) async {
    bool actionTapped = false;

    await tester.pumpWidget(
      wrapWithTheme(
        Column(
          children: [
            EmptyState(
              icon: Icons.inbox_outlined,
              title: 'No Bookings',
              message: 'You have no scheduled bookings.',
              actionLabel: 'Browse Services',
              onActionPressed: () => actionTapped = true,
            ),
            const LoadingPlaceholder.card(),
          ],
        ),
      ),
    );

    expect(find.text('No Bookings'), findsOneWidget);
    expect(find.text('You have no scheduled bookings.'), findsOneWidget);
    expect(find.text('Browse Services'), findsOneWidget);

    await tester.tap(find.text('Browse Services'));
    expect(actionTapped, isTrue);
  });

  testWidgets('ServiceCategoryItem compact test', (WidgetTester tester) async {
    bool categoryTapped = false;

    await tester.pumpWidget(
      wrapWithTheme(
        ServiceCategoryItem.compact(
          label: 'Cleaning',
          icon: Icons.cleaning_services_outlined,
          isSelected: true,
          onTap: () => categoryTapped = true,
        ),
      ),
    );

    expect(find.text('Cleaning'), findsOneWidget);
    await tester.tap(find.text('Cleaning'));
    expect(categoryTapped, isTrue);
  });

  testWidgets('ProviderCard test', (WidgetTester tester) async {
    bool cardTapped = false;
    bool bookTapped = false;

    final testProvider = ServiceProvider.nearbyPros.first;

    await tester.pumpWidget(
      wrapWithTheme(
        ProviderCard(
          provider: testProvider,
          onTap: () => cardTapped = true,
          onBookTap: () => bookTapped = true,
        ),
      ),
    );

    expect(find.text(testProvider.name), findsOneWidget);
    expect(find.text(testProvider.startingPrice), findsOneWidget);

    await tester.tap(find.text(testProvider.name));
    expect(cardTapped, isTrue);

    await tester.tap(find.text('Book'));
    expect(bookTapped, isTrue);
  });

  testWidgets('SectionHeader test', (WidgetTester tester) async {
    bool seeAllTapped = false;

    await tester.pumpWidget(
      wrapWithTheme(
        SectionHeader(
          title: 'Popular Services',
          actionText: 'See all',
          onActionTap: () => seeAllTapped = true,
        ),
      ),
    );

    expect(find.text('Popular Services'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);

    await tester.tap(find.text('See all'));
    expect(seeAllTapped, isTrue);
  });

  testWidgets('RequestServiceScreen validation and submission test', (WidgetTester tester) async {
    setMobileViewport(tester);
    final pro = ServiceProvider.nearbyPros.first; // Ochuko Efe
    final service = pro.services.first;

    await tester.pumpWidget(
      wrapWithTheme(
        RequestServiceScreen(
          provider: pro,
          selectedService: service,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Provider and Service headers
    expect(find.text('Ochuko Efe'), findsOneWidget);
    expect(find.text('Select Service'), findsOneWidget);
    expect(find.text('Service Delivery Mode'), findsOneWidget);
    expect(find.text('Describe the Problem'), findsOneWidget);
    expect(find.text('Send Service Request'), findsOneWidget);

    // 1. Attempt to submit with empty description -> shows error
    await tester.ensureVisible(find.text('Send Service Request'));
    await tester.tap(find.text('Send Service Request'));
    await tester.pumpAndSettle();

    expect(find.text('Please describe the problem or work needed.'), findsOneWidget);

    // 2. Enter description
    final descField = find.byType(TextField).first;
    await tester.enterText(descField, 'Main PVC inlet pipe is cracked and spraying water across pump room.');
    await tester.pumpAndSettle();

    // Error message clears
    expect(find.text('Please describe the problem or work needed.'), findsNothing);

    // 3. Test photo attachment sheet
    await tester.tap(find.text('Add Photo'));
    await tester.pumpAndSettle();

    expect(find.text('Attach Issue Photo'), findsOneWidget);
    expect(find.text('Pipe Joint Fracture'), findsOneWidget);

    // Select sample photo
    await tester.tap(find.text('Pipe Joint Fracture'));
    await tester.pumpAndSettle();

    // Photo is now attached (counter says 1/4)
    expect(find.text('1/4'), findsOneWidget);

    // 4. Submit valid request
    await tester.ensureVisible(find.text('Send Service Request'));
    await tester.tap(find.text('Send Service Request'));
    await tester.pump(); // Start submission
    await tester.pump(const Duration(milliseconds: 800)); // Complete async delay
    await tester.pumpAndSettle();

    // Verify Success Screen
    expect(find.text('Request Submitted!'), findsOneWidget);
    expect(find.text('View in My Bookings'), findsOneWidget);
    expect(find.text('Return to Home'), findsOneWidget);
  });

  testWidgets('GlassSurface & GlassSearchField test in Dark Mode', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        const Column(
          children: [
            GlassSurface(child: Text('Surface Content')),
            GlassSearchField(hintText: 'Search pros...'),
          ],
        ),
        isDark: true,
      ),
    );

    expect(find.text('Surface Content'), findsOneWidget);
    expect(find.text('Search pros...'), findsOneWidget);
  });

  testWidgets('NegotiationScreen initial state, offer accept and state transitions', (WidgetTester tester) async {
    setMobileViewport(tester);
    final testRequest = ServiceRequest(
      id: 'SOA-NEGOTIATE-TEST',
      providerId: 'pro-warri-3',
      providerName: 'Tunde Adeleke',
      providerProfession: 'Industrial & Domestic Generator Technician',
      providerAvatarUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=400&q=80',
      serviceId: 'srv-gen-1',
      serviceTitle: 'Routine Servicing (Oil & Filters)',
      servicePrice: '₦18,000',
      servicePriceAmount: 18000,
      description: 'Mikano 20kVA Maintenance',
      address: 'Plot 4, Effurun Roundabout, Warri',
      preferredDate: DateTime.now().add(const Duration(days: 2)),
      preferredTimeSlot: '10:00 AM – 12:00 PM',
      deliveryMode: ServiceDeliveryMode.onSiteVisit,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      status: 'Pending Provider Confirmation',
      negotiationStatus: NegotiationStatus.counterofferReceived,
      negotiationMessages: [
        NegotiationMessage(
          id: 'msg-offer-1',
          sender: OfferSender.provider,
          senderName: 'Tunde Adeleke',
          text: 'I can do this for ₦16,500.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
          proposedPrice: 16500,
          offerStatus: OfferStatus.pending,
        ),
      ],
    );

    await tester.pumpWidget(
      wrapWithTheme(
        NegotiationScreen(
          requestId: testRequest.id,
          initialRequest: testRequest,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Header and Status
    expect(find.text('Price Negotiation'), findsOneWidget);
    expect(find.textContaining('SOA-NEGOTIATE-TEST'), findsWidgets);
    expect(find.text('Counteroffer Received'), findsOneWidget);

    // 2. Verify Service Summary & Base Price
    expect(find.text('Routine Servicing (Oil & Filters)'), findsOneWidget);
    expect(find.text('Base: ₦18,000'), findsOneWidget);

    // 3. Verify Messages & Offers
    expect(find.text('₦16,500'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);

    // 4. Test Accepting the Counteroffer
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    // Status transitions to Price Agreed
    expect(find.text('Price Agreed'), findsOneWidget);
    expect(find.textContaining('Agreed Price: ₦16,500'), findsOneWidget);
    expect(find.textContaining('Continue to Booking'), findsOneWidget);

    // Verify Offer card shows Accepted badge and Accept/Decline buttons are gone
    expect(find.text('Offer Accepted'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
  });

  testWidgets('NegotiationScreen price proposal validation test', (WidgetTester tester) async {
    setMobileViewport(tester);
    final testRequest = ServiceRequest(
      id: 'SOA-VAL-1',
      providerId: 'pro-warri-1',
      providerName: 'Ochuko Efe',
      providerProfession: 'Plumber',
      providerAvatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
      serviceId: 'srv-p1',
      serviceTitle: 'Pipe Repair',
      servicePrice: '₦8,500',
      servicePriceAmount: 8500,
      description: 'Kitchen pipe leak',
      address: 'Warri',
      preferredDate: DateTime.now(),
      preferredTimeSlot: 'Morning',
      deliveryMode: ServiceDeliveryMode.onSiteVisit,
      createdAt: DateTime.now(),
      negotiationStatus: NegotiationStatus.awaitingResponse,
      negotiationMessages: [],
    );

    await tester.pumpWidget(
      wrapWithTheme(
        NegotiationScreen(
          requestId: testRequest.id,
          initialRequest: testRequest,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap 'Propose Price' filter chip
    await tester.tap(find.text('Propose Price'));
    await tester.pumpAndSettle();

    expect(find.text('Proposing Price'), findsOneWidget);

    // Attempt to submit invalid/low price (< ₦1,000)
    final priceInput = find.byType(TextField).first;
    await tester.enterText(priceInput, '500');
    await tester.pumpAndSettle();

    // Tap send icon button
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Minimum negotiable rate is ₦1,000.'), findsOneWidget);

    // Enter valid price
    await tester.enterText(priceInput, '7500');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    // Customer offer appears in conversation
    expect(find.text('₦7,500'), findsWidgets);
    expect(find.text('Pending Decision'), findsWidgets);
  });

  testWidgets('BookingsScreen 4 segmented tabs, filtering and contextual actions test', (WidgetTester tester) async {
    ServiceRequest.reset();
    setMobileViewport(tester);
    await tester.pumpWidget(
      wrapWithTheme(
        const BookingsScreen(),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Page Heading
    expect(find.text('My Bookings'), findsOneWidget);

    // 2. Verify 4 Segmented Tabs are visible
    expect(find.textContaining('All ('), findsOneWidget);
    expect(find.textContaining('Pending ('), findsOneWidget);
    expect(find.textContaining('Ongoing ('), findsOneWidget);
    expect(find.textContaining('Completed ('), findsOneWidget);

    // 3. Test Switching to Ongoing Tab
    await tester.tap(find.textContaining('Ongoing ('));
    await tester.pumpAndSettle();

    expect(find.text('Tunde Adeleke • Industrial & Domestic Generator Technician'), findsOneWidget);
    expect(find.text('View Passcode'), findsWidgets);
    expect(find.text('Mark Completed'), findsWidgets);

    // 4. Test View Passcode Modal
    await tester.tap(find.text('View Passcode').first);
    await tester.pumpAndSettle();

    expect(find.text('Job Start & Release Passcode'), findsOneWidget);
    expect(find.textContaining('SEC-3091'), findsOneWidget);

    // Close Passcode sheet
    await tester.tap(find.text('Close Passcode'));
    await tester.pumpAndSettle();

    // 5. Test Switching to Completed Tab
    await tester.tap(find.textContaining('Completed ('));
    await tester.pumpAndSettle();

    expect(find.text('Blessing Igbinoba • Deep Cleaning & Post-Construction Specialist'), findsOneWidget);
    expect(find.text('Leave Review'), findsOneWidget);
    expect(find.text('View Receipt'), findsOneWidget);

    // 6. Test Review Dialog
    await tester.tap(find.text('Leave Review'));
    await tester.pumpAndSettle();

    expect(find.text('Rate Blessing Igbinoba'), findsOneWidget);
    expect(find.text('Submit Review'), findsOneWidget);

    // Dismiss dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // 7. Test Switching to Pending Tab
    await tester.tap(find.textContaining('Pending ('));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ochuko Efe'), findsWidgets);
    expect(find.text('Review Offer'), findsWidgets);
    expect(find.text('Cancel'), findsWidgets);
  });

  testWidgets('MessagesScreen conversation list and search test', (WidgetTester tester) async {
    setMobileViewport(tester);
    await tester.pumpWidget(
      wrapWithTheme(
        const MessagesScreen(),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Header and Search Field
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Search chats or specialists...'), findsOneWidget);

    // 2. Verify Conversation items
    expect(find.text('Ochuko Efe'), findsOneWidget);
    expect(find.text('Tunde Adeleke'), findsOneWidget);
    expect(find.text('Blessing Igbinoba'), findsOneWidget);

    // 3. Test Search filtering
    final searchInput = find.byType(TextField);
    await tester.enterText(searchInput, 'piping');
    await tester.pumpAndSettle();

    expect(find.text('Ochuko Efe'), findsOneWidget);
    expect(find.text('Blessing Igbinoba'), findsNothing);

    // Clear search
    await tester.enterText(searchInput, '');
    await tester.pumpAndSettle();

    expect(find.text('Blessing Igbinoba'), findsOneWidget);
  });

  testWidgets('ConversationScreen rendering and message sending test', (WidgetTester tester) async {
    setMobileViewport(tester);
    final testConv = ChatConversation.activeConversations.first; // Ochuko Efe

    await tester.pumpWidget(
      wrapWithTheme(
        ConversationScreen(
          conversationId: testConv.id,
          initialConversation: testConv,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Header and Booking context banner
    expect(find.text('Ochuko Efe'), findsOneWidget);
    expect(find.text('Emergency Pipe Leak Repair'), findsOneWidget);
    expect(find.text('Rate: ₦8,000 in Escrow'), findsOneWidget);

    // 2. Verify message history
    expect(find.textContaining('packed the 3/4-inch PVC couplings'), findsOneWidget);

    // 3. Send a message
    final msgInput = find.byType(TextField);
    await tester.enterText(msgInput, 'Please bring the high pressure glue as well.');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    // Verify customer message appears immediately
    expect(find.text('Please bring the high pressure glue as well.'), findsOneWidget);
  });

  testWidgets('NotificationsScreen category tabs and mark all read test', (WidgetTester tester) async {
    setMobileViewport(tester);
    await tester.pumpWidget(
      wrapWithTheme(
        const NotificationsScreen(),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Header and Tabs
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.textContaining('All ('), findsOneWidget);
    expect(find.textContaining('Bookings ('), findsOneWidget);
    expect(find.textContaining('Messages ('), findsOneWidget);
    expect(find.textContaining('Payments ('), findsOneWidget);

    // 2. Verify notification item present
    expect(find.text('Counteroffer Received from Ochuko Efe'), findsOneWidget);

    // 3. Test Mark all as read action
    await tester.tap(find.byIcon(Icons.done_all_rounded));
    await tester.pumpAndSettle();

    expect(find.text('All notifications marked as read.'), findsOneWidget);
  });

  testWidgets('ProfileScreen customer details, summary activity, and quick navigation test', (WidgetTester tester) async {
    setMobileViewport(tester);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ProfileScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Header and Customer Profile Info
    expect(find.text('Customer Profile'), findsOneWidget);
    expect(find.text('Kolawole Adams'), findsOneWidget);
    expect(find.text('kolawole.adams@soama.ng'), findsOneWidget);
    expect(find.textContaining('+234 803 123 4567'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Edit Profile'), findsOneWidget);

    // 2. Verify Account Activity Metrics
    expect(find.text('Account Activity'), findsOneWidget);
    expect(find.text('My Bookings'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Escrow Protection'), findsOneWidget);
    expect(find.text('Saved Locations'), findsOneWidget);

    // 3. Verify Quick Navigation items
    expect(find.text('Quick Navigation'), findsOneWidget);
    expect(find.text('My Bookings & Orders'), findsOneWidget);
    expect(find.text('Messages & Chats'), findsOneWidget);
    expect(find.text('Notifications & Alerts'), findsOneWidget);
    expect(find.text('Settings & Preferences'), findsOneWidget);

    // 4. Verify Theme selector
    expect(find.text('Appearance & Theme'), findsOneWidget);
    expect(find.text('Warm Ivory'), findsOneWidget);
    expect(find.text('Deep Charcoal'), findsOneWidget);
  });

  testWidgets('EditProfileScreen inline validation, avatar selection, and save profile changes test', (WidgetTester tester) async {
    setMobileViewport(tester);
    await tester.pumpWidget(
      wrapWithTheme(
        const EditProfileScreen(),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify screen title and initial values
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Save Profile Changes'), findsOneWidget);
    expect(find.text('Select Profile Photo'), findsOneWidget);

    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(4)); // Name, Email, Phone, Location

    // 2. Validation: Empty Name
    await tester.enterText(textFields.at(0), '');
    await tester.tap(find.text('Save Profile Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Full name is required.'), findsOneWidget);

    // Validation: Short Name (< 3 chars)
    await tester.enterText(textFields.at(0), 'Al');
    await tester.tap(find.text('Save Profile Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Full name must be at least 3 characters.'), findsOneWidget);

    // Fix Name
    await tester.enterText(textFields.at(0), 'Kolawole A. Adams');
    await tester.pumpAndSettle();

    // Validation: Invalid Email
    await tester.enterText(textFields.at(1), 'invalid-email');
    await tester.tap(find.text('Save Profile Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email address.'), findsOneWidget);

    // Fix Email
    await tester.enterText(textFields.at(1), 'kola.adams@soama.ng');
    await tester.pumpAndSettle();

    // Validation: Short Phone (< 8 chars)
    await tester.enterText(textFields.at(2), '1234');
    await tester.tap(find.text('Save Profile Changes'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid phone number.'), findsOneWidget);

    // Fix Phone
    await tester.enterText(textFields.at(2), '+234 809 999 8888');
    await tester.pumpAndSettle();

    // 3. Save valid profile
    await tester.tap(find.text('Save Profile Changes'));
    await tester.pumpAndSettle();

    // 4. Verify shared local CustomerProfile.current updated
    expect(CustomerProfile.current.fullName, equals('Kolawole A. Adams'));
    expect(CustomerProfile.current.email, equals('kola.adams@soama.ng'));
    expect(CustomerProfile.current.phoneNumber, equals('+234 809 999 8888'));
  });

  testWidgets('SettingsScreen saved addresses, notification preferences, and support FAQ test', (WidgetTester tester) async {
    setMobileViewport(tester);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Sections
    expect(find.text('Settings & Preferences'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Appearance & Preferences'), findsOneWidget);
    expect(find.text('Support & Policies'), findsOneWidget);
    expect(find.text('About Soama'), findsOneWidget);

    // 2. Test Notification Preferences Switch Toggle
    expect(find.text('Booking Status Updates'), findsOneWidget);
    final switchFinder = find.byType(Switch).first;
    expect(switchFinder, findsOneWidget);

    final initialSwitchVal = CustomerProfile.current.notificationPreferences.bookingAlerts;
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    // Switch state changed
    expect(CustomerProfile.current.notificationPreferences.bookingAlerts, equals(!initialSwitchVal));

    // 3. Test Saved Delivery Addresses Modal Sheet
    await tester.tap(find.text('Saved Delivery Addresses'));
    await tester.pumpAndSettle();

    expect(find.text('Saved Addresses'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Office'), findsOneWidget);

    // Test Delete Address Confirmation Dialog
    final initialCount = CustomerProfile.current.savedAddresses.length;
    final deleteButtons = find.byIcon(Icons.delete_outline_rounded);
    expect(deleteButtons, findsWidgets);

    await tester.tap(deleteButtons.first);
    await tester.pumpAndSettle();

    expect(find.text('Delete Address?'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    // Confirm deletion
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(CustomerProfile.current.savedAddresses.length, equals(initialCount - 1));

    // Close bottom sheet
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    // 4. Test Help & FAQ Sheet
    await tester.tap(find.text('Help & FAQ'));
    await tester.pumpAndSettle();

    expect(find.text('Frequently Asked Questions'), findsOneWidget);
    expect(find.text('How does Soama Escrow protect my money?'), findsOneWidget);
  });

  testWidgets('OnboardingScreen 3-page navigation, page indicator, skip, and get started flow', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: OnboardingScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Page 1 (Find Trusted Professionals)
    expect(find.textContaining('Find Trusted Professionals'), findsOneWidget);
    expect(find.text('Ochuko Efe'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    // 2. Advance to Page 2 (Agree on the Price)
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Agree on the Price'), findsOneWidget);
    expect(find.text('Price Negotiation Flow'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    // 3. Advance to Page 3 (Get the Job Done)
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Get the Job Done'), findsOneWidget);
    expect(find.text('Soama Escrow Protection'), findsOneWidget);
    expect(find.text('SEC-3091'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('WelcomeScreen logo, actions, Google placeholder dialog, and terms sheet', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      wrapWithTheme(
        const WelcomeScreen(),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Branding & Copy
    expect(find.text('SOAMA'), findsOneWidget);
    expect(find.textContaining('Hire Trusted Artisans'), findsOneWidget);
    expect(find.text('Continue with Email'), findsOneWidget);
    expect(find.textContaining('Continue with Google'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Explore Marketplace as Guest'), findsOneWidget);

    // 2. Tap Google Placeholder action -> shows explanation snackbar
    await tester.tap(find.textContaining('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Google Sign-In is a UI preview'), findsOneWidget);

    // 3. Tap Terms & Privacy Policy link
    await tester.tap(find.textContaining('Terms of Service'));
    await tester.pumpAndSettle();

    expect(find.text('Terms of Service & Privacy Policy'), findsOneWidget);
    expect(find.textContaining('Soama is a verified peer-to-specialist services marketplace'), findsOneWidget);

    // Close policy sheet
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('RegisterScreen form validation (name, email, phone, password matching)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RegisterScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Create Account'), findsWidgets);
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(5)); // Name, Email, Phone, Password, ConfirmPassword

    // 1. Blank submission validation
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(find.text('Full name is required.'), findsOneWidget);

    // 2. Short name validation
    await tester.enterText(textFields.at(0), 'Ka');
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(find.text('Full name must be at least 3 characters.'), findsOneWidget);

    await tester.enterText(textFields.at(0), 'Kolawole Adams');
    await tester.pumpAndSettle();

    // 3. Invalid email validation
    await tester.enterText(textFields.at(1), 'notanemail');
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email address.'), findsOneWidget);

    await tester.enterText(textFields.at(1), 'kola@soama.ng');
    await tester.pumpAndSettle();

    // 4. Short phone validation
    await tester.enterText(textFields.at(2), '0803');
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('valid phone number'), findsOneWidget);

    await tester.enterText(textFields.at(2), '+234 803 123 4567');
    await tester.pumpAndSettle();

    // 5. Short password validation
    await tester.enterText(textFields.at(3), '123');
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(find.text('Password must be at least 6 characters.'), findsOneWidget);

    await tester.enterText(textFields.at(3), 'Secret123');
    await tester.pumpAndSettle();

    // 6. Password mismatch validation
    await tester.enterText(textFields.at(4), 'DifferentPass');
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  testWidgets('LoginScreen form validation and remember me toggle', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Remember Me'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);

    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2)); // Email, Password

    // Clear email and test validation
    await tester.enterText(textFields.at(0), '');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Email address is required.'), findsOneWidget);

    // Invalid email validation
    await tester.enterText(textFields.at(0), 'bademail');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email address.'), findsOneWidget);

    // Toggle Remember Me Checkbox
    final checkbox = find.byType(Checkbox);
    expect(checkbox, findsOneWidget);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
  });

  testWidgets('ForgotPasswordScreen email validation and mock disclaimer state', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithTheme(
        const ForgotPasswordScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Reset Password'), findsOneWidget);
    expect(find.text('Send Recovery Instructions'), findsOneWidget);

    final emailField = find.byType(TextField);

    // 1. Clear field & test required validation
    await tester.enterText(emailField, '');
    await tester.tap(find.text('Send Recovery Instructions'));
    await tester.pumpAndSettle();

    expect(find.text('Email address is required.'), findsOneWidget);

    // 2. Submit valid email -> shows success disclaimer
    await tester.enterText(emailField, 'recovery@soama.ng');
    await tester.tap(find.text('Send Recovery Instructions'));
    await tester.pumpAndSettle();

    expect(find.text('Recovery Link Sent!'), findsOneWidget);
    expect(find.text('recovery@soama.ng'), findsOneWidget);
    expect(find.textContaining('No actual email was dispatched'), findsOneWidget);
    expect(find.text('Return to Login'), findsOneWidget);
  });

  testWidgets('VerificationScreen 6-digit code validation, cooldown timer, and mock completion', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: VerificationScreen(email: 'test@soama.ng'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Verify Your Email'), findsOneWidget);
    expect(find.textContaining('test@soama.ng'), findsOneWidget);
    expect(find.textContaining('Mock Mode'), findsOneWidget);
    expect(find.text('Verify & Enter Marketplace'), findsOneWidget);

    final codeField = find.byType(TextField);

    // 1. Clear field and test validation
    await tester.enterText(codeField, '');
    await tester.tap(find.text('Verify & Enter Marketplace'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter the 6-digit code.'), findsOneWidget);

    // 2. Short code validation
    await tester.enterText(codeField, '12');
    await tester.tap(find.text('Verify & Enter Marketplace'));
    await tester.pumpAndSettle();

    expect(find.text('Code must be 6 digits.'), findsOneWidget);
  });

  testWidgets('Dual-Role: UserAccount model mode switching and role capabilities', (tester) async {
    // 1. Initial State: Customer Mode, hasCustomerCapability = true, hasProviderCapability = false
    expect(UserAccount.current.currentMode, AppMode.customer);
    expect(UserAccount.current.hasCustomerCapability, isTrue);
    expect(UserAccount.current.hasProviderCapability, isFalse);

    // 2. Attempting to switch to Provider Mode without capability should be prevented
    UserAccount.switchMode(AppMode.provider);
    expect(UserAccount.current.currentMode, AppMode.customer);

    // 3. Enable Provider Capability
    const providerProfile = ProviderProfileData(
      providerId: 'pro-test-01',
      businessName: 'Adams Test Works',
      profession: 'Electrical Specialist',
      categoryId: 'electrical',
      categoryTitle: 'Electrical',
      bio: 'Test bio description',
      serviceArea: 'Warri Central',
      verificationStatus: ProviderVerificationStatus.pending,
    );
    UserAccount.enableProviderCapability(providerProfile);

    // Verify capability enabled and auto-switched to provider mode
    expect(UserAccount.current.hasProviderCapability, isTrue);
    expect(UserAccount.current.currentMode, AppMode.provider);
    expect(UserAccount.current.providerProfile?.businessName, 'Adams Test Works');
    expect(UserAccount.current.providerProfile?.verificationStatus, ProviderVerificationStatus.pending);

    // 4. Switch back to Customer mode
    UserAccount.switchMode(AppMode.customer);
    expect(UserAccount.current.currentMode, AppMode.customer);
    // User preserves personal profile & provider profile
    expect(UserAccount.current.fullName, contains('Adams'));
    expect(UserAccount.current.providerProfile?.providerId, 'pro-test-01');
  });

  testWidgets('Provider Onboarding: Become a Service Provider flow and mock verification state', (tester) async {
    setMobileViewport(tester);
    await tester.pumpWidget(wrapWithTheme(const ProviderOnboardingScreen()));
    await tester.pumpAndSettle();

    // Step 1: Professional Profile
    expect(find.text('Step 1: Professional Profile'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    // Tap Continue to Step 2
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 2: Service & Pricing
    expect(find.text('Step 2: Service & Pricing'), findsOneWidget);
    expect(find.text('Electrical'), findsOneWidget);

    // Tap Continue to Step 3
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 3: Location & Availability
    expect(find.text('Step 3: Location & Availability'), findsOneWidget);
    expect(find.text('I visit customer on-site'), findsOneWidget);

    // Tap Continue to Step 4
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 4: Review & Launch
    expect(find.text('Step 4: Review & Launch'), findsOneWidget);
    expect(find.text('Mock Verification Status: Pending Review'), findsOneWidget);
    expect(find.text('Launch Provider Mode'), findsOneWidget);
  });

  testWidgets('Shared Marketplace State: Customer Request -> Provider Counteroffer -> Negotiation Sync', (tester) async {
    // 1. Customer submits a request
    final testReq = ServiceRequest(
      id: 'SOA-DUAL-TEST-01',
      providerId: 'pro-current-user',
      providerName: 'Adams Precision Electro-Works',
      providerProfession: 'Certified Electrician',
      providerAvatarUrl: '',
      serviceId: 'pro-srv-1',
      serviceTitle: 'Emergency AC Line Rewiring',
      servicePrice: '₦10,000',
      servicePriceAmount: 10000,
      description: 'Burned wiring needing urgent overhaul',
      address: 'NPA Expressway, Warri',
      preferredDate: DateTime.now().add(const Duration(days: 1)),
      preferredTimeSlot: 'Morning',
      deliveryMode: ServiceDeliveryMode.onSiteVisit,
      createdAt: DateTime.now(),
      status: 'Pending Provider Confirmation',
      negotiationStatus: NegotiationStatus.awaitingResponse,
      negotiationMessages: [
        NegotiationMessage(
          id: 'msg-cust-01',
          sender: OfferSender.customer,
          senderName: 'Customer',
          text: 'Can we do ₦10,000?',
          timestamp: DateTime.now(),
          proposedPrice: 10000,
          offerStatus: OfferStatus.pending,
        ),
      ],
    );
    ServiceRequest.submittedRequests.add(testReq);

    // 2. In Provider Mode, provider sees the request and sends counteroffer
    ServiceRequest.sendProviderCounteroffer(
      requestId: 'SOA-DUAL-TEST-01',
      counterPrice: 12000,
      messageText: 'I can do ₦12,000 including 4mm cables.',
      providerName: 'Adams Electro-Works (You)',
    );

    final updatedAfterCounter = ServiceRequest.submittedRequests.firstWhere((r) => r.id == 'SOA-DUAL-TEST-01');
    expect(updatedAfterCounter.negotiationStatus, NegotiationStatus.counterofferReceived);
    expect(updatedAfterCounter.negotiationMessages.length, 2);
    expect(updatedAfterCounter.negotiationMessages.last.proposedPrice, 12000);
    expect(updatedAfterCounter.negotiationMessages.last.sender, OfferSender.provider);

    // 3. Customer accepts the provider offer
    ServiceRequest.acceptCustomerOffer('SOA-DUAL-TEST-01');

    final updatedAfterAccept = ServiceRequest.submittedRequests.firstWhere((r) => r.id == 'SOA-DUAL-TEST-01');
    expect(updatedAfterAccept.agreedPrice, 12000);
    expect(updatedAfterAccept.status, 'Confirmed Appointment');
    expect(updatedAfterAccept.negotiationStatus, NegotiationStatus.priceAgreed);

    // Clean up
    ServiceRequest.submittedRequests.removeWhere((r) => r.id == 'SOA-DUAL-TEST-01');
  });

  testWidgets('Provider Jobs Status Progression: Arrival -> Start Work -> Completed Escrow Release Sync', (tester) async {
    final jobReq = ServiceRequest(
      id: 'SOA-JOB-FLOW-01',
      providerId: 'pro-current-user',
      providerName: 'Adams Precision Electro-Works',
      providerProfession: 'Certified Electrician',
      providerAvatarUrl: '',
      serviceId: 'pro-srv-1',
      serviceTitle: 'Main Breaker Servicing',
      servicePrice: '₦15,000',
      servicePriceAmount: 15000,
      agreedPrice: 15000,
      description: 'Breaker diagnostic',
      address: 'Airport Road, Warri',
      preferredDate: DateTime.now(),
      preferredTimeSlot: 'Morning',
      deliveryMode: ServiceDeliveryMode.onSiteVisit,
      createdAt: DateTime.now(),
      status: 'Confirmed Appointment',
      negotiationStatus: NegotiationStatus.priceAgreed,
    );
    ServiceRequest.submittedRequests.add(jobReq);

    // Status transition 1: Provider marks arrival
    ServiceRequest.updateJobStatus('SOA-JOB-FLOW-01', 'Specialist Arrived');
    expect(ServiceRequest.submittedRequests.firstWhere((r) => r.id == 'SOA-JOB-FLOW-01').status, 'Specialist Arrived');

    // Status transition 2: Provider starts work
    ServiceRequest.updateJobStatus('SOA-JOB-FLOW-01', 'Job In Progress');
    expect(ServiceRequest.submittedRequests.firstWhere((r) => r.id == 'SOA-JOB-FLOW-01').status, 'Job In Progress');

    // Status transition 3: Provider completes job -> releases escrow
    ServiceRequest.updateJobStatus('SOA-JOB-FLOW-01', 'Completed');
    expect(ServiceRequest.submittedRequests.firstWhere((r) => r.id == 'SOA-JOB-FLOW-01').status, 'Completed');

    // Clean up
    ServiceRequest.submittedRequests.removeWhere((r) => r.id == 'SOA-JOB-FLOW-01');
  });

  testWidgets('Dual-Role AppShell Navigation: Bottom nav changes dynamically with AppMode', (tester) async {
    setMobileViewport(tester);
    await tester.pumpWidget(const ProviderScope(child: SoamaApp()));
    await tester.pumpAndSettle();

    // In Customer Mode: Bottom bar has Home active tab
    expect(find.descendant(of: find.byType(GlassBottomNavigation), matching: find.text('Home')), findsOneWidget);
    expect(find.descendant(of: find.byType(GlassBottomNavigation), matching: find.byIcon(Icons.explore_outlined)), findsOneWidget);
    expect(find.descendant(of: find.byType(GlassBottomNavigation), matching: find.byIcon(Icons.calendar_today_outlined)), findsOneWidget);

    // Switch to Provider Mode
    UserAccount.enableProviderCapability(
      const ProviderProfileData(
        providerId: 'pro-nav-test',
        businessName: 'Nav Test Services',
        profession: 'Electrician',
        categoryId: 'electrical',
        categoryTitle: 'Electrical',
        bio: 'Bio',
        serviceArea: 'Warri',
      ),
    );
    await tester.pumpAndSettle();

    // In Provider Mode: Bottom bar dynamically updates to Dashboard active tab and Provider icons
    expect(find.descendant(of: find.byType(GlassBottomNavigation), matching: find.text('Dashboard')), findsOneWidget);
    expect(find.descendant(of: find.byType(GlassBottomNavigation), matching: find.byIcon(Icons.inbox_outlined)), findsOneWidget);
    expect(find.descendant(of: find.byType(GlassBottomNavigation), matching: find.byIcon(Icons.work_outline_rounded)), findsOneWidget);

    // Switch back to Customer Mode
    UserAccount.switchMode(AppMode.customer);
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byType(GlassBottomNavigation), matching: find.text('Home')), findsOneWidget);
    expect(find.descendant(of: find.byType(GlassBottomNavigation), matching: find.byIcon(Icons.explore_outlined)), findsOneWidget);
  });
}

