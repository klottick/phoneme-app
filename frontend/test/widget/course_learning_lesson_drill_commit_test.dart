import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_store.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/providers/app_providers.dart';
import 'package:linguist/src/core/services/streak_service.dart';
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

class _HeldStreakService extends StreakService {
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> recordPractice() async {
    if (!entered.isCompleted) entered.complete();
    await release.future;
  }
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
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            courseLearningStoreProvider.overrideWithValue(store),
            courseAudioProvider.overrideWithValue(audio),
          ],
          child: const MaterialApp(
            home: CourseLessonScreen(lessonId: 'en-fr-vowels'),
          ),
        ),
      );
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
            .widget<FilledButton>(
              find.ancestor(
                of: find.text('Next word'),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      final failed = store.submitted.last;
      expect(failed.action, isA<ChooseSound>());

      store.failingActions.clear();
      await tester.tap(find.text('Retry saving'));
      await _settle(tester);
      expect(store.submitted.last, same(failed));
      expect(store.committedState.history, hasLength(1));
      expect(store.committedState.history.single.attempts, hasLength(1));
    },
  );

  testWidgets('lesson reference cannot replace a failed answer command', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = CourseLearningWidgetStore();
    store.failingActions.add(ChooseSound);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(store),
          courseAudioProvider.overrideWithValue(_Audio()),
        ],
        child: const MaterialApp(
          home: CourseLessonScreen(lessonId: 'en-fr-vowels'),
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(find.text('Listen to French word'));
    await _settle(tester);
    await tester.tap(find.text('/i/'));
    await _settle(tester);
    final failed = store.submitted.singleWhere(
      (command) => command.action is ChooseSound,
    );
    expect(failed.action, isA<ChooseSound>());
    expect(find.textContaining('could not be saved'), findsOneWidget);

    await tester.ensureVisible(find.text('Word reference'));
    await tester.tap(find.text('Word reference'));
    await _settle(tester);

    expect(
      find.text('lit /li/'),
      findsNothing,
      reason: 'answers must not be exposed before assistance is committed',
    );
    expect(
      store.submitted.where((command) => command.action is ObserveAssistance),
      isEmpty,
      reason: 'reference observation must not replace the failed answer',
    );
    expect(store.submitted.where((command) => command.action is ChooseSound), [
      same(failed),
    ]);
    expect(store.committedState.history, isEmpty);

    store.failingActions.clear();
    await tester.ensureVisible(find.text('Retry saving'));
    await tester.tap(find.text('Retry saving'));
    await _settle(tester);
    expect(store.submitted.last, same(failed));
    expect(store.committedState.history.single.attempts, hasLength(1));
  });

  testWidgets(
    'competing lesson answer requires explicit committed-state reload',
    (tester) async {
      final store = CourseLearningWidgetStore();
      final audio = _Audio();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            courseLearningStoreProvider.overrideWithValue(store),
            courseAudioProvider.overrideWithValue(audio),
          ],
          child: const MaterialApp(
            home: CourseLessonScreen(lessonId: 'en-fr-vowels'),
          ),
        ),
      );
      await _settle(tester);

      final committed = store.committedState;
      final competing = store.prepare(
        state: committed,
        activityId: 'lesson:en-fr-vowels',
        action: ChooseSound(
          selectedSound: 'i',
          audioSource: AttemptAudioSource.pendingRecording,
        ),
      );
      await store.submit(competing);

      await tester.tap(find.text('Listen to French word'));
      await _settle(tester);
      await tester.tap(find.text('/i/'));
      await _settle(tester);
      expect(find.text('Retry saving'), findsNothing);
      expect(find.text('Reload saved progress'), findsOneWidget);
      expect(store.committedState.history, hasLength(1));

      await tester.tap(find.text('Reload saved progress'));
      await _settle(tester);
      expect(
        store.retryLoadCalls,
        0,
        reason: 'a slot conflict reloads current state, not quarantine repair',
      );
      expect(store.loadCalls, 2);
      expect(store.committedState.history.single.attempts, hasLength(1));
      expect(
        (store.committedState.activities['lesson:en-fr-vowels']!.snapshot
                as LegacyLessonCheckpoint)
            .selectedSound,
        'i',
      );
      await tester.scrollUntilVisible(find.text('Next word'), 200);
      expect(
        find.text('Next word'),
        findsOneWidget,
        reason: 'the competing committed answer is shown after reload',
      );
    },
  );

  testWidgets('invalid lesson command is not reported as an offline save', (
    tester,
  ) async {
    final store = CourseLearningWidgetStore()
      ..actionFailures[ChooseSound] = const LearningInvalidCommandException();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(store),
          courseAudioProvider.overrideWithValue(_Audio()),
        ],
        child: const MaterialApp(
          home: CourseLessonScreen(lessonId: 'en-fr-vowels'),
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(find.text('Listen to French word'));
    await _settle(tester);
    await tester.tap(find.text('/i/'));
    await _settle(tester);

    expect(find.text('Retry saving'), findsNothing);
    expect(find.text('Reload saved progress'), findsOneWidget);
    expect(find.textContaining('could not be saved'), findsNothing);
    expect(store.committedState.history, isEmpty);
  });

  testWidgets('unavailable drill answer requires retry loading', (
    tester,
  ) async {
    final store = CourseLearningWidgetStore()
      ..actionFailures[ChooseDrillWord] = const LearningUnavailableException();
    final audio = _Audio();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(store),
          courseAudioProvider.overrideWithValue(audio),
        ],
        child: const MaterialApp(home: DrillScreen()),
      ),
    );
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await _settle(tester);
    await tester.tap(find.text(audio.spoken.single == 'tu' ? 'tu' : 'roue'));
    await _settle(tester);

    expect(find.text('Retry saving'), findsNothing);
    expect(find.text('Retry loading'), findsOneWidget);
    await tester.tap(find.text('Retry loading'));
    await _settle(tester);
    expect(store.retryLoadCalls, 1);
    expect(store.committedState.history, isEmpty);
    expect(
      store.committedState.activities['drill:minimal-pairs']!.snapshot,
      isA<DrillCheckpoint>(),
    );
    expect(find.text('Item 1'), findsOneWidget);
    expect(
      audio.spoken,
      hasLength(1),
      reason: 'recovery must not restore the failed answer hearing',
    );
  });

  testWidgets('invalid drill command requires reload, not save retry', (
    tester,
  ) async {
    final store = CourseLearningWidgetStore()
      ..actionFailures[ChooseDrillWord] =
          const LearningInvalidCommandException();
    final audio = _Audio();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(store),
          courseAudioProvider.overrideWithValue(audio),
        ],
        child: const MaterialApp(home: DrillScreen()),
      ),
    );
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await _settle(tester);
    await tester.tap(find.text(audio.spoken.single == 'tu' ? 'tu' : 'roue'));
    await _settle(tester);

    expect(find.text('Retry saving'), findsNothing);
    expect(find.text('Reload saved progress'), findsOneWidget);
    expect(store.committedState.history, isEmpty);
    await tester.tap(find.text('Reload saved progress'));
    await _settle(tester);
    expect(store.loadCalls, 2);
    expect(find.text('Item 1'), findsOneWidget);
  });

  testWidgets('competing drill answer requires explicit saved-state reload', (
    tester,
  ) async {
    final store = CourseLearningWidgetStore();
    final audio = _Audio();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(store),
          courseAudioProvider.overrideWithValue(audio),
        ],
        child: const MaterialApp(home: DrillScreen()),
      ),
    );
    await _settle(tester);
    final competing = store.prepare(
      state: store.committedState,
      activityId: 'drill:minimal-pairs',
      action: ChooseDrillWord(
        selectedWord: 'tu',
        audioSource: AttemptAudioSource.pendingRecording,
      ),
    );
    await store.submit(competing);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await _settle(tester);
    await tester.tap(find.text(audio.spoken.single == 'tu' ? 'tu' : 'roue'));
    await _settle(tester);

    expect(find.text('Retry saving'), findsNothing);
    expect(find.text('Reload saved progress'), findsOneWidget);
    expect(store.committedState.history, hasLength(1));
    await tester.tap(find.text('Reload saved progress'));
    await _settle(tester);
    expect(store.retryLoadCalls, 0);
    expect(store.loadCalls, 2);
    expect(find.text('Item 2'), findsOneWidget);
    expect(
      store.committedState.history,
      hasLength(1),
      reason: 'the stale answer must not receive a second credit',
    );
  });

  testWidgets('drill answer retry credits only after one committed retry', (
    tester,
  ) async {
    final store = CourseLearningWidgetStore();
    store.failingActions.add(ChooseDrillWord);
    final audio = _Audio();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(store),
          courseAudioProvider.overrideWithValue(audio),
        ],
        child: const MaterialApp(home: DrillScreen()),
      ),
    );
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

  testWidgets('failed drill answer blocks replay and reanswer until retry', (
    tester,
  ) async {
    final store = CourseLearningWidgetStore();
    store.failingActions.add(ChooseDrillWord);
    final audio = _Audio();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(store),
          courseAudioProvider.overrideWithValue(audio),
        ],
        child: const MaterialApp(home: DrillScreen()),
      ),
    );
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await _settle(tester);
    final choice = audio.spoken.single == 'tu' ? 'tu' : 'roue';
    await tester.tap(find.text(choice));
    await _settle(tester);
    final failed = store.submitted.singleWhere(
      (command) => command.action is ChooseDrillWord,
    );
    expect(failed.action, isA<ChooseDrillWord>());

    final play = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Play audio'),
        matching: find.byType(IconButton),
      ),
    );
    expect(
      play.onPressed,
      isNull,
      reason: 'a pending answer cannot be replaced by playback/re-answer',
    );
    await tester.tap(
      find.ancestor(
        of: find.byTooltip('Play audio'),
        matching: find.byType(IconButton),
      ),
    );
    await _settle(tester);
    await tester.tap(find.text(audio.spoken.last == 'tu' ? 'tu' : 'roue'));
    await _settle(tester);
    expect(
      store.prepared.where((command) => command.action is ChooseDrillWord),
      hasLength(1),
    );
    expect(
      store.submitted.where((command) => command.action is ChooseDrillWord),
      [same(failed)],
    );
    expect(store.committedState.history, isEmpty);
  });

  testWidgets('End Session cannot replace a failed drill answer', (
    tester,
  ) async {
    final store = CourseLearningWidgetStore();
    store.failingActions.add(ChooseDrillWord);
    final audio = _Audio();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(store),
          courseAudioProvider.overrideWithValue(audio),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DrillScreen()),
              ),
              child: const Text('Open drill'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open drill'));
    await tester.pumpAndSettle();
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await _settle(tester);
    await tester.tap(find.text(audio.spoken.single == 'tu' ? 'tu' : 'roue'));
    await _settle(tester);
    final failed = store.submitted.singleWhere(
      (command) => command.action is ChooseDrillWord,
    );

    await tester.tap(find.text('End Session'));
    await _settle(tester);
    expect(find.text('Minimal Pair Drill'), findsOneWidget);
    expect(
      store.submitted.where((command) => command.action is EndDrill),
      isEmpty,
    );
    expect(store.submitted, [
      ...store.submitted.where((command) => command.action is StartLearningRun),
      same(failed),
    ]);
    expect(store.committedState.history, isEmpty);
  });

  testWidgets('reopen resumes both activities without restoring hearing', (
    tester,
  ) async {
    final lessonStore = CourseLearningWidgetStore();
    final lessonAudio = _Audio();
    Future<void> pumpLesson() async => tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(lessonStore),
          courseAudioProvider.overrideWithValue(lessonAudio),
        ],
        child: const MaterialApp(
          home: CourseLessonScreen(lessonId: 'en-fr-vowels'),
        ),
      ),
    );
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
          .widget<OutlinedButton>(
            find.ancestor(
              of: find.text('/o/'),
              matching: find.byType(OutlinedButton),
            ),
          )
          .onPressed,
      isNull,
    );

    final drillStore = CourseLearningWidgetStore();
    final drillAudio = _Audio();
    Future<void> pumpDrill() async => tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(drillStore),
          courseAudioProvider.overrideWithValue(drillAudio),
        ],
        child: const MaterialApp(home: DrillScreen()),
      ),
    );
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
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('rue'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('A to B to A does not publish a delayed old drill commit', (
    tester,
  ) async {
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
    final container = ProviderContainer(
      overrides: [
        selectedStore.overrideWith((ref) {
          ref.watch(_storeEpoch);
          return activeStore;
        }),
        courseLearningStoreProvider.overrideWith(
          (ref) => ref.watch(selectedStore),
        ),
        courseAudioProvider.overrideWithValue(audio),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DrillScreen()),
      ),
    );
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await _settle(tester);
    await tester.tap(find.text('tu'));
    await tester.pump();
    expect(
      oldA.submitted.where((command) => command.action is ChooseDrillWord),
      hasLength(1),
    );

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

  testWidgets('new drill owner answers while old answer is held and settling', (
    tester,
  ) async {
    final oldStore = CourseLearningWidgetStore();
    final newStore = CourseLearningWidgetStore();
    final oldGate = Completer<void>();
    final newGate = Completer<void>();
    oldStore.actionGates[ChooseDrillWord] = oldGate;
    newStore.actionGates[ChooseDrillWord] = newGate;
    final audio = _Audio();
    var activeStore = oldStore;
    final selectedStore = Provider<CourseLearningStore>((ref) {
      ref.watch(_storeEpoch);
      return activeStore;
    });
    final container = ProviderContainer(
      overrides: [
        selectedStore.overrideWith((ref) {
          ref.watch(_storeEpoch);
          return activeStore;
        }),
        courseLearningStoreProvider.overrideWith(
          (ref) => ref.watch(selectedStore),
        ),
        courseAudioProvider.overrideWithValue(audio),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DrillScreen()),
      ),
    );
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await _settle(tester);
    await tester.tap(find.text(audio.spoken.single == 'tu' ? 'tu' : 'roue'));
    await tester.pump();
    expect(
      oldStore.submitted.where((command) => command.action is ChooseDrillWord),
      hasLength(1),
    );

    activeStore = newStore;
    container.read(_storeEpoch.notifier).state++;
    await _settle(tester);
    final newOwnerPlay = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Play audio'),
        matching: find.byType(IconButton),
      ),
    );
    expect(
      newOwnerPlay.onPressed,
      isNotNull,
      reason: 'the replacement owner must not inherit the old transition guard',
    );

    await tester.tap(find.byIcon(Icons.play_arrow));
    await _settle(tester);
    await tester.tap(find.text(audio.spoken.last == 'tu' ? 'tu' : 'roue'));
    await tester.pump();
    final newAnswer = newStore.submitted.singleWhere(
      (command) => command.action is ChooseDrillWord,
    );

    oldGate.complete();
    await _settle(tester);
    expect(
      newStore.submitted.where((command) => command.action is ChooseDrillWord),
      [same(newAnswer)],
      reason:
          'settling the old operation cannot replace the new pending answer',
    );
    expect(newStore.committedState.history, isEmpty);

    newGate.complete();
    await _settle(tester);
    expect(oldStore.committedState.history, hasLength(1));
    expect(newStore.committedState.history, hasLength(1));
    expect(find.text('Item 2'), findsOneWidget);
  });

  testWidgets('held old-owner drill finish cannot pop or report on new owner', (
    tester,
  ) async {
    final oldStore = CourseLearningWidgetStore();
    final initial = await oldStore.load();
    final start = await oldStore.submit(
      oldStore.prepare(
        state: initial,
        activityId: 'drill:minimal-pairs',
        action: StartLearningRun(options: RunOptions()),
      ),
    );
    await oldStore.submit(
      oldStore.prepare(
        state: start.state,
        activityId: 'drill:minimal-pairs',
        action: const EndDrill(),
      ),
    );
    final newStore = CourseLearningWidgetStore();
    final streak = _HeldStreakService();
    var activeStore = oldStore;
    final selectedStore = Provider<CourseLearningStore>((ref) {
      ref.watch(_storeEpoch);
      return activeStore;
    });
    final container = ProviderContainer(
      overrides: [
        selectedStore.overrideWith((ref) {
          ref.watch(_storeEpoch);
          return activeStore;
        }),
        courseLearningStoreProvider.overrideWith(
          (ref) => ref.watch(selectedStore),
        ),
        streakServiceProvider.overrideWithValue(streak),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DrillScreen(),
                    ),
                  ),
                  child: const Text('Open drill'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open drill'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End Session'));
    await tester.pump();
    await streak.entered.future;

    activeStore = newStore;
    container.read(_storeEpoch.notifier).state++;
    await tester.pumpAndSettle();
    expect(find.text('Item 1'), findsOneWidget);
    expect(newStore.committedState.history, isEmpty);

    streak.release.complete();
    await tester.pumpAndSettle();
    expect(
      find.text('Item 1'),
      findsOneWidget,
      reason: 'the old owner completion must not pop the replacement route',
    );
    expect(find.text('Open drill'), findsNothing);
    expect(
      find.textContaining('Session complete!'),
      findsNothing,
      reason: 'the old result must not be shown with the new owner counters',
    );
    expect(newStore.committedState.history, isEmpty);
  });

  testWidgets('typed repository persists an answer through SQLite', (
    tester,
  ) async {
    final harness = CourseLearningSqlTestHarness();
    final store = harness.store;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(store),
          courseAudioProvider.overrideWithValue(_Audio()),
        ],
        child: const MaterialApp(
          home: CourseLessonScreen(lessonId: 'en-fr-vowels'),
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(find.text('Listen to French word'));
    await _settle(tester);
    await tester.tap(find.text('/i/'));
    await _settle(tester);
    final committed = await store.load();
    expect(committed.history.single.attempts.single.correct, isTrue);
    expect(
      committed.activities['lesson:en-fr-vowels']!.snapshot,
      isA<LegacyLessonCheckpoint>(),
    );
  });

  testWidgets(
    'corrupt legacy and drill snapshots stay unavailable until retry',
    (tester) async {
      final lessonStore = CourseLearningWidgetStore()
        ..loadHandler = (call) async {
          if (call == 1) throw const LearningCorruptException();
          return CourseLearningWidgetStore().committedState;
        };
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            courseLearningStoreProvider.overrideWithValue(lessonStore),
          ],
          child: const MaterialApp(
            home: CourseLessonScreen(lessonId: 'en-fr-vowels'),
          ),
        ),
      );
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
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            courseLearningStoreProvider.overrideWithValue(drillStore),
          ],
          child: const MaterialApp(home: DrillScreen()),
        ),
      );
      await _settle(tester);
      expect(find.textContaining('unavailable'), findsOneWidget);
      expect(drillStore.prepareCalls, 0);
      expect(drillStore.submitted, isEmpty);
      await tester.tap(find.text('Retry loading'));
      await _settle(tester);
      expect(drillStore.retryLoadCalls, 1);
      expect(drillStore.submitted.single.action, isA<StartLearningRun>());
    },
  );

  testWidgets(
    'opening lesson reference persists answerRevealed for all contexts',
    (tester) async {
      final store = CourseLearningWidgetStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            courseLearningStoreProvider.overrideWithValue(store),
            courseAudioProvider.overrideWithValue(_Audio()),
          ],
          child: const MaterialApp(
            home: CourseLessonScreen(lessonId: 'en-fr-vowels'),
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('Word reference'));
      await _settle(tester);
      final slot = store.committedState.activities['lesson:en-fr-vowels']!;
      expect(slot.exposures, isNotEmpty);
      expect(
        slot.exposures.values.every(
          (exposure) =>
              exposure.assistance.contains(AssistanceFlag.answerRevealed),
        ),
        isTrue,
      );
      await tester.tap(find.text('Word reference'));
      await _settle(tester);
      expect(
        store.committedState.activities['lesson:en-fr-vowels']!.exposures.values
            .every(
              (exposure) =>
                  exposure.assistance.contains(AssistanceFlag.answerRevealed),
            ),
        isTrue,
      );
    },
  );

  testWidgets('legacy review finishes without recording completion', (
    tester,
  ) async {
    final store = CourseLearningWidgetStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(store),
          courseAudioProvider.overrideWithValue(_Audio()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CourseLessonScreen(
                    lessonId: 'en-fr-vowels',
                    review: true,
                  ),
                ),
              ),
              child: const Text('Open review'),
            ),
          ),
        ),
      ),
    );
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
        find.text(index == 3 ? 'Finish' : 'Next word'),
        200,
      );
      await tester.tap(find.text(index == 3 ? 'Finish' : 'Next word'));
      await _settle(tester);
    }
    await tester.pumpAndSettle();
    expect(find.text('Open review'), findsOneWidget);
    expect(
      store.committedState.history.expand((batch) => batch.attempts),
      hasLength(4),
    );
    expect(store.committedState.completions, isEmpty);
  });
}
