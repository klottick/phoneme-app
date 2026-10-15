import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:linguist/src/app.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_codec.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/features/course/course_lesson_screen.dart';
import 'package:linguist/src/features/course/discovery_lesson_screen.dart';
import 'package:linguist/src/features/course/discovery_section_view.dart';
import 'package:linguist/src/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import '../support/course_learning_widget_store.dart';

class FakeAudio implements CourseAudio {
  FakeAudio({this.fail = false, this.hold = false, this.cancel = false});
  bool fail;
  bool hold;
  bool cancel;
  int speaks = 0;
  int stops = 0;
  final List<String> spoken = [];

  @override
  Future<void> speak(String word) async {
    speaks++;
    spoken.add(word);
    if (cancel) throw const CourseAudioCancelledException();
    if (fail) throw StateError('no french voice');
    if (hold) {
      await Completer<void>().future; // Never completes.
    }
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

/// Audio whose playback future is held open by a [Completer] so that a late
/// (real) completion can be delivered after disposal, suspension, or owner
/// replacement; unlike [FakeAudio]'s `hold` it actually continues.
class GateAudio extends FakeAudio {
  final Completer<void> gate = Completer<void>();

  @override
  Future<void> speak(String word) {
    spoken.add(word);
    return gate.future;
  }
}

class FailablePreferences extends InMemorySharedPreferencesStore {
  FailablePreferences() : super.withData(const {});

  bool failWrites = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (failWrites) {
      failWrites = false;
      return Future.value(false);
    }
    return super.setValue(valueType, key, value);
  }
}

final List<String> expectedSounds =
    frenchUySection.items.map((item) => item.expectedSound).toList();
final List<String> discoveryItemIds =
    frenchUySection.items.map((item) => item.id).toList();

void seedStoreSession(
    CourseLearningWidgetStore store, LessonSectionSession session) {
  store.seedSession(session);
}

LessonSectionSession? parseStoreSession(CourseLearningWidgetStore store) =>
    store.discoverySession;

Map<String, dynamic>? sessionJson(CourseLearningWidgetStore store) =>
    store.discoverySession?.toJson();

bool hasCompletion(CourseLearningWidgetStore store) =>
    store.committedState.completions
        .any((completion) => completion.lessonId == 'en-fr-u-y');

int actionCount(CourseLearningWidgetStore store, Type actionType) =>
    store.submitted
        .where((command) => command.action.runtimeType == actionType)
        .length;

void failAction(CourseLearningWidgetStore store, Type action, bool fail) {
  if (fail) {
    store.failingActions.add(action);
  } else {
    store.failingActions.remove(action);
  }
}

Widget pumpLesson(
  WidgetTester tester,
  FakeAudio audio,
  CourseLearningWidgetStore? store, {
  bool review = false,
  LessonPolicy? policy,
}) {
  final List<Override> overrides = [
    courseAudioProvider.overrideWithValue(audio),
  ];
  if (store != null) {
    overrides.add(courseLearningStoreProvider.overrideWithValue(store));
  }
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: DiscoveryLessonScreen(
        lessonId: 'en-fr-u-y',
        review: review,
        policy: policy,
      ),
    ),
  );
}

Future<void> advance(WidgetTester tester, {required bool last}) async {
  await tester.tap(find.text(last ? 'See section explanation' : 'Next word'));
  await tester.pumpAndSettle();
}

/// Suspends (forcing the one frame the engine would not schedule while
/// suspended) and then resumes.
Future<void> suspendResume(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.scheduleForcedFrame();
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
}

