import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/app_providers.dart';
import '../core/services/auth_service.dart';
import '../features/auth/login_screen.dart';
import '../features/drills/drill_screen.dart';
import '../features/home/home_screen.dart';
import '../features/ipa/ipa_explorer_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/review/review_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/speak/speak_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final onboarding = ref.watch(onboardingControllerProvider);
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/onboarding',
    redirect: (_, state) {
      if (!onboarding.isReady) {
        return '/onboarding';
      }

      final hasLanguage = onboarding.selectedLanguageCode != null;
      final isOnboarding = state.matchedLocation == '/onboarding';
      if (!hasLanguage && !isOnboarding) {
        return '/onboarding';
      }
      
      // Auth requirement - for now, skip auth redirect
      //final needsAuth = state.matchedLocation != '/login';
      //if (!authState.isAuthenticated && needsAuth) {
      //  return '/login';
      //}
      
      if (hasLanguage && isOnboarding) {
        return '/home';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) {
          return const LoginScreen();
        },
      ),
      GoRoute(
        path: '/onboarding',
        builder: (BuildContext context, GoRouterState state) {
          return const OnboardingScreen();
        },
      ),
      GoRoute(
        path: '/home',
        builder: (BuildContext context, GoRouterState state) {
          return const HomeScreen();
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (BuildContext context, GoRouterState state) {
          return const ProfileScreen();
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (BuildContext context, GoRouterState state) {
          return const SettingsScreen();
        },
      ),
      GoRoute(
        path: '/ipa',
        builder: (BuildContext context, GoRouterState state) {
          return const IpaExplorerScreen();
        },
      ),
      GoRoute(
        path: '/drill',
        builder: (BuildContext context, GoRouterState state) {
          return const DrillScreen();
        },
      ),
      GoRoute(
        path: '/speak',
        builder: (BuildContext context, GoRouterState state) {
          return const SpeakScreen();
        },
      ),
      GoRoute(
        path: '/progress',
        builder: (BuildContext context, GoRouterState state) {
          return const ProgressScreen();
        },
      ),
      GoRoute(
        path: '/review',
        builder: (BuildContext context, GoRouterState state) {
          return const ReviewScreen();
        },
      ),
    ],
  );
});
