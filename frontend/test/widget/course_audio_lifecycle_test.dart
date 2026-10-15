// FR-03 Task 4 (fix round 1): listener-lesson lifecycle with the default
// (shared) player.
//
// Screen-level behavior over the REAL [CourseLessonScreen] with only the
// plugin boundary replaced. Two boundary shapes, kept deliberately
// distinct (I3 fix):
//
// * [CancellingCueAudio] — the realistic facade shape: Stop invalidates the
//   held request immediately, and the caller's suppression/cancel path runs
//   on a genuinely cancelled terminal.
// * [HeldCueAudio] — the adversarial compatible shape: Stop only records
//   itself; each request is retained per cue and really settles (success or
//   an exact engine error) AFTER retirement. A late settlement must never
//   unlock, clear a newer request's busy, publish feedback, leak an
//   unhandled error, or arm progress.
//
// I2 fix round: app suspension (paused/hidden) must invalidate the held
// request BEFORE stopping the captured playback, keep the listener
// retryable, and never let a late success/error of the retired request
// unlock or republish a newer one.
//
// RED note (fix round 1): on the pre-fix code the suspension assertions
// fail (no lifecycle retirement: no stop, busy stuck, stale success
// unlocks); the pre-fix Round-0 late-release calls were no-ops on
// self-cancelling doubles and do not establish stale settlement at all.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/features/course/course_lesson_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../support/course_learning_widget_store.dart';

const String alphaDisclosure =
    'Alpha audio: recordings are unverified; device speech is practice-only.';

/// Common observable surface of the two cue doubles, so the late-case loop
/// can assert on spoken/stops without casts.
abstract class CueAudioProbe implements CourseAudio {
  List<String> get spoken;
  int get stops;
}

/// Realistic prompt cancellation: [stop] invalidates the held request now
/// (the facade hands the caller its cancellation terminal), exactly like
/// the shared player's stop semantics.
final class CancellingCueAudio implements CourseAudio, CueAudioProbe {
  @override
  final List<String> spoken = <String>[];
  @override
  int stops = 0;
  Completer<Object?>? _pending;

  @override
  Future<void> speak(String word) {
    spoken.add(word);
    final Completer<Object?> settle = Completer<Object?>();
    _pending = settle;
    final Future<void> delivery = settle.future.then((Object? _) {});
    unawaited(
        delivery.then<void>((Object? value) {}, onError: (Object error) {}));
    return delivery;
  }

  @override
  Future<void> stop() {
    stops++;
    final Completer<Object?>? pending = _pending;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(const CourseAudioCancelledException());
    }
    return Future<void>.value();
  }

  void release([Object? error]) {
    final Completer<Object?>? pending = _pending;
    if (pending == null || pending.isCompleted) return;
    if (error == null) {
      pending.complete();
    } else {
      pending.completeError(error);
    }
  }
}

/// One retained request of [HeldCueAudio]: released exactly once, with
/// success or the exact engine error.
final class HeldCue {
  HeldCue(this._settle);

  final Completer<Object?> _settle;

  bool get settled => _settle.isCompleted;

  void release([Object? error]) {
    if (_settle.isCompleted) return;
    if (error == null) {
      _settle.complete();
    } else {
      _settle.completeError(error);
    }
  }
}

/// Adversarial-compatible [CourseAudio] for caller-generation tests:
/// [speak] retains a per-request cue; [stop] only records itself (a
/// compatible implementation may settle after Stop); the cues then really
/// settle with success or an exact error — success AND error must each be
/// survivable by the caller's generation guard.
final class HeldCueAudio implements CourseAudio, CueAudioProbe {
  @override
  final List<String> spoken = <String>[];
  final List<HeldCue> cues = <HeldCue>[];
  @override
  int stops = 0;

  @override
  Future<void> speak(String word) {
    spoken.add(word);
    final Completer<Object?> settle = Completer<Object?>();
    final HeldCue cue = HeldCue(settle);
    cues.add(cue);
    final Future<void> delivery = settle.future.then((Object? _) {});
    // Quiet observer: a late error release must never become an unhandled
    // async failure, regardless of how soon (or never) the caller is
    // listening.
    unawaited(
        delivery.then<void>((Object? value) {}, onError: (Object error) {}));
    return delivery;
  }

  @override
  Future<void> stop() {
    // Stop is recorded; the request stays retained and settles later,
    // really — that is the stale-settlement shape callers must survive.
    stops++;
    return Future<void>.value();
  }
}

/// Drain microtasks with real frames so gate releases settle deterministically.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

bool answerEnabled(WidgetTester tester, String sound) {
  final Finder buttons = find.ancestor(
    of: find.text('/$sound/'),
    matching: find.byType(OutlinedButton),
  );
  final OutlinedButton button = tester.widget<OutlinedButton>(buttons);
  final void Function()? pressed = button.onPressed;
  return pressed != null;
}