void main() {
  final section = frenchUySection;
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('first pass', () {
    testWidgets(
        'full ten-item pass shows immediate feedback, no early '
        'explanation, debrief at 10/10, and completes once', (tester) async {
      final audio = FakeAudio();
      final store = CourseLearningWidgetStore();
      await tester.pumpWidget(pumpLesson(tester, audio, store));
      await tester.pumpAndSettle();
      expect(find.text('Item 1 of 10'), findsOneWidget);
      for (var i = 0; i < section.items.length; i++) {
        expect(find.text(section.explanation), findsNothing);
        await tester.tap(find.text('Listen to the word'));
        await tester.pumpAndSettle();
        expect(audio.spoken.last, section.items[i].word);
        await tester.tap(find.text('/${expectedSounds[i]}/'));
        await tester.pumpAndSettle();
        expect(find.text('Correct'), findsOneWidget);
        expect(find.text(section.explanation), findsNothing);
        await advance(tester, last: i == section.items.length - 1);
      }
      expect(find.text('Section debrief'), findsOneWidget);
      expect(find.text('You got 10 of 10 correct.'), findsOneWidget);
      expect(find.text('Passing needs 8 of 10 correct.'), findsOneWidget);
      expect(find.text('Every word is correct now.'), findsOneWidget);
      expect(find.text('Review mistakes'), findsNothing);
      await tester.tap(find.text('Finish section'));
      await tester.pumpAndSettle();
      expect(hasCompletion(store), isTrue);
      expect((parseStoreSession(store)?.attemptCount ?? 0), 10);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'failing score still debriefs, mistake-only review, then '
        'completion', (tester) async {
      final audio = FakeAudio();
      final store = CourseLearningWidgetStore();
      await tester.pumpWidget(pumpLesson(tester, audio, store));
      await tester.pumpAndSettle();
      // Correct: the /u/ words (tout, rouge, vous, doux, loup). Wrong: the
      // /y/ words (tu, rue, lune, jus, mur).
      const List<bool> pass = [
        true,
        false,
        true,
        false,
        true,
        false,
        true,
        false,
        true,
        false
      ];
      for (var i = 0; i < section.items.length; i++) {
        await tester.tap(find.text('Listen to the word'));
        await tester.pumpAndSettle();
        final String pick = pass[i]
            ? expectedSounds[i]
            : (expectedSounds[i] == 'u' ? 'y' : 'u');
        await tester.tap(find.text('/$pick/'));
        await tester.pumpAndSettle();
        expect(find.text(pass[i] ? 'Correct' : 'Not yet'), findsOneWidget);
        await advance(tester, last: i == section.items.length - 1);
      }
      expect(find.text('You got 5 of 10 correct.'), findsOneWidget);
      expect(find.text('Passing needs 8 of 10 correct.'), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Finish section'))
              .onPressed,
          isNull,
          reason: 'Finish must be unavailable below the threshold');
      for (final word in ['tu', 'rue', 'lune', 'jus', 'mur']) {
        expect(find.text(word), findsOneWidget);
      }
      // Review round: only the five unresolved words, in original order.
      await tester.tap(find.text('Review mistakes'));
      await tester.pumpAndSettle();
      final List<String> unresolved = ['tu', 'rue', 'lune', 'jus', 'mur'];
      for (var i = 0; i < unresolved.length; i++) {
        await tester.tap(find.text('Listen to the word'));
        await tester.pumpAndSettle();
        expect(audio.spoken.last, unresolved[i],
            reason: 'review must follow the unresolved order');
        await tester.tap(find.text('/y/')); // the expected sound for all five
        await tester.pumpAndSettle();
        expect(find.text('Correct'), findsOneWidget);
        await advance(tester, last: i == unresolved.length - 1);
      }
      expect(find.text('You got 10 of 10 correct.'), findsOneWidget);
      await tester.tap(find.text('Finish section'));
      await tester.pumpAndSettle();
      expect(hasCompletion(store), isTrue);
      expect((parseStoreSession(store)?.attemptCount ?? 0), 15);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a wrong choice is recorded against the expected sound',
        (tester) async {
      final store = CourseLearningWidgetStore();
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      // 'tout' expects /u/; picking /y/ is wrong but must still be recorded
      // for the expected sound (the store rejects the choice sound).
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/y/'));
      await tester.pumpAndSettle();
      expect(find.text('Not yet'), findsOneWidget);
      expect(parseStoreSession(store)!.latestAnswers['tout'], false);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('resume and restore', () {
    testWidgets('resumes an in-progress first pass without replaying items',
        (tester) async {
      final store = CourseLearningWidgetStore();
      final session =
          LessonSectionSession(itemIds: discoveryItemIds, sessionId: 'seed');
      session.submit(true);
      session.advance();
      session.submit(false);
      session.advance();
      session.submit(true);
      session.advance();
      seedStoreSession(store, session);
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      expect(find.text('Item 4 of 10'), findsOneWidget);
      expect(choicesEnabled(tester), isFalse,
          reason: 'a resumed unsubmitted item needs a fresh listen');
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      expect(choicesEnabled(tester), isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('resumes the debrief and finishes from the saved state',
        (tester) async {
      final store = CourseLearningWidgetStore();
      final session =
          LessonSectionSession(itemIds: discoveryItemIds, sessionId: 'seed');
      for (var i = 0; i < 10; i++) {
        session.submit(true);
        session.advance();
      }
      seedStoreSession(store, session);
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      expect(find.text('Section debrief'), findsOneWidget);
      expect(find.text('You got 10 of 10 correct.'), findsOneWidget);
      await tester.tap(find.text('Finish section'));
      await tester.pumpAndSettle();
      expect(hasCompletion(store), isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('resumes a review round and completes after mastering it',
        (tester) async {
      final audio = FakeAudio();
      final store = CourseLearningWidgetStore();
      final session =
          LessonSectionSession(itemIds: discoveryItemIds, sessionId: 'seed');
      const firstPass = [
        true,
        false,
        true,
        true,
        true,
        true,
        true,
        false,
        true,
        true
      ];
      for (final bool outcome in firstPass) {
        session.submit(outcome);
        session.advance();
      }
      session.reviewMistakes();
      seedStoreSession(store, session);
      await tester.pumpWidget(pumpLesson(tester, audio, store));
      await tester.pumpAndSettle();
      expect(find.textContaining('Review round 2'), findsOneWidget);
      final List<String> unresolved = ['tu', 'jus'];
      for (var i = 0; i < unresolved.length; i++) {
        await tester.tap(find.text('Listen to the word'));
        await tester.pumpAndSettle();
        expect(audio.spoken.last, unresolved[i]);
        await tester.tap(find.text('/y/'));
        await tester.pumpAndSettle();
        expect(find.text('Correct'), findsOneWidget);
        await advance(tester, last: i == unresolved.length - 1);
      }
      expect(find.text('You got 10 of 10 correct.'), findsOneWidget);
      await tester.tap(find.text('Finish section'));
      await tester.pumpAndSettle();
      expect(hasCompletion(store), isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'unsupported saved data stays unavailable and requires explicit retry',
        (tester) async {
      final store = CourseLearningWidgetStore()
        ..failLoad = true
        ..loadFailure = const LearningUnsupportedVersionException();
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be loaded'), findsOneWidget);
      expect(find.text('Retry loading'), findsOneWidget);
      expect(store.submitCalls, 0,
          reason: 'unavailable data must not trigger an automatic new run');
      store.failLoad = false;
      await tester.tap(find.text('Retry loading'));
      await tester.pumpAndSettle();
      expect(find.text('Item 1 of 10'), findsOneWidget);
      expect(store.submitCalls, 1,
          reason: 'fresh state starts only after an explicit retry');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('load failure offers retry, then restores the session',
        (tester) async {
      final store = CourseLearningWidgetStore();
      final session =
          LessonSectionSession(itemIds: discoveryItemIds, sessionId: 'seed');
      session.submit(true);
      seedStoreSession(store, session);
      store.failLoad = true;
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be loaded'), findsOneWidget);
      expect(find.text('Retry loading'), findsOneWidget);
      store.failLoad = false;
      await tester.tap(find.text('Retry loading'));
      await tester.pumpAndSettle();
      expect(find.text('Correct'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('saved policy is authoritative on resume', (tester) async {
      final store = CourseLearningWidgetStore();
      final session = LessonSectionSession(
          itemIds: discoveryItemIds,
          sessionId: 'seed',
          policy: LessonPolicy(completionThresholdPercent: 90));
      for (var i = 0; i < 10; i++) {
        session.submit(i != 4);
        session.advance();
      }
      seedStoreSession(store, session);
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      expect(find.text('Passing needs 9 of 10 correct.'), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Finish section'))
              .onPressed,
          isNot(isNull),
          reason: '9 of 10 meets the saved 90% threshold');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('fresh sessions carry the configured policy when saved',
        (tester) async {
      final store = CourseLearningWidgetStore();
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store,
          policy: LessonPolicy(completionThresholdPercent: 70)));
      await tester.pumpAndSettle();
      for (var i = 0; i < 10; i++) {
        await tester.tap(find.text('Listen to the word'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('/${expectedSounds[i]}/'));
        await tester.pumpAndSettle();
        await advance(tester, last: i == 9);
      }
      expect(
          (sessionJson(store)!['policy'] as Map)['completionThresholdPercent'],
          70);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'resume during initial load must not leave a permanent '
        'spinner', (tester) async {
      final store = CourseLearningWidgetStore()..loadGate = Completer<void>();
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pump();
      await suspendResume(tester);
      store.loadGate!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Item 1 of 10'), findsOneWidget,
          reason: 'resume must re-drive the interrupted initial load');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'an initial load that completes while suspended still '
        'recovers on resume', (tester) async {
      final store = CourseLearningWidgetStore()..loadGate = Completer<void>();
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.scheduleForcedFrame();
      await tester.pump();
      store.loadGate!.complete(); // the load completes while suspended
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Item 1 of 10'), findsNothing,
          reason: 'a suspended load must not publish to the UI');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Item 1 of 10'), findsOneWidget,
          reason: 'resume must re-drive the interrupted load');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'double retry loading must not allow a late load to '
        'erase feedback', (tester) async {
      final first = Completer<CourseLearningState>();
      final second = Completer<CourseLearningState>();
      final store = CourseLearningWidgetStore()
        ..loadHandler = (call) => call == 1
            ? Future.error(const LearningUnavailableException())
            : (call == 2 ? first.future : second.future);
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      expect(find.text('Retry loading'), findsOneWidget);
      await tester.tap(find.text('Retry loading'));
      await tester.tap(find.text('Retry loading')); // before redraw
      await tester.pump();
      first.complete(store.committedState);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/u/'));
      await tester.pumpAndSettle();
      expect(find.text('Correct'), findsOneWidget);
      second.complete(store.committedState);
      await tester.pumpAndSettle();
      expect(find.text('Correct'), findsOneWidget,
          reason: 'a late duplicate load result must not replace an '
              'answered session');
      expect(store.loadCalls, 2,
          reason: 'initial failure plus one coalesced retry');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'resumed recovery re-drives a hung load without waiting '
        'on it', (tester) async {
      final store = CourseLearningWidgetStore()..loadGate = Completer<void>();
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pump(); // initial load in flight, still hung
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.scheduleForcedFrame();
      await tester.pump();
      // Resume while the pre-suspension load is still hung: recovery must
      // orphan and re-drive the load, not serialize behind it forever.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Item 1 of 10'), findsNothing,
          reason: 'the hung load has not settled yet in either generation');
      store.loadGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Item 1 of 10'), findsOneWidget,
          reason: 'the re-driven load must still settle the UI');
      expect(store.loadCalls, 2,
          reason: 'one initial plus one recovery load, no duplicates');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('save failures and retries', () {
    testWidgets('answer save failure keeps the same attempt, retried once',
        (tester) async {
      final store = CourseLearningWidgetStore();
      failAction(store, ChooseSound, true);
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/u/'));
      await tester.pumpAndSettle();
      expect(find.text('Correct'), findsOneWidget,
          reason: 'feedback is immediate while persistence is pending');
      expect(find.textContaining('could not be saved'), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Next word'))
              .onPressed,
          isNull,
          reason: 'Next stays disabled until the save succeeds');
      expect(parseStoreSession(store)!.attemptCount, 0,
          reason: 'the failed answer must not update committed attempts');
      failAction(store, ChooseSound, false);
      await tester.tap(find.text('Retry saving'));
      await tester.pumpAndSettle();
      expect(sessionJson(store), isNotNull);
      expect(parseStoreSession(store)!.attemptCount, 1,
          reason: 'the failed answer is recorded exactly once');
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Next word'))
              .onPressed,
          isNot(isNull));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('advance save failure keeps the saved item; retry advances',
        (tester) async {
      final store = CourseLearningWidgetStore();
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/u/'));
      await tester.pumpAndSettle();
      expect(parseStoreSession(store)!.position, 0);
      expect(parseStoreSession(store)!.answered, isTrue,
          reason: 'the answer itself saved before the advance attempt');
      failAction(store, AdvanceLesson, true);
      await tester.tap(find.text('Next word'));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be saved'), findsOneWidget);
      expect(find.text('Item 1 of 10'), findsOneWidget,
          reason: 'the UI must not move past the saved item');
      expect(parseStoreSession(store)!.position, 0,
          reason: 'a failed advance must not fabricate the new item');
      failAction(store, AdvanceLesson, false);
      await tester.tap(find.text('Retry saving'));
      await tester.pumpAndSettle();
      expect(find.text('Item 2 of 10'), findsOneWidget);
      expect(parseStoreSession(store)!.position, 1);
      expect(parseStoreSession(store)!.answered, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'completion failure leaves no completion; retry completes '
        'exactly once', (tester) async {
      final store = CourseLearningWidgetStore();
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      for (var i = 0; i < 10; i++) {
        await tester.tap(find.text('Listen to the word'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('/${expectedSounds[i]}/'));
        await tester.pumpAndSettle();
        await advance(tester, last: i == 9);
      }
      failAction(store, FinishLearningActivity, true);
      await tester.tap(find.text('Finish section'));
      await tester.pumpAndSettle();
      expect(hasCompletion(store), isFalse,
          reason: 'no completion before the save succeeds');
      expect(find.textContaining('could not be saved'), findsOneWidget);
      expect(find.text('Finish section'), findsOneWidget,
          reason: 'the learner stays on the debrief');
      failAction(store, FinishLearningActivity, false);
      await tester.tap(find.text('Retry saving'));
      await tester.pumpAndSettle();
      expect(hasCompletion(store), isTrue);
      expect(actionCount(store, FinishLearningActivity), 2,
          reason: 'the failed attempt and one successful retry');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('review start failure stays on the debrief; retry resumes',
        (tester) async {
      final store = CourseLearningWidgetStore();
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      for (var i = 0; i < 10; i++) {
        await tester.tap(find.text('Listen to the word'));
        await tester.pumpAndSettle();
        final String pick =
            i < 8 ? expectedSounds[i] : (expectedSounds[i] == 'u' ? 'y' : 'u');
        await tester.tap(find.text('/$pick/'));
        await tester.pumpAndSettle();
        await advance(tester, last: i == 9);
      }
      failAction(store, ReviewDiscoveryMistakes, true);
      await tester.tap(find.text('Review mistakes'));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be saved'), findsOneWidget);
      expect(sessionJson(store), isNotNull);
      expect(parseStoreSession(store)!.phase, LessonSectionPhase.debrief,
          reason: 'the review round must not publish before its save');
      failAction(store, ReviewDiscoveryMistakes, false);
      await tester.tap(find.text('Retry saving'));
      await tester.pumpAndSettle();
      expect(parseStoreSession(store)!.phase, LessonSectionPhase.exercise);
      expect(parseStoreSession(store)!.queue, ['loup', 'mur']);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('lifecycle and owners', () {
    testWidgets(
        'a save held at dispose commits exactly once and never '
        'touches the disposed screen', (tester) async {
      final audio = GateAudio();
      final store = CourseLearningWidgetStore()
        ..actionGates[ChooseSound] = Completer<void>();
      await tester.pumpWidget(pumpLesson(tester, audio, store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      audio.gate.complete();
      await tester.pumpAndSettle();
      expect(choicesEnabled(tester), isTrue);
      await tester.tap(find.text('/u/'));
      await tester.pump(); // the answer save starts and is held by the gate
      expect(actionCount(store, ChooseSound), 1);
      await tester.pumpWidget(const SizedBox()); // dispose while it is held
      store.actionGates[ChooseSound]!
          .complete(); // the save completes after disposal
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull,
          reason: 'a save completing after disposal must not throw or publish');
      expect(actionCount(store, ChooseSound), 1,
          reason: 'a disposed screen must not resend the save');
      expect((parseStoreSession(store)?.attemptCount ?? 0), 1,
          reason: 'the same-owner save lands exactly once in storage');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'a playback held at dispose cannot unlock or record '
        'anything afterwards', (tester) async {
      final audio = GateAudio();
      final store = CourseLearningWidgetStore();
      await tester.pumpWidget(pumpLesson(tester, audio, store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox()); // dispose with playback held
      audio.gate.complete(); // the real late completion
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull,
          reason: 'a playback completing after disposal must not throw');
      expect(actionCount(store, ChooseSound), 0,
          reason: 'a late playback must not record or enable answers');
      expect(audio.stops, greaterThanOrEqualTo(1));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'in-flight playback cannot unlock choices across '
        'background/resume', (tester) async {
      final audio = GateAudio();
      final store = CourseLearningWidgetStore();
      await tester.pumpWidget(pumpLesson(tester, audio, store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pump(); // playback in flight
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.scheduleForcedFrame();
      await tester.pump();
      audio.gate.complete(); // playback completes while suspended
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(choicesEnabled(tester), isFalse,
          reason: 'a suspended playback completion must not unlock choices');
      expect(actionCount(store, ChooseSound), 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(choicesEnabled(tester), isFalse,
          reason: 'a fresh completed playback is required after resume');
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      expect(choicesEnabled(tester), isTrue,
          reason: 'a fresh completed playback re-enables the choices');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('backgrounding must not abandon a failed answer retry',
        (tester) async {
      final store = CourseLearningWidgetStore()
        ..failingActions.add(ChooseSound);
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/u/'));
      await tester.pumpAndSettle();
      expect(find.text('Retry saving'), findsOneWidget);
      await suspendResume(tester);
      failAction(store, ChooseSound, false);
      final FilledButton next = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Next word'));
      expect(next.onPressed, isNull,
          reason: 'uncommitted answer must not advance after resume');
      expect(find.text('Retry saving'), findsOneWidget,
          reason: 'the failed save intent survives suspension');
      await tester.tap(find.text('Retry saving'));
      await tester.pumpAndSettle();
      expect((parseStoreSession(store)?.attemptCount ?? 0), 1,
          reason: 'the retry records the held answer exactly once');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'a save completing while suspended settles exactly once '
        'on resume', (tester) async {
      final store = CourseLearningWidgetStore()
        ..actionGates[ChooseSound] = Completer<void>();
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/u/'));
      await tester.pump(); // the answer save is in flight
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.scheduleForcedFrame();
      await tester.pump();
      store.actionGates[ChooseSound]!.complete(); // completes while suspended
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Retry saving'), findsNothing,
          reason: 'a suspended completion is neither success nor error UI');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect((parseStoreSession(store)?.attemptCount ?? 0), 1,
          reason: 'resume must settle the save idempotently, exactly once');
      expect(find.text('Correct'), findsOneWidget);
      expect(find.text('Retry saving'), findsNothing,
          reason: 'a settled save must not leave an error behind');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a held answer must stay non-advanceable while suspended',
        (tester) async {
      final store = CourseLearningWidgetStore()
        ..actionGates[ChooseSound] = Completer<void>();
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/u/'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.scheduleForcedFrame();
      await tester.pump();
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Next word'))
              .onPressed,
          isNull,
          reason: 'pending persistence must not masquerade as committed '
              'while suspended');
      store.actionGates[ChooseSound]!.complete();
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'inactive focus changes must not duplicate an in-flight '
        'save', (tester) async {
      final store = CourseLearningWidgetStore()
        ..actionGates[ChooseSound] = Completer<void>();
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/u/'));
      await tester.pump();
      expect(actionCount(store, ChooseSound), 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(actionCount(store, ChooseSound), 1,
          reason: 'no suspension occurred; do not re-run pending action');
      store.actionGates[ChooseSound]!.complete();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('replacing owner must stop old playback immediately',
        (tester) async {
      final audio = GateAudio();
      final ownerA = CourseLearningWidgetStore();
      final ownerB = CourseLearningWidgetStore();
      Widget app(CourseLearningWidgetStore owner) => ProviderScope(
              overrides: [
                courseAudioProvider.overrideWithValue(audio),
                courseLearningStoreProvider.overrideWithValue(owner),
              ],
              child: const MaterialApp(
                  home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y')));
      await tester.pumpWidget(app(ownerA));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pump(); // old-owner playback in flight
      await tester.pumpWidget(app(ownerB));
      await tester.pump();
      expect(audio.stops, greaterThan(0),
          reason: 'owner replacement must stop the old playback');
      audio.gate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(choicesEnabled(tester), isFalse,
          reason: 'old playback must not enable choices');
      expect(find.text('Item 1 of 10'), findsOneWidget,
          reason: 'the replacement owner state must be loaded');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'account provider replacement loads the new owner state '
        'and old in-flight saves cannot touch it', (tester) async {
      final ownerA = CourseLearningWidgetStore();
      final seedA =
          LessonSectionSession(itemIds: discoveryItemIds, sessionId: 'owner-a');
      seedA.submit(true);
      seedA.advance();
      seedA.submit(false);
      seedA.advance();
      seedA.submit(true);
      seedA.advance();
      seedStoreSession(ownerA, seedA);
      ownerA.actionGates[ChooseSound] =
          Completer<void>(); // Holds the pending save open.
      final ownerB =
          CourseLearningWidgetStore(); // This owner has no saved state.
      final audio = FakeAudio();
      await tester.pumpWidget(ProviderScope(
          overrides: [
            courseAudioProvider.overrideWithValue(audio),
            courseLearningStoreProvider.overrideWithValue(ownerA),
          ],
          child: const MaterialApp(
              home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'))));
      await tester.pumpAndSettle();
      expect(find.text('Item 4 of 10'), findsOneWidget);
      // Start an answer against owner A but hold its save open.
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/${expectedSounds[3]}/'));
      await tester.pump();
      // The provider switches owners while the save is pending.
      await tester.pumpWidget(ProviderScope(
          overrides: [
            courseAudioProvider.overrideWithValue(audio),
            courseLearningStoreProvider.overrideWithValue(ownerB),
          ],
          child: const MaterialApp(
              home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'))));
      await tester.pumpAndSettle();
      expect(find.text('Item 1 of 10'), findsOneWidget,
          reason: 'the new owner state must be loaded');
      expect(parseStoreSession(ownerB)!.attemptCount, 0,
          reason: 'the replacement owner receives no old-owner answers');
      // The old owner's pending save may land on its own data, but the UI
      // must keep showing the new owner state.
      ownerA.actionGates[ChooseSound]!.complete();
      await tester.pump();
      final LessonSectionSession aSession = parseStoreSession(ownerA)!;
      expect(aSession.sessionId, 'owner-a');
      expect(aSession.answeredItemCount, 4);
      expect(parseStoreSession(ownerB)!.attemptCount, 0,
          reason: 'the stale save must not transfer a checkpoint');
      expect(find.text('Item 1 of 10'), findsOneWidget,
          reason: 'stale callbacks must not mutate the UI');
      expect(choicesEnabled(tester), isFalse,
          reason: 'stale callbacks must not enable unanswered audio');
      // New-owner answers land on the new owner only.
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/u/'));
      await tester.pumpAndSettle();
      expect(parseStoreSession(ownerB)!.sessionId, isNot('owner-a'),
          reason: 'the new owner must carry its own session identity');
      expect(parseStoreSession(ownerA)!.sessionId, 'owner-a');
      expect(parseStoreSession(ownerA)!.attemptCount, 4,
          reason: 'stale UI writes must not extend the old owner session');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'owner replacement discards the old owner late load '
        'result', (tester) async {
      final ownerA = CourseLearningWidgetStore()..loadGate = Completer<void>();
      final ownerB = CourseLearningWidgetStore();
      final seedB =
          LessonSectionSession(itemIds: discoveryItemIds, sessionId: 'owner-b');
      seedB.submit(true);
      seedStoreSession(ownerB, seedB);
      final audio = FakeAudio();
      Widget app(CourseLearningWidgetStore owner) => ProviderScope(
              overrides: [
                courseAudioProvider.overrideWithValue(audio),
                courseLearningStoreProvider.overrideWithValue(owner),
              ],
              child: const MaterialApp(
                  home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y')));
      await tester.pumpWidget(app(ownerA));
      await tester.pump(); // owner A's load is in flight, held
      await tester.pumpWidget(app(ownerB));
      await tester.pumpAndSettle();
      expect(find.text('Item 1 of 10'), findsOneWidget,
          reason: 'the replacement owner state must be loaded');
      expect(find.text('Correct'), findsOneWidget,
          reason: 'the replacement owner saved state must be restored');
      ownerA.loadGate!.complete(); // the old owner load lands late
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Correct'), findsOneWidget,
          reason: 'the old owner late load result must not replace the '
              'new owner session');
      expect(sessionJson(ownerB), isNotNull,
          reason: 'the new owner state must remain intact');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'audio failure creates no answer and keeps listening '
        'retryable', (tester) async {
      final audio = FakeAudio(fail: true);
      final store = CourseLearningWidgetStore();
      await tester.pumpWidget(pumpLesson(tester, audio, store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be played'), findsOneWidget);
      expect(choicesEnabled(tester), isFalse,
          reason: 'a failed playback must not unlock the choices');
      expect(actionCount(store, ChooseSound), 0);
      expect(parseStoreSession(store)!.attemptCount, 0);
      expect(find.text('Listen to the word'), findsWidgets);
      audio.fail = false;
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      expect(choicesEnabled(tester), isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('cancelled playback is silent and keeps listening retryable',
        (tester) async {
      final audio = FakeAudio(cancel: true);
      final store = CourseLearningWidgetStore();
      await tester.pumpWidget(pumpLesson(tester, audio, store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be played'), findsNothing,
          reason: 'a cancelled request is not an audio failure');
      expect(choicesEnabled(tester), isFalse,
          reason: 'a cancelled playback must never unlock the choices');
      expect(actionCount(store, ChooseSound), 0,
          reason: 'a cancelled playback records no answer');
      // Listening stays retryable after a cancellation.
      audio.cancel = false;
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      expect(choicesEnabled(tester), isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'the audio failure guidance carries the exact alpha '
        'disclosure', (tester) async {
      final audio = FakeAudio(fail: true);
      final store = CourseLearningWidgetStore();
      await tester.pumpWidget(pumpLesson(tester, audio, store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      expect(
          find.text('Alpha audio: recordings are unverified; '
              'device speech is practice-only.'),
          findsOneWidget,
          reason: 'practice surfaces must carry the exact alpha label');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'the exercise surface pins the exact disclosure persistently — '
        'initial, pending and success — with no device-source claim',
        (tester) async {
      final audio = GateAudio();
      final store = CourseLearningWidgetStore();
      await tester.pumpWidget(pumpLesson(tester, audio, store));
      await tester.pumpAndSettle();
      expect(
          find.text('Alpha audio: recordings are unverified; '
              'device speech is practice-only.'),
          findsWidgets,
          reason: 'the exact alpha disclosure must be present from the '
              'initial state, before any playback at all (I1: previously only '
              'failure wording carried it)');
      expect(find.textContaining('Practice audio: spoken by this device.'),
          findsNothing,
          reason: 'covered words now select recorded (unverified) assets — '
              'the unconditional device-source claim is false and must be '
              'gone');
      // Pending (held) playback keeps the same disclosure.
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      expect(
          find.text('Alpha audio: recordings are unverified; '
              'device speech is practice-only.'),
          findsWidgets);
      expect(choicesEnabled(tester), isFalse);
      // Success keeps the same disclosure: a successful listener must see
      // the alpha sentence, not a device-speech claim.
      audio.gate.complete();
      await tester.pumpAndSettle();
      expect(
          find.text('Alpha audio: recordings are unverified; '
              'device speech is practice-only.'),
          findsWidgets,
          reason: 'the disclosure must persist on the success state');
      expect(choicesEnabled(tester), isTrue);
      expect(find.textContaining('Practice audio: spoken by this device.'),
          findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('stale session conflicts (typed conflict recovery)', () {
    testWidgets(
        'a conflicting answer offers Reload saved progress and '
        'the reload recovers the stored state', (tester) async {
      final audio = FakeAudio();
      final store = CourseLearningWidgetStore();
      await tester.pumpWidget(pumpLesson(tester, audio, store));
      await tester.pumpAndSettle();
      // A competing instance committed the same step first (different
      // session identity), as in the stacked real-store regression.
      final foreign = LessonSectionSession(
          itemIds: discoveryItemIds, sessionId: 'other-screen-session')
        ..submit(true);
      seedStoreSession(store, foreign);

      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/u/'));
      await tester.pumpAndSettle();
      expect(find.text('Correct'), findsOneWidget,
          reason: 'the local feedback stays while the state is stale');
      expect(find.textContaining('matches the saved progress'), findsOneWidget,
          reason: 'the typed conflict must be surfaced');
      expect(find.text('Retry saving'), findsNothing,
          reason: 'resending the same checkpoint can never succeed');
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Next word'))
              .onPressed,
          isNull,
          reason: 'stale state must not advance');

      await tester.tap(find.text('Reload saved progress'));
      await tester.pumpAndSettle();
      expect(find.text('Reload saved progress'), findsNothing);
      expect(find.textContaining('matches the saved progress'), findsNothing);
      expect(parseStoreSession(store)!.sessionId, 'other-screen-session',
          reason: 'the reload discarded the stale draft, not the store');
      expect(actionCount(store, ChooseSound), 1,
          reason: 'the stale answer was attempted once and rejected once');
      // Reload cancels the stale hearing: a fresh completed playback is
      // required before the restored exercise can be answered again.
      expect(audio.stops, greaterThanOrEqualTo(1));
      await tester.tap(find.text('Next word'));
      await tester.pumpAndSettle();
      expect(find.text('Item 2 of 10'), findsOneWidget,
          reason: 'the recovered state must be usable');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'a stale same-session advance conflict recovers via the '
        'explicit reload', (tester) async {
      final store = CourseLearningWidgetStore();
      final seed =
          LessonSectionSession(itemIds: discoveryItemIds, sessionId: 'shared')
            ..submit(true);
      seedStoreSession(store, seed);
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      expect(find.text('Correct'), findsOneWidget,
          reason: 'both instances load the same stored state');
      // The competing instance advances and answers the next item.
      final competitor = LessonSectionSession.fromJson(sessionJson(store)!,
          itemIds: discoveryItemIds,
          contentRevision: frenchUySection.contentRevision)
        ..advance()
        ..submit(true);
      seedStoreSession(store, competitor);

      await tester.tap(find.text('Next word'));
      await tester.pumpAndSettle();
      expect(find.textContaining('matches the saved progress'), findsOneWidget,
          reason: 'the behind stored count is a typed conflict');
      expect(find.text('Item 1 of 10'), findsOneWidget,
          reason: 'the stale advance must not publish');
      await tester.tap(find.text('Reload saved progress'));
      await tester.pumpAndSettle();
      expect(parseStoreSession(store)!.attemptCount, 2,
          reason: 'the store rejection is untouched by the reload');
      expect(find.text('Correct'), findsOneWidget);
      expect(find.text('Item 2 of 10'), findsOneWidget,
          reason: 'the recovered state must be usable');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a failing reload keeps Retry loading and recovers after',
        (tester) async {
      final store = CourseLearningWidgetStore();
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      final foreign = LessonSectionSession(
          itemIds: discoveryItemIds, sessionId: 'other-screen-session')
        ..submit(true);
      seedStoreSession(store, foreign);
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/u/'));
      await tester.pumpAndSettle();
      expect(find.text('Reload saved progress'), findsOneWidget);
      store.failLoad = true;
      await tester.tap(find.text('Reload saved progress'));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be loaded'), findsOneWidget);
      expect(find.text('Retry loading'), findsOneWidget);
      expect(find.text('Reload saved progress'), findsNothing);
      store.failLoad = false;
      await tester.tap(find.text('Retry loading'));
      await tester.pumpAndSettle();
      expect(parseStoreSession(store)!.sessionId, 'other-screen-session');
      expect(find.text('Correct'), findsOneWidget,
          reason: 'the retry load restored the stored committed state');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'a second Reload tap before redraw cannot start a '
        'competing load', (tester) async {
      final store = CourseLearningWidgetStore();
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      final foreign = LessonSectionSession(
          itemIds: discoveryItemIds, sessionId: 'other-screen-session')
        ..submit(true);
      seedStoreSession(store, foreign);
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/u/'));
      await tester.pumpAndSettle();
      expect(find.text('Reload saved progress'), findsOneWidget);
      store.loadGate = Completer<void>();
      await tester.tap(find.text('Reload saved progress'));
      await tester.tap(find.text('Reload saved progress')); // before redraw
      await tester.pump();
      store.loadGate!.complete();
      await tester.pumpAndSettle();
      expect(store.loadCalls, 2,
          reason: 'initial load plus one coalesced reload');
      expect(find.text('Correct'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'owner replacement discards a held stale conflict save '
        'and the new owner stays untouched', (tester) async {
      final storeA = CourseLearningWidgetStore()
        ..actionGates[ChooseSound] = Completer<void>()
        ..actionFailures[ChooseSound] = const LearningConflictException();
      final storeB = CourseLearningWidgetStore();
      final seedB =
          LessonSectionSession(itemIds: discoveryItemIds, sessionId: 'owner-b')
            ..submit(true);
      seedStoreSession(storeB, seedB);
      final audio = FakeAudio();
      Widget app(CourseLearningWidgetStore owner) => ProviderScope(
              overrides: [
                courseAudioProvider.overrideWithValue(audio),
                courseLearningStoreProvider.overrideWithValue(owner),
              ],
              child: const MaterialApp(
                  home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y')));
      await tester.pumpWidget(app(storeA));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/u/'));
      await tester.pump(); // the stale answer save is in flight, held
      expect(actionCount(storeA, ChooseSound), 1);
      // The owner switches while the save is pending; the replacement
      // owner's state loads and the stale intent is dropped.
      await tester.pumpWidget(app(storeB));
      await tester.pumpAndSettle();
      expect(find.text('Correct'), findsOneWidget,
          reason: 'the replacement owner state must be loaded');
      expect(storeA.actionGates[ChooseSound]!.isCompleted, isFalse);
      storeA.actionGates[ChooseSound]!.complete(); // conflict lands late
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(parseStoreSession(storeB)!.sessionId, 'owner-b',
          reason: 'the stale save must not transfer a checkpoint');
      expect(parseStoreSession(storeB)!.attemptCount, 1);
      expect(find.textContaining('matches the saved progress'), findsNothing,
          reason: 'a conflict that lands after the owner switch '
              'must not publish into the new owner UI');
      expect(find.text('Reload saved progress'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a conflict completing while suspended settles on resume',
        (tester) async {
      final store = CourseLearningWidgetStore()
        ..actionGates[ChooseSound] = Completer<void>()
        ..actionFailures[ChooseSound] = const LearningConflictException();
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/u/'));
      await tester.pump(); // save in flight, held
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.scheduleForcedFrame();
      await tester.pump();
      store.actionGates[ChooseSound]!.complete(); // conflict settles suspended
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('matches the saved progress'), findsNothing,
          reason: 'a suspended completion must not publish');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.textContaining('matches the saved progress'), findsOneWidget,
          reason: 'resume must settle the stale conflict');
      expect(find.text('Retry saving'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('repeat practice', () {
    LessonSectionSession perfectSeed(String sessionId) {
      final seed =
          LessonSectionSession(itemIds: discoveryItemIds, sessionId: sessionId);
      for (var i = 0; i < 10; i++) {
        seed.submit(true);
        seed.advance();
      }
      return seed;
    }

    testWidgets(
        'a completed review route offers Practise again, persists '
        'the fresh zero-attempt identity first, then exposes the exercise',
        (tester) async {
      final audio = FakeAudio();
      final store = CourseLearningWidgetStore()
        ..seedSession(perfectSeed('perfect'));
      await tester.pumpWidget(pumpLesson(tester, audio, store, review: true));
      await tester.pumpAndSettle();
      expect(find.text('Section debrief'), findsOneWidget,
          reason: 'the historical debrief is restored');
      expect(find.text('Practise again'), findsOneWidget,
          reason: 'a mastered review entry must be practisable');
      expect(find.text('Listen to the word'), findsNothing,
          reason: 'until the explicit restart, no exercise is exposed');

      await tester.tap(find.text('Practise again'));
      await tester.pumpAndSettle();
      final restarted = parseStoreSession(store)!;
      expect(restarted.attemptCount, 0,
          reason: 'the fresh zero-attempt identity was persisted first');
      expect(restarted.sessionId, isNot('perfect'),
          reason: 'a new session identity starts the repeat');
      expect(find.text('Item 1 of 10'), findsOneWidget,
          reason: 'only after the save settles is the exercise exposed');
      expect(actionCount(store, ChooseSound), 0,
          reason: 'no answer may land before the restart save');
      expect(hasCompletion(store), isFalse,
          reason: 'restarting does not itself complete the section');

      // The recovered exercise is usable and records the new history.
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      expect(audio.spoken.last, 'tout',
          reason: 'a fresh hearing for the first item');
      await tester.tap(find.text('/u/'));
      await tester.pumpAndSettle();
      expect(find.text('Correct'), findsOneWidget);
      expect(parseStoreSession(store)!.attemptCount, 1,
          reason: 'the repeated practice records its own history');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'a normal-route debrief with unresolved words offers '
        'Practise again alongside review', (tester) async {
      final store = CourseLearningWidgetStore();
      final seed =
          LessonSectionSession(itemIds: discoveryItemIds, sessionId: 'seed');
      for (var i = 0; i < 10; i++) {
        seed.submit(i < 8);
        seed.advance();
      }
      seedStoreSession(store, seed);
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      expect(find.text('Section debrief'), findsOneWidget);
      expect(find.text('Review mistakes'), findsOneWidget);
      expect(find.text('Finish section'), findsOneWidget);
      expect(find.text('Practise again'), findsOneWidget,
          reason: 'the restart is offered with unresolved words present');
      // The unresolved-words debrief is the tallest variant: on the default
      // 800x600 test surface the restart control sits below the fold, so
      // scroll it into the scroller (as the accessibility regressions do)
      // before interacting.
      await tester.scrollUntilVisible(find.text('Practise again'), 100);
      await tester.tap(find.text('Practise again'));
      await tester.pumpAndSettle();
      expect(parseStoreSession(store)!.attemptCount, 0,
          reason: 'the restart persists before the exercise is exposed');
      expect(find.text('Item 1 of 10'), findsOneWidget);
      expect(find.text('Review mistakes'), findsNothing,
          reason: 'the fresh first pass replaces the debrief');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'a failed restart save keeps the debrief, retries the same '
        'identity, and never exposes or records the exercise early',
        (tester) async {
      final seedJson = perfectSeed('perfect').toJson();
      final store = CourseLearningWidgetStore()
        ..seedSession(perfectSeed('perfect'))
        ..failingActions.add(StartLearningRun);
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practise again'));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be saved'), findsOneWidget);
      expect(sessionJson(store), seedJson,
          reason: 'a failed restart must not touch the saved state');
      expect(find.text('Item 1 of 10'), findsNothing,
          reason: 'the new exercise must not leak before its save lands');
      expect(find.text('Practise again'), findsWidgets,
          reason: 'the historical debrief stays');

      failAction(store, StartLearningRun, false);
      await tester.tap(find.text('Retry saving'));
      await tester.tap(find.text('Retry saving')); // before redraw
      await tester.pump();
      await tester.pumpAndSettle();
      expect(actionCount(store, StartLearningRun), 2,
          reason: 'a double retry before redraw must be single-shot');
      final restarted = parseStoreSession(store)!;
      expect(restarted.attemptCount, 0);
      expect(find.text('Item 1 of 10'), findsOneWidget,
          reason: 'the settled restart exposes the exercise');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a double Practise again before redraw starts one save',
        (tester) async {
      final store = CourseLearningWidgetStore()
        ..seedSession(perfectSeed('perfect'))
        ..actionGates[StartLearningRun] = Completer<void>();
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practise again'));
      await tester.tap(find.text('Practise again')); // before redraw
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(actionCount(store, StartLearningRun), 1,
          reason: 'a double tap must not start a second restart save');
      store.actionGates[StartLearningRun]!.complete();
      await tester.pumpAndSettle();
      expect(parseStoreSession(store)!.attemptCount, 0);
      expect(find.text('Item 1 of 10'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'a restart save completing while suspended settles '
        'idempotently on resume', (tester) async {
      final store = CourseLearningWidgetStore()
        ..seedSession(perfectSeed('perfect'))
        ..actionGates[StartLearningRun] = Completer<void>();
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practise again'));
      await tester.pump(); // restart save in flight, held
      expect(actionCount(store, StartLearningRun), 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.scheduleForcedFrame();
      await tester.pump();
      store.actionGates[StartLearningRun]!
          .complete(); // settles while suspended
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Item 1 of 10'), findsNothing,
          reason: 'a suspended settlement must not publish the exercise');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(parseStoreSession(store)!.attemptCount, 0,
          reason: 'the restart save landed exactly once in storage');
      expect(find.text('Item 1 of 10'), findsOneWidget,
          reason: 'resume settles the pending restart exercise');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'a failed restart keeps its retry intent across '
        'suspension', (tester) async {
      final seedJson = perfectSeed('perfect').toJson();
      final store = CourseLearningWidgetStore()
        ..seedSession(perfectSeed('perfect'))
        ..failingActions.add(StartLearningRun);
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practise again'));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be saved'), findsOneWidget);
      await suspendResume(tester);
      expect(sessionJson(store), seedJson,
          reason: 'suspension must not settle the failed restart');
      expect(find.textContaining('could not be saved'), findsOneWidget,
          reason: 'the failed save intent survives suspension');
      failAction(store, StartLearningRun, false);
      await tester.tap(find.text('Retry saving'));
      await tester.pumpAndSettle();
      expect(parseStoreSession(store)!.attemptCount, 0);
      expect(find.text('Item 1 of 10'), findsOneWidget,
          reason: 'the retry settles the restart exercise');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'owner replacement discards a held pending restart and '
        'the new owner stays untouched', (tester) async {
      final ownerA = CourseLearningWidgetStore()
        ..seedSession(perfectSeed('perfect'))
        ..actionGates[StartLearningRun] = Completer<void>();
      final ownerB = CourseLearningWidgetStore();
      final audio = FakeAudio();
      Widget app(CourseLearningWidgetStore owner) => ProviderScope(
              overrides: [
                courseAudioProvider.overrideWithValue(audio),
                courseLearningStoreProvider.overrideWithValue(owner),
              ],
              child: const MaterialApp(
                  home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y')));
      await tester.pumpWidget(app(ownerA));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practise again'));
      await tester.pump(); // restart save in flight, held
      expect(sessionJson(ownerA), perfectSeed('perfect').toJson(),
          reason: 'nothing is written before the save settles');
      await tester.pumpWidget(app(ownerB));
      await tester.pumpAndSettle();
      expect(parseStoreSession(ownerB)!.attemptCount, 0,
          reason: 'the replacement owner must stay untouched');
      ownerA.actionGates[StartLearningRun]!
          .complete(); // the old save may land on its own data
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(parseStoreSession(ownerA)!.attemptCount, 0,
          reason: 'the old owner keeps its reconciled restart');
      expect(parseStoreSession(ownerB)!.attemptCount, 0,
          reason: 'the stale restart save must not transfer a checkpoint');
      expect(find.text('Item 1 of 10'), findsOneWidget,
          reason: 'the screen shows the new owner state, not the pending '
              'restart exercise');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Practise again is disabled while a save is in flight',
        (tester) async {
      final store = CourseLearningWidgetStore()
        ..seedSession(perfectSeed('perfect'))
        ..actionGates[StartLearningRun] = Completer<void>();
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practise again'));
      await tester.pump(); // the busy state is now drawn
      final button = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Practise again'));
      expect(button.onPressed, isNull,
          reason: 'a pending restart must not be re-triggered');
      store.actionGates[StartLearningRun]!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Item 1 of 10'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('routing', () {
    testWidgets(
        'pilot route opens the discovery screen, non-pilot and '
        'unknown lessons keep the legacy screen', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final audio = FakeAudio();
      final store = CourseLearningWidgetStore();
      final container = ProviderContainer(overrides: [
        courseAudioProvider.overrideWithValue(audio),
        courseLearningStoreProvider.overrideWithValue(store),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container, child: const LinguistApp()));
      await tester.pumpAndSettle();
      expect(find.text('I speak English'), findsOneWidget);
      await tester.tap(find.text('Start English → French'));
      await tester.pumpAndSettle();
      final GoRouter router = container.read(appRouterProvider);
      router.go('/course-lesson/en-fr-u-y');
      await tester.pumpAndSettle();
      expect(find.byType(DiscoveryLessonScreen), findsOneWidget);

      router.go('/course-lesson/en-fr-vowels');
      await tester.pumpAndSettle();
      expect(find.byType(CourseLessonScreen), findsOneWidget);

      router.go('/course-lesson/does-not-exist');
      await tester.pumpAndSettle();
      expect(find.byType(CourseLessonScreen), findsOneWidget);
      expect(find.text('This lesson is unavailable.'), findsOneWidget);

      router.go('/course-lesson/en-fr-u-y?review=true');
      await tester.pumpAndSettle();
      final screen = tester
          .widget<DiscoveryLessonScreen>(find.byType(DiscoveryLessonScreen));
      expect(screen.review, isTrue, reason: 'the review query is preserved');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a held Finish does not navigate while suspended',
        (tester) async {
      final store = CourseLearningWidgetStore()
        ..actionGates[FinishLearningActivity] = Completer<void>();
      final router = lessonRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            courseAudioProvider.overrideWithValue(FakeAudio()),
            courseLearningStoreProvider.overrideWithValue(store),
          ],
          child: MaterialApp.router(
              debugShowCheckedModeBanner: false, routerConfig: router)));
      await tester.pumpAndSettle();
      await playPerfectSection(tester);
      await tester.tap(find.text('Finish section'));
      await tester.pump(); // the completion save is in flight, held
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.scheduleForcedFrame();
      await tester.pump();
      store.actionGates[FinishLearningActivity]!
          .complete(); // completes while suspended
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(router.routeInformationProvider.value.uri.path,
          '/course-lesson/en-fr-u-y',
          reason: 'a suspended completion must not navigate');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(hasCompletion(store), isTrue,
          reason: 'resume must settle the pending completion');
      expect(router.routeInformationProvider.value.uri.path, '/home',
          reason: 'a settled completion exits to home');
    });

    testWidgets(
        'inactive after suspension must not navigate before '
        'resumed', (tester) async {
      final store = CourseLearningWidgetStore()
        ..actionGates[FinishLearningActivity] = Completer<void>();
      final router = lessonRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            courseAudioProvider.overrideWithValue(FakeAudio()),
            courseLearningStoreProvider.overrideWithValue(store),
          ],
          child: MaterialApp.router(
              debugShowCheckedModeBanner: false, routerConfig: router)));
      await tester.pumpAndSettle();
      await playPerfectSection(tester);
      await tester.tap(find.text('Finish section'));
      await tester.pump(); // the completion save is in flight, held
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.scheduleForcedFrame();
      await tester.pump();
      store.actionGates[FinishLearningActivity]!
          .complete(); // completes while suspended
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.scheduleForcedFrame();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(router.routeInformationProvider.value.uri.path,
          '/course-lesson/en-fr-u-y',
          reason: 'inactive is not recovery; navigation waits for resumed');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/home',
          reason: 'resumed settles the completion exactly once');
    });

    testWidgets(
        'a double Finish before redraw settles once and pops '
        'exactly one route', (tester) async {
      final store = CourseLearningWidgetStore()
        ..actionGates[FinishLearningActivity] = Completer<void>();
      final router = GoRouter(initialLocation: '/home', routes: [
        GoRoute(
            path: '/home',
            pageBuilder: (_, __) => const NoTransitionPage(child: _HomeStub())),
        GoRoute(
            path: '/course-list',
            pageBuilder: (_, __) => const NoTransitionPage(
                child: Scaffold(body: Center(child: Text('course list'))))),
        GoRoute(
            path: '/course-lesson/:id',
            pageBuilder: (_, state) {
              final String id = state.pathParameters['id']!;
              return NoTransitionPage(
                  child: sectionForLesson(id) != null
                      ? DiscoveryLessonScreen(lessonId: id)
                      : CourseLessonScreen(lessonId: id));
            }),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            courseAudioProvider.overrideWithValue(FakeAudio()),
            courseLearningStoreProvider.overrideWithValue(store),
          ],
          child: MaterialApp.router(
              debugShowCheckedModeBanner: false, routerConfig: router)));
      await tester.pumpAndSettle();
      // Multi-entry stack: home -> course list -> lesson, so a double pop has
      // a different, observable landing screen than a single pop. `push`
      // appends unambiguously. (With go_router defaults the provider URI
      // intentionally reports only the declarative base after a push, so the
      // stack is asserted through the visible pages, not the provider value.)
      router.push('/course-list');
      await tester.pumpAndSettle();
      expect(find.text('course list'), findsOneWidget);
      router.push('/course-lesson/en-fr-u-y');
      await tester.pumpAndSettle();
      expect(find.byType(DiscoveryLessonScreen), findsOneWidget);
      expect(router.canPop(), isTrue, reason: 'the lesson sits on a stack');
      await playPerfectSection(tester);
      await tester.tap(find.text('Finish section'));
      // Double invocation before the busy state is drawn: no frame is pumped
      // between the taps, so both observe the still-enabled button and only
      // the screen's own single-shot guard may block the second one.
      await tester.tap(find.text('Finish section'));
      await tester.pump(); // first save starts (held); the second is refused
      store.actionGates[FinishLearningActivity]!.complete();
      await tester.pumpAndSettle();
      expect(actionCount(store, FinishLearningActivity), 1,
          reason: 'a double tap must not start a second completion');
      expect(hasCompletion(store), isTrue);
      // One settled Finish pops exactly one route, landing on the course
      // list; a double pop would drop the stack to home instead.
      expect(find.byType(DiscoveryLessonScreen), findsNothing);
      expect(find.text('course list'), findsOneWidget,
          reason: 'one settled Finish pops exactly one route (no double pop)');
      expect(find.byType(_HomeStub), findsNothing);
    });

    testWidgets(
        'only a successful Finish exits; without a previous route '
        'it falls back to home', (tester) async {
      final store = CourseLearningWidgetStore();
      failAction(store, FinishLearningActivity, true);
      final router = lessonRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            courseAudioProvider.overrideWithValue(FakeAudio()),
            courseLearningStoreProvider.overrideWithValue(store),
          ],
          child: MaterialApp.router(
              debugShowCheckedModeBanner: false, routerConfig: router)));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path,
          '/course-lesson/en-fr-u-y');
      await playPerfectSection(tester);
      await tester.tap(find.text('Finish section'));
      await tester.pumpAndSettle();
      expect(hasCompletion(store), isFalse);
      expect(find.byType(DiscoveryLessonScreen), findsOneWidget,
          reason: 'a failed Finish must not navigate away');
      failAction(store, FinishLearningActivity, false);
      await tester.tap(find.text('Retry saving'));
      await tester.pumpAndSettle();
      expect(hasCompletion(store), isTrue);
      expect(router.routeInformationProvider.value.uri.path, '/home');
      expect(find.byType(DiscoveryLessonScreen), findsNothing);
    });

    testWidgets('review=true Finish saves but never records completion',
        (tester) async {
      final store = CourseLearningWidgetStore();
      final GoRouter router = GoRouter(
          initialLocation: '/course-lesson/en-fr-u-y?review=true',
          routes: [
            GoRoute(
              path: '/course-lesson/:id',
              builder: (_, state) => DiscoveryLessonScreen(
                  lessonId: state.pathParameters['id']!,
                  review: state.uri.queryParameters['review'] == 'true'),
            ),
            GoRoute(path: '/home', builder: (_, __) => const _HomeStub()),
          ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            courseAudioProvider.overrideWithValue(FakeAudio()),
            courseLearningStoreProvider.overrideWithValue(store),
          ],
          child: MaterialApp.router(
              debugShowCheckedModeBanner: false, routerConfig: router)));
      await tester.pumpAndSettle();
      await playPerfectSection(tester);
      await tester.tap(find.text('Finish section'));
      await tester.pumpAndSettle();
      expect(hasCompletion(store), isFalse,
          reason: 'review=true must not add a completion');
      expect(sessionJson(store), isNotNull,
          reason: 'review=true must still save the section state');
      expect(router.routeInformationProvider.value.uri.path, '/home');
    });
  });

  group('hidden listening content', () {
    final section = frenchUySection;
    final List<String> words = section.items.map((item) => item.word).toList();

    void expectNoHiddenContent(WidgetTester tester) {
      expect(find.text('Listening practice'), findsWidgets,
          reason: 'the neutral title must be active outside the debrief');
      final List<String> texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((Text widget) => widget.data ?? '')
          .toList();
      for (final String word in words) {
        expect(texts, isNot(contains(word)),
            reason: 'word "$word" must stay hidden outside the debrief');
      }
      expect(texts, isNot(contains(section.title)),
          reason: 'the word-bearing authored title must stay hidden '
              'outside the debrief');
    }

    testWidgets(
        'the active first item exposes no words before playback, '
        'after playback, or after a wrong or correct submission',
        (tester) async {
      await tester.pumpWidget(
          pumpLesson(tester, FakeAudio(), CourseLearningWidgetStore()));
      await tester.pumpAndSettle();
      expectNoHiddenContent(tester);
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      expectNoHiddenContent(tester);
      // A wrong submission on /u/ (item 1 expects /u/): feedback only.
      await tester.tap(find.text('/y/'));
      await tester.pumpAndSettle();
      expect(find.text('Not yet'), findsOneWidget);
      expectNoHiddenContent(tester);
      // Reload is not needed: advance to the correct-answer state instead.
      // 'tu' expects /y/; a correct submission there must leak nothing.
      await advance(tester, last: false);
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/y/'));
      await tester.pumpAndSettle();
      expect(find.text('Correct'), findsOneWidget);
      expectNoHiddenContent(tester);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'a restored exercise keeps the words hidden until the '
        'debrief', (tester) async {
      final store = CourseLearningWidgetStore();
      final seed =
          LessonSectionSession(itemIds: discoveryItemIds, sessionId: 'seed');
      seed.submit(true);
      seed.advance();
      seed.submit(false);
      seed.advance();
      seedStoreSession(store, seed);
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      expect(find.text('Item 3 of 10'), findsOneWidget);
      expectNoHiddenContent(tester);
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      expectNoHiddenContent(tester);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('loading and load-error states keep the words hidden',
        (tester) async {
      final holder = CourseLearningWidgetStore()..loadGate = Completer<void>();
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), holder));
      await tester.pump(); // the load is still in flight
      expect(find.text('Listening practice'), findsWidgets);
      for (final String word in words) {
        expect(find.text(word), findsNothing, reason: word);
      }
      expect(find.text(section.title), findsNothing);
      holder.loadGate!.complete();
      await tester.pumpAndSettle();

      final failing = CourseLearningWidgetStore()..failLoad = true;
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), failing));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be loaded'), findsOneWidget);
      expect(find.text('Retry loading'), findsOneWidget);
      for (final String word in words) {
        expect(find.text(word), findsNothing, reason: word);
      }
      expect(find.text(section.title), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the debrief reveals the authored title and explanation',
        (tester) async {
      final store = CourseLearningWidgetStore();
      final seed =
          LessonSectionSession(itemIds: discoveryItemIds, sessionId: 'seed');
      for (var i = 0; i < 10; i++) {
        seed.submit(true);
        seed.advance();
      }
      seedStoreSession(store, seed);
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      expect(find.text('Section debrief'), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(DiscoverySectionView),
              matching: find.text(section.title)),
          findsOneWidget,
          reason: 'the word-bearing title is revealed in the debrief body');
      expect(find.text(section.title), findsWidgets,
          reason: 'the debrief app bar may carry the authored title too');
      expect(find.text(section.explanation), findsOneWidget);
      expect(find.text('Listening practice'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('real typed repository integration', () {
    testWidgets('two stacked instances recover through explicit typed reload',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      addTearDown(() => SharedPreferences.setMockInitialValues({}));
      final prefs = FailablePreferences();
      SharedPreferencesStorePlatform.instance = prefs;
      final router = GoRouter(initialLocation: '/home', routes: [
        GoRoute(
            path: '/home',
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: Scaffold(body: Text('home')))),
        GoRoute(
            path: '/lesson',
            pageBuilder: (_, __) => const NoTransitionPage(
                child: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'))),
      ]);
      addTearDown(router.dispose);
      final audio = FakeAudio();
      await tester.pumpWidget(ProviderScope(
          overrides: [courseAudioProvider.overrideWithValue(audio)],
          child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      router.push('/lesson');
      await tester.pumpAndSettle();
      router.push('/lesson');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/u/'));
      await tester.pumpAndSettle();
      expect(find.text('Correct'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/u/'));
      await tester.pumpAndSettle();
      expect(find.textContaining('matches the saved progress'), findsOneWidget);
      expect(find.text('Retry saving'), findsNothing);
      await tester.tap(find.text('Reload saved progress'));
      await tester.pumpAndSettle();
      expect(find.text('Correct'), findsOneWidget);
      await tester.tap(find.text('Next word'));
      await tester.pumpAndSettle();
      expect(find.text('Item 2 of 10'), findsOneWidget);
      prefs.failWrites = true;
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/y/'));
      await tester.pumpAndSettle();
      expect(find.text('Correct'), findsOneWidget);
      expect(find.textContaining('could not be saved'), findsOneWidget);
      final scope =
          LearningScope(courseId: 'en-fr', owner: LearningOwner.guest());
      final preferences = await SharedPreferences.getInstance();
      var persisted = preferences.getString(scope.storageKey);
      expect(persisted, isNotNull);
      var committed = const LearningDocumentCodec().decode(persisted!, scope);
      expect(committed.history, hasLength(1),
          reason: 'the failed answer did not publish into real preferences');
      prefs.failWrites = false;
      await tester.tap(find.text('Retry saving'));
      await tester.pumpAndSettle();
      committed = const LearningDocumentCodec()
          .decode(preferences.getString(scope.storageKey)!, scope);
      expect(committed.history, hasLength(2),
          reason: 'retry commits the answer exactly once');
      await tester.tap(find.text('Next word'));
      await tester.pumpAndSettle();
      for (var i = 2; i < 10; i++) {
        await tester.tap(find.text('Listen to the word'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('/${expectedSounds[i]}/'));
        await tester.pumpAndSettle();
        await advance(tester, last: i == 9);
      }
      expect(find.text('Section debrief'), findsOneWidget);
      await tester.tap(find.text('Finish section'));
      await tester.pumpAndSettle();
      persisted = preferences.getString(scope.storageKey);
      expect(persisted, isNotNull,
          reason: 'the real preferences repository wrote its typed document');
      committed = const LearningDocumentCodec().decode(persisted!, scope);
      expect(committed.history, hasLength(10));
      expect(committed.completions.map((entry) => entry.lessonId),
          contains('en-fr-u-y'));
      expect(committed.activities['lesson:en-fr-u-y']?.snapshot,
          isA<DiscoveryCheckpoint>());
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('same-session competing advance reload preserves typed state',
        (tester) async {
      final store = CourseLearningWidgetStore();
      final seed = LessonSectionSession(
          itemIds: discoveryItemIds, sessionId: 'shared-real-contract')
        ..submit(true);
      seedStoreSession(store, seed);
      await tester.pumpWidget(pumpLesson(tester, FakeAudio(), store));
      await tester.pumpAndSettle();
      expect(find.text('Correct'), findsOneWidget);
      final competitor = LessonSectionSession.fromJson(sessionJson(store)!,
          itemIds: discoveryItemIds,
          contentRevision: frenchUySection.contentRevision)
        ..advance()
        ..submit(true);
      seedStoreSession(store, competitor);

      await tester.tap(find.text('Next word'));
      await tester.pumpAndSettle();
      expect(find.textContaining('matches the saved progress'), findsOneWidget);
      expect(find.text('Item 1 of 10'), findsOneWidget);
      await tester.tap(find.text('Reload saved progress'));
      await tester.pumpAndSettle();
      expect(parseStoreSession(store)!.attemptCount, 2);
      expect(find.text('Correct'), findsOneWidget);
      expect(find.text('Item 2 of 10'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'failed typed commit does not publish state; retry commits '
        'the answer once', (tester) async {
      final store = CourseLearningWidgetStore();
      final audio = FakeAudio();
      await tester.pumpWidget(pumpLesson(tester, audio, store));
      await tester.pumpAndSettle();

      store.failSubmit = true;
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/u/'));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not be saved'), findsOneWidget);
      expect(store.committedState.history, isEmpty);

      store.failSubmit = false;
      await tester.tap(find.text('Retry saving'));
      await tester.pumpAndSettle();
      expect(store.committedState.history, hasLength(1));
      await tester.tap(find.text('Next word'));
      await tester.pumpAndSettle();
      for (var i = 1; i < 10; i++) {
        await tester.tap(find.text('Listen to the word'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('/${expectedSounds[i]}/'));
        await tester.pumpAndSettle();
        await advance(tester, last: i == 9);
      }
      expect(store.committedState.history, hasLength(10));
      expect(store.committedState.completions, isEmpty);
      failAction(store, FinishLearningActivity, true);
      await tester.tap(find.text('Finish section'));
      await tester.pumpAndSettle();
      expect(store.committedState.completions, isEmpty,
          reason: 'failed completion is not authoritative');
      failAction(store, FinishLearningActivity, false);
      await tester.tap(find.text('Retry saving'));
      await tester.pumpAndSettle();
      expect(store.committedState.completions, hasLength(1));
      expect(actionCount(store, FinishLearningActivity), 2);
      await tester.pumpWidget(const SizedBox());
    });
  });
}

GoRouter lessonRouter() {
  return GoRouter(initialLocation: '/course-lesson/en-fr-u-y', routes: [
    GoRoute(
        path: '/course-lesson/:id',
        builder: (_, state) {
          final String id = state.pathParameters['id']!;
          final bool review = state.uri.queryParameters['review'] == 'true';
          return sectionForLesson(id) != null
              ? DiscoveryLessonScreen(lessonId: id, review: review)
              : CourseLessonScreen(lessonId: id, review: review);
        }),
    GoRoute(path: '/home', builder: (_, __) => const _HomeStub()),
  ]);
}

Future<void> playPerfectSection(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.tap(find.text('Listen to the word'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('/${expectedSounds[i]}/'));
    await tester.pumpAndSettle();
    expect(find.text('Correct'), findsOneWidget);
    await advance(tester, last: i == 9);
  }
}

bool choicesEnabled(WidgetTester tester) =>
    tester
        .widget<TextButton>(find.widgetWithText(TextButton, '/u/'))
        .onPressed !=
    null;

class _HomeStub extends StatelessWidget {
  const _HomeStub();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('home'));
}
