// FR-03 Task 4: minimal-pair drill lifecycle with the default (shared)
// player.
//
// Screen-level behavior over the REAL [DrillScreen]. The first drill pair
// uses the unmapped drill word `roue`, so the practice-speech fallback path
// is the one under test: the surface must never present it as a reviewed or
// human recording — the exact alpha disclosure says device speech is
// practice-only. Gate-controlled boundary audio proves: held completion
// locking, the Play/Stop control retiring in-flight playback, source-
// appropriate failure guidance with no wrong-answer outcome, and
// end-session/dispose retiring audio so a late settlement can never mark
// heard or unlock the choices.
//
// RED note: on the pre-Task-4 baseline the exact-disclosure assertion
// fails (no label), the Stop-control and end/dispose assertions fail
// (the old screen never stops in-flight audio), and the late-success
// assertion fails (the old screen marks a stale request heard).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/models/minimal_pair.dart';
import 'package:linguist/src/core/providers/app_providers.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/features/drills/drill_screen.dart';
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

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

const List<MinimalPair> drillPairs = <MinimalPair>[
  MinimalPair(
      id: 'test-roue-rue',
      wordA: 'roue',
      wordB: 'rue',
      phonemeA: '/u/',
      phonemeB: '/y/'),
  MinimalPair(
      id: 'test-tu-tout',
      wordA: 'tu',
      wordB: 'tout',
      phonemeA: '/y/',
      phonemeB: '/u/'),
];

class DrillHarness {
  DrillHarness(this.navigator, this.audio);

  final GlobalKey<NavigatorState> navigator;
  final GateAudio audio;

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        minimalPairsProvider.overrideWith((ref) => Future.value(drillPairs)),
        courseAudioProvider.overrideWithValue(audio),
      ],
      child: MaterialApp(
        navigatorKey: navigator,
        home: const DrillScreen(),
      ),
    ));
    await settle(tester);
  }
}

