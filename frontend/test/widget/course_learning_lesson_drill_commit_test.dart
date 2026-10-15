import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_persistence.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_store.dart';
import 'package:linguist/src/core/course/course_learning_transition.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/features/course/course_lesson_screen.dart';
import 'package:linguist/src/features/drills/drill_screen.dart';
import '../support/course_learning_widget_store.dart';

final _storeEpoch = StateProvider<int>((ref) => 0);

class _Audio implements CourseAudio {
  final List<String> spoken = [];

  @override
  Future<void> speak(String word) async => spoken.add(word);

  @override
  Future<void> stop() async {}
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'legacy answer retry submits the identical command and credits once',
      (tester) async {
    final store = CourseLearningWidgetStore();
    store.failingActions.add(ChooseSound);
    final audio = _Audio();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        courseLearningStoreProvider.overrideWithValue(store),
        courseAudioProvider.overrideWithValue(audio),
      ],
      child: const MaterialApp(
        home: CourseLessonScreen(lessonId: 'en-fr-vowels'),
      ),
    ));
    await _settle(tester);
    await tester.tap(find.text('Listen to French word'));
    await _settle(tester);
    await tester.tap(find.text('/i/'));
    await _settle(tester);
    expect(find.textContaining('could not be saved'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Next word'), 200);
    expect(find.text('Next word'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.ancestor(
              of: find.text('Next word'),
              matching: find.byType(FilledButton),
            ))
            .onPressed,
        isNull);
    final failed = store.submitted.last;
    expect(failed.action, isA<ChooseSound>());

    store.failingActions.clear();
    await tester.tap(find.text('Retry saving'));
    await _settle(tester);
    expect(store.submitted.last, same(failed));
    expect(store.committedState.history, hasLength(1));
    expect(store.committedState.history.single.attempts, hasLength(1));
  });

  testWidgets('drill answer retry credits only after one committed retry',
      (tester) async {
    final store = CourseLearningWidgetStore();
    store.failingActions.add(ChooseDrillWord);
    final audio = _Audio();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        courseLearningStoreProvider.overrideWithValue(store),
        courseAudioProvider.overrideWithValue(audio),
      ],
      child: const MaterialApp(home: DrillScreen()),
    ));
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await _settle(tester);
    final choice = audio.spoken.single == 'tu' ? 'tu' : 'roue';
    await tester.tap(find.text(choice));
    await _settle(tester);

    expect(find.textContaining('Could not save your answer'), findsOneWidget);
    expect(find.text('Item 1'), findsOneWidget);
    expect(find.text('0 / 1'), findsOneWidget);
    final failed = store.submitted.last;
    expect(failed.action, isA<ChooseDrillWord>());
    store.failingActions.clear();
    await tester.tap(find.text('Retry saving'));
    await _settle(tester);
    expect(store.submitted.last, same(failed));
    expect(store.committedState.history, hasLength(1));
    expect(store.committedState.history.single.attempts, hasLength(1));
    expect(find.text('Item 2'), findsOneWidget);
  });

  testWidgets('reopen resumes both activities without restoring hearing',
      (tester) async {
    final lessonStore = CourseLearningWidgetStore();
    final lessonAudio = _Audio();
    Future<void> pumpLesson() async => tester.pumpWidget(ProviderScope(
          overrides: [
            courseLearningStoreProvider.overrideWithValue(lessonStore),
            courseAudioProvider.overrideWithValue(lessonAudio),
          ],
          child: const MaterialApp(
              home: CourseLessonScreen(lessonId: 'en-fr-vowels')),
        ));
    await pumpLesson();
    await _settle(tester);
    await tester.tap(find.text('Listen to French word'));
    await _settle(tester);
    await tester.tap(find.text('/i/'));
    await _settle(tester);
    await tester.scrollUntilVisible(find.text('Next word'), 200);
    await tester.tap(find.text('Next word'));
    await _settle(tester);
    await tester.pumpWidget(const SizedBox());
    await pumpLesson();
    await _settle(tester);
    expect(find.text('Listen 2 of 4'), findsOneWidget);
    expect(lessonAudio.spoken, ['lit']);
    expect(
        tester
            .widget<OutlinedButton>(find.ancestor(
              of: find.text('/o/'),
              matching: find.byType(OutlinedButton),
            ))
            .onPressed,
        isNull);

    final drillStore = CourseLearningWidgetStore();
    final drillAudio = _Audio();
    Future<void> pumpDrill() async => tester.pumpWidget(ProviderScope(
          overrides: [
            courseLearningStoreProvider.overrideWithValue(drillStore),
            courseAudioProvider.overrideWithValue(drillAudio),
          ],
          child: const MaterialApp(home: DrillScreen()),
        ));
    await tester.pumpWidget(const SizedBox());
    await pumpDrill();
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await _settle(tester);
    await tester.tap(find.text('tu'));
    await _settle(tester);
    await tester.pumpWidget(const SizedBox());
    await pumpDrill();
    await _settle(tester);
    expect(find.text('Item 2'), findsOneWidget);
    expect(drillAudio.spoken, ['tu']);
    expect(
        tester
            .widget<FilledButton>(find.ancestor(
              of: find.text('rue'),
              matching: find.byType(FilledButton),
            ))
            .onPressed,
        isNull);
  });

  testWidgets('A to B to A does not publish a delayed old drill commit',
      (tester) async {
    final oldA = CourseLearningWidgetStore();
    final storeB = CourseLearningWidgetStore();
    final newA = CourseLearningWidgetStore();
    final gate = Completer<void>();
    final audio = _Audio();
    oldA.actionGates[ChooseDrillWord] = gate;
    var activeStore = oldA;
    final selectedStore = Provider<CourseLearningStore>((ref) {
      ref.watch(_storeEpoch);
      return activeStore;
    });
    final container = ProviderContainer(overrides: [
      selectedStore.overrideWith((ref) {
        ref.watch(_storeEpoch);
        return activeStore;
      }),
      courseLearningStoreProvider
          .overrideWith((ref) => ref.watch(selectedStore)),
      courseAudioProvider.overrideWithValue(audio),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: DrillScreen()),
    ));
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await _settle(tester);
    await tester.tap(find.text('tu'));
    await tester.pump();
    expect(oldA.submitted.where((command) => command.action is ChooseDrillWord),
        hasLength(1));

    activeStore = storeB;
    container.read(_storeEpoch.notifier).state++;
    await _settle(tester);
    activeStore = newA;
    container.read(_storeEpoch.notifier).state++;
    await _settle(tester);
    gate.complete();
    await _settle(tester);

    expect(find.text('Item 1'), findsOneWidget);
    expect(find.text('0 / 1'), findsOneWidget);
    expect(find.text('Correct'), findsNothing);
    expect(oldA.committedState.history, hasLength(1));
    expect(newA.committedState.history, isEmpty);
  });

  testWidgets('typed repository persists an answer through mocked preferences',
      (tester) async {
    final guest = LearningOwner.guest();
    final scope = LearningScope(courseId: 'en-fr', owner: guest);
    final auth = LearningAuthScope(owner: guest, generation: 0, ready: true);
    var token = 0;
    final store = CourseLearningRepository(
      scope: scope,
      authGeneration: 0,
      currentAuth: () => auth,
      backendOwner: () => guest,
      persistence: PreferencesLearningPersistence(
        preferences: SharedPreferences.getInstance,
      ),
      transitions: LearningTransitionEngine(LearningRegistry.french()),
      cloud: null,
      clock: () => DateTime.utc(2026, 10, 15),
      newToken: () => (++token).toString().padLeft(22, '0'),
      random: Random(1),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        courseLearningStoreProvider.overrideWithValue(store),
        courseAudioProvider.overrideWithValue(_Audio()),
      ],
      child:
          const MaterialApp(home: CourseLessonScreen(lessonId: 'en-fr-vowels')),
    ));
    await _settle(tester);
    await tester.tap(find.text('Listen to French word'));
    await _settle(tester);
    await tester.tap(find.text('/i/'));
    await _settle(tester);
    final committed = await store.load();
    expect(committed.history.single.attempts.single.correct, isTrue);
    expect(committed.activities['lesson:en-fr-vowels']!.snapshot,
        isA<LegacyLessonCheckpoint>());
  });

  testWidgets('corrupt legacy and drill snapshots stay unavailable until retry',
      (tester) async {
    final lessonStore = CourseLearningWidgetStore()
      ..loadHandler = (call) async {
        if (call == 1) throw const LearningCorruptException();
        return CourseLearningWidgetStore().committedState;
      };
    await tester.pumpWidget(ProviderScope(
      overrides: [courseLearningStoreProvider.overrideWithValue(lessonStore)],
      child:
          const MaterialApp(home: CourseLessonScreen(lessonId: 'en-fr-vowels')),
    ));
    await _settle(tester);
    expect(find.textContaining('unavailable'), findsOneWidget);
    expect(lessonStore.prepareCalls, 0);
    expect(lessonStore.submitted, isEmpty);
    await tester.tap(find.text('Retry loading'));
    await _settle(tester);
    expect(lessonStore.retryLoadCalls, 1);
    expect(lessonStore.submitted.single.action, isA<StartLearningRun>());

    await tester.pumpWidget(const SizedBox());
    final drillStore = CourseLearningWidgetStore()
      ..loadHandler = (call) async {
        if (call == 1) throw const LearningCorruptException();
        return CourseLearningWidgetStore().committedState;
      };
    await tester.pumpWidget(ProviderScope(
      overrides: [courseLearningStoreProvider.overrideWithValue(drillStore)],
      child: const MaterialApp(home: DrillScreen()),
    ));
    await _settle(tester);
    expect(find.textContaining('unavailable'), findsOneWidget);
    expect(drillStore.prepareCalls, 0);
    expect(drillStore.submitted, isEmpty);
    await tester.tap(find.text('Retry loading'));
    await _settle(tester);
    expect(drillStore.retryLoadCalls, 1);
    expect(drillStore.submitted.single.action, isA<StartLearningRun>());
  });

  testWidgets(
      'opening lesson reference persists answerRevealed for all contexts',
      (tester) async {
    final store = CourseLearningWidgetStore();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        courseLearningStoreProvider.overrideWithValue(store),
        courseAudioProvider.overrideWithValue(_Audio()),
      ],
      child:
          const MaterialApp(home: CourseLessonScreen(lessonId: 'en-fr-vowels')),
    ));
    await _settle(tester);
    await tester.tap(find.text('Word reference'));
    await _settle(tester);
    final slot = store.committedState.activities['lesson:en-fr-vowels']!;
    expect(slot.exposures, isNotEmpty);
    expect(
        slot.exposures.values.every((exposure) =>
            exposure.assistance.contains(AssistanceFlag.answerRevealed)),
        isTrue);
    await tester.tap(find.text('Word reference'));
    await _settle(tester);
    expect(
        store.committedState.activities['lesson:en-fr-vowels']!.exposures.values
            .every((exposure) =>
                exposure.assistance.contains(AssistanceFlag.answerRevealed)),
        isTrue);
  });

  testWidgets('legacy review finishes without recording completion',
      (tester) async {
    final store = CourseLearningWidgetStore();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        courseLearningStoreProvider.overrideWithValue(store),
        courseAudioProvider.overrideWithValue(_Audio()),
      ],
      child: MaterialApp(
        home: Builder(
            builder: (context) => TextButton(
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const CourseLessonScreen(
                      lessonId: 'en-fr-vowels',
                      review: true,
                    ),
                  )),
                  child: const Text('Open review'),
                )),
      ),
    ));
    await tester.tap(find.text('Open review'));
    await tester.pumpAndSettle();
    for (var index = 0; index < 4; index++) {
      final sound = ['i', 'o', 'i', 'o'][index];
      await tester.scrollUntilVisible(find.text('Listen to French word'), -200);
      await tester.tap(find.text('Listen to French word'));
      await _settle(tester);
      await tester.tap(find.text('/$sound/'));
      await _settle(tester);
      await tester.scrollUntilVisible(
          find.text(index == 3 ? 'Finish' : 'Next word'), 200);
      await tester.tap(find.text(index == 3 ? 'Finish' : 'Next word'));
      await _settle(tester);
    }
    await tester.pumpAndSettle();
    expect(find.text('Open review'), findsOneWidget);
    expect(store.committedState.history.expand((batch) => batch.attempts),
        hasLength(4));
    expect(store.committedState.completions, isEmpty);
  });
}
