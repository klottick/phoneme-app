// FR-03 Task 4 (fix round 1): minimal-pair drill lifecycle with the default
// (shared) player.
//
// Screen-level behavior over the REAL [DrillScreen]. The first drill pair
// uses the unmapped drill word `roue`, so the practice-speech fallback path
// is the one under test: the surface must never present it as a reviewed or
// human recording — the exact alpha disclosure says device speech is
// practice-only.
//
// Boundary doubles (I3 fix): [CancellingCueAudio] is the realistic facade
// shape (Stop hands the caller a cancellation terminal); [HeldCueAudio] is
// the adversarial compatible shape — Stop only records itself, each request
// is retained per cue and REALLY settles (success or an exact engine error)
// after retirement, while a newer request may be held. A stale settlement
// must never publish heard/unlock/feedback, clear a newer request, or leak
// an unhandled error.
//
// RED note (fix round 1): on the pre-fix code the suspension assertions
// fail (the screen never observed the lifecycle: no stop, a late success
// still unlocked); the Stop/End/leaving tests with the pre-fix
// self-cancelling double had release calls that were no-ops, so they never
// actually delivered a late settlement.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/models/minimal_pair.dart';
import 'package:linguist/src/core/providers/app_providers.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_progress.dart';
import 'package:linguist/src/core/services/streak_service.dart';
import 'package:linguist/src/features/drills/drill_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String alphaDisclosure =
    'Alpha audio: recordings are unverified; device speech is practice-only.';

/// Realistic prompt cancellation: [stop] invalidates the held request now
/// (the facade hands the caller its cancellation terminal).
final class CancellingCueAudio implements CourseAudio {
  final List<String> spoken = <String>[];
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
/// [speak] retains a per-request cue; [stop] only records itself; the cues
/// then really settle with success or an exact error — each must be
/// survivable by the caller's generation guard.
final class HeldCueAudio implements CourseAudio {
  final List<String> spoken = <String>[];
  final List<HeldCue> cues = <HeldCue>[];
  int stops = 0;

  @override
  Future<void> speak(String word) {
    spoken.add(word);
    final Completer<Object?> settle = Completer<Object?>();
    final HeldCue cue = HeldCue(settle);
    cues.add(cue);
    final Future<void> delivery = settle.future.then((Object? _) {});
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

/// One held persistence call of [HeldStreakService]: the future really
/// stays pending until [release] settles it — with success or a genuine
/// error. The quiet observer is attached at creation, BEFORE any release
/// can settle with an error.
final class HeldRelease {
  final Completer<void> _settle = Completer<void>();

  HeldRelease() {
    unawaited(
        _settle.future.then<void>((void value) {}, onError: (Object error) {}));
  }

  bool get held => !_settle.isCompleted;

  Future<void> get future => _settle.future;

  void release([Object? error]) {
    if (_settle.isCompleted) return;
    if (error == null) {
      _settle.complete();
    } else {
      _settle.completeError(error);
    }
  }
}

/// Streak-persistence boundary for the End-Session guard (R2): each
/// `recordPractice` call is genuinely HELD until its [HeldRelease] is
/// settled, so the screen's await window is deterministic and observable.
/// No production [StreakService] API change — only the existing
/// `streakServiceProvider` override seam is used.
class HeldStreakService extends StreakService {
  final List<HeldRelease> releases = <HeldRelease>[];

  int get recordCalls => releases.length;

  @override
  Future<void> recordPractice() {
    final HeldRelease release = HeldRelease();
    releases.add(release);
    return release.future;
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
  final CourseAudio audio;

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
    final DrillHarness harness =
        DrillHarness(GlobalKey<NavigatorState>(), HeldCueAudio());
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
      'Play holds the choices locked; an actual completion unlocks only '
      'while that request still owns the screen', (WidgetTester tester) async {
    final HeldCueAudio audio = HeldCueAudio();
    final DrillHarness harness =
        DrillHarness(GlobalKey<NavigatorState>(), audio);
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
    audio.cues[0].release();
    await settle(tester);
    expect(
      optionEnabled(tester, 'roue'),
      isTrue,
      reason: 'an actual completion unlocks the choices',
    );
  });

  testWidgets(
      'answer-save ownership rejects cached Play callbacks before and after advancement',
      (WidgetTester tester) async {
    final HeldCueAudio audio = HeldCueAudio();
    final DrillHarness harness =
        DrillHarness(GlobalKey<NavigatorState>(), audio);
    await harness.pump(tester);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);
    audio.cues.single.release();
    await settle(tester);
    final IconButton play = tester.widget<IconButton>(find.byType(IconButton));
    final FilledButton answer = tester.widget<FilledButton>(find.ancestor(
        of: find.text('roue'), matching: find.byType(FilledButton)));
    final VoidCallback savedPlay = play.onPressed!;
    final VoidCallback savedAnswer = answer.onPressed!;

    savedAnswer();
    savedPlay();
    expect(audio.spoken, <String>['roue'],
        reason: 'the answer transition must own A before persistence yields');
    await settle(tester);
    expect(find.text('Item 2'), findsOneWidget);
    savedPlay();
    await settle(tester);
    expect(audio.spoken, <String>['roue'],
        reason: 'a stale A callback cannot replay over B');
    expect(optionEnabled(tester, 'tu'), isFalse,
        reason: 'B requires its own completed listen');
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);
    expect(audio.spoken, <String>['roue', 'tu']);
    audio.cues.last.release();
    await settle(tester);
    expect(optionEnabled(tester, 'tu'), isTrue);
  });

