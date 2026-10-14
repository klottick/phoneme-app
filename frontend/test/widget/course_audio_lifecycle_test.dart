// FR-03 Task 4: listener-lesson lifecycle with the default (shared) player.
//
// Screen-level behavior over the REAL [CourseLessonScreen] with only the
// plugin boundary replaced: a gate-controlled [CourseAudio] double decides
// when playback settles, and with what outcome (success, an engine error,
// or cancellation). Proves held-completion locking, source-appropriate
// failure guidance (recording Retry guidance, never a voice installation),
// cancellation silence, the exact alpha disclosure, and late-settlement
// safety after leaving the lesson.
//
// RED note: on the pre-Task-4 baseline the exact-disclosure and
// source-appropriate-guidance assertions fail against the old voice-setup
// copy; the cancellation assertion fails because the old caller displays a
// failure for a cancelled request.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/features/course/course_lesson_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String alphaDisclosure =
    'Alpha audio: recordings are unverified; device speech is practice-only.';

/// Gate-controlled [CourseAudio] boundary double: the test decides when a
/// requested playback settles and with what outcome (success, an engine
/// error, or cancellation). [stop] cancels the held request exactly like
/// the shared player's stop semantics.
class GateAudio implements CourseAudio {
  final List<String> spoken = <String>[];
  int stops = 0;
  Completer<Object?>? _pending;

  @override
  Future<void> speak(String word) {
    spoken.add(word);
    final Completer<Object?> settle = Completer<Object?>();
    _pending = settle;
    return settle.future.then((Object? _) {});
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

Future<GateAudio> openLesson(
  WidgetTester tester,
  GlobalKey<NavigatorState> navigator,
) async {
  final GateAudio fake = GateAudio();
  await tester.pumpWidget(ProviderScope(
    overrides: <Override>[courseAudioProvider.overrideWithValue(fake)],
    child: MaterialApp(
      navigatorKey: navigator,
      home: const CourseLessonScreen(lessonId: 'en-fr-vowels'),
    ),
  ));
  await settle(tester);
  return fake;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('the lesson listening surface pins the exact alpha disclosure',
      (WidgetTester tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await openLesson(tester, navigator);
    expect(
      find.text(alphaDisclosure),
      findsOneWidget,
      reason: 'listening surfaces must carry the exact alpha label',
    );
  });

  testWidgets('held completion keeps the choices locked until actual success',
      (WidgetTester tester) async {
    final GateAudio fake =
        await openLesson(tester, GlobalKey<NavigatorState>());
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
    fake.release();
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
    final GateAudio fake =
        await openLesson(tester, GlobalKey<NavigatorState>());
    await tester.tap(find.text('Listen to French word'));
    await settle(tester);
    fake.release(StateError('asset playback failed'));
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
    fake.release();
    await settle(tester);
    expect(answerEnabled(tester, 'i'), isTrue);
  });

  testWidgets('a cancelled playback is silent: no failure feedback, '
      'still retryable', (WidgetTester tester) async {
    final GateAudio fake =
        await openLesson(tester, GlobalKey<NavigatorState>());
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

  final List<(Object?, String)> lateCases = <(Object?, String)>[
    (null, 'success'),
    (StateError('late engine failure'), 'error'),
    (const CourseAudioCancelledException(), 'cancellation'),
  ];
  for (final (Object? lateError, String label) in lateCases) {
    testWidgets('a late $label settlement after leaving the lesson '
        'settles quietly', (WidgetTester tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final GateAudio fake = GateAudio();
      await tester.pumpWidget(ProviderScope(
        overrides: <Override>[courseAudioProvider.overrideWithValue(fake)],
        child: MaterialApp(
          navigatorKey: navigator,
          home: Builder(builder: (BuildContext context) {
            return TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<
                  Widget>(builder: (_) => const CourseLessonScreen(
                      lessonId: 'en-fr-vowels'))),
              child: const Text('Open lesson'),
            );
          }),
        ),
      ));
      await settle(tester);
      await tester.tap(find.text('Open lesson'));
      await settle(tester);
      await tester.tap(find.text('Listen to French word'));
      await settle(tester);
      expect(fake.spoken, <String>['lit']);

      // Leave while the playback is still held.
      navigator.currentState!.pop();
      await settle(tester);
      expect(
        fake.stops,
        greaterThanOrEqualTo(1),
        reason: 'leaving the lesson must stop its audio',
      );

      // The held request settles late: nothing may leak an unhandled error
      // or mutate the departed screen.
      fake.release(lateError);
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
