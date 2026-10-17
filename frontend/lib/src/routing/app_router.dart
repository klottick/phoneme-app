import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/app_providers.dart';
import '../core/course/lesson_section.dart';
import '../features/arcade/arcade_screen.dart';
import '../features/course/course_lesson_screen.dart';
import '../features/course/course_progress_screen.dart';
import '../features/course/discovery_lesson_screen.dart';
import '../features/course/comparison_lesson_screen.dart';
import '../core/course/comparison_content.dart';
import '../core/course/course_learning_providers.dart';
import '../features/auth/login_screen.dart';
import '../features/drills/drill_screen.dart';
import '../features/home/home_screen.dart';
import '../features/ipa/ipa_explorer_screen.dart';
import '../features/audio/audio_compare_screen.dart';
import '../features/content/content_manager_screen.dart';
import '../features/modes/challenge_mode_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../core/services/curriculum_service.dart';
import '../core/services/data_export_service.dart';
import '../core/services/insights_service.dart';
import '../features/phoneme_id/phoneme_identify_screen.dart';
import '../features/phoneme_test/phoneme_test_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/progress/progress_analytics_screen.dart';
import '../features/review/review_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/speak/speak_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final onboarding = ref.watch(onboardingControllerProvider);

  return GoRouter(
    initialLocation: '/onboarding',
    redirect: (_, state) {
      if (!onboarding.isReady) {
        return '/onboarding';
      }

      final hasLanguage = onboarding.courseId != null;
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
      GoRoute(path: '/arcade', builder: (_, __) => const ArcadeLobby()),
      GoRoute(
          path: '/arcade/sound',
          builder: (_, __) => const ArcadeScreen(silent: false)),
      GoRoute(
          path: '/arcade/word',
          builder: (_, __) => const ArcadeScreen(silent: true)),
      GoRoute(
          path: '/course-lesson/:id',
          builder: (_, state) {
            final String lessonId = state.pathParameters['id']!;
            final bool review = state.uri.queryParameters['review'] == 'true';
            // Selective routing: only authored discovery sections use the new
            // lifecycle-aware screen; every other lesson keeps the legacy
            // screen and its behavior.
            if (sectionForLesson(lessonId) != null) {
              return DiscoveryLessonScreen(lessonId: lessonId, review: review);
            }
            return CourseLessonScreen(lessonId: lessonId, review: review);
          }),
      GoRoute(
          path: '/course-progress',
          builder: (_, __) => const CourseProgressScreen()),
      GoRoute(
          path: '/course-comparison/:activityId',
          builder: (context, state) {
            const unavailable = Scaffold(
                body: Center(
                    child: Text('This comparison activity is unavailable.')));
            final activityId = state.pathParameters['activityId'];
            final all = state.uri.queryParametersAll;
            if (activityId != comparisonActivityId ||
                all.keys.any((key) => key != 'review' && key != 'pairId') ||
                all.values.any((values) => values.length != 1) ||
                (all['review'] != null &&
                    !{'true', 'false'}.contains(all['review']!.single))) {
              return unavailable;
            }
            final pairId = all['pairId']?.single;
            return Consumer(builder: (context, ref, _) {
              try {
                final catalogue = ref.watch(comparisonCatalogueProvider);
                if (pairId != null && !catalogue.byId.containsKey(pairId)) {
                  return unavailable;
                }
                return ComparisonLessonScreen(
                    activityId: activityId!,
                    review: all['review']?.single == 'true',
                    pairId: pairId);
              } catch (_) {
                return unavailable;
              }
            });
          }),
      GoRoute(
          path: '/course-review',
          builder: (_, __) => const CourseProgressScreen(review: true)),
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
        path: '/phoneme-id',
        builder: (BuildContext context, GoRouterState state) {
          return const PhonemeIdentifyScreen();
        },
      ),
      GoRoute(
        path: '/phoneme-test',
        builder: (BuildContext context, GoRouterState state) {
          return const PhonemeTestScreen();
        },
      ),
      GoRoute(
        path: '/compare',
        builder: (BuildContext context, GoRouterState state) {
          return const AudioCompareScreen();
        },
      ),
      GoRoute(
        path: '/analytics',
        builder: (BuildContext context, GoRouterState state) {
          return const ProgressAnalyticsScreen();
        },
      ),
      GoRoute(
        path: '/modes',
        builder: (BuildContext context, GoRouterState state) {
          return const ChallengeModeScreen();
        },
      ),
      GoRoute(
        path: '/custom',
        builder: (BuildContext context, GoRouterState state) {
          return const ContentManagerScreen();
        },
      ),
      GoRoute(
        path: '/lessons',
        builder: (BuildContext context, GoRouterState state) {
          final code = state.uri.queryParameters['lang'] ?? 'fr';
          return LessonPlanScreen(languageCode: code);
        },
      ),
      GoRoute(
        path: '/export',
        builder: (BuildContext context, GoRouterState state) {
          return const DataExportScreen();
        },
      ),
      GoRoute(
        path: '/insights',
        builder: (BuildContext context, GoRouterState state) {
          return const InsightsScreen();
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