  testWidgets(
      'Stop retires in-flight playback; a really released stale '
      'error of the old request cannot surface over the newer held one',
      (WidgetTester tester) async {
    final HeldCueAudio audio = HeldCueAudio();
    final DrillHarness harness =
        DrillHarness(GlobalKey<NavigatorState>(), audio);
    await harness.pump(tester);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);
    expect(audio.spoken, <String>['roue']);
    // The Stop control retires the held request (recorded stop).
    await tester.tap(find.byIcon(Icons.stop));
    await settle(tester);
    expect(
      audio.stops,
      greaterThanOrEqualTo(1),
      reason: 'the Stop control must actually stop the shared playback',
    );
    expect(
      find.text('French audio unavailable. Please retry.'),
      findsNothing,
      reason: 'a user stop must not surface as an audio failure',
    );
    expect(optionEnabled(tester, 'roue'), isFalse);
    // Retry is open after a stop: a newer request is now held.
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);
    expect(audio.spoken, hasLength(2));
    expect(find.byIcon(Icons.stop), findsOneWidget);
    // The OLD request now settles for real, with an engine error, while the
    // newer one is still held: it must stay the newer request's own state.
    audio.cues[0].release(StateError('late engine failure'));
    await settle(tester);
    expect(
      find.text('French audio unavailable. Please retry.'),
      findsNothing,
      reason: 'a stale error must not publish failure over the newer '
          'request',
    );
    expect(
      find.byIcon(Icons.stop),
      findsOneWidget,
      reason: 'a stale error must not end the newer held playback',
    );
    expect(
      optionEnabled(tester, 'roue'),
      isFalse,
      reason: 'a stale settlement must never mark audio heard',
    );
    audio.cues[1].release();
    await settle(tester);
    expect(optionEnabled(tester, 'roue'), isTrue);
  });

  testWidgets(
      'a stale SUCCESS of a retired request during a newer held '
      'attempt cannot unlock', (WidgetTester tester) async {
    final HeldCueAudio audio = HeldCueAudio();
    final DrillHarness harness =
        DrillHarness(GlobalKey<NavigatorState>(), audio);
    await harness.pump(tester);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.stop));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);
    expect(audio.spoken, hasLength(2));
    // The OLD request settles with success, really, while the newer one is
    // still held.
    audio.cues[0].release();
    await settle(tester);
    expect(
      optionEnabled(tester, 'roue'),
      isFalse,
      reason: 'a stale success must not unlock the choices',
    );
    expect(find.byIcon(Icons.stop), findsOneWidget,
        reason: 'a stale success must not end the newer held playback');
    audio.cues[1].release();
    await settle(tester);
    expect(optionEnabled(tester, 'roue'), isTrue);
  });

  testWidgets(
      'a failed speech keeps the practice-retry guidance and records no '
      'wrong-answer outcome', (WidgetTester tester) async {
    final HeldCueAudio audio = HeldCueAudio();
    final DrillHarness harness =
        DrillHarness(GlobalKey<NavigatorState>(), audio);
    await harness.pump(tester);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);
    audio.cues[0].release(StateError('speech engine failed'));
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
    audio.cues[1].release();
    await settle(tester);
    expect(optionEnabled(tester, 'roue'), isTrue);
  });

  final List<Object?> endOutcomes = <Object?>[
    null,
    StateError('late engine failure'),
  ];
  for (final Object? outcome in endOutcomes) {
    testWidgets(
        'End Session retires in-flight audio (late ${outcome == null ? 'success' : 'error'} release stays quiet) and books practice exactly once',
        (WidgetTester tester) async {
      final HeldCueAudio audio = HeldCueAudio();
      final DrillHarness harness =
          DrillHarness(GlobalKey<NavigatorState>(), audio);
      await harness.pump(tester);
      await tester.tap(find.byIcon(Icons.play_arrow));
      await settle(tester);
      await tester.tap(find.text('End Session'));
      // Assert inside the snackbar's display window (the screen leaves a
      // few frames later in this harness).
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
      // The engine settles late after the session ended — for real now:
      // quiet, no exception.
      audio.cues[0].release(outcome);
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  final List<Object?> leaveOutcomes = <Object?>[
    null,
    StateError('late engine failure'),
  ];
  for (final Object? outcome in leaveOutcomes) {
    testWidgets(
        'leaving the drill retires in-flight audio and a really '
        'late ${outcome == null ? 'success' : 'error'} settlement stays quiet',
        (WidgetTester tester) async {
      final HeldCueAudio audio = HeldCueAudio();
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
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open drill'));
      await tester.pumpAndSettle(); // route transition before interacting
      await tester.tap(find.byIcon(Icons.play_arrow));
      await settle(tester);
      expect(audio.spoken, <String>['roue']);
      navigator.currentState!.pop();
      await tester.pumpAndSettle(); // disposal needs the full transition
      expect(
        audio.stops,
        greaterThanOrEqualTo(1),
        reason: 'leaving the drill must stop its audio',
      );
      // Late settlements must stay quiet after disposal — delivered for
      // real, with success or the exact failure.
      audio.cues[0].release(outcome);
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'leaving the drill after a realistic cancellation stays '
      'quiet', (WidgetTester tester) async {
    final CancellingCueAudio audio = CancellingCueAudio();
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
                MaterialPageRoute<Widget>(builder: (_) => const DrillScreen())),
            child: const Text('Open drill'),
          );
        }),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open drill'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);
    expect(audio.spoken, <String>['roue']);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(audio.stops, greaterThanOrEqualTo(1));
    // The prompt cancellation terminal settles into a disposed listener.
    audio.release();
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'app suspension retires a held playback: stopped, retryable, '
      'and stale success during a newer attempt cannot unlock',
      (WidgetTester tester) async {
    final HeldCueAudio audio = HeldCueAudio();
    final DrillHarness harness =
        DrillHarness(GlobalKey<NavigatorState>(), audio);
    await harness.pump(tester);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);
    expect(find.byIcon(Icons.stop), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await settle(tester);
    expect(
      audio.stops,
      greaterThanOrEqualTo(1),
      reason: 'suspending the app must stop the in-flight playback',
    );
    expect(find.byIcon(Icons.play_arrow), findsOneWidget,
        reason: 'the retired request must not look like an active playback');
    expect(optionEnabled(tester, 'roue'), isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(
      optionEnabled(tester, 'roue'),
      isFalse,
      reason: 'resuming must require a fresh listen, never auto-replay',
    );
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(audio.spoken, hasLength(1),
        reason: 'resume must not replay the retired request');

    // A newer attempt: the retired request's late success (really settled
    // after its retirement) must not touch it.
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);
    expect(audio.spoken, hasLength(2));
    audio.cues[0].release();
    await settle(tester);
    expect(
      optionEnabled(tester, 'roue'),
      isFalse,
      reason: 'a stale success must not unlock the choices',
    );
    expect(find.byIcon(Icons.stop), findsOneWidget,
        reason: 'a stale success must not end the newer held playback');
    audio.cues[1].release();
    await settle(tester);
    expect(optionEnabled(tester, 'roue'), isTrue);
  });

  testWidgets(
      'a stale error after suspension cannot publish failure '
      'feedback over a newer held attempt', (WidgetTester tester) async {
    final HeldCueAudio audio = HeldCueAudio();
    final DrillHarness harness =
        DrillHarness(GlobalKey<NavigatorState>(), audio);
    await harness.pump(tester);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await settle(tester);
    expect(audio.stops, greaterThanOrEqualTo(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);
    expect(audio.spoken, hasLength(2));
    expect(find.byIcon(Icons.stop), findsOneWidget);
    audio.cues[0].release(StateError('late engine failure'));
    await settle(tester);
    expect(
      find.text('French audio unavailable. Please retry.'),
      findsNothing,
      reason: 'a stale error must not publish failure over the newer '
          'request',
    );
    expect(
      find.byIcon(Icons.stop),
      findsOneWidget,
      reason: 'a stale error must not end the newer held playback',
    );
    expect(optionEnabled(tester, 'roue'), isFalse);
    audio.cues[1].release();
    await settle(tester);
    expect(optionEnabled(tester, 'roue'), isTrue);
  });

  // ---------- R2 (fix round 2): the synchronous single-shot ending state ----------

  Future<GlobalKey<NavigatorState>> pumpDrillRoute(
    WidgetTester tester,
    HeldCueAudio audio,
    HeldStreakService streak,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[
        minimalPairsProvider.overrideWith((ref) => Future.value(drillPairs)),
        courseAudioProvider.overrideWithValue(audio),
        streakServiceProvider.overrideWithValue(streak),
      ],
      child: MaterialApp(
        navigatorKey: navigator,
        home: Builder(builder: (BuildContext context) {
          return TextButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<Widget>(builder: (_) => const DrillScreen())),
            child: const Text('Open drill'),
          );
        }),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open drill'));
    await tester.pumpAndSettle(); // route transition before interacting
    return navigator;
  }

  testWidgets(
      'End Session: while the persistence await is genuinely held, '
      'no new play/answer/End is admitted and a late A SUCCESS stays stale',
      (WidgetTester tester) async {
    final HeldCueAudio audio = HeldCueAudio();
    final HeldStreakService streak = HeldStreakService();
    await pumpDrillRoute(tester, audio, streak);
    // Start request A and hold it, then End the session.
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);
    expect(audio.spoken, <String>['roue']);
    await tester.tap(find.text('End Session'));
    await settle(tester);
    expect(streak.recordCalls, 1,
        reason: 'a user end books the streak exactly once');
    expect(streak.releases[0].held, isTrue,
        reason: 'the persistence await is genuinely held for this test');
    // Held across frames: no banner, no exit, and the screen must admit
    // NO new work (R2).
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Session complete'), findsNothing,
        reason: 'no completion banner may appear while the await is held');
    expect(find.text('Open drill'), findsNothing,
        reason: 'no exit may happen while the await is held');
    // A really late SUCCESS of the retired A during ending stays stale.
    audio.cues[0].release();
    await settle(tester);
    expect(optionEnabled(tester, 'roue'), isFalse,
        reason: 'a late success during ending must not unlock the choices');
    // New Play is rejected: no B dispatch.
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);
    expect(audio.spoken, <String>['roue'],
        reason: 'ending must reject a new playback request (no B dispatch)');
    // Answers stay blocked: no new evidence.
    final data = await CourseProgressStore('en-fr').load();
    expect(data['evidence'], isEmpty,
        reason: 'no answer may land while ending');
    // End re-entry is rejected: no duplicate booking.
    await tester.tap(find.text('End Session'));
    await settle(tester);
    expect(streak.recordCalls, 1,
        reason: 'no duplicate end operation while the first is in flight');
    // Now release the persistence: exactly one banner, one exit, one booking.
    streak.releases[0].release();
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Session complete'), findsOneWidget,
        reason: 'the successful end shows its banner');
    await tester.pumpAndSettle();
    expect(find.text('Open drill'), findsOneWidget,
        reason: 'the successful end exits exactly once (real route)');
    expect(streak.recordCalls, 1, reason: 'exactly one booking');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'End Session: a late A ERROR during ending stays silent and '
      'the exit is still governed by the persistence outcome',
      (WidgetTester tester) async {
    final HeldCueAudio audio = HeldCueAudio();
    final HeldStreakService streak = HeldStreakService();
    await pumpDrillRoute(tester, audio, streak);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);
    await tester.tap(find.text('End Session'));
    await settle(tester);
    expect(streak.recordCalls, 1);
    // The old request settles with a REAL engine error while ending.
    audio.cues[0].release(StateError('late engine failure'));
    await settle(tester);
    expect(find.text('French audio unavailable. Please retry.'), findsNothing,
        reason: 'a stale error of the retired request must not surface');
    expect(find.textContaining('Session complete'), findsNothing,
        reason: 'a late failure is not a successful end');
    expect(find.text('Open drill'), findsNothing,
        reason: 'a late failure must not exit the session');
    expect(optionEnabled(tester, 'roue'), isFalse,
        reason: 'a stale error must not unlock the choices');
    // The persistence release is what ends the session — success exits once.
    streak.releases[0].release();
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Session complete'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Open drill'), findsOneWidget);
    expect(streak.recordCalls, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'End Session after a completed listen: hearing is cleared '
      'synchronously and cached callbacks cannot re-enter',
      (WidgetTester tester) async {
    final HeldCueAudio audio = HeldCueAudio();
    final HeldStreakService streak = HeldStreakService();
    await pumpDrillRoute(tester, audio, streak);
    // A real completion first: the choices are unlocked (heard).
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);
    audio.cues[0].release();
    await settle(tester);
    expect(optionEnabled(tester, 'roue'), isTrue,
        reason: 'a real completion unlocks the choices');
    final IconButton playButton = tester.widget<IconButton>(find.ancestor(
        of: find.byIcon(Icons.play_arrow), matching: find.byType(IconButton)));
    final void Function()? cachedPlay = playButton.onPressed;
    final FilledButton answerButton = tester.widget<FilledButton>(find.ancestor(
        of: find.text('roue'), matching: find.byType(FilledButton)));
    final void Function()? cachedAnswer = answerButton.onPressed;
    final TextButton endButton = tester.widget<TextButton>(find.ancestor(
        of: find.text('End Session'), matching: find.byType(TextButton)));
    final void Function()? cachedEnd = endButton.onPressed;
    expect(cachedPlay, isNotNull);
    expect(cachedAnswer, isNotNull);
    expect(cachedEnd, isNotNull);
    // End the session while the persistence await is held.
    cachedEnd!();
    // Invoke the callbacks captured from the enabled pre-ending frame before
    // allowing the setState above to rebuild disabled controls.
    cachedPlay!();
    cachedAnswer!();
    cachedEnd();
    await settle(tester);
    expect(audio.spoken, <String>['roue'],
        reason: 'cached Play cannot dispatch B before the next frame');
    expect(find.text('Item 1'), findsOneWidget);
    expect(find.text('0 / 1'), findsOneWidget,
        reason: 'cached answer cannot change item score');
    expect(streak.recordCalls, 1,
        reason: 'cached End cannot book twice before the next frame');
    expect(optionEnabled(tester, 'roue'), isFalse,
        reason: 'ending clears hearing BEFORE the persistence await: an '
            'already-heard item must not remain answerable');
    // Saved enabled callbacks remain stale even after one or more frames.
    cachedPlay();
    cachedAnswer();
    cachedEnd();
    await tester.pump();
    await tester.pump();
    final data = await CourseProgressStore('en-fr').load();
    expect(data['evidence'], isEmpty,
        reason: 'a cached answer callback must not record during ending');
    // Repeated pre-ending callbacks across frames remain rejected.
    cachedPlay();
    cachedAnswer();
    cachedEnd();
    await tester.pump();
    await tester.pump();
    expect(audio.spoken, <String>['roue'],
        reason: 'a cached Play callback must not start a new request');
    await tester.tap(find.text('End Session'));
    await settle(tester);
    expect(streak.recordCalls, 1,
        reason: 'a cached End callback must not double-book');
    // Release: one banner, one exit.
    streak.releases[0].release();
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Session complete'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Open drill'), findsOneWidget);
    expect(streak.recordCalls, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'a failed persistence is a deliberate retryable state: no '
      'exit, no automatic retry, and one successful retry exits once',
      (WidgetTester tester) async {
    final HeldCueAudio audio = HeldCueAudio();
    final HeldStreakService streak = HeldStreakService();
    await pumpDrillRoute(tester, audio, streak);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await settle(tester);
    await tester.tap(find.text('End Session'));
    await settle(tester);
    expect(streak.recordCalls, 1);
    expect(streak.releases[0].held, isTrue);
    // Release the persistence with a REAL failure (observers attached in
    // the double at creation): it must be handled, not unhandled.
    streak.releases[0].release(StateError('storage failed'));
    await settle(tester);
    expect(find.textContaining('Session complete'), findsNothing,
        reason: 'a failed booking must not show the completion banner');
    expect(find.text('Open drill'), findsNothing,
        reason: 'a failed booking must not exit the session');
    expect(
        tester
            .widget<TextButton>(find.ancestor(
                of: find.text('End Session'),
                matching: find.byType(TextButton)))
            .onPressed,
        isNotNull,
        reason: 'the failure clears the ending into a retryable state');
    expect(optionEnabled(tester, 'roue'), isFalse,
        reason: 'hearing stays false in the retryable state');
    expect(tester.takeException(), isNull,
        reason: 'the failed write is handled, never an unhandled error');
    await tester.pump();
    await tester.pump();
    expect(streak.recordCalls, 1,
        reason: 'no automatic retry after a failed write');
    // An explicit retry may book again; release it successfully.
    await tester.tap(find.text('End Session'));
    await settle(tester);
    expect(streak.recordCalls, 2,
        reason: 'an explicit retry books the streak again');
    expect(streak.releases[1].held, isTrue);
    streak.releases[1].release();
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Session complete'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Open drill'), findsOneWidget,
        reason: 'exactly one exit, on the successful booking');
    expect(streak.recordCalls, 2, reason: 'no further bookings');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