Future<CourseAudio> openLesson(
  WidgetTester tester,
  GlobalKey<NavigatorState> navigator,
  CourseAudio audio,
) async {
  await tester.pumpWidget(ProviderScope(
    overrides: <Override>[
      courseAudioProvider.overrideWithValue(audio),
      courseLearningStoreProvider
          .overrideWithValue(CourseLearningWidgetStore()),
    ],
    child: MaterialApp(
      navigatorKey: navigator,
      home: const CourseLessonScreen(lessonId: 'en-fr-vowels'),
    ),
  ));
  await settle(tester);
  return audio;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('the lesson listening surface pins the exact alpha disclosure',
      (WidgetTester tester) async {
    await openLesson(tester, GlobalKey<NavigatorState>(), CancellingCueAudio());
    expect(
      find.text(alphaDisclosure),
      findsOneWidget,
      reason: 'listening surfaces must carry the exact alpha label',
    );
  });

  testWidgets('held completion keeps the choices locked until actual success',
      (WidgetTester tester) async {
    final HeldCueAudio fake = HeldCueAudio();
    await openLesson(tester, GlobalKey<NavigatorState>(), fake);
    await tester.tap(find.text('Listen to French word'));
    await settle(tester);
    expect(fake.spoken, <String>['lit']);
    // Held: busy state, nothing unlocked, no feedback text yet.
    expect(find.text('Please wait…'), findsOneWidget);
    expect(
      answerEnabled(tester, 'i'),
      isFalse,
      reason: 'a held playback must not unlock the choices',
    );
    // The late success unlocks exactly the listening gate.
    fake.cues[0].release();
    await settle(tester);
    expect(
      answerEnabled(tester, 'i'),
      isTrue,
      reason: 'an actual completion unlocks the choices',
    );
    expect(find.text('Please wait…'), findsNothing);
  });

  testWidgets('a failed recording shows Retry/unavailable, not voice setup',
      (WidgetTester tester) async {
    final HeldCueAudio fake = HeldCueAudio();
    await openLesson(tester, GlobalKey<NavigatorState>(), fake);
    await tester.tap(find.text('Listen to French word'));
    await settle(tester);
    fake.cues[0].release(StateError('asset playback failed'));
    await settle(tester);
    expect(
      find.textContaining('Install a French voice'),
      findsNothing,
      reason: 'a bundled-recording failure is never a voice-installation '
          'instruction',
    );
    expect(
      find.textContaining('unavailable'),
      findsOneWidget,
      reason: 'the surface must say the audio is unavailable now',
    );
    expect(
      find.textContaining('try again'),
      findsOneWidget,
      reason: 'a failed recording must stay retryable',
    );
    expect(
      answerEnabled(tester, 'i'),
      isFalse,
      reason: 'a failed playback must not unlock the choices',
    );
    // Retry re-runs the same listening flow against the new owner.
    await tester.tap(find.text('Listen to French word'));
    await settle(tester);
    expect(fake.spoken, <String>['lit', 'lit']);
    fake.cues[1].release();
    await settle(tester);
    expect(answerEnabled(tester, 'i'), isTrue);
  });

  testWidgets(
      'a realistically cancelled playback is silent: no failure '
      'feedback, still retryable', (WidgetTester tester) async {
    final CancellingCueAudio fake = CancellingCueAudio();
    await openLesson(tester, GlobalKey<NavigatorState>(), fake);
    await tester.tap(find.text('Listen to French word'));
    await settle(tester);
    // The shared player owns cancellation: Stop invalidates the held
    // request and the caller treats it as neither success nor failure.
    fake.stop();
    await settle(tester);
    expect(
      find.textContaining('unavailable'),
      findsNothing,
      reason: 'a user/system cancellation must not display an audio failure',
    );
    expect(
      find.textContaining('Install a French voice'),
      findsNothing,
      reason: 'cancellation is never misreported as a voice problem',
    );
    expect(
      answerEnabled(tester, 'i'),
      isFalse,
      reason: 'a cancelled playback must never mark audio heard',
    );
    expect(fake.stops, 1);
    // Listening stays retryable after a cancellation.
    await tester.tap(find.text('Listen to French word'));
    await settle(tester);
    expect(fake.spoken, hasLength(2));
    fake.release();
    await settle(tester);
    expect(answerEnabled(tester, 'i'), isTrue);
  });

  testWidgets(
      'app suspension retires a held playback: stopped, retryable, '
      'and a stale success during a newer held request cannot unlock',
      (WidgetTester tester) async {
    final HeldCueAudio fake = HeldCueAudio();
    await openLesson(tester, GlobalKey<NavigatorState>(), fake);
    await tester.tap(find.text('Listen to French word'));
    await settle(tester);
    expect(find.text('Please wait…'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await settle(tester);
    expect(
      fake.stops,
      greaterThanOrEqualTo(1),
      reason: 'suspending the app must stop the in-flight playback',
    );
    expect(
      find.text('Please wait…'),
      findsNothing,
      reason: 'the retired request must leave the listener retryable',
    );
    expect(
      answerEnabled(tester, 'i'),
      isFalse,
      reason: 'suspension must never mark playback heard',
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(
      find.text('Please wait…'),
      findsNothing,
      reason: 'no automatic replay on resume: a fresh listen is required',
    );
    expect(fake.spoken, hasLength(1),
        reason: 'resume must not replay the retired request');

    // A newer, current request: the retired one's late success (really
    // settled after its retirement) must not touch this one.
    await tester.tap(find.text('Listen to French word'));
    await settle(tester);
    expect(fake.spoken, hasLength(2));
    expect(find.text('Please wait…'), findsOneWidget);
    fake.cues[0].release();
    await settle(tester);
    expect(
      find.text('Please wait…'),
      findsOneWidget,
      reason: 'a stale success must not clear a newer request',
    );
    expect(
      answerEnabled(tester, 'i'),
      isFalse,
      reason: 'a stale success must not unlock the choices',
    );
    fake.cues[1].release();
    await settle(tester);
    expect(
      answerEnabled(tester, 'i'),
      isTrue,
      reason: 'only the current request may complete and unlock',
    );
  });

  testWidgets(
      'a stale error after suspension cannot publish failure '
      'feedback or unlock', (WidgetTester tester) async {
    final HeldCueAudio fake = HeldCueAudio();
    await openLesson(tester, GlobalKey<NavigatorState>(), fake);
    await tester.tap(find.text('Listen to French word'));
    await settle(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await settle(tester);
    expect(fake.stops, greaterThanOrEqualTo(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    await tester.tap(find.text('Listen to French word'));
    await settle(tester);
    expect(fake.spoken, hasLength(2));
    expect(find.text('Please wait…'), findsOneWidget);
    fake.cues[0].release(StateError('late engine failure'));
    await settle(tester);
    expect(
      find.textContaining('unavailable'),
      findsNothing,
      reason: 'a stale error must not publish failure feedback over a '
          'newer request',
    );
    expect(
      find.textContaining('Install a French voice'),
      findsNothing,
      reason: 'a stale error is never presented as a voice problem',
    );
    expect(
      find.text('Please wait…'),
      findsOneWidget,
      reason: 'a stale error must not clear a newer request',
    );
    expect(answerEnabled(tester, 'i'), isFalse);
    fake.cues[1].release();
    await settle(tester);
    expect(answerEnabled(tester, 'i'), isTrue);
  });

  final List<(Object?, CueFactory, String)> lateCases =
      <(Object?, CueFactory, String)>[
    (null, () => HeldCueAudio(), 'success'),
    (StateError('late engine failure'), () => HeldCueAudio(), 'error'),
    (
      const CourseAudioCancelledException(),
      () => CancellingCueAudio(),
      'cancellation'
    ),
  ];
  for (final (Object? lateError, CueFactory makeFake, String label)
      in lateCases) {
    testWidgets(
        'a late $label settlement after leaving the lesson '
        'settles quietly', (WidgetTester tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final CueAudioProbe fake = makeFake();
      await tester.pumpWidget(ProviderScope(
        overrides: <Override>[
          courseAudioProvider.overrideWithValue(fake),
          courseLearningStoreProvider
              .overrideWithValue(CourseLearningWidgetStore()),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          home: Builder(builder: (BuildContext context) {
            return TextButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<Widget>(
                      builder: (_) =>
                          const CourseLessonScreen(lessonId: 'en-fr-vowels'))),
              child: const Text('Open lesson'),
            );
          }),
        ),
      ));
      await settle(tester);
      await tester.tap(find.text('Open lesson'));
      // Let the route transition finish before interacting.
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to French word'));
      await settle(tester);
      expect(fake.spoken, <String>['lit']);

      // Leave while the playback is still held; wait for the element to be
      // disposed (the route-removal transition must finish).
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(
        fake.stops,
        greaterThanOrEqualTo(1),
        reason: 'leaving the lesson must stop its audio',
      );

      // The held request now settles FOR REAL after retirement: nothing may
      // leak an unhandled error or mutate the departed screen.
      if (fake is CancellingCueAudio) {
        fake.release(lateError);
      } else {
        (fake as HeldCueAudio).cues[0].release(lateError);
      }
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

typedef CueFactory = CueAudioProbe Function();
