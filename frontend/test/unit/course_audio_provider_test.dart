// FR-03 Task 4: default provider wiring for the alpha reference player.
//
// Proves the shared-provider contract against the REAL facade and the REAL
// catalogue loader (over the shipped pending manifest/provenance files):
// one owned instance served by both provider names, zero engines before a
// requested Play, exact recording selection for all 24 authored words
// without any speech session, catalogue-failure honesty (fail, never
// silently substitute), and provider disposal cancelling a held start
// without late playback or unhandled failures. Plugin-level behavior is
// replaced with the deterministic session doubles at the plugin boundary;
// no device, no plugin, no TTS channel is touched here, and word identities
// come from the authored [frenchCurriculum.audioReferences] read through
// the loader — never from hardcoded constants.
//
// Note for the RED phase: this file targets the new
// `courseReferenceAudioProvider` wiring, so it does not compile on the
// pre-Task-4 baseline; the red log records that along with the real
// assertion failures of the screen-level lifecycle tests.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_audio_catalog.dart';
import 'package:linguist/src/core/course/course_exercise.dart';
import 'package:linguist/src/core/course/course_reference_audio.dart';
import 'package:linguist/src/core/course/french_course.dart';

import '../support/fake_course_recording_session.dart';
import '../support/fake_course_speech_session.dart';

/// Test-only asset bundle over the shipped files (the asset boundary).
class _RealFileBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key, {bool cache = true}) async {
    final List<int> bytes = File(key).readAsBytesSync();
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

/// Serves the real files but fails its first [failingLoads] reads — the
/// same Retry pattern as the credits-view tests.
class _FlakyBundle extends AssetBundle {
  _FlakyBundle(this.failingLoads);

  final int failingLoads;
  int _emitted = 0;

