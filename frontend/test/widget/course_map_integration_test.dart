import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/app.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/french_sentence_exercises.dart';
import 'package:linguist/src/core/course/french_sentence_package.dart';
import 'package:linguist/src/core/course/lesson_section.dart';
import 'package:linguist/src/features/course/course_completion_summary.dart';
import 'package:linguist/src/features/course/discovery_lesson_screen.dart';
import 'package:linguist/src/features/course_map/course_map_screen.dart';
import 'package:linguist/src/features/course_map/course_map_providers.dart';
import 'package:linguist/src/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/controlled_listening_audio.dart';
import '../support/course_learning_widget_store.dart';
import '../support/map_motion_test_support.dart';

void main() {
  late Map<String, String> sentenceAssets;
  setUpAll(() {
    sentenceAssets = {
      for (final file in const [
        'manifest.json',
        'provenance.json',
        'annotations.json',
        'source-evidence.json',
      ])
        'assets/audio/fr-sentences/$file': File(
          'assets/audio/fr-sentences/$file',
        ).readAsStringSync(),
    };
  });
  setUp(
    () =>
        SharedPreferences.setMockInitialValues({'selected_course_id': 'en-fr'}),
  );

  testWidgets('map_journey_uses_real_committed_state', (tester) async {
    final store = CourseLearningWidgetStore()
      ..actionGates[FinishLearningActivity] = Completer<void>()
      ..failingActions.add(FinishLearningActivity);
    final audio = ControlledListeningAudio();
    disableMapMotion(tester);
    final container = ProviderContainer(
      overrides: [
        courseLearningStoreProvider.overrideWithValue(store),
        courseAudioProvider.overrideWithValue(audio),
        sentencePackageLoaderProvider.overrideWithValue(
          FrenchSentencePackageLoader(
            bundle: _RepositoryAssetBundle(sentenceAssets),
          ),
        ),
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
      store.actionGates[FinishLearningActivity]?.complete();
      audio.releaseAll();
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      container.dispose();
      await audio.dispose();
    });

    expect(router.state.uri.path, '/home');
    expect(find.byType(CourseMapScreen), findsOneWidget);
    expect(find.text('Start lesson'), findsOneWidget);
    expect(
      find.textContaining('%'),
      findsNothing,
      reason: 'the map must not fabricate a course mastery percentage',
    );

    final planned = find.widgetWithText(ListTile, 'Compare /u/ and /y/');
    if (planned.evaluate().isEmpty) {
      await tester.ensureVisible(find.text('All destinations'));
      await tester.tap(find.text('All destinations'));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(
      find.widgetWithText(ListTile, 'Compare /u/ and /y/'),
    );
    await tester.tap(find.widgetWithText(ListTile, 'Compare /u/ and /y/'));
    await tester.pumpAndSettle();
    expect(find.text('Start comparison'), findsOneWidget);
    expect(
      find.text(
        'Demo practice: this authored comparison content has not had qualified French review. It is practice, not an assessment.',
      ),
      findsOneWidget,
    );
    expect(
      router.state.uri.path,
      '/home',
      reason: 'inspection does not navigate',
    );
    expect(
      store.submitted,
      isEmpty,
      reason:
          'inspection and optional practice do not move the ship or write learning',
    );

    await tester.ensureVisible(
      find.widgetWithText(ListTile, 'Hear the difference'),
    );
    await tester.tap(find.widgetWithText(ListTile, 'Hear the difference'));
    await tester.pumpAndSettle();
    final launch = find.text('Start lesson');
    await tester.ensureVisible(launch);
    await tester.tap(launch);
    await tester.pumpAndSettle();
    expect(find.byType(DiscoveryLessonScreen), findsOneWidget);
    expect(
      store.submitted.where((command) => command.action is StartLearningRun),
      hasLength(1),
    );

    for (var i = 0; i < frenchUySection.items.length; i++) {
      final item = frenchUySection.items[i];
      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      expect(
        audio.requests,
        isNotEmpty,
        reason: 'the real discovery screen requested controlled audio',
      );
      audio.requests.last.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.text('/${item.expectedSound}/'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          i == frenchUySection.items.length - 1
              ? 'See section explanation'
              : 'Next word',
        ),
      );
      await tester.pumpAndSettle();
    }
    expect(find.text('Section debrief'), findsOneWidget);
    expect(
      store.committedState.completions,
      isEmpty,
      reason: 'a valid debrief is not durable completion',
    );
    expect(
      store.committedState.history.expand((batch) => batch.attempts),
      hasLength(10),
    );
    final preFinish = CourseCompletionSummary.fromState(
      state: store.committedState,
      registry: LearningRegistry.french(),
    );
    expect(preFinish.discoveryCompleteCount, 0);

    await tester.tap(find.text('Finish section'));
    await tester.pump();
    expect(store.committedState.completions, isEmpty);
    expect(router.state.uri.path, '/course-lesson/en-fr-u-y');
    expect(find.text('Retry saving'), findsNothing);
    final pendingFinish = store.submitted.singleWhere(
      (command) => command.action is FinishLearningActivity,
    );
    store.actionGates[FinishLearningActivity]!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Retry saving'), findsOneWidget);
    expect(store.committedState.completions, isEmpty);
    expect(router.state.uri.path, '/course-lesson/en-fr-u-y');

    store.failingActions.remove(FinishLearningActivity);
    store.actionGates.remove(FinishLearningActivity);
    await tester.tap(find.text('Retry saving'));
    await tester.pumpAndSettle();
    expect(store.submitted.last, same(pendingFinish));
    expect(store.committedState.completions, hasLength(1));
    expect(router.state.uri.path, '/home');
    await tester.pumpAndSettle();
    expect(
      find.text('Available main lessons: 1/2 available complete'),
      findsOneWidget,
    );
    expect(
      find.text('All currently available lessons complete.'),
      findsNothing,
    );
    expect(find.text('Review lesson'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);

    final currentBody = container
        .read(courseMapStateProvider('en-fr-u-y-system'))
        .currentBodyId;
    final destinationDisclosure = find.text('All destinations');
    if (destinationDisclosure.evaluate().isNotEmpty) {
      await tester.ensureVisible(destinationDisclosure);
      await tester.tap(destinationDisclosure);
      await tester.pumpAndSettle();
    }
    final optionalPractice = find.widgetWithText(
      ListTile,
      'Mixed comparison practice',
    );
    expect(optionalPractice, findsOneWidget);
    await tester.ensureVisible(optionalPractice);
    await tester.tap(optionalPractice);
    await tester.pumpAndSettle();
    expect(
      container.read(courseMapStateProvider('en-fr-u-y-system')).currentBodyId,
      currentBody,
      reason:
          'optional practice inspection does not move the committed ship anchor',
    );
    expect(store.committedState.completions, hasLength(1));

    router.go('/course-sentence-hunt/en-fr-sentence-hunt-vowels');
    await container.read(sentenceHuntCatalogueProvider.future);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Keep the observed route output in failure logs: a blocked route must not
    // silently fall back to another lesson or become a launchable activity.
    final routeText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .where((text) => text.isNotEmpty)
        .toList();
    expect(
      find.textContaining('This complete sentence section is unavailable'),
      findsOneWidget,
      reason:
          'actual blocked sentence route ${router.state.uri}: ${routeText.join(' | ')}, known IDs: ${sentenceHuntSectionSpecifications.map((section) => section.id).join(',')}',
    );
    expect(find.text('Retry validation'), findsNothing);
    expect(
      store.submitted.where((command) => command.action is StartLearningRun),
      hasLength(1),
      reason: 'the actual blocked sentence package cannot launch learning',
    );
  });
}

/// Reads the shipped, unmodified production packet through Flutter's loader.
/// Widget tests do not mount the application's asset bundle automatically.
final class _RepositoryAssetBundle extends AssetBundle {
  _RepositoryAssetBundle(this.contents);

  final Map<String, String> contents;

  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      Future<String>.value(contents[key]!);

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(utf8.encode(contents[key]!));
}
