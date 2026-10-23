import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/app_providers.dart';
import '../core/course/lesson_section.dart';
import '../core/course/french_sentence_exercises.dart';
import '../core/course/french_sentence_package.dart';
import '../core/course/sentence_hunt_content.dart';
import '../features/arcade/arcade_screen.dart';
import '../features/course/course_lesson_screen.dart';
import '../features/course/course_progress_screen.dart';
import '../features/course_map/course_map_screen.dart';
import '../features/course_map/course_chart_screen.dart';
import 'course_root_navigation.dart';
import '../features/course/discovery_lesson_screen.dart';
import '../features/course/comparison_lesson_screen.dart';
import '../features/course/exercises/sentence_hunt_lesson_screen.dart';
import '../features/course/sentence_hunt_sections_screen.dart';
import '../core/course/comparison_content.dart';
import '../core/course/course_learning_providers.dart';
import '../features/auth/login_screen.dart';
import '../features/drills/drill_screen.dart';
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
      GoRoute(path: '/arcade', builder: (_, __) => const CourseRootNavigation(location: '/arcade', child: ArcadeLobby())),
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
          builder: (_, __) => const CourseRootNavigation(location: '/course-progress', child: CourseProgressScreen())),
      GoRoute(path: '/course-chart', builder: (_, __) => const CourseChartScreen()),
      GoRoute(path: '/course-system/:systemId', builder: (_, state) => CourseMapScreen(systemId: state.pathParameters['systemId']!)),
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
        path: '/course-sentence-hunt',
        builder: (context, state) {
          if (state.uri.queryParametersAll.isNotEmpty) {
            return const _SentenceHuntRouteUnavailable();
          }
          return const SentenceHuntSectionsScreen();
        },
      ),
      GoRoute(
        path: '/course-sentence-hunt/:sectionId',
        builder: (context, state) {
          final String? sectionId = state.pathParameters['sectionId'];
          final SentenceHuntSectionSpecification? specification =
              _sentenceHuntSpecification(sectionId);
          final Map<String, List<String>> all = state.uri.queryParametersAll;
          if (specification == null ||
              all.keys
                  .any((String key) => key != 'review' && key != 'itemId') ||
              all.values.any((List<String> values) => values.length != 1) ||
              (all['review'] != null &&
                  !<String>{'true', 'false'}.contains(all['review']!.single))) {
            return const _SentenceHuntRouteUnavailable();
          }
          final String? itemId = all['itemId']?.single;
          if (itemId != null &&
              (itemId.trim().isEmpty ||
                  !specification.items.any(
                      (SentenceHuntItemSpecification item) =>
                          item.id == itemId))) {
            return const _SentenceHuntRouteUnavailable();
          }
          return Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              final AsyncValue<SentenceHuntCatalogue> catalogue =
                  ref.watch(sentenceHuntCatalogueProvider);
              return catalogue.when(
                skipLoadingOnRefresh: false,
                loading: () => Scaffold(
                  appBar: AppBar(title: const Text('Sentence hunt')),
                  body: const Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => _SentenceHuntContentUnavailable(
                  message: 'Sentence-hunt content could not be checked.',
                  onRetry: () => ref.invalidate(sentenceHuntCatalogueProvider),
                ),
                data: (SentenceHuntCatalogue value) {
                  try {
                    value.section(specification.id);
                  } on Object {
                    return const _SentenceHuntContentUnavailable(
                      message: 'This sentence-hunt section is unavailable.',
                    );
                  }
                  if (!value.isAvailable(specification.id)) {
                    return const _SentenceHuntContentUnavailable(
                      message: 'This complete sentence section is unavailable '
                          'until its content and audio are reviewed.',
                    );
                  }
                  return SentenceHuntLessonScreen(
                    sectionId: specification.id,
                    review: all['review']?.single == 'true',
                    itemId: itemId,
                  );
                },
              );
            },
          );
        },
      ),
      GoRoute(
          path: '/course-review',
          builder: (_, __) => const CourseRootNavigation(location: '/course-review', child: CourseProgressScreen(review: true))),
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
          return const CourseMapScreen(systemId: 'en-fr-u-y-system');
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

SentenceHuntSectionSpecification? _sentenceHuntSpecification(String? id) {
  if (id == null) return null;
  for (final SentenceHuntSectionSpecification specification
      in sentenceHuntSectionSpecifications) {
    if (specification.id == id) return specification;
  }
  return null;
}

class _SentenceHuntRouteUnavailable extends StatelessWidget {
  const _SentenceHuntRouteUnavailable();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Sentence sound hunt')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('This sentence-hunt route is unavailable.'),
                TextButton(
                  onPressed: () => context.go('/course-sentence-hunt'),
                  child: const Text('Back to sentence sections'),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SentenceHuntContentUnavailable extends StatelessWidget {
  const _SentenceHuntContentUnavailable({
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Sentence hunt')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(message),
                if (onRetry != null)
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Retry validation'),
                  ),
                TextButton(
                  onPressed: () => context.go('/course-sentence-hunt'),
                  child: const Text('Back to sentence sections'),
                ),
              ],
            ),
          ),
        ),
      );
}