  @override
  Future<ByteData> load(String key, {bool cache = true}) async {
    if (_emitted < failingLoads) {
      _emitted++;
      throw FlutterError('injected bundle read failure: $key');
    }
    final List<int> bytes = File(key).readAsBytesSync();
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

/// Settles a flag the moment [future] settles (success or failure) — the
/// probe [until] loops poll instead of the Future API, which has no
/// completion state getter.
final class SettledProbe {
  SettledProbe(Future<Object?> future) {
    unawaited(future.then(
      (Object? value) => done = true,
      onError: (Object error) => done = true,
    ));
  }

  bool done = false;
}

/// The preserved legacy-mock contract: a plain two-method [CourseAudio]
/// injected through `courseAudioProvider.overrideWithValue` must keep
/// compiling and running unchanged.
class _LegacyMock implements CourseAudio {
  int speaks = 0;
  int stops = 0;
  final List<String> spoken = <String>[];

  @override
  Future<void> speak(String word) async {
    speaks++;
    spoken.add(word);
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

/// Counts the factories of a test facade.
final class SessionCounts {
  final List<FakeCourseRecordingSession> recordings =
      <FakeCourseRecordingSession>[];
  final List<FakeCourseSpeechSession> speeches = <FakeCourseSpeechSession>[];
  int recordingCreations = 0;
  int speechCreations = 0;
}

CourseAudioCatalogLoader buildLoader(AssetBundle bundle) =>
    CourseAudioCatalogLoader(
      bundle: bundle,
      references: frenchCurriculum.audioReferences,
    );

/// Builds the REAL facade with counting factories over [loader]; any
/// pre-queued session doubles are consumed first, in order.
FrenchReferenceAudio buildFacade(
  CourseAudioCatalogLoader loader,
  SessionCounts counts, {
  List<FakeCourseRecordingSession> firstRecordings =
      const <FakeCourseRecordingSession>[],
  List<FakeCourseSpeechSession> firstSpeeches =
      const <FakeCourseSpeechSession>[],
}) {
  return FrenchReferenceAudio(
    loadCatalog: loader.load,
    recordingFactory: () {
      final FakeCourseRecordingSession session = firstRecordings.isNotEmpty
          ? firstRecordings.removeAt(0)
          : FakeCourseRecordingSession();
      counts.recordingCreations++;
      counts.recordings.add(session);
      return session;
    },
    speechFactory: () {
      final FakeCourseSpeechSession session = firstSpeeches.isNotEmpty
          ? firstSpeeches.removeAt(0)
          : FakeCourseSpeechSession();
      counts.speechCreations++;
      counts.speeches.add(session);
      return session;
    },
    deadlines: const CourseAudioDeadlines(
      setup: Duration(milliseconds: 800),
      cleanup: Duration(milliseconds: 800),
      completionFloor: Duration(milliseconds: 400),
      completionSlack: Duration(milliseconds: 200),
      ttsUtterance: Duration(milliseconds: 600),
    ),
  );
}

ProviderContainer containerFor(
  CourseAudioCatalogLoader loader,
  FrenchReferenceAudio facade,
) {
  return ProviderContainer(overrides: <Override>[
    courseAudioCatalogLoaderProvider.overrideWithValue(loader),
    // Riverpod does not inherit the original body's onDispose hook into an
    // override, so the test override registers the provider's own disposal
    // contract: container disposal disposes the shared player exactly as
    // the real provider body does.
    courseReferenceAudioProvider.overrideWith((ref) {
      ref.onDispose(() {
        unawaited(facade.dispose().catchError((Object _) {}));
      });
      return facade;
    }),
  ]);
}

Future<void> pump() => Future<void>.delayed(Duration.zero);

Future<void> until(
  bool Function() condition, {
  String reason = 'condition',
}) async {
  final stopwatch = Stopwatch()..start();
  while (!condition()) {
    if (stopwatch.elapsed > const Duration(seconds: 5)) {
      fail('timed out waiting for $reason');
    }
    await pump();
  }
}

void main() {
  final AssetBundle files = _RealFileBundle();

  group('shared provider (one owner, two interfaces)', () {
    test('both providers expose the identical shared player', () {
      final CourseAudioCatalogLoader loader = buildLoader(files);
      final ProviderContainer container =
          ProviderContainer(overrides: <Override>[
        courseAudioCatalogLoaderProvider.overrideWithValue(loader),
      ]);
      addTearDown(container.dispose);

      final CourseAudio legacy = container.read(courseAudioProvider);
      final CourseReferenceAudio reference =
          container.read(courseReferenceAudioProvider);
      expect(
        identical(legacy, reference),
        isTrue,
        reason: 'the two providers must serve one shared player, '
            'never a second engine',
      );
      // The shared object also implements the extended reference interface,
      // so reference requests are available wherever the legacy one is.
      expect(legacy, isA<CourseReferenceAudio>());
    });

    test('zero engines before Play: reading providers constructs no session',
        () {
      final CourseAudioCatalogLoader loader = buildLoader(files);
      final SessionCounts counts = SessionCounts();
      final FrenchReferenceAudio facade =
          buildFacade(loader, counts);
      final ProviderContainer container = containerFor(loader, facade);
      addTearDown(container.dispose);

      container.read(courseAudioProvider);
      container.read(courseReferenceAudioProvider);
      expect(
        counts.recordingCreations,
        0,
        reason: 'no recording session may exist before a requested Play',
      );
      expect(
        counts.speechCreations,
        0,
        reason: 'no speech session may exist before a requested Play',
      );
    });

    test('the existing overrideWithValue legacy mock compiles and runs '
        'unchanged', () async {
      final _LegacyMock mock = _LegacyMock();
      final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
        courseAudioProvider.overrideWithValue(mock)
      ]);
      addTearDown(container.dispose);

      final CourseAudio audio = container.read(courseAudioProvider);
      expect(identical(audio, mock), isTrue);
      await audio.speak('tout');
      expect(mock.spoken, <String>['tout']);
      await audio.stop();
      expect(mock.stops, 1);
    });

    test('provider disposal invalidates a held start without late playback '
        'or unhandled failures', () async {
      final CourseAudioCatalogLoader loader = buildLoader(files);
      final SessionCounts counts = SessionCounts();
      final Completer<void> heldStart = Completer<void>();
      final FakeCourseRecordingSession held = FakeCourseRecordingSession()
        ..startGate = heldStart.future;
      final FrenchReferenceAudio facade = buildFacade(loader, counts,
          firstRecordings: <FakeCourseRecordingSession>[held]);
      final ProviderContainer container = containerFor(loader, facade);

      final CourseAudio legacy = container.read(courseAudioProvider);
      final Future<void> speak = legacy.speak('tout');
      await until(() => counts.recordingCreations == 1,
          reason: 'recording session created');
      await held.waitForStart();

      // Disposal is permanent and prompts the cancellation: the request
      // settles as cancelled NOW, while the platform start is still held.
      container.dispose();
      await pump();
      await pump();
      expect(
        speak,
        throwsA(isA<CourseAudioCancelledException>()),
        reason: 'a disposed owner must hand the caller a cancellation, '
            'never a late completion',
      );

      // The held platform start releases late with a failure: it must be
      // fenced quietly (no unhandled failure escapes the test) and the
      // session must already be retired.
      heldStart.completeError(PlatformException(code: 'disposed'));
      await pump();
      await pump();
      expect(
        held.calls,
        contains('stop'),
        reason: 'disposal must retire the active recording session',
      );
    });

    test('a disposed player rejects new requests instead of playing',
        () async {
      final CourseAudioCatalogLoader loader = buildLoader(files);
      final FrenchReferenceAudio player =
          buildFacade(loader, SessionCounts());
      player.dispose();
      await pump();
      // The published contract (Task 3): a disposed owner's entry points
      // throw synchronously; the call itself is the rejection.
      expect(
        () => player.speak('tout'),
        throwsA(isA<StateError>()),
        reason: 'disposal is permanent; no late playback is allowed',
      );
      expect(
        () => player.playReference('fr-word-tout'),
        throwsA(isA<StateError>()),
      );
    });

    test('all 24 current words select the bundled recording, without TTS',
        () async {
      final CourseAudioCatalogLoader loader = buildLoader(files);
      final SessionCounts counts = SessionCounts();
      final FrenchReferenceAudio facade = buildFacade(loader, counts);
      final ProviderContainer container = containerFor(loader, facade);
      addTearDown(container.dispose);
      final CourseAudio legacy = container.read(courseAudioProvider);

      final List<CourseAudioReference> references =
          frenchCurriculum.audioReferences;
      expect(
        references.length,
        24,
        reason: 'the authored catalogue has exactly 24 covered words',
      );

      for (final CourseAudioReference reference in references) {
        final Future<void> speak = legacy.speak(reference.spokenText);
        final SettledProbe probe = SettledProbe(speak);
        // Each word gets its own isolated session (the previous request was
        // retired when it settled); wait until THIS word's session exists.
        final int before = counts.recordingCreations;
        await until(
          () => counts.recordingCreations >= before + 1,
          reason: 'a recording session is selected for ${reference.id}',
        );
        final FakeCourseRecordingSession session = counts.recordings.last;
        await session.waitForStart();
        session.emitCompleted();
        await until(() => probe.done,
            reason: 'completion settles for ${reference.id}');
        expect(
          session.preparedRecording,
          isNotNull,
          reason: '${reference.id} must prepare its bundled asset',
        );
        expect(
          session.preparedRecording!.assetKey,
          'assets/audio/fr/words/${reference.spokenText}.wav',
          reason: 'exact authored identity (including île): no slug '
              'derivation for ${reference.id}',
        );
        await pump();
      }
      expect(
        counts.speechCreations,
        0,
        reason: 'no covered word may reach the practice-speech engine',
      );
      expect(counts.recordingCreations, 24,
          reason: 'each of the 24 words selects its own recording session');
    });

    test('a failed covered recording never falls back to TTS', () async {
      final CourseAudioCatalogLoader loader = buildLoader(files);
      final SessionCounts counts = SessionCounts();
      final Completer<void> failStart = Completer<void>();
      final FakeCourseRecordingSession failing = FakeCourseRecordingSession()
        ..startGate = failStart.future;
      final FrenchReferenceAudio facade = buildFacade(loader, counts,
          firstRecordings: <FakeCourseRecordingSession>[failing]);
      final ProviderContainer container = containerFor(loader, facade);
      addTearDown(container.dispose);
      final CourseAudio legacy = container.read(courseAudioProvider);

      final Future<void> speak = legacy.speak('tout');
      final SettledProbe probe = SettledProbe(speak);
      await until(() => counts.recordingCreations == 1,
          reason: 'the declared recording is selected first');
      await failing.waitForStart();
      failStart.completeError(
          PlatformException(code: 'UnsupportedOperation'));
      await until(() => probe.done, reason: 'failure settles');
      expect(speak, throwsA(isA<CourseAudioException>()));
      expect(
        counts.speechCreations,
        0,
        reason: 'a failed declared recording is never rescued by TTS',
      );

      // Retry is available: a terminal failure state is retryable, not a
      // latch — the fresh request reaches a fresh recording session.
      final Future<void> retry = legacy.speak('tout');
      final SettledProbe retryProbe = SettledProbe(retry);
      await until(() => counts.recordingCreations == 2,
          reason: 'Retry selects a fresh recording session');
      final FakeCourseRecordingSession fresh = counts.recordings.last;
      await fresh.waitForStart();
      fresh.emitCompleted();
      await until(() => retryProbe.done, reason: 'retry completes');
      expect(retry, completes);
    });

    test('unmapped legacy text may select practice speech (drill path)',
        () async {
      final CourseAudioCatalogLoader loader = buildLoader(files);
      final SessionCounts counts = SessionCounts();
      final FrenchReferenceAudio facade = buildFacade(loader, counts);
      final ProviderContainer container = containerFor(loader, facade);
      addTearDown(container.dispose);
      final CourseAudio legacy = container.read(courseAudioProvider);

      // 'roue' appears in drill pairs but has no bundled recording; after a
      // successful metadata resolution, practice speech of the exact text
      // is the allowed legacy fallback.
      final Future<void> speak = legacy.speak('roue');
      await until(() => counts.speechCreations == 1,
          reason: 'unmapped text selects practice speech');
      expect(counts.speeches.single.calls, contains('speak:roue'));
      expect(
        counts.recordingCreations,
        0,
        reason: 'no recording session may exist for unmapped text',
      );
      expect(speak, completes);
    });

    test('catalogue failure fails the request instead of substituting '
        'speech', () async {
      final CourseAudioCatalogLoader flaky =
          buildLoader(_FlakyBundle(1));
      final SessionCounts counts = SessionCounts();
      final FrenchReferenceAudio facade = buildFacade(flaky, counts);
      final ProviderContainer container = containerFor(flaky, facade);
      addTearDown(container.dispose);
      final CourseAudio legacy = container.read(courseAudioProvider);

      // The first read fails (injected bundle failure): the request must
      // fail typed — it cannot paper over unproven coverage with TTS.
      final Future<void> speak = legacy.speak('tout');
      final SettledProbe probe = SettledProbe(speak);
      await until(() => probe.done, reason: 'failure settles');
      expect(speak, throwsA(isA<CourseAudioException>()));
      expect(counts.recordingCreations, 0);
      expect(
        counts.speechCreations,
        0,
        reason: 'a catalogue failure cannot establish coverage for TTS',
      );

      // Retry recovers: a failed load is not latched permanently.
      final Future<void> retry = legacy.speak('tout');
      final SettledProbe retryProbe = SettledProbe(retry);
      await until(() => counts.recordingCreations == 1,
          reason: 'Retry re-reads the catalogue and selects the recording');
      final FakeCourseRecordingSession session = counts.recordings.last;
      await session.waitForStart();
      session.emitCompleted();
      await until(() => retryProbe.done, reason: 'retry completes');
      expect(retry, completes);
    });
  });

  group('unmapped drill word: practice-speech identity', () {
    test('speech is selected after resolution, not as a review recording',
        () async {
      final CourseAudioCatalogLoader loader = buildLoader(files);
      final SessionCounts counts = SessionCounts();
      final FrenchReferenceAudio facade = buildFacade(loader, counts);
      final ProviderContainer container = containerFor(loader, facade);
      addTearDown(container.dispose);
      final CourseReferenceAudio reference =
          container.read(courseReferenceAudioProvider);

      // An unmapped ID in the typed API yields a typed failure, never a
      // TTS disguise: [playReference] settles with a failed outcome.
      final Future<CourseAudioResult> unknown =
          reference.playReference('fr-word-roue');
      final SettledProbe probe = SettledProbe(unknown);
      await until(() => probe.done, reason: 'unknown reference is terminal');
      final CourseAudioResult typed = await unknown;
      expect(typed.outcome, CourseAudioOutcome.failed);
      expect(
        typed.failure,
        isA<CourseAudioFailure>()
            .having((f) => f.reason, 'reason',
                CourseAudioFailureReason.unknownReference),
      );

      // Legacy unmapped text resolves through the catalogue first and only
      // then may speak the exact authored text.
      final Future<void> speak = reference.speak('roue');
      await until(() => counts.speechCreations == 1,
          reason: 'practice speech is the allowed legacy fallback');
      expect(counts.speeches.single.calls, contains('speak:roue'));
      expect(speak, completes);
    });
  });
}