bool optionEnabled(WidgetTester tester, String option) {
  final Finder buttons = find.ancestor(
    of: find.text(option),
    matching: find.byType(FilledButton),
  );
  final FilledButton button = tester.widget<FilledButton>(buttons);
  final void Function()? pressed = button.onPressed;
  return pressed != null;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets(
      'the drill pins the exact alpha disclosure and never claims a '
      'reviewed or human recording for the unmapped practice speech',
      (WidgetTester tester) async {
    final GateAudio audio = GateAudio();
    final DrillHarness harness = DrillHarness(
        GlobalKey<NavigatorState>(), audio);
    await harness.pump(tester);
    // 'roue' is item 1: unmapped, so the practice-speech fallback is the
    // path under test.
    expect(find.text('Item 1'), findsOneWidget);
    expect(
      find.text(alphaDisclosure),
      findsOneWidget,
      reason: 'the drill surface must carry the exact alpha label',
    );
    expect(
      find.textContaining('human recording'),
      findsNothing,
      reason: 'device speech must never be presented as a human recording',
    );
    expect(
      find.textContaining('reviewed recording'),
      findsNothing,
      reason: 'the practice fallback is unverified, not reviewed',
    );
  });

  testWidgets(
      'Play holds the choices locked; a late success unlocks only after '
      'the request still owns the screen', (WidgetTester tester) async {
    final GateAudio audio = GateAudio();
    final DrillHarness harness = DrillHarness(
        GlobalKey<NavigatorState>(), audio);
    await harness.pump(tester);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);
    expect(audio.spoken, <String>['roue']);
    expect(find.byIcon(Icons.stop), findsOneWidget);
    expect(
      optionEnabled(tester, 'roue'),
      isFalse,
      reason: 'a held playback must not unlock the choices',
    );
    audio.release();
    await settle(tester);
    expect(
      optionEnabled(tester, 'roue'),
      isTrue,
      reason: 'an actual completion unlocks the choices',
    );
  });

  testWidgets('the Stop control retires in-flight playback: no heard mark, '
      'no unlock, no failure snackbar', (WidgetTester tester) async {
    final GateAudio audio = GateAudio();
    final DrillHarness harness =
        DrillHarness(GlobalKey<NavigatorState>(), audio);
    await harness.pump(tester);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);
    expect(audio.spoken, <String>['roue']);
    // The Stop control retires the held request.
    await tester.tap(find.byIcon(Icons.stop));
    await settle(tester);
    expect(
      audio.stops,
      greaterThanOrEqualTo(1),
      reason: 'the Stop control must actually stop the shared playback',
    );
    // The engine still settles late; the retiring screen must ignore it.
    audio.release(const CourseAudioCancelledException());
    audio.release();
    await settle(tester);
    expect(
      find.text('French audio unavailable. Please retry.'),
      findsNothing,
      reason: 'a user stop must not surface as an audio failure',
    );
    expect(
      optionEnabled(tester, 'roue'),
      isFalse,
      reason: 'a stopped request must never mark audio heard',
    );
    // Retry is open after a stop.
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);
    expect(audio.spoken, hasLength(2));
    audio.release();
    await settle(tester);
    expect(optionEnabled(tester, 'roue'), isTrue);
  });

  testWidgets(
      'a failed speech keeps the practice-retry guidance and records no '
      'wrong-answer outcome', (WidgetTester tester) async {
    final GateAudio audio = GateAudio();
    final DrillHarness harness =
        DrillHarness(GlobalKey<NavigatorState>(), audio);
    await harness.pump(tester);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);
    audio.release(StateError('speech engine failed'));
    await settle(tester);
    expect(
      find.text('French audio unavailable. Please retry.'),
      findsOneWidget,
      reason: 'a failed practice speech stays retryable',
    );
    expect(
      optionEnabled(tester, 'roue'),
      isFalse,
      reason: 'a failed playback must not unlock the choices',
    );
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getInt('current_streak'),
      isNull,
      reason: 'a failed playback records no practice outcome',
    );
    // Retry stays available against the same drill item.
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);
    expect(audio.spoken, hasLength(2));
    audio.release();
    await settle(tester);
    expect(optionEnabled(tester, 'roue'), isTrue);
  });

  testWidgets(
      'End Session retires in-flight audio and books practice exactly '
      'once', (WidgetTester tester) async {
    final GateAudio audio = GateAudio();
    final DrillHarness harness = DrillHarness(
        GlobalKey<NavigatorState>(), audio);
    await harness.pump(tester);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);
    await tester.tap(find.text('End Session'));
    await settle(tester);
    expect(
      find.textContaining('Session complete'),
      findsOneWidget,
      reason: 'End Session books the practice streak',
    );
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('current_streak'), 1);
    // The in-flight audio is retired before the screen exits.
    expect(
      audio.stops,
      greaterThanOrEqualTo(1),
      reason: 'End Session must stop in-flight playback',
    );
    // The engine settles late after the session ended: quiet on both sides.
    audio.release();
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('leaving the drill retires in-flight audio and a late '
      'settlement stays quiet', (WidgetTester tester) async {
    final GateAudio audio = GateAudio();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        minimalPairsProvider.overrideWith((ref) => Future.value(drillPairs)),
        courseAudioProvider.overrideWithValue(audio),
      ],
      child: MaterialApp(
        navigatorKey: navigator,
        home: Builder(builder: (BuildContext context) {
          return TextButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<Widget>(
                    builder: (_) => const DrillScreen())),
            child: const Text('Open drill'),
          );
        }),
      ),
    ));
    await settle(tester);
    await tester.tap(find.text('Open drill'));
    await tester.pumpAndSettle(); // let the route transition settle before tapping
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);
    expect(audio.spoken, <String>['roue']);
    navigator.currentState!.pop();
    // The route-removal transition must finish for the drill element to
    // dispose; two micro-pumps are not the 300ms transition.
    await tester.pumpAndSettle();
    expect(
      audio.stops,
      greaterThanOrEqualTo(1),
      reason: 'leaving the drill must stop its audio',
    );
    // Late settlements must stay quiet after disposal.
    audio.release();
    await settle(tester);
    expect(tester.takeException(), isNull);
    audio.release(StateError('late engine failure'));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
