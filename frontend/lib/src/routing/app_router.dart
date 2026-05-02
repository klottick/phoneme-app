import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/app_providers.dart';
import '../features/drills/drill_screen.dart';
import '../features/home/home_screen.dart';
import '../features/ipa/ipa_explorer_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/review/review_screen.dart';
import '../features/speak/speak_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final onboarding = ref.watch(onboardingControllerProvider);

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
      if (hasLanguage && isOnboarding) {
        return '/home';
      }
      return null;
    },
    routes: <RouteBase>[
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
