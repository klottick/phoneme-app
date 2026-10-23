import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/app.dart';
import 'package:linguist/src/core/theme/app_theme.dart';
import 'package:linguist/src/core/theme/space_course_colors.dart';
import 'package:linguist/src/core/theme/space_course_theme.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/lesson_section.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/features/course/discovery_lesson_screen.dart';
import 'package:linguist/src/features/course_map/course_map_screen.dart';
import 'package:linguist/src/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/controlled_listening_audio.dart';
import '../support/course_learning_widget_store.dart';
import '../support/map_motion_test_support.dart';

void main() {
  setUp(
    () =>
        SharedPreferences.setMockInitialValues({'selected_course_id': 'en-fr'}),
  );

  test('palette_is_exact_and_legacy_theme_unchanged', () {
    expect(
      <Color>[
        SpaceCourseColors.canvas,
        SpaceCourseColors.background,
        SpaceCourseColors.panel,
        SpaceCourseColors.raised,
        SpaceCourseColors.border,
        SpaceCourseColors.action,
        SpaceCourseColors.selected,
        SpaceCourseColors.ship,
        SpaceCourseColors.currentRing,
        SpaceCourseColors.textPrimary,
        SpaceCourseColors.textSecondary,
      ],
      <Color>[
        const Color(0xFF172231),
        const Color(0xFF142131),
        const Color(0xFF1D2C40),
        const Color(0xFF213349),
        const Color(0xFF3C4C62),
        const Color(0xFF68428A),
        const Color(0xFF513367),
        const Color(0xFF70438F),
        const Color(0xFF9461BA),
        const Color(0xFFF3F5F9),
        const Color(0xFFB9C8DB),
      ],
    );
    final light = spaceCourseTheme(lightTheme);
    expect(light, same(lightTheme));
    expect(light.colorScheme, lightTheme.colorScheme);
    expect(light.textTheme, lightTheme.textTheme);
    expect(
      spaceCourseTheme(darkTheme).colorScheme.error,
      darkTheme.colorScheme.error,
    );
    expect(
      spaceCourseTheme(darkTheme).colorScheme.tertiary,
      darkTheme.colorScheme.tertiary,
    );

    final dark = spaceCourseTheme(darkTheme);
    expect(dark.scaffoldBackgroundColor, SpaceCourseColors.background);
    expect(dark.colorScheme.surface, SpaceCourseColors.panel);
    expect(dark.cardTheme.color, SpaceCourseColors.panel);
    expect(dark.appBarTheme.backgroundColor, SpaceCourseColors.background);
    expect(
      dark.filledButtonTheme.style!.foregroundColor!.resolve({}),
      SpaceCourseColors.textPrimary,
    );
    expect(
      dark.filledButtonTheme.style!.backgroundColor!.resolve({}),
      SpaceCourseColors.action,
    );
    expect(
      dark.navigationBarTheme.backgroundColor,
      SpaceCourseColors.background,
    );
    expect(dark.navigationBarTheme.indicatorColor, SpaceCourseColors.selected);
    expect(SpaceCourseColors.currentRing, isNot(SpaceCourseColors.selected));
    expect(
      dark.inputDecorationTheme.focusedBorder!.borderSide.color,
      SpaceCourseColors.currentRing,
    );
    expect(dark.disabledColor.computeLuminance(), greaterThan(0.1));
    expect(dark.colorScheme.onPrimary, SpaceCourseColors.textPrimary);
    expect(dark.textTheme.bodyMedium!.color, SpaceCourseColors.textPrimary);
    expect(dark.textTheme.bodySmall!.color, SpaceCourseColors.textSecondary);
    expect(
      dark.textTheme.bodyMedium!.fontSize,
      darkTheme.textTheme.bodyMedium!.fontSize,
      reason: 'appearance changes preserve typography metrics',
    );
    expect(dark.colorScheme.error, darkTheme.colorScheme.error);
    expect(dark.colorScheme.tertiary, darkTheme.colorScheme.tertiary);
    expect(
      _contrast(SpaceCourseColors.textPrimary, SpaceCourseColors.action),
      greaterThan(4.5),
    );
    expect(
      _contrast(SpaceCourseColors.textSecondary, SpaceCourseColors.panel),
      greaterThan(4.5),
    );
    expect(
      _contrast(SpaceCourseColors.currentRing, SpaceCourseColors.canvas),
      greaterThan(3),
    );
    final disabledText = dark.filledButtonTheme.style!.foregroundColor!.resolve(
      {WidgetState.disabled},
    )!;
    final disabledSurface = dark.filledButtonTheme.style!.backgroundColor!
        .resolve({WidgetState.disabled})!;
    expect(_contrast(disabledText, disabledSurface), greaterThan(4.5));
    final focusedBorder =
        dark.inputDecorationTheme.focusedBorder!.borderSide.color;
    expect(_contrast(focusedBorder, SpaceCourseColors.panel), greaterThan(3));
  });

  testWidgets('saved_light_dark_system_preferences_survive_navigation', (
    tester,
  ) async {
    for (final mode in ThemeMode.values) {
      SharedPreferences.setMockInitialValues({
        'selected_course_id': 'en-fr',
        'theme_mode': mode.name,
      });
      final store = CourseLearningWidgetStore();
      store.seedSession(_debriefSession());
      final audio = ControlledListeningAudio();
      disableMapMotion(tester);
      final container = ProviderContainer(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(store),
          courseAudioProvider.overrideWithValue(audio),
          comparisonLearningStateProvider.overrideWith(
            (ref) async => ComparisonLearningState.empty(
              ComparisonProfileScope(
                courseId: 'en-fr',
                owner: LearningOwner.guest(),
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const LinguistApp(),
        ),
      );
      await tester.pumpAndSettle();
      final router = container.read(appRouterProvider);
      final prefs = await SharedPreferences.getInstance();
      final originalPreference = prefs.getString('theme_mode');
      expect(originalPreference, mode.name);
      for (final route in [
        '/home',
        '/course-chart',
        '/course-system/en-fr-u-y-system',
        '/course-lesson/en-fr-u-y',
        '/course-comparison/en-fr-phoneme-comparison',
        '/course-review',
        '/course-progress',
        '/arcade',
        '/settings',
        '/ipa',
        '/course-lesson/en-fr-vowels',
        '/arcade/sound',
        '/arcade/word',
      ]) {
        router.go(route);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        if (route == '/course-lesson/en-fr-u-y') {
          expect(
            find.text('Section debrief'),
            findsOneWidget,
            reason: 'the saved valid debrief remains available under $mode',
          );
        }
        expect(
          prefs.getString('theme_mode'),
          originalPreference,
          reason: 'navigation to $route must not persist appearance',
        );
      }
      if (mode == ThemeMode.system) {
        router.go('/home');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        tester.binding.platformDispatcher.platformBrightnessTestValue =
            Brightness.dark;
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.byType(CourseMapScreen))).brightness,
          Brightness.dark,
        );
        router.go('/home');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        tester.binding.platformDispatcher.platformBrightnessTestValue =
            Brightness.light;
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.byType(CourseMapScreen))).brightness,
          Brightness.light,
        );
        expect(prefs.getString('theme_mode'), 'system');
        tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
      }
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      container.dispose();
      await audio.dispose();
    }
  });

  testWidgets('supported_routes_inherit_course_theme_not_game_boards', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'selected_course_id': 'en-fr',
      'theme_mode': 'dark',
    });
    final store = CourseLearningWidgetStore();
    final audio = ControlledListeningAudio();
    disableMapMotion(tester);
    final container = ProviderContainer(
      overrides: [
        courseLearningStoreProvider.overrideWithValue(store),
        courseAudioProvider.overrideWithValue(audio),
        comparisonLearningStateProvider.overrideWith(
          (ref) async => ComparisonLearningState.empty(
            ComparisonProfileScope(
              courseId: 'en-fr',
              owner: LearningOwner.guest(),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);
    addTearDown(() async {
      audio.releaseAll();
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      container.dispose();
      await audio.dispose();
    });
    for (final route in [
      '/home',
      '/course-chart',
      '/course-system/en-fr-u-y-system',
      '/course-lesson/en-fr-u-y',
      '/course-comparison/en-fr-phoneme-comparison',
      '/course-comparison/invalid-recovery',
      '/course-review',
      '/course-progress',
      '/arcade',
    ]) {
      router.go(route);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        Theme.of(
          tester.element(find.byType(Scaffold).last),
        ).scaffoldBackgroundColor,
        SpaceCourseColors.background,
        reason: '$route receives scoped dark theme',
      );
      expect(find.byType(SpaceCourseTheme), findsWidgets);
    }
    router.go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final launch = find.text('Start lesson').evaluate().isNotEmpty
        ? find.text('Start lesson')
        : find.text('Continue lesson');
    await tester.ensureVisible(launch);
    await tester.tap(launch);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < frenchUySection.items.length; i++) {
      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      audio.requests.last.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(
        find.text('/${frenchUySection.items[i].expectedSound}/'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(
        find.text(
          i == frenchUySection.items.length - 1
              ? 'See section explanation'
              : 'Next word',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Section debrief'), findsOneWidget);
    expect(
      Theme.of(
        tester.element(find.byType(DiscoveryLessonScreen)),
      ).scaffoldBackgroundColor,
      SpaceCourseColors.background,
      reason: 'the debrief remains inside the scoped course theme',
    );
    for (final route in [
      '/settings',
      '/ipa',
      '/drill',
      '/course-lesson/en-fr-vowels',
      '/arcade/sound',
      '/arcade/word',
    ]) {
      router.go(route);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.byType(SpaceCourseTheme),
        findsNothing,
        reason: '$route is deliberately not in the supported appearance scope',
      );
    }
  });
}

double _contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  final lighter = a > b ? a : b;
  final darker = a > b ? b : a;
  return (lighter + 0.05) / (darker + 0.05);
}

LessonSectionSession _debriefSession() {
  final session = LessonSectionSession(
    itemIds: frenchUySection.items.map((item) => item.id).toList(),
    sessionId: 'theme-test-debrief',
  );
  for (var index = 0; index < frenchUySection.items.length; index++) {
    session.submit(true);
    session.advance();
  }
  return session;
}
