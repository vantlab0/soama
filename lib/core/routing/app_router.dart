import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/bookings/presentation/bookings_screen.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/messages/presentation/conversation_screen.dart';
import '../../features/messages/presentation/messages_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/verification_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/negotiation/presentation/negotiation_screen.dart';
import '../../features/providers/presentation/provider_details_screen.dart';
import '../../features/providers/presentation/request_service_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/provider/presentation/my_services_screen.dart';
import '../../features/provider/presentation/provider_dashboard_screen.dart';
import '../../features/provider/presentation/provider_jobs_screen.dart';
import '../../features/provider/presentation/provider_onboarding_screen.dart';
import '../../features/provider/presentation/provider_profile_screen.dart';
import '../../features/provider/presentation/provider_requests_screen.dart';
import '../../shared/models/chat_conversation.dart';
import '../../shared/models/service_provider.dart';
import '../../shared/models/service_request.dart';
import '../../shared/models/user_account.dart';
import 'app_routes.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

class AppRouter {
  AppRouter._();

  static Page<dynamic> _buildFadeTransitionPage({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: child,
        );
      },
    );
  }

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: false,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          // 0: Home / Provider Dashboard Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                pageBuilder: (context, state) => _buildFadeTransitionPage(
                  context: context,
                  state: state,
                  child: ValueListenableBuilder<UserAccount>(
                    valueListenable: UserAccount.notifier,
                    builder: (context, account, _) {
                      if (account.currentMode == AppMode.provider) {
                        return const ProviderDashboardScreen();
                      }
                      return const HomeScreen();
                    },
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'categories',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) => CustomTransitionPage<void>(
                      key: state.pageKey,
                      child: const CategoriesScreen(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        final slideAnimation = Tween<Offset>(
                          begin: const Offset(0.08, 0),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ));
                        return SlideTransition(
                          position: slideAnimation,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 1: Explore / Provider Requests Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.explore,
                pageBuilder: (context, state) => _buildFadeTransitionPage(
                  context: context,
                  state: state,
                  child: ValueListenableBuilder<UserAccount>(
                    valueListenable: UserAccount.notifier,
                    builder: (context, account, _) {
                      if (account.currentMode == AppMode.provider) {
                        return const ProviderRequestsScreen();
                      }
                      return const SearchScreen();
                    },
                  ),
                ),
              ),
            ],
          ),

          // 2: Bookings / Provider Jobs Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.bookings,
                pageBuilder: (context, state) => _buildFadeTransitionPage(
                  context: context,
                  state: state,
                  child: ValueListenableBuilder<UserAccount>(
                    valueListenable: UserAccount.notifier,
                    builder: (context, account, _) {
                      if (account.currentMode == AppMode.provider) {
                        return const ProviderJobsScreen();
                      }
                      return const BookingsScreen();
                    },
                  ),
                ),
              ),
            ],
          ),

          // 3: Messages Destination Branch (Shared)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.messages,
                pageBuilder: (context, state) => _buildFadeTransitionPage(
                  context: context,
                  state: state,
                  child: const MessagesScreen(),
                ),
              ),
            ],
          ),

          // 4: Profile / Provider Profile Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                pageBuilder: (context, state) => _buildFadeTransitionPage(
                  context: context,
                  state: state,
                  child: ValueListenableBuilder<UserAccount>(
                    valueListenable: UserAccount.notifier,
                    builder: (context, account, _) {
                      if (account.currentMode == AppMode.provider) {
                        return const ProviderProfileScreen();
                      }
                      return const ProfileScreen();
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),

      // Provider Details Screen (Opens over root navigator)
      GoRoute(
        path: AppRoutes.providerDetails,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final provider = state.extra is ServiceProvider
              ? state.extra as ServiceProvider
              : ServiceProvider.findById(id);

          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: ProviderDetailsScreen(
              providerId: id,
              initialProvider: provider,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final slideAnimation = Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ));
              return SlideTransition(
                position: slideAnimation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
          );
        },
      ),

      // Request Service Screen (Placeholder route)
      GoRoute(
        path: AppRoutes.requestService,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          ServiceProvider? pro;
          ProviderServiceOffering? selectedService;

          if (state.extra is RequestServiceArgs) {
            final args = state.extra as RequestServiceArgs;
            pro = args.provider;
            selectedService = args.selectedService;
          } else if (state.extra is ServiceProvider) {
            pro = state.extra as ServiceProvider;
          }

          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: RequestServiceScreen(
              provider: pro,
              selectedService: selectedService,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final slideAnimation = Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ));
              return SlideTransition(
                position: slideAnimation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
          );
        },
      ),

      // Price Negotiation Screen (Opens over root navigator)
      GoRoute(
        path: AppRoutes.negotiation,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final request = state.extra is ServiceRequest
              ? state.extra as ServiceRequest
              : ServiceRequest.findById(id);

          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: NegotiationScreen(
              requestId: id,
              initialRequest: request,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final slideAnimation = Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ));
              return SlideTransition(
                position: slideAnimation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
          );
        },
      ),

      // Chat Conversation Screen (Opens over root navigator)
      GoRoute(
        path: AppRoutes.conversation,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final conversation = state.extra is ChatConversation
              ? state.extra as ChatConversation
              : ChatConversation.findById(id);

          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: ConversationScreen(
              conversationId: id,
              initialConversation: conversation,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final slideAnimation = Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ));
              return SlideTransition(
                position: slideAnimation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
          );
        },
      ),

      // Notifications Screen (Opens over root navigator)
      GoRoute(
        path: AppRoutes.notifications,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const NotificationsScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final slideAnimation = Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ));
              return SlideTransition(
                position: slideAnimation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
          );
        },
      ),

      // Edit Profile Screen (Opens over root navigator)
      GoRoute(
        path: AppRoutes.editProfile,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const EditProfileScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final slideAnimation = Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ));
              return SlideTransition(
                position: slideAnimation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
          );
        },
      ),

      // Settings Screen (Opens over root navigator)
      GoRoute(
        path: AppRoutes.settings,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const SettingsScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final slideAnimation = Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ));
              return SlideTransition(
                position: slideAnimation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
          );
        },
      ),

      // Onboarding Screen (Opens over root navigator)
      GoRoute(
        path: AppRoutes.onboarding,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const OnboardingScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),

      // Welcome Screen (Opens over root navigator)
      GoRoute(
        path: AppRoutes.welcome,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const WelcomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),

      // Login Screen (Opens over root navigator)
      GoRoute(
        path: AppRoutes.login,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const LoginScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final slideAnimation = Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ));
              return SlideTransition(
                position: slideAnimation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
          );
        },
      ),

      // Register Screen (Opens over root navigator)
      GoRoute(
        path: AppRoutes.register,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const RegisterScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final slideAnimation = Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ));
              return SlideTransition(
                position: slideAnimation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
          );
        },
      ),

      // Forgot Password Screen (Opens over root navigator)
      GoRoute(
        path: AppRoutes.forgotPassword,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const ForgotPasswordScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final slideAnimation = Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ));
              return SlideTransition(
                position: slideAnimation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
          );
        },
      ),

      // Verification Screen (Opens over root navigator)
      GoRoute(
        path: AppRoutes.verification,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final email = state.extra is String ? state.extra as String : null;
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: VerificationScreen(email: email),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final slideAnimation = Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ));
              return SlideTransition(
                position: slideAnimation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
          );
        },
      ),

      // Provider Onboarding Screen
      GoRoute(
        path: AppRoutes.providerOnboarding,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const ProviderOnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slideAnimation = Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));
            return SlideTransition(
              position: slideAnimation,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
        ),
      ),

      // Provider Services Catalog Screen
      GoRoute(
        path: AppRoutes.providerServices,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const MyServicesScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // Provider Requests Direct Route
      GoRoute(
        path: AppRoutes.providerRequests,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const ProviderRequestsScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // Provider Jobs Direct Route
      GoRoute(
        path: AppRoutes.providerJobs,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const ProviderJobsScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // Provider Dashboard Direct Route
      GoRoute(
        path: AppRoutes.providerDashboard,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const ProviderDashboardScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
    ],
  );
}
