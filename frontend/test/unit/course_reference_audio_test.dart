// FR-03 Task 3: ownership-aware reference facade and bounded practice speech.
//
// Facade tests run against the deterministic session doubles with injected
// immutable catalogue fixtures — no device, no plugin, and no shipped
// manifest. They prove the facade's selection, ownership, deadline and
// terminal-result behavior; the real TTS/recording adapters are covered
// separately in course_audio_test.dart and the Task 2 backend tests.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_audio_catalog.dart';
import 'package:linguist/src/core/course/course_exercise.dart';
import 'package:linguist/src/core/course/course_reference_audio.dart';

import '../support/fake_course_recording_session.dart';
import '../support/fake_course_speech_session.dart';

CourseAudioReference _ref(
  String id,
  String text, [
  AudioReferenceKind kind = AudioReferenceKind.word,
]) =>
    CourseAudioReference(id: id, kind: kind, spokenText: text);

CourseAudioCredit _credit(String id, String text) => CourseAudioCredit(
      referenceId: id,
      spokenText: text,
      creator: 'LoquaxFR',
      sourceUrl: 'https://commons.wikimedia.org/wiki/File_A',
      auditedRevisionUrl:
          'https://commons.wikimedia.org/w/index.php?title=A&oldid=1',
      licenseId: 'CC-BY-4.0',
      licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
      licenseTextAssetKey: 'assets/audio/fr/licenses/CC-BY-4.0.txt',
      attribution: 'LoquaxFR (CC BY 4.0, alpha practice material)',
      notices: const ['alpha practice material, linguistically unverified'],
      unchanged: true,
    );

CourseAudioRecording _recording(String id,
        [Duration duration = const Duration(milliseconds: 100)]) =>
    CourseAudioRecording(
      assetKey: 'assets/audio/fr/words/$id.wav',
      byteLength: 44100,
      duration: duration,
      source: CourseAudioSource.unverifiedRecording,
    );

/// Fixture catalogue: one recorded word (`tout`), one declared but
/// unrecorded word (`huit`), and one uncovered `sound` kind (`boat`).
CourseAudioCatalog fixtureCatalogue() => CourseAudioCatalog(
      references: [
        _ref('fr-word-tout', 'tout'),
        _ref('fr-word-huit', 'huit'),
        _ref('fr-sound-boat', 'battement', AudioReferenceKind.sound),
      ],
      entries: [
        CourseAudioEntry(
          reference: _ref('fr-word-tout', 'tout'),
          recordings: {
            CourseAudioVariant.normal: _recording('fr-word-tout'),
          },
          credit: _credit('fr-word-tout', 'tout'),
        ),
      ],
    );

class Harness {
  late final FrenchReferenceAudio facade;

  /// Doubles still queued for the next factory call(s).
  final List<FakeCourseRecordingSession> recordings;
  final List<FakeCourseSpeechSession> speeches;

  int recordingCreations = 0;
  int speechCreations = 0;
  FakeCourseRecordingSession? lastRecording;
  FakeCourseSpeechSession? lastSpeech;

  Harness({
    Future<CourseAudioCatalog> Function()? loader,
    this.recordings = const <FakeCourseRecordingSession>[],
    this.speeches = const <FakeCourseSpeechSession>[],
  }) {
    facade = FrenchReferenceAudio(
      loadCatalog:
          loader ??
              (() =>
                  Future<CourseAudioCatalog>.value(fixtureCatalogue())),
      recordingFactory: () {
        final FakeCourseRecordingSession session = recordings.isNotEmpty
            ? recordings.first
            : FakeCourseRecordingSession();
        if (recordings.isNotEmpty) recordings.removeAt(0);
        recordingCreations++;
        lastRecording = session;
        return session;
      },
      speechFactory: () {
        final FakeCourseSpeechSession session = speeches.isNotEmpty
            ? speeches.first
            : FakeCourseSpeechSession();
        if (speeches.isNotEmpty) speeches.removeAt(0);
        speechCreations++;
        lastSpeech = session;
        return session;
      },
      deadlines: const CourseAudioDeadlines(
        setup: Duration(milliseconds: 150),
        cleanup: Duration(milliseconds: 200),
        completionFloor: Duration(milliseconds: 50),
        completionSlack: Duration(milliseconds: 80),
        ttsUtterance: Duration(milliseconds: 150),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  FakeCourseRecordingSession recording() => FakeCourseRecordingSession();
  FakeCourseSpeechSession speech() => FakeCourseSpeechSession();

  Future<void> until(
    bool Function() condition, {
    String reason = 'condition',
  }) async {
    final stopwatch = Stopwatch()..start();
    while (!condition()) {
      if (stopwatch.elapsed > const Duration(seconds: 5)) {
        fail('timed out waiting for $reason');
      }
      await pumpEventQueue();
    }
  }

  group('FrenchReferenceAudio (selection and outcomes)', () {
    test('constructor does not call any factory', () {
      final h = Harness(recordings: [recording()], speeches: [speech()]);
      expect(h.recordingCreations, 0);
      expect(h.speechCreations, 0);
    });

    test('rejects nonpositive injected deadlines before use', () {
      expect(
        () => FrenchReferenceAudio(
          loadCatalog: () =>
              Future<CourseAudioCatalog>.value(fixtureCatalogue()),
          recordingFactory: FakeCourseRecordingSession.new,
          speechFactory: FakeCourseSpeechSession.new,
          deadlines: const CourseAudioDeadlines(setup: Duration.zero),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('recording startup does not resolve playback', () async {
      final session = recording();
      final h = Harness(recordings: [session]);
      final pending = h.facade.playReference('fr-word-tout');
      var settled = false;
      pending.then((_) => settled = true);
      await until(() => session.calls.contains('start'), reason: 'start dispatch');
      await session.waitForStart(); // fake helper waits for dispatch, not a timer
      expect(settled, isFalse);
      session.emitCompleted();
      final result = await pending;
      expect(result.outcome, CourseAudioOutcome.completed);
      expect(result.source, CourseAudioSource.unverifiedRecording);
      expect(result.referenceId, 'fr-word-tout');
    });

    test(
        'reviewedOnly denies all shipped candidates before factory creation',
        () async {
      final rec = recording();
      final sp = speech();
      final h = Harness(recordings: [rec], speeches: [sp]);
      for (final id in <String>[
        'fr-word-tout', // recorded candidate
        'fr-word-huit', // declared candidate without a recording
        'fr-sound-boat', // uncovered future kind
      ]) {
        for (final allowTts in <bool>[false, true]) {
          final result = await h.facade.playReference(
            id,
            use: CourseAudioUse.reviewedOnly,
            allowPracticeTts: allowTts,
          );
          expect(result.outcome, CourseAudioOutcome.failed,
              reason: 'reviewedOnly must deny $id');
          expect(result.failure, isNotNull,
              reason: 'reviewedOnly denial of $id needs a failure');
          expect(result.failure!.reason,
              CourseAudioFailureReason.unreviewedSource,
              reason: 'reviewedOnly denial of $id (allowTts=$allowTts)');
        }
      }
      expect(h.recordingCreations, 0,
          reason: 'denial must happen before the recording factory is called');
      expect(h.speechCreations, 0,
          reason: 'denial must happen before the speech factory is called');
    });

    test('unknown ID fails without text-derived TTS', () async {
      final h = Harness(recordings: [recording()], speeches: [speech()]);
      final result = await h.facade.playReference('fr-word-never-declared',
          allowPracticeTts: true);
      expect(result.outcome, CourseAudioOutcome.failed);
      expect(result.failure!.reason, CourseAudioFailureReason.unknownReference);
      expect(result.source, isNull,
          reason: 'a selection that never started must not claim a source');
      expect(h.recordingCreations, 0);
      expect(h.speechCreations, 0,
          reason: 'a reference ID must never become text-derived TTS');

      // The policy gate cannot deny what it cannot identify.
      final denied = await h.facade
          .playReference('fr-word-never-declared',
              use: CourseAudioUse.reviewedOnly);
      expect(denied.failure!.reason, CourseAudioFailureReason.unknownReference);
    });

    test('missing slow variant is unavailable', () async {
      final h = Harness(recordings: [recording()], speeches: [speech()]);
      final denied = await h.facade.playReference('fr-word-tout',
          variant: CourseAudioVariant.slow);
      expect(denied.outcome, CourseAudioOutcome.failed);
      expect(
          denied.failure!.reason, CourseAudioFailureReason.unavailableVariant,
          reason: 'recorded normal + requested slow is an unavailable '
              'variant, not a missing asset');
      expect(h.recordingCreations, 0);

      final sp = speech();
      final h2 = Harness(recordings: [recording()], speeches: [sp]);
      final allowed = await h2.facade.playReference('fr-word-tout',
          variant: CourseAudioVariant.slow, allowPracticeTts: true);
      expect(allowed.outcome, CourseAudioOutcome.completed);
      expect(allowed.source, CourseAudioSource.practiceTts);
      expect(sp.calls, contains('speak:tout'),
          reason: 'practice TTS speaks the exact authored reference text');
      expect(h2.recordingCreations, 0,
          reason: 'the unrecorded slow variant must never play the normal take');
    });

    test('missing declared asset never invokes speech', () async {
      final h = Harness(recordings: [recording()], speeches: [speech()]);
      final declared = await h.facade.playReference('fr-word-huit');
      expect(declared.outcome, CourseAudioOutcome.failed);
      expect(declared.failure!.reason, CourseAudioFailureReason.missingAsset);

      // Future kinds without recordings are unavailable, not word-path play.
      final sound = await h.facade
          .playReference('fr-sound-boat', allowPracticeTts: false);
      expect(sound.outcome, CourseAudioOutcome.failed);
      expect(sound.failure!.reason, CourseAudioFailureReason.missingAsset);
      expect(h.recordingCreations, 0);
      expect(h.speechCreations, 0,
          reason: 'practice TTS requires an explicit practice-fallback policy');
    });

    test('no recording-error TTS substitution', () async {
      final session = recording();
      final sp = speech();
      final startHold = Completer<void>();
      session.startGate = startHold.future;
      final h = Harness(recordings: [session], speeches: [sp]);
      final pending =
          h.facade.playReference('fr-word-tout', allowPracticeTts: true);
      await until(() => session.calls.contains('start'), reason: 'start dispatch');
      await session.waitForStart();
      startHold.complete(); // the start acknowledgement settles cleanly
      await _settleGate(startHold);
      session
          .emitError(PlatformException(code: 'wav-decode-failed'));
      final result = await pending;
      expect(result.outcome, CourseAudioOutcome.failed);
      expect(result.source, CourseAudioSource.unverifiedRecording);
      expect(result.failure!.reason,
          CourseAudioFailureReason.unsupportedPlayback);
      expect(result.failure!.cause, isA<PlatformException>(),
          reason: 'the diagnostic cause must be preserved');
      expect(sp.calls, isEmpty,
          reason:
              'a declared recording failure must never silently substitute TTS');
    });

    test('explicit practice fallback alone permits a declared unrecorded word',
        () async {
      final session = speech();
      final rec = recording();
      final gate = Completer<void>();
      session.speakGate = gate.future;
      final h = Harness(recordings: [rec], speeches: [session]);
      final pending =
          h.facade.playReference('fr-word-huit', allowPracticeTts: true);
      await until(() => session.calls.isNotEmpty, reason: 'speech dispatch');
      expect(session.calls.first, 'speak:huit');
      var settled = false;
      pending.then((_) => settled = true);
      await pumpEventQueue();
      expect(settled, isFalse,
          reason: 'the reference bridge resolves only on completion');
      gate.complete();
      final result = await pending;
      expect(result.outcome, CourseAudioOutcome.completed);
      expect(result.source, CourseAudioSource.practiceTts);
      expect(h.recordingCreations, 0);
    });

    test('reviewedOnly never permits TTS for a declared unrecorded word',
        () async {
      final h = Harness(recordings: [recording()], speeches: [speech()]);
      final result = await h.facade.playReference('fr-word-huit',
          use: CourseAudioUse.reviewedOnly, allowPracticeTts: true);
      expect(result.outcome, CourseAudioOutcome.failed);
      expect(result.failure!.reason, CourseAudioFailureReason.unreviewedSource);
      expect(h.speechCreations, 0);
    });

    test('invalid catalogue retains its diagnostic cause', () async {
      final cause = StateError('malformed manifest entry 7');
      final h = Harness(
          loader: () => Future<CourseAudioCatalog>.error(
                CourseAudioException(CourseAudioFailure(
                  reason: CourseAudioFailureReason.invalidCatalogue,
                  cause: cause,
                )),
              ));
      final result = await h.facade.playReference('fr-word-tout');
      expect(result.outcome, CourseAudioOutcome.failed);
      expect(result.failure!.reason,
          CourseAudioFailureReason.invalidCatalogue);
      expect(identical(result.failure!.cause, cause), isTrue,
          reason: 'the loader diagnostic must survive classification');
    });

    test('denied review policy is reported with its stable reason', () async {
      final h = Harness(recordings: [recording()], speeches: [speech()]);
      final denied =
          await h.facade.playReference('fr-word-tout',
              use: CourseAudioUse.reviewedOnly);
      expect(denied.outcome, CourseAudioOutcome.failed);
      expect(denied.failure!.reason, CourseAudioFailureReason.unreviewedSource);
      expect(denied.source, CourseAudioSource.unverifiedRecording,
          reason: 'the denied candidate is known but was never played');
    });

    test('startup deadline bounds catalogue load with a startup timeout',
        () async {
      final gate = Completer<void>();
      final h = Harness(
          recordings: [recording()],
          loader: () => gate.future.then((_) => fixtureCatalogue()));
      final result = await h.facade.playReference('fr-word-tout');
      expect(result.outcome, CourseAudioOutcome.failed);
      expect(result.failure!.reason, CourseAudioFailureReason.startupTimeout);
      expect(result.failure!.cause, isA<TimeoutException>());
      expect(h.recordingCreations, 0,
          reason: 'no engine work after a catalogue startup timeout');
      gate.complete(); // drain the abandoned catalogue load
      await pumpEventQueue();
    });

    test('applied completion maximum includes declared duration plus slack',
        () async {
      // Injected deadlines: floor 50ms, slack 80ms; fixture duration 100ms →
      // bound max(50ms, 100ms + 80ms) = 180ms. A floor-only implementation
      // would time out at 50ms and settle before the 100ms probe.
      final session = recording();
      final h = Harness(recordings: [session]);
      final pending = h.facade.playReference('fr-word-tout');
      await until(() => session.calls.contains('start'), reason: 'start dispatch');
      await session.waitForStart();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      var settled = false;
      pending.then((_) => settled = true);
      await pumpEventQueue();
      expect(settled, isFalse,
          reason: 'the bound must be max(floor, duration + slack) = 180ms');
      final result = await pending; // elapses the remaining bound
      expect(result.outcome, CourseAudioOutcome.failed);
      expect(result.failure!.reason,
          CourseAudioFailureReason.completionTimeout);
      expect(result.failure!.cause, isA<TimeoutException>());
    });

    test('recognizable browser gesture rejection maps to userGestureRequired',
        () async {
      final gesture = PlatformException(
        code: 'NotAllowedError',
        message: 'audio playback requires a user gesture',
      );
      final session = speech();
      final gate = Completer<void>();
      session.speakGate = gate.future;
      final h = Harness(recordings: [recording()], speeches: [session]);
      final pending =
          h.facade.playReference('fr-word-huit', allowPracticeTts: true);
      await until(() => session.calls.isNotEmpty, reason: 'speech dispatch');
      gate.completeError(gesture);
      final result = await pending;
      expect(result.outcome, CourseAudioOutcome.failed);
      expect(result.failure!.reason,
          CourseAudioFailureReason.userGestureRequired);
      expect(identical(result.failure!.cause, gesture), isTrue,
          reason: 'the diagnostic cause must be preserved');
    });

    test('French voice unavailability classifies as unavailableVoice (TTS only)',
        () async {
      final voice = StateError(
          'Install a French voice in your device speech settings.');
      final session = speech();
      final gate = Completer<void>();
      session.speakGate = gate.future;
      final h = Harness(recordings: [recording()], speeches: [session]);
      final pending =
          h.facade.playReference('fr-word-huit', allowPracticeTts: true);
      await until(() => session.calls.isNotEmpty, reason: 'speech dispatch');
      gate.completeError(voice);
      final result = await pending;
      expect(result.outcome, CourseAudioOutcome.failed);
      expect(result.failure!.reason,
          CourseAudioFailureReason.unavailableVoice);
      expect(identical(result.failure!.cause, voice), isTrue,
          reason: 'the original voice-availability cause is preserved');
    });

    test('recording platform errors are not classified as voice problems',
        () async {
      final cause = StateError('bundled wav undecodable');
      final session = recording();
      final h = Harness(recordings: [session], speeches: [speech()]);
      final pending = h.facade.playReference('fr-word-tout');
      await until(() => session.calls.contains('start'), reason: 'start dispatch');
      await session.waitForStart();
      session.emitError(cause);
      final result = await pending;
      expect(result.outcome, CourseAudioOutcome.failed);
      expect(result.source, CourseAudioSource.unverifiedRecording);
      expect(
          result.failure!.reason, CourseAudioFailureReason.unsupportedPlayback,
          reason: 'a recording source failure must stay generic playback, '
              'never an invented voice diagnosis');
      expect(identical(result.failure!.cause, cause), isTrue);
    });

    test('other decoder/platform failures map to unsupportedPlayback',
        () async {
      final decoder = PlatformException(code: 'bad-decoder');
      final session = speech();
      final gate = Completer<void>();
      session.speakGate = gate.future;
      final h = Harness(recordings: [recording()], speeches: [session]);
      final pending =
          h.facade.playReference('fr-word-huit', allowPracticeTts: true);
      await until(() => session.calls.isNotEmpty, reason: 'speech dispatch');
      gate.completeError(decoder);
      final result = await pending;
      expect(result.outcome, CourseAudioOutcome.failed);
      expect(result.failure!.reason,
          CourseAudioFailureReason.unsupportedPlayback);
      expect(identical(result.failure!.cause, decoder), isTrue,
          reason: 'the diagnostic cause must be preserved');
    });

    test('unrecognized causes stay generic, never inventing a diagnosis',
        () async {
      final mystery = Object();
      final session = speech();
      final gate = Completer<void>();
      session.speakGate = gate.future;
      final h = Harness(recordings: [recording()], speeches: [session]);
      final pending =
          h.facade.playReference('fr-word-huit', allowPracticeTts: true);
      await until(() => session.calls.isNotEmpty, reason: 'speech dispatch');
      gate.completeError(mystery);
      final result = await pending;
      expect(result.outcome, CourseAudioOutcome.failed);
      expect(result.failure!.reason,
          CourseAudioFailureReason.unsupportedPlayback,
          reason: 'unknown causes stay generic, without an invented '
              'voice or permission diagnosis');
      expect(identical(result.failure!.cause, mystery), isTrue);
    });
  });

  group('FrenchReferenceAudio (race and ownership)', () {
    test('idle stop and policy denial are lazy', () async {
      final rec = recording();
      final sp = speech();
      final h = Harness(recordings: [rec], speeches: [sp]);
      await h.facade.stop();
      expect(h.recordingCreations, 0,
          reason: 'a stop with no engine must not construct one');
      expect(h.speechCreations, 0,
          reason: 'a stop with no engine must not construct one');
      final denied = await h.facade.playReference('fr-word-tout',
          use: CourseAudioUse.reviewedOnly);
      expect(denied.outcome, CourseAudioOutcome.failed);
      expect(h.recordingCreations, 0);
      expect(h.speechCreations, 0);
    });

    test('stop cancels a held recording request promptly, once, both outcomes',
        () async {
      final session = recording();
      final startHold = Completer<void>();
      session.startGate = startHold.future;
      final h = Harness(recordings: [session, recording()]);
      final pending = h.facade.playReference('fr-word-tout');
      await until(() => session.calls.contains('start'), reason: 'start dispatch');
      await session.waitForStart();

      var terminals = 0;
      pending.then((_) => terminals++, onError: (_) => terminals++);
      await h.facade.stop(); // ownership invalidation is synchronous
      final result = await pending; // must not wait for the held ack
      expect(result.outcome, CourseAudioOutcome.cancelled);
      expect(result.referenceId, 'fr-word-tout');

      startHold.complete(); // release the held ack with success
      await _settleGate(startHold);
      await pumpEventQueue();
      expect(terminals, 1,
          reason: 'exactly one terminal result per request');

      // Same guarantee for a stale ack failure on a second request.
      final secondSession =
          h.recordings.isNotEmpty ? h.recordings.first : null;
      if (secondSession == null) {
        fail('the queued second session must be available');
      }
      final secondHold = Completer<void>();
      secondSession.startGate = secondHold.future;
      final pending2 = h.facade.playReference('fr-word-tout');
      await until(
          () =>
              h.lastRecording == secondSession &&
              secondSession.calls.contains('start'),
          reason: 'second dispatch');
      var terminals2 = 0;
      pending2.then((_) => terminals2++, onError: (_) => terminals2++);
      await h.facade.stop();
      final result2 = await pending2;
      expect(result2.outcome, CourseAudioOutcome.cancelled);
      secondHold
          .completeError(PlatformException(code: 'stale-ack-failure'));
      await _settleGate(secondHold);
      await pumpEventQueue();
      expect(terminals2, 1,
          reason: 'a stale ack failure must not republish a second terminal');
    });

    test('older completion cannot complete a newer session', () async {
      final older = recording();
      final newer = recording();
      final startHold = Completer<void>();
      older.startGate = startHold.future;
      final h = Harness(recordings: [older, newer]);
      final oldPending = h.facade.playReference('fr-word-tout');
      await until(
          () => h.lastRecording == older && older.calls.contains('start'),
          reason: 'older dispatch');
      await older.waitForStart();
      await h.facade.stop();
      startHold.complete();
      await _settleGate(startHold);
      await pumpEventQueue();
      final oldResult = await oldPending;
      expect(oldResult.outcome, CourseAudioOutcome.cancelled);

      // A fresh, fully successful request.
      var newerTerminals = 0;
      final newPending = h.facade.playReference('fr-word-tout');
      newPending
          .then((_) => newerTerminals++, onError: (_) => newerTerminals++);
      await until(() => h.lastRecording == newer, reason: 'newer session');
      await newer.waitForStart();
      newer.emitCompleted();
      final newResult = await newPending;
      expect(newResult.outcome, CourseAudioOutcome.completed);

      // Late terminal events on the retired older identity must not mutate
      // either request.
      older.emitCompleted();
      older.emitError(PlatformException(code: 'stale-old-error'));
      await pumpEventQueue();
      expect(newerTerminals, 1,
          reason: 'a stale older event must not complete the newer session');
    });

    test('older failure cannot stop a newer session', () async {
      final older = recording();
      final newer = recording();
      final startHold = Completer<void>();
      older.startGate = startHold.future;
      final h = Harness(recordings: [older, newer]);
      final oldPending = h.facade.playReference('fr-word-tout');
      await until(
          () => h.lastRecording == older && older.calls.contains('start'),
          reason: 'older dispatch');
      await older.waitForStart();
      await h.facade.stop();
      startHold.complete();
      await _settleGate(startHold);
      await pumpEventQueue();
      final oldResult = await oldPending;
      expect(oldResult.outcome, CourseAudioOutcome.cancelled);

      final newPending = h.facade.playReference('fr-word-tout');
      await until(() => h.lastRecording == newer, reason: 'newer session');
      await newer.waitForStart();

      // The old identity fails late; the newer request must not feel it.
      older.emitError(PlatformException(code: 'stale-old-failure'));
      await pumpEventQueue();
      newer.emitCompleted();
      final newResult = await newPending;
      expect(newResult.outcome, CourseAudioOutcome.completed,
          reason: 'a stale older failure must not stop the newer session');
    });

    test('a newer request supersedes the older and both settle exactly once',
        () async {
      final older = recording();
      final newer = recording();
      final startHold = Completer<void>();
      older.startGate = startHold.future;
      final h = Harness(recordings: [older, newer]);
      final oldPending = h.facade.playReference('fr-word-tout');
      await until(
          () => h.lastRecording == older && older.calls.contains('start'),
          reason: 'older dispatch');
      await older.waitForStart();

      var oldTerminals = 0;
      oldPending.then((_) => oldTerminals++, onError: (_) => oldTerminals++);
      final newPending = h.facade.playReference('fr-word-tout');
      startHold.complete(); // the older raw work quiesces → replacement allowed
      await _settleGate(startHold);
      await pumpEventQueue();
      final oldResult = await oldPending;
      expect(oldResult.outcome, CourseAudioOutcome.cancelled,
          reason: 'the superseded request is cancelled, not failed');
      expect(older.calls, anyOf(contains('stop'), contains('dispose')),
          reason: 'the superseded single-use session is retired, not left live');

      await until(() => h.lastRecording == newer, reason: 'newer session');
      await newer.waitForStart();
      newer.emitCompleted();
      final newResult = await newPending;
      expect(newResult.outcome, CourseAudioOutcome.completed);
      expect(newResult.source, CourseAudioSource.unverifiedRecording);

      older.emitCompleted();
      await pumpEventQueue();
      expect(oldTerminals, 1,
          reason: 'a stale completion must not double-settle the older request');
    });

    test('blocked retirement fails replacement rather than overlapping',
        () async {
      final old = recording();
      final retry = recording();
      final startHold = Completer<void>();
      old.startGate = startHold.future;
      final h = Harness(recordings: [old, retry]);
      final first = h.facade.playReference('fr-word-tout');
      await until(
          () => h.lastRecording == old && old.calls.contains('start'),
          reason: 'older dispatch');
      await old.waitForStart();
      startHold.complete(); // the old raw work is quiescent
      await _settleGate(startHold);
      await pumpEventQueue();
      final hold = Completer<void>();
      old.stopGate = hold.future; // captured at retirement entry
      await h.facade.stop();
      final cancelled = await first;
      expect(cancelled.outcome, CourseAudioOutcome.cancelled);

      // Replacement while the old retirement is held past the cleanup bound.
      final blocked = h.facade.playReference('fr-word-tout');
      final blockedResult = await blocked; // elapses the cleanup bound
      expect(blockedResult.outcome, CourseAudioOutcome.failed);
      expect(blockedResult.failure!.reason,
          CourseAudioFailureReason.cleanupFailed,
          reason: 'a retirement that cannot establish quiescence must block '
              'the next audible owner');
      expect(h.recordingCreations, 1,
          reason: 'no overlapping engine while the old one is unquiesced');

      // Retry only proceeds after confirmed quiescence.
      hold.complete();
      await pumpEventQueue();
      final retried = h.facade.playReference('fr-word-tout');
      await until(() => h.lastRecording == retry, reason: 'retry session');
      await retry.waitForStart();
      retry.emitCompleted();
      final retriedResult = await retried;
      expect(retriedResult.outcome, CourseAudioOutcome.completed);
    });

    test('a failed retirement durably blocks new audible ownership', () async {
      final old = recording();
      final startHold = Completer<void>();
      old.startGate = startHold.future;
      final h = Harness(recordings: [old, recording()]);
      final first = h.facade.playReference('fr-word-tout');
      await until(
          () => h.lastRecording == old && old.calls.contains('start'),
          reason: 'older dispatch');
      await old.waitForStart();
      startHold.complete();
      await _settleGate(startHold);
      await pumpEventQueue();
      final hold = Completer<void>();
      final teardownError = StateError('plugin teardown failed');
      old.stopGate = hold.future;
      await h.facade.stop();
      await first;

      final blocked = h.facade.playReference('fr-word-tout');
      final blockedResult = await blocked; // elapses the cleanup bound
      expect(blockedResult.outcome, CourseAudioOutcome.failed);
      expect(blockedResult.failure!.reason,
          CourseAudioFailureReason.cleanupFailed);

      // Release the retirement as a failure: durable, shared, and never
      // turned into success.
      hold.completeError(teardownError);
      await pumpEventQueue();
      final second = h.facade.playReference('fr-word-tout');
      final secondResult = await second;
      expect(secondResult.outcome, CourseAudioOutcome.failed);
      expect(secondResult.failure!.reason,
          CourseAudioFailureReason.cleanupFailed);
      expect(identical(secondResult.failure!.cause, teardownError), isTrue,
          reason: 'the original cleanup cause must be preserved');
      expect(h.recordingCreations, 1,
          reason: 'a cleanup failure must not admit another audible owner');
    });

    test('stop invalidates an in-flight catalogue load before any engine',
        () async {
      final loaderGate = Completer<void>();
      final h = Harness(
        recordings: [recording()],
        loader: () => loaderGate.future.then((_) => fixtureCatalogue()),
      );
      final pending = h.facade.playReference('fr-word-tout');
      await h.facade.stop();
      final result = await pending;
      expect(result.outcome, CourseAudioOutcome.cancelled);
      expect(h.recordingCreations, 0,
          reason: 'a stop must invalidate in-flight catalogue work before '
              'any engine exists');
      loaderGate.complete();
      await pumpEventQueue();
      expect(h.recordingCreations, 0);
    });

    test('blocked TTS retirement fails the replacement, then retry succeeds',
        () async {
      final oldSpeech = speech();
      final okSpeech = speech();
      final utteranceGate = Completer<void>();
      oldSpeech.speakGate = utteranceGate.future;
      final h = Harness(
          recordings: [recording(), recording()],
          speeches: [oldSpeech, okSpeech]);
      final first =
          h.facade.playReference('fr-word-huit', allowPracticeTts: true);
      await until(
          () => h.lastSpeech == oldSpeech && oldSpeech.calls.isNotEmpty,
          reason: 'speech dispatch');
      final hold = Completer<void>();
      oldSpeech.stopGate = hold.future;
      await h.facade.stop();
      final cancelled = await first;
      expect(cancelled.outcome, CourseAudioOutcome.cancelled);

      final blocked =
          h.facade.playReference('fr-word-huit', allowPracticeTts: true);
      final blockedResult = await blocked; // elapses the cleanup bound
      expect(blockedResult.outcome, CourseAudioOutcome.failed);
      expect(blockedResult.failure!.reason,
          CourseAudioFailureReason.cleanupFailed);
      expect(h.speechCreations, 1,
          reason: 'no overlapping speech owner while the old one is unquiesced');

      utteranceGate.complete(); // the held utterance drains
      await pumpEventQueue();
      hold.complete(); // confirmed quiescence
      await pumpEventQueue();
      final retried =
          h.facade.playReference('fr-word-huit', allowPracticeTts: true);
      await until(() => h.lastSpeech == okSpeech, reason: 'retry speech');
      final retriedResult = await retried;
      expect(retriedResult.outcome, CourseAudioOutcome.completed);
    });

    test('retry proceeds after a failed prepare error', () async {
      final first = recording();
      final second = recording();
      final prepareGate = Completer<void>();
      first.prepareGate = prepareGate.future;
      final h = Harness(recordings: [first, second]);
      final pending = h.facade.playReference('fr-word-tout');
      await until(() => h.lastRecording == first, reason: 'first session');
      prepareGate
          .completeError(PlatformException(code: 'asset-missing'));
      await pumpEventQueue();
      final failed = await pending;
      expect(failed.outcome, CourseAudioOutcome.failed);
      expect(failed.failure!.reason,
          CourseAudioFailureReason.unsupportedPlayback);
      expect(failed.failure!.cause, isA<PlatformException>());

      final retried = h.facade.playReference('fr-word-tout');
      await until(() => h.lastRecording == second, reason: 'second session');
      await second.waitForStart();
      second.emitCompleted();
      final retriedResult = await retried;
      expect(retriedResult.outcome, CourseAudioOutcome.completed);
    });

    test('retry proceeds after a start error', () async {
      final first = recording();
      final second = recording();
      final startGate = Completer<void>();
      first.startGate = startGate.future;
      final h = Harness(recordings: [first, second]);
      final pending = h.facade.playReference('fr-word-tout');
      await until(
          () => h.lastRecording == first && first.calls.contains('start'),
          reason: 'first dispatch');
      await first.waitForStart();
      startGate
          .completeError(PlatformException(code: 'start-rejected'));
      await pumpEventQueue();
      final failed = await pending;
      expect(failed.outcome, CourseAudioOutcome.failed);
      expect(failed.failure!.reason,
          CourseAudioFailureReason.unsupportedPlayback);

      final retried = h.facade.playReference('fr-word-tout');
      await until(() => h.lastRecording == second, reason: 'second session');
      await second.waitForStart();
      second.emitCompleted();
      final retriedResult = await retried;
      expect(retriedResult.outcome, CourseAudioOutcome.completed);
    });

    test('disposed objects cannot restart or accept new requests', () async {
      final old = recording();
      final startHold = Completer<void>();
      old.startGate = startHold.future;
      final h = Harness(recordings: [old, recording()]);
      final pending = h.facade.playReference('fr-word-tout');
      await until(
          () => h.lastRecording == old && old.calls.contains('start'),
          reason: 'older dispatch');
      await h.facade.dispose();
      final result = await pending;
      expect(result.outcome, CourseAudioOutcome.cancelled,
          reason: 'disposal invalidates the active request');
      startHold.complete(); // drain the held acknowledgement
      await pumpEventQueue();
      expect(
        () => h.facade.playReference('fr-word-tout'),
        throwsA(isA<StateError>()),
      );
      expect(
        () => h.facade.speak('tout'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('stale legacy catalogue failures never dispatch speech (C1)', () {
    test(
        'stop during a held legacy catalogue load never dispatches TTS, '
        'even when the stale settlement is an error',
        () async {
      final loaderHold = Completer<void>();
      var loads = 0;
      final h = Harness(
        loader: () async {
          loads++;
          if (loads == 1) {
            await loaderHold.future;
            throw StateError('catalogue-store-lost');
          }
          return fixtureCatalogue();
        },
        recordings: const <FakeCourseRecordingSession>[],
        // No speech session queued on purpose: a stale dispatch would
        // fabricate and consume one.
        speeches: [speech()],
      );
      final pending = h.facade.speak('quelques mots');
      await until(() => loads >= 1, reason: 'legacy load dispatch');
      await h.facade.stop();
      Object? legacyCaught;
      try {
        await pending;
      } on Object catch (error) {
        legacyCaught = error;
      }
      expect(legacyCaught, isA<CourseAudioCancelledException>(),
          reason: 'stop cancels the pending legacy request distinctly');
      loaderHold.complete(); // the stale settlement arrives as an error
      await pumpEventQueue();
      expect(h.speechCreations, 0,
          reason: 'a stale catalogue error must never select speech');
      expect(h.lastSpeech, isNull,
          reason: 'no stale speech engine may be created or retained');
      // The facade remains usable for a newer owner after the stale error.
      await expectLater(h.facade.speak('quelques mots'), completes,
          reason: 'facade survives the stale catalogue error');
      expect(h.speechCreations, 1,
          reason: 'only the newer, owned request may use the queued speech');
    });

    test(
        'disposal during a held legacy catalogue load never dispatches TTS '
        'and retires nothing stale',
        () async {
      final loaderHold = Completer<void>();
      final h = Harness(
        loader: () async {
          await loaderHold.future;
          throw StateError('catalogue-store-lost');
        },
      );
      final pending = h.facade.speak('quelques mots');
      await pumpEventQueue();
      await h.facade.dispose();
      Object? legacyCaught;
      try {
        await pending;
      } on Object catch (error) {
        legacyCaught = error;
      }
      expect(legacyCaught, isA<CourseAudioCancelledException>(),
          reason: 'disposal cancels the pending legacy request distinctly');
      loaderHold.complete(); // stale error settlement after disposal
      await pumpEventQueue();
      expect(h.speechCreations, 0,
          reason: 'a disposed facade must never dispatch speech for a stale '
              'catalogue error');
      expect(h.lastSpeech, isNull);
    });

    test(
        'replacement leaves the newer speech owner intact and never '
        'dispatches the stale TTS',
        () async {
      final newer = speech();
      final utteranceHold = Completer<void>();
      newer.speakGate = utteranceHold.future;
      final loaderHold = Completer<void>();
      var loads = 0;
      final h = Harness(
        loader: () async {
          loads++;
          if (loads == 1) {
            await loaderHold.future;
            throw StateError('catalogue-store-lost');
          }
          return fixtureCatalogue();
        },
        recordings: const <FakeCourseRecordingSession>[],
        speeches: [newer],
      );
      final stalePending = h.facade.speak('quelques mots');
      await until(() => loads >= 1, reason: 'stale load dispatch');
      final newerPending = h.facade.speak('bonjour');
      await until(
          () => h.lastSpeech == newer && newer.calls.contains('speak:bonjour'),
          reason: 'newer speech dispatch');
      Object? staleCaught;
      try {
        await stalePending;
      } on Object catch (error) {
        staleCaught = error;
      }
      expect(staleCaught, isA<CourseAudioCancelledException>(),
          reason: 'replacement cancels the stale legacy request distinctly');
      loaderHold.complete(); // stale error while the newer owner is pending
      await pumpEventQueue();
      expect(h.speechCreations, 1,
          reason: 'the stale catalogue error must never dispatch speech');
      expect(
          newer.calls.where((String c) => c == 'speak:quelques mots').length, 0,
          reason: 'no stale utterance may overwrite the newer speech identity');
      utteranceHold.complete();
      await pumpEventQueue();
      await expectLater(newerPending, completes,
          reason: 'the newer owner resolves on its own completion');
      expect(identical(h.lastSpeech, newer), isTrue);
    });

    test(
        'stop during a held legacy catalogue load never dispatches TTS '
        'when the stale settlement is a success',
        () async {
      final loaderHold = Completer<void>();
      var loads = 0;
      final h = Harness(
        loader: () async {
          loads++;
          if (loads == 1) {
            await loaderHold.future;
            return fixtureCatalogue();
          }
          return fixtureCatalogue();
        },
        recordings: const <FakeCourseRecordingSession>[],
        // No speech session queued on purpose: a stale dispatch would
        // fabricate and consume one.
        speeches: [speech()],
      );
      final pending = h.facade.speak('quelques mots');
      await until(() => loads >= 1, reason: 'legacy load dispatch');
      await h.facade.stop();
      Object? legacyCaught;
      try {
        await pending;
      } on Object catch (error) {
        legacyCaught = error;
      }
      expect(legacyCaught, isA<CourseAudioCancelledException>(),
          reason: 'stop cancels the pending legacy request distinctly');
      loaderHold.complete(); // the stale settlement arrives as a success
      await pumpEventQueue();
      expect(h.speechCreations, 0,
          reason: 'a stale catalogue success must never select speech');
      expect(h.lastSpeech, isNull,
          reason: 'no stale speech engine may be created or retained');
      // The facade remains usable for a newer owner after the stale
      // success.
      await expectLater(h.facade.speak('quelques mots'), completes,
          reason: 'facade survives the stale catalogue success');
      expect(h.speechCreations, 1,
          reason: 'only the newer, owned request may use the queued speech');
    });

    test(
        'disposal during a held legacy catalogue load dispatches nothing '
        'when the settlement is a success',
        () async {
      final loaderHold = Completer<void>();
      final h = Harness(
        loader: () async {
          await loaderHold.future;
          return fixtureCatalogue();
        },
      );
      final pending = h.facade.speak('quelques mots');
      await pumpEventQueue();
      await h.facade.dispose();
      Object? legacyCaught;
      try {
        await pending;
      } on Object catch (error) {
        legacyCaught = error;
      }
      expect(legacyCaught, isA<CourseAudioCancelledException>(),
          reason: 'disposal cancels the pending legacy request distinctly');
      loaderHold.complete(); // stale success settlement after disposal
      await pumpEventQueue();
      expect(h.speechCreations, 0,
          reason: 'a disposed facade must never dispatch speech for a stale '
              'catalogue success');
      expect(h.lastSpeech, isNull);
    });

    test(
        'replacement never dispatches the stale TTS when the stale '
        'settlement is a success',
        () async {
      final newer = speech();
      final utteranceHold = Completer<void>();
      newer.speakGate = utteranceHold.future;
      final loaderHold = Completer<void>();
      var loads = 0;
      final h = Harness(
        loader: () async {
          loads++;
          if (loads == 1) {
            await loaderHold.future;
            return fixtureCatalogue();
          }
          return fixtureCatalogue();
        },
        recordings: const <FakeCourseRecordingSession>[],
        speeches: [newer],
      );
      final stalePending = h.facade.speak('quelques mots');
      await until(() => loads >= 1, reason: 'stale load dispatch');
      final newerPending = h.facade.speak('bonjour');
      await until(
          () => h.lastSpeech == newer && newer.calls.contains('speak:bonjour'),
          reason: 'newer speech dispatch');
      Object? staleCaught;
      try {
        await stalePending;
      } on Object catch (error) {
        staleCaught = error;
      }
      expect(staleCaught, isA<CourseAudioCancelledException>(),
          reason: 'replacement cancels the stale legacy request distinctly');
      loaderHold.complete(); // stale success while the newer owner is pending
      await pumpEventQueue();
      expect(h.speechCreations, 1,
          reason: 'the stale catalogue success must never dispatch speech');
      expect(
          newer.calls.where((String c) => c == 'speak:quelques mots').length, 0,
          reason: 'no stale utterance may overwrite the newer speech identity');
      utteranceHold.complete();
      await pumpEventQueue();
      await expectLater(newerPending, completes,
          reason: 'the newer owner resolves on its own completion');
      expect(identical(h.lastSpeech, newer), isTrue);
    });

    test(
        'a stale load settling after its setup deadline is never '
        'dispatched for a stopped request',
        () async {
      final loaderHold = Completer<void>();
      var loads = 0;
      final h = Harness(
        loader: () async {
          loads++;
          if (loads == 1) {
            await loaderHold.future;
            return fixtureCatalogue();
          }
          return fixtureCatalogue();
        },
        recordings: const <FakeCourseRecordingSession>[],
        speeches: [speech()],
      );
      final pending = h.facade.speak('quelques mots');
      await until(() => loads >= 1, reason: 'legacy load dispatch');
      await h.facade.stop();
      Object? legacyCaught;
      try {
        await pending;
      } on Object catch (error) {
        legacyCaught = error;
      }
      expect(legacyCaught, isA<CourseAudioCancelledException>(),
          reason: 'stop cancels the pending legacy request distinctly');
      // Let the harness setup allowance (150ms) expire before the stale
      // settlement arrives: a revoked timeout, not a prompt settlement.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      loaderHold.complete();
      await pumpEventQueue();
      expect(h.speechCreations, 0,
          reason: 'a settlement arriving after its setup deadline must not '
              'select speech');
      expect(h.lastSpeech, isNull);
    });

    test(
        'a stale load settling after its setup deadline is never '
        'dispatched for a disposed request',
        () async {
      final loaderHold = Completer<void>();
      final h = Harness(
        loader: () async {
          await loaderHold.future;
          return fixtureCatalogue();
        },
      );
      final pending = h.facade.speak('quelques mots');
      await pumpEventQueue();
      await h.facade.dispose();
      Object? legacyCaught;
      try {
        await pending;
      } on Object catch (error) {
        legacyCaught = error;
      }
      expect(legacyCaught, isA<CourseAudioCancelledException>(),
          reason: 'disposal cancels the pending legacy request distinctly');
      // Let the harness setup allowance (150ms) expire before the stale
      // settlement arrives: a revoked timeout, not a prompt settlement.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      loaderHold.complete();
      await pumpEventQueue();
      expect(h.speechCreations, 0,
          reason: 'a settlement arriving after its setup deadline must not '
              'select speech on a disposed facade');
      expect(h.lastSpeech, isNull);
    });

    test(
        'a stale load settling after its setup deadline never dispatches '
        'over the newer owner',
        () async {
      final newer = speech();
      final utteranceHold = Completer<void>();
      newer.speakGate = utteranceHold.future;
      final loaderHold = Completer<void>();
      var loads = 0;
      final h = Harness(
        loader: () async {
          loads++;
          if (loads == 1) {
            await loaderHold.future;
            return fixtureCatalogue();
          }
          return fixtureCatalogue();
        },
        recordings: const <FakeCourseRecordingSession>[],
        speeches: [newer],
      );
      final stalePending = h.facade.speak('quelques mots');
      await until(() => loads >= 1, reason: 'stale load dispatch');
      final newerPending = h.facade.speak('bonjour');
      await until(
          () => h.lastSpeech == newer && newer.calls.contains('speak:bonjour'),
          reason: 'newer speech dispatch');
      Object? staleCaught;
      try {
        await stalePending;
      } on Object catch (error) {
        staleCaught = error;
      }
      expect(staleCaught, isA<CourseAudioCancelledException>(),
          reason: 'replacement cancels the stale legacy request distinctly');
      // Let the harness setup allowance (150ms) expire before the stale
      // settlement arrives: a revoked timeout, not a prompt settlement.
      // 220ms also stays inside the newer owner's 300ms facade backstop
      // (setup 150ms + utterance 150ms), so the newer request can still
      // complete on its own when its utterance is released.
      await Future<void>.delayed(const Duration(milliseconds: 220));
      loaderHold.complete(); // stale success after its own deadline
      await pumpEventQueue();
      expect(h.speechCreations, 1,
          reason: 'a revoked stale settlement must never dispatch speech');
      expect(
          newer.calls.where((String c) => c == 'speak:quelques mots').length, 0,
          reason: 'no stale utterance may overwrite the newer speech identity');
      utteranceHold.complete();
      await pumpEventQueue();
      await expectLater(newerPending, completes,
          reason: 'the newer owner resolves on its own completion');
      expect(identical(h.lastSpeech, newer), isTrue);
    });
  });

  group('recording held-boundary coordination (I1)', () {
    test(
        'an actual completion emitted while the start ack is held settles '
        'the request; the late ack success never overrides it',
        () async {
      final session = recording();
      final startHold = Completer<void>();
      session.startGate = startHold.future;
      final h = Harness(recordings: [session]);
      final pending = h.facade.playReference('fr-word-tout');
      await until(() => session.calls.contains('start'), reason: 'start dispatch');
      await session.waitForStart();
      var terminals = 0;
      pending.then((_) => terminals++, onError: (Object _) => terminals++);
      session.emitCompleted(); // actual terminal event, ack still held
      Object? settled;
      try {
        settled = await pending.timeout(const Duration(seconds: 2));
      } on Object catch (error) {
        settled = error;
      }
      expect(settled, isA<CourseAudioResult>(),
          reason: 'an actual completion must settle the public request even '
              'while the raw start ack is still held');
      expect((settled as CourseAudioResult).outcome,
          CourseAudioOutcome.completed);
      startHold.complete(); // the late ack success arrives afterwards
      await pumpEventQueue();
      expect(terminals, 1,
          reason: 'the late ack success must not republish a second terminal');
    });

    test(
        'an actual error emitted while the start ack is held settles the '
        'request; the late ack success never overrides it',
        () async {
      final session = recording();
      final startHold = Completer<void>();
      session.startGate = startHold.future;
      final h = Harness(recordings: [session]);
      final pending = h.facade.playReference('fr-word-tout');
      await until(() => session.calls.contains('start'), reason: 'start dispatch');
      await session.waitForStart();
      session.emitError(PlatformException(code: 'wav-decode-failed'));
      Object? settled;
      try {
        settled = await pending.timeout(const Duration(seconds: 2));
      } on Object catch (error) {
        settled = error;
      }
      expect(settled, isA<CourseAudioResult>(),
          reason: 'an actual error must settle the public request while the '
              'raw start ack is still held');
      final result = settled as CourseAudioResult;
      expect(result.outcome, CourseAudioOutcome.failed);
      expect(result.failure!.reason,
          CourseAudioFailureReason.unsupportedPlayback,
          reason: 'the actual event failure is classified with its cause');
      expect(result.failure!.cause, isA<PlatformException>());
      startHold.complete(); // late success after the actual failure
      await pumpEventQueue();
      await pumpEventQueue();
      final settled2 = await pending;
      expect(settled2, same(result),
          reason: 'the later ack must not override the actual terminal');
    });

    test(
        'a missing completion is bounded from dispatch, not from the late '
        'acknowledgement',
        () async {
      final session = recording();
      final startHold = Completer<void>();
      session.startGate = startHold.future;
      final h = Harness(recordings: [session]);
      final pending = h.facade.playReference('fr-word-tout');
      await until(() => session.calls.contains('start'), reason: 'start dispatch');
      await session.waitForStart();
      // Harness deadlines: setup 150ms, completion floor 50ms, slack 80ms;
      // declared duration 100ms → window max(50, 180) = 180ms from dispatch.
      // The ack is released inside the startup window (100ms) but AFTER the
      // dispatch-origin completion bound (180ms) has expired.
      unawaited(Future<void>.delayed(const Duration(milliseconds: 100),
          () => startHold.complete()));
      final stopwatch = Stopwatch()..start();
      final result = await pending.timeout(const Duration(seconds: 2));
      final elapsed = stopwatch.elapsed.inMilliseconds;
      expect(result.outcome, CourseAudioOutcome.failed);
      expect(result.failure!.reason, CourseAudioFailureReason.completionTimeout,
          reason: 'missing completion is a completion failure, not a '
              'second startup allowance');
      expect(result.failure!.cause, isA<PhaseTimeoutException>(),
          reason: 'the owned floor expiry is the typed owned deadline '
              '(onTimeout-generated), not a raw untyped timeout');
      expect(
          (result.failure!.cause as PhaseTimeoutException).phase,
          CourseAudioFailureReason.completionTimeout,
          reason: 'the completion floor is the expired phase, not an '
              'inference');
      expect(elapsed, lessThan(230),
          reason: 'the completion bound is measured from the start dispatch, '
              'not re-armed after the acknowledgement');
      await pumpEventQueue();
    });

    test(
        'a stale ack failure after an actual terminal is fenced, never a '
        'second terminal',
        () async {
      final session = recording();
      final startHold = Completer<void>();
      session.startGate = startHold.future;
      final h = Harness(recordings: [session]);
      final pending = h.facade.playReference('fr-word-tout');
      await until(() => session.calls.contains('start'), reason: 'start dispatch');
      await session.waitForStart();
      var terminals = 0;
      pending.then((_) => terminals++, onError: (Object _) => terminals++);
      session.emitCompleted();
      Object? settled;
      try {
        settled = await pending.timeout(const Duration(seconds: 2));
      } on Object catch (error) {
        settled = error;
      }
      expect((settled as CourseAudioResult).outcome,
          CourseAudioOutcome.completed);
      startHold.completeError(PlatformException(code: 'stale-ack-failure'));
      await pumpEventQueue();
      await pumpEventQueue();
      expect(terminals, 1,
          reason: 'a stale ack failure must not republish a second terminal');
    });

    test('disposal during a held prepare never starts the recording', () async {
      final session = recording();
      final prepareHold = Completer<void>();
      session.prepareGate = prepareHold.future;
      final h = Harness(recordings: [session]);
      final pending = h.facade.playReference('fr-word-tout');
      await until(() => session.calls.contains('prepare'),
          reason: 'prepare dispatch');
      await h.facade.dispose();
      final result = await pending;
      expect(result.outcome, CourseAudioOutcome.cancelled);
      prepareHold.completeError(PlatformException(code: 'prepare-stale'));
      await pumpEventQueue();
      expect(session.calls.contains('start'), isFalse,
          reason: 'a disposed request never reaches the start dispatch');
    });

    test('stop during a held prepare never starts the recording', () async {
      final session = recording();
      final prepareHold = Completer<void>();
      session.prepareGate = prepareHold.future;
      final h = Harness(recordings: [session]);
      final pending = h.facade.playReference('fr-word-tout');
      await until(() => session.calls.contains('prepare'),
          reason: 'prepare dispatch');
      await h.facade.stop();
      final result = await pending;
      expect(result.outcome, CourseAudioOutcome.cancelled,
          reason: 'stop cancels the held prepare distinctly');
      prepareHold.complete(); // the stale prepare settles as a success
      await pumpEventQueue();
      expect(session.calls.contains('start'), isFalse,
          reason: 'a stopped request never reaches the start dispatch, '
              'even on a successful stale prepare');
    });

    test(
        'stop during a held prepare never starts the recording when the '
        'stale prepare fails',
        () async {
      final session = recording();
      final prepareHold = Completer<void>();
      session.prepareGate = prepareHold.future;
      final h = Harness(recordings: [session]);
      final pending = h.facade.playReference('fr-word-tout');
      await until(() => session.calls.contains('prepare'),
          reason: 'prepare dispatch');
      await h.facade.stop();
      final result = await pending;
      expect(result.outcome, CourseAudioOutcome.cancelled,
          reason: 'stop cancels the held prepare distinctly');
      prepareHold.completeError(PlatformException(code: 'prepare-stale'));
      await pumpEventQueue();
      expect(session.calls.contains('start'), isFalse,
          reason: 'a failed stale prepare never reaches the start dispatch '
              'on a stopped request');
    });

    test(
        'replacement waits for a held stale prepare, then proceeds with the '
        'newer identity, never the stale start',
        () async {
      final stale = recording();
      final newer = recording();
      final prepareHold = Completer<void>();
      stale.prepareGate = prepareHold.future;
      final h = Harness(recordings: [stale, newer]);
      final stalePending = h.facade.playReference('fr-word-tout');
      await until(() => stale.calls.contains('prepare'),
          reason: 'stale prepare dispatch');
      final newerPending = h.facade.playReference('fr-word-tout');
      // While the stale prepare raw operation is still held, the newer
      // owner must not be created or dispatched.
      await pumpEventQueue();
      await pumpEventQueue();
      expect(h.recordingCreations, 1,
          reason: 'the newer recording is not created while the stale '
              'prepare is still held');
      expect(newer.calls, isEmpty,
          reason: 'no start dispatch may occur while the stale prepare is '
              'still held');
      prepareHold.complete(); // the stale prepare settles as a success
      await until(
          () => h.lastRecording == newer && newer.calls.contains('start'),
          reason: 'newer dispatch after the stale prepare quiesces');
      final staleResult = await stalePending;
      expect(staleResult.outcome, CourseAudioOutcome.cancelled,
          reason: 'replacement cancels the stale request distinctly');
      expect(stale.calls.contains('start'), isFalse,
          reason: 'the stale request never reaches start under the newer '
              'identity');
      newer.emitCompleted();
      final result = await newerPending.timeout(const Duration(seconds: 2));
      expect(result.outcome, CourseAudioOutcome.completed);
      expect(identical(h.lastRecording, newer), isTrue,
          reason: 'the newer identity is preserved');
    });

    test(
        'replacement proceeds with the newer identity even when the stale '
        'prepare settles as a failure',
        () async {
      final stale = recording();
      final newer = recording();
      final prepareHold = Completer<void>();
      stale.prepareGate = prepareHold.future;
      final h = Harness(recordings: [stale, newer]);
      final stalePending = h.facade.playReference('fr-word-tout');
      await until(() => stale.calls.contains('prepare'),
          reason: 'stale prepare dispatch');
      final newerPending = h.facade.playReference('fr-word-tout');
      // While the stale prepare raw operation is still held, the newer
      // owner must not be created or dispatched.
      await pumpEventQueue();
      await pumpEventQueue();
      expect(h.recordingCreations, 1,
          reason: 'the newer recording is not created while the stale '
              'prepare is still held');
      expect(newer.calls, isEmpty,
          reason: 'no start dispatch may occur while the stale prepare is '
              'still held');
      prepareHold.completeError(PlatformException(code: 'prepare-stale'));
      await until(
          () => h.lastRecording == newer && newer.calls.contains('start'),
          reason: 'newer dispatch after the stale prepare quiesces');
      final staleResult = await stalePending;
      expect(staleResult.outcome, CourseAudioOutcome.cancelled,
          reason: 'replacement cancels the stale request distinctly');
      expect(stale.calls.contains('start'), isFalse,
          reason: 'the failed stale prepare never reaches start');
      newer.emitCompleted();
      final result = await newerPending.timeout(const Duration(seconds: 2));
      expect(result.outcome, CourseAudioOutcome.completed,
          reason: 'a failed stale prepare operation is fenced by '
              'quiescence and must not block the newer owner');
      expect(identical(h.lastRecording, newer), isTrue,
          reason: 'the newer identity is preserved');
    });

    test(
        'a stale ack failure after cancellation is fenced; the cancelled '
        'terminal is the only one',
        () async {
      final session = recording();
      final startHold = Completer<void>();
      session.startGate = startHold.future;
      final h = Harness(recordings: [session]);
      final pending = h.facade.playReference('fr-word-tout');
      await until(() => session.calls.contains('start'), reason: 'start dispatch');
      await session.waitForStart();
      var terminals = 0;
      pending.then((_) => terminals++, onError: (Object _) => terminals++);
      await h.facade.stop();
      final result = await pending;
      expect(result.outcome, CourseAudioOutcome.cancelled);
      startHold.completeError(PlatformException(code: 'stale-ack-failure'));
      await pumpEventQueue();
      await pumpEventQueue();
      expect(terminals, 1,
          reason: 'the stale ack failure must not republish a second terminal');
    });
  });

  group('narrow failure classification (I4)', () {
    test(
        'a speech failure merely mentioning a French voice stays generic',
        () async {
      final session = speech();
      final decoder = StateError('French voice decoder failed');
      final gate = Completer<void>();
      session.speakGate = gate.future;
      final h = Harness(
          recordings: const <FakeCourseRecordingSession>[],
          speeches: [session]);
      final pending = h.facade.speak('quelques mots');
      await until(() => session.calls.isNotEmpty, reason: 'speech dispatch');
      gate.completeError(decoder);
      Object? caught;
      try {
        await pending;
      } on Object catch (error) {
        caught = error;
      }
      expect(caught, isA<CourseAudioException>());
      final failure = (caught! as CourseAudioException).failure;
      expect(failure.reason, CourseAudioFailureReason.unsupportedPlayback,
          reason:
              'an unrelated speech failure is never relabeled as voice '
              'unavailability');
      expect(identical(failure.cause, decoder), isTrue,
          reason: 'the original diagnostic is preserved');
    });

    test(
        'a platform code merely resembling a gesture rejection stays '
        'generic',
        () async {
      final session = recording();
      final cause = PlatformException(code: 'gesture-decoder-bug');
      final h = Harness(recordings: [session]);
      final pending = h.facade.playReference('fr-word-tout');
      await until(() => session.calls.contains('start'), reason: 'dispatch');
      await session.waitForStart();
      session.emitError(cause);
      final result = await pending;
      expect(result.outcome, CourseAudioOutcome.failed);
      expect(result.failure!.reason, CourseAudioFailureReason.unsupportedPlayback,
          reason:
              'string resemblance is not the autoplay signature; the exact '
              'standard code is the only gesture mapping');
      expect(identical(result.failure!.cause, cause), isTrue);
    });

    test(
        'a misleading permission message with an unrelated code stays '
        'generic',
        () async {
      final session = recording();
      final cause = PlatformException(
          code: 'media-error', message: 'not allowed without user activation');
      final h = Harness(recordings: [session]);
      final pending = h.facade.playReference('fr-word-tout');
      await until(() => session.calls.contains('start'), reason: 'dispatch');
      await session.waitForStart();
      session.emitError(cause);
      final result = await pending;
      expect(result.outcome, CourseAudioOutcome.failed);
      expect(result.failure!.reason, CourseAudioFailureReason.unsupportedPlayback,
          reason: 'invented message inference must not become a gesture '
              'diagnosis');
      expect(identical(result.failure!.cause, cause), isTrue);
    });

    test(
        'the standard autoplay rejection code maps to a gesture '
        'requirement',
        () async {
      final session = recording();
      final cause = PlatformException(code: 'NotAllowedError');
      final h = Harness(recordings: [session]);
      final pending = h.facade.playReference('fr-word-tout');
      await until(() => session.calls.contains('start'), reason: 'dispatch');
      await session.waitForStart();
      session.emitError(cause);
      final result = await pending;
      expect(result.outcome, CourseAudioOutcome.failed);
      expect(result.failure!.reason, CourseAudioFailureReason.userGestureRequired,
          reason: 'the exact standard code is the narrowed autoplay '
              'signature');
      expect(identical(result.failure!.cause, cause), isTrue,
          reason: 'the original diagnostic is preserved');
    });

    test(
        'an opaque, untyped rejection (the untranslated web JS error '
        'shape) stays generic',
        () async {
      final session = recording();
      // The locked web path awaits `play().toDart` untranslated: the
      // rejection arrives as an opaque JS error object, not a typed
      // PlatformException. Such a cause is never diagnosed beyond its
      // generic classification. Real-browser behavior is not certified by
      // this test.
      final cause = Object();
      final h = Harness(recordings: [session]);
      final pending = h.facade.playReference('fr-word-tout');
      await until(() => session.calls.contains('start'), reason: 'dispatch');
      await session.waitForStart();
      session.emitError(cause);
      final result = await pending;
      expect(result.outcome, CourseAudioOutcome.failed);
      expect(result.failure!.reason, CourseAudioFailureReason.unsupportedPlayback,
          reason:
              'an untyped rejection is not a voice, gesture, or phase '
              'diagnosis');
      expect(identical(result.failure!.cause, cause), isTrue,
          reason: 'the original opaque cause is preserved');
    });

    test(
        'a native Dart object resembling a browser rejection stays generic '
        'off the web platform',
        () async {
      final session = recording();
      // A native Dart object whose surface deliberately mimics a browser
      // DOMException (string name/message fields). Off the web platform it
      // is not a browser diagnostic and must stay generic.
      const cause = _NativeRejectionLike(
          message: 'play() not allowed', name: 'NotAllowedError');
      final h = Harness(recordings: [session]);
      final pending = h.facade.playReference('fr-word-tout');
      await until(() => session.calls.contains('start'), reason: 'dispatch');
      await session.waitForStart();
      session.emitError(cause);
      final result = await pending;
      expect(result.outcome, CourseAudioOutcome.failed);
      expect(result.failure!.reason, CourseAudioFailureReason.unsupportedPlayback,
          reason:
              'a native Dart .name surface is not a browser DOMException; '
                  'the VM boundary fabricates no gesture diagnosis');
      expect(identical(result.failure!.cause, cause), isTrue,
          reason: 'the original cause is preserved');
    });
  });

  group('applied production defaults and remaining matrix (I6)', () {
    testWidgets(
        'the default 10-second setup allowance is applied behaviorally '
        'while the raw load is held',
        (tester) async {
      final gate = Completer<void>();
      var loads = 0;
      final facade = FrenchReferenceAudio(
        loadCatalog: () async {
          loads++;
          await gate.future; // raw catalogue load, held past the public bound
          return fixtureCatalogue();
        },
        recordingFactory: () => FakeCourseRecordingSession(),
        speechFactory: () => FakeCourseSpeechSession(),
        deadlines: const CourseAudioDeadlines(), // production defaults
      );
      final pending = facade.playReference('fr-word-tout');
      var settled = false;
      // Terminal observer attached BEFORE the fake clock is advanced.
      pending.then<void>(
          (CourseAudioResult _) => settled = true,
          onError: (Object _) => settled = true);
      await tester.pump();
      expect(loads, 1, reason: 'the load is dispatched once');
      await tester.pump(const Duration(milliseconds: 9500));
      await tester.pump(); // yield so the observer runs before asserting
      expect(settled, isFalse,
          reason: 'inside the default setup allowance the request is '
              'still pending, not failed');
      await tester.pump(const Duration(seconds: 2)); // past the 10s default
      final result = await pending;
      expect(result.outcome, CourseAudioOutcome.failed);
      expect(result.failure!.reason, CourseAudioFailureReason.startupTimeout,
          reason: 'the held load expires the default setup allowance');
      gate.complete(); // the stale load settles after the public failure
      await tester.pump();
      await tester.pump();
    });

    testWidgets(
        'the default 5-second cleanup allowance bounds a pending '
        'retirement, then fails the next owner without overlap',
        (tester) async {
      final session = recording();
      final gate = Completer<void>();
      session.stopGate = gate.future; // holds the raw retirement settlement
      final facade = FrenchReferenceAudio(
        loadCatalog: () =>
            Future<CourseAudioCatalog>.value(fixtureCatalogue()),
        recordingFactory: () => session,
        speechFactory: () => FakeCourseSpeechSession(),
        deadlines: const CourseAudioDeadlines(), // production defaults
      );
      final first = facade.playReference('fr-word-tout');
      await tester.pump();
      await tester.pump();
      expect(session.calls, contains('start'),
          reason: 'the first request dispatches');
      await facade.stop(); // invalidates; the retirement is held by the gate
      final cancelled = await first;
      expect(cancelled.outcome, CourseAudioOutcome.cancelled);
      final second = facade.playReference('fr-word-tout');
      var settled = false;
      // Terminal observer attached BEFORE the fake clock is advanced.
      second.then<void>(
          (CourseAudioResult _) => settled = true,
          onError: (Object _) => settled = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 4900));
      await tester.pump(); // yield so the observer runs before asserting
      expect(settled, isFalse,
          reason: 'the next owner waits for quiescence instead of '
              'overlapping audio');
      await tester.pump(const Duration(seconds: 2)); // past the 5s default
      final blocked = await second;
      expect(blocked.outcome, CourseAudioOutcome.failed);
      expect(blocked.failure!.reason, CourseAudioFailureReason.cleanupFailed,
          reason: 'the held retirement expires the default cleanup '
              'allowance');
      gate.complete(); // release the held raw retirement (fence hygiene)
      await tester.pump();
      await tester.pump();
      // The superseded core keeps its dispatch-origin bound armed (default
      // floor 10s + slack); let it expire on the fake clock so no timer
      // outlives the test.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets(
        'the default 10-second completion floor applies from the start '
        'dispatch while the raw ack stays held',
        (tester) async {
      final session = recording();
      final ackHold = Completer<void>();
      session.startGate = ackHold.future;
      final facade = FrenchReferenceAudio(
        loadCatalog: () =>
            Future<CourseAudioCatalog>.value(fixtureCatalogue()),
        recordingFactory: () => session,
        speechFactory: () => FakeCourseSpeechSession(),
        deadlines: const CourseAudioDeadlines(), // production defaults
      );
      final pending = facade.playReference('fr-word-tout');
      var settled = false;
      // Terminal observer attached BEFORE the fake clock is advanced.
      pending.then<void>(
          (CourseAudioResult _) => settled = true,
          onError: (Object _) => settled = true);
      await tester.pump();
      await tester.pump();
      expect(session.calls, contains('start'),
          reason: 'the start is dispatched and the ack is held raw');
      await tester.pump(const Duration(seconds: 9)); // inside the 10s floor
      await tester.pump(); // yield so the observer runs before asserting
      expect(settled, isFalse,
          reason: 'inside the default completion floor the request stays '
              'pending, not failed');
      // No completion event is ever emitted; the dispatch-origin bound is
      // the default completion floor (10s) for this declared duration.
      await tester.pump(const Duration(seconds: 2)); // past the 10s floor
      final result = await pending;
      expect(result.outcome, CourseAudioOutcome.failed);
      expect(result.failure!.reason, CourseAudioFailureReason.completionTimeout,
          reason:
              'a missing completion is bounded by the default floor from '
              'dispatch, independent of the held raw ack');
      ackHold.complete(); // the raw ack settles long after the public bound
      await tester.pump();
      await tester.pump();
    });

    test(
        'a pending speech is retired, not overlapped, when a newer '
        'recording supersedes it',
        () async {
      final speechFake = speech();
      final utteranceHold = Completer<void>();
      speechFake.speakGate = utteranceHold.future;
      final rec = recording();
      final h = Harness(recordings: [rec], speeches: [speechFake]);
      final legacy = h.facade.speak('quelques mots');
      await until(
          () => speechFake.calls.contains('speak:quelques mots'),
          reason: 'speech dispatch');
      final pending = h.facade.playReference('fr-word-tout');
      // While the stale speech's raw utterance is still held, the newer
      // recording must not be created or dispatched.
      await pumpEventQueue();
      await pumpEventQueue();
      expect(h.recordingCreations, 0,
          reason: 'recording creation is blocked while the old speech is '
              'still held');
      expect(rec.calls, isEmpty,
          reason: 'no start dispatch may occur while the old speech is '
              'still held');
      // The newer owner may not overlap audible work: the stale speech's
      // raw utterance must quiesce before the recording dispatches.
      utteranceHold.complete(); // the stale utterance settles (raw fence)
      await until(
          () => h.lastRecording == rec && rec.calls.contains('start'),
          reason: 'newer dispatch after the stale speech quiesces');
      Object? caughtLegacy;
      try {
        await legacy;
      } on Object catch (error) {
        caughtLegacy = error;
      }
      expect(caughtLegacy, isA<CourseAudioCancelledException>(),
          reason: 'the stale speech request is cancelled distinctly');
      rec.emitCompleted();
      final result = await pending.timeout(const Duration(seconds: 2));
      expect(result.outcome, CourseAudioOutcome.completed);
      expect(speechFake.calls, contains('dispose'),
          reason: 'the superseded speech engine is retired');
      expect(identical(h.lastRecording, rec), isTrue,
          reason: 'the newer identity is not overwritten');
    });

    test(
        'a request after a recording completion timeout succeeds with the '
        'next recording',
        () async {
      final first = recording();
      final second = recording();
      final h = Harness(recordings: [first, second]);
      // Harness bound: max(50ms floor, 100ms + 80ms slack) = 180ms.
      final p1 = h.facade.playReference('fr-word-tout');
      await until(() => first.calls.contains('start'), reason: 'first dispatch');
      // No completion event: the bound expires; retry then succeeds.
      final r1 = await p1.timeout(const Duration(seconds: 2));
      expect(r1.outcome, CourseAudioOutcome.failed);
      expect(r1.failure!.reason, CourseAudioFailureReason.completionTimeout);
      final p2 = h.facade.playReference('fr-word-tout');
      await until(
          () => h.lastRecording == second && second.calls.contains('start'),
          reason: 'retry dispatch');
      second.emitCompleted();
      final r2 = await p2.timeout(const Duration(seconds: 2));
      expect(r2.outcome, CourseAudioOutcome.completed,
          reason: 'a completion timeout does not brick the facade');
      expect(identical(h.lastRecording, second), isTrue);
    });

    test(
        'disposal with a held start ack cancels the terminal once and the '
        'released raw ack never republishes',
        () async {
      final session = recording();
      final ackHold = Completer<void>();
      session.startGate = ackHold.future;
      final h = Harness(recordings: [session]);
      final pending = h.facade.playReference('fr-word-tout');
      await until(() => session.calls.contains('start'), reason: 'dispatch');
      await session.waitForStart();
      var terminals = 0;
      pending.then<void>((CourseAudioResult _) => terminals = 1,
          onError: (Object _) => terminals = 1);
      await h.facade.dispose();
      final result = await pending;
      expect(result.outcome, CourseAudioOutcome.cancelled);
      ackHold.complete(); // the held raw ack settles after disposal
      await pumpEventQueue();
      expect(terminals, 1,
          reason: 'a stale raw settlement after disposal is fenced, never '
              'a second terminal');
    });

    test(
        'a real session utterance-phase expiry through the facade preserves '
        'the EXACT cause and stack the real session boundary produced',
        () async {
      const channel = MethodChannel('flutter_tts');
      final binding = TestWidgetsFlutterBinding.instance;
      final gate = Completer<Object?>();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        if (call.method == 'speak') {
          return gate.future; // hold the raw utterance past the bound
        }
        if (call.method == 'isLanguageAvailable') return true;
        return 1;
      });
      // Observe the ACTUAL createFrenchPracticeSpeechSession result at the
      // facade's speechFactory seam: the recorder records the exact cause
      // and stack of the real session's failed `speak` future and forwards
      // that same settlement by identity (same future, no re-throw), so it
      // cannot replace the diagnostic. It only observes and passes the real
      // failure through — it never manufactures one.
      final observed = _ObservedPracticeSpeechSession(
        createFrenchPracticeSpeechSession(
          deadlines: const CourseAudioDeadlines(
              setup: Duration(milliseconds: 100),
              ttsUtterance: Duration(milliseconds: 150)),
        ),
      );
      final facade = FrenchReferenceAudio(
        loadCatalog: () =>
            Future<CourseAudioCatalog>.value(fixtureCatalogue()),
        recordingFactory: () => FakeCourseRecordingSession(),
        speechFactory: () => observed,
        // The facade backstop (setup + utterance = 450ms) outlives the
        // session's own phases (setup 100ms + utterance 150ms), so the
        // session-typed expiry wins over the facade's backstop
        // classification.
        deadlines: const CourseAudioDeadlines(
          setup: Duration(milliseconds: 150),
          cleanup: Duration(milliseconds: 200),
          completionFloor: Duration(milliseconds: 50),
          completionSlack: Duration(milliseconds: 80),
          ttsUtterance: Duration(milliseconds: 300),
        ),
      );
      Object? caught;
      try {
        await facade
            .speak('quelques mots')
            .timeout(const Duration(seconds: 2));
      } on Object catch (error) {
        caught = error;
      }
      expect(caught, isA<CourseAudioException>(),
          reason: 'the failure is surfaced through the legacy bridge');
      expect(observed.speakDispatches, 1,
          reason: 'the ACTUAL practice session ran exactly once at the '
              'real session-to-facade boundary (not a recording double)');
      expect(observed.observedCause, isA<PhaseTimeoutException>(),
          reason: 'the session boundary delivered its typed utterance-phase '
              'expiry as the exact cause');
      final failure = (caught! as CourseAudioException).failure;
      expect(failure.reason, CourseAudioFailureReason.completionTimeout,
          reason: 'the expired utterance phase classifies as a completion '
              'timeout');
      expect(failure.cause, isA<PhaseTimeoutException>(),
          reason: 'the session-typed owned-deadline diagnostic is the cause '
              'preserved through the stable facade contract');
      expect(
          (failure.cause! as PhaseTimeoutException).phase,
          CourseAudioFailureReason.completionTimeout,
          reason: 'the typed phase is the utterance phase');
      expect(identical(failure.cause, observed.observedCause), isTrue,
          reason: 'the facade preserves the SAME cause object the real '
              'session boundary produced — no replacement between the '
              'session and the facade');
      expect(identical(failure.stackTrace, observed.observedStack), isTrue,
          reason: 'the facade forwards the real session boundary stack '
              'exactly (identical, not merely non-null)');
      gate.complete(null); // release the held raw utterance (fence hygiene)
      await pumpEventQueue();
      await pumpEventQueue();
    });
  });

  group('typed phase and stack preservation (I3)', () {
    test(
        'a speech-session setup timeout classifies as a startup timeout, '
        'not a completion timeout',
        () async {
      const channel = MethodChannel('flutter_tts');
      final binding = TestWidgetsFlutterBinding.instance;
      final gate = Completer<Object?>();
      var held = false;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        if (!held && call.method != 'speak') {
          held = true;
          return gate.future; // hold the setup phase
        }
        if (call.method == 'isLanguageAvailable') return true;
        return 1;
      });
      final facade = FrenchReferenceAudio(
        loadCatalog: () =>
            Future<CourseAudioCatalog>.value(fixtureCatalogue()),
        recordingFactory: () => FakeCourseRecordingSession(),
        speechFactory: () => createFrenchPracticeSpeechSession(
            deadlines: const CourseAudioDeadlines(
                setup: Duration(milliseconds: 150),
                ttsUtterance: Duration(milliseconds: 300))),
        deadlines: const CourseAudioDeadlines(
          setup: Duration(milliseconds: 150),
          cleanup: Duration(milliseconds: 200),
          completionFloor: Duration(milliseconds: 50),
          completionSlack: Duration(milliseconds: 80),
          ttsUtterance: Duration(milliseconds: 150),
        ),
      );
      // An uncovered text speaks through the real bounded session; its
      // setup phase exceeds the setup allowance while the utterance never
      // starts.
      Object? caught;
      try {
        await facade
            .speak('quelques mots')
            .timeout(const Duration(seconds: 2));
      } on Object catch (error) {
        caught = error;
      }
      expect(caught, isA<CourseAudioException>(),
          reason: 'the failure is surfaced through the legacy bridge');
      final failure = (caught! as CourseAudioException).failure;
      expect(failure.reason, CourseAudioFailureReason.startupTimeout,
          reason: 'an expired setup allowance is a startup timeout, not '
              'a completion timeout');
      gate.complete(null); // drain the held setup raw operation
      await pumpEventQueue();
    });

    test(
        'stop during a held speech setup never dispatches the utterance, '
        'even when the stale setup settles as a success',
        () async {
      const channel = MethodChannel('flutter_tts');
      final binding = TestWidgetsFlutterBinding.instance;
      final gate = Completer<Object?>();
      var hasHeld = false;
      var utterances = 0;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        if (call.method == 'isLanguageAvailable') return true;
        if (call.method == 'speak') {
          utterances++;
          return null;
        }
        if (!hasHeld) {
          hasHeld = true;
          return gate.future; // hold the setup phase
        }
        return 1;
      });
      final facade = FrenchReferenceAudio(
        loadCatalog: () =>
            Future<CourseAudioCatalog>.value(fixtureCatalogue()),
        recordingFactory: () => FakeCourseRecordingSession(),
        speechFactory: () => createFrenchPracticeSpeechSession(
            deadlines: const CourseAudioDeadlines(
                setup: Duration(milliseconds: 150),
                ttsUtterance: Duration(milliseconds: 300))),
        deadlines: const CourseAudioDeadlines(
          setup: Duration(milliseconds: 150),
          cleanup: Duration(milliseconds: 200),
          completionFloor: Duration(milliseconds: 50),
          completionSlack: Duration(milliseconds: 80),
          ttsUtterance: Duration(milliseconds: 150),
        ),
      );
      final pending = facade.speak('quelques mots');
      await until(() => hasHeld, reason: 'setup dispatch held');
      await facade.stop();
      Object? caught;
      try {
        await pending;
      } on Object catch (error) {
        caught = error;
      }
      expect(caught, isA<CourseAudioCancelledException>(),
          reason: 'stop cancels the held speech request distinctly');
      gate.complete(null); // the stale setup settles as a success
      await pumpEventQueue();
      await pumpEventQueue();
      expect(utterances, 0,
          reason: 'a stopped request must never start an utterance, even '
              'when the stale setup succeeds');
    });

    test(
        'stop during a held speech setup never dispatches the utterance '
        'when the stale setup fails',
        () async {
      const channel = MethodChannel('flutter_tts');
      final binding = TestWidgetsFlutterBinding.instance;
      final gate = Completer<Object?>();
      var hasHeld = false;
      var utterances = 0;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        if (call.method == 'isLanguageAvailable') return true;
        if (call.method == 'speak') {
          utterances++;
          return null;
        }
        if (!hasHeld) {
          hasHeld = true;
          return gate.future; // hold the setup phase
        }
        return 1;
      });
      final facade = FrenchReferenceAudio(
        loadCatalog: () =>
            Future<CourseAudioCatalog>.value(fixtureCatalogue()),
        recordingFactory: () => FakeCourseRecordingSession(),
        speechFactory: () => createFrenchPracticeSpeechSession(
            deadlines: const CourseAudioDeadlines(
                setup: Duration(milliseconds: 150),
                ttsUtterance: Duration(milliseconds: 300))),
        deadlines: const CourseAudioDeadlines(
          setup: Duration(milliseconds: 150),
          cleanup: Duration(milliseconds: 200),
          completionFloor: Duration(milliseconds: 50),
          completionSlack: Duration(milliseconds: 80),
          ttsUtterance: Duration(milliseconds: 150),
        ),
      );
      final pending = facade.speak('quelques mots');
      await until(() => hasHeld, reason: 'setup dispatch held');
      await facade.stop();
      Object? caught;
      try {
        await pending;
      } on Object catch (error) {
        caught = error;
      }
      expect(caught, isA<CourseAudioCancelledException>(),
          reason: 'stop cancels the held speech request distinctly');
      gate.completeError(StateError('setup-stale')); // stale setup failure
      await pumpEventQueue();
      await pumpEventQueue();
      expect(utterances, 0,
          reason: 'a failed stale setup must never start an utterance on a '
              'stopped request');
    });

    test(
        'replacement waits for a held stale speech setup, then dispatches '
        'only the newer utterance',
        () async {
      const channel = MethodChannel('flutter_tts');
      final binding = TestWidgetsFlutterBinding.instance;
      final gate = Completer<Object?>();
      var hasHeld = false;
      final spoken = <String>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        if (call.method == 'isLanguageAvailable') return true;
        if (call.method == 'speak') {
          spoken.add('${call.arguments}');
          return null;
        }
        if (!hasHeld) {
          hasHeld = true;
          return gate.future; // hold only the first (stale) setup call
        }
        return 1;
      });
      final facade = FrenchReferenceAudio(
        loadCatalog: () =>
            Future<CourseAudioCatalog>.value(fixtureCatalogue()),
        recordingFactory: () => FakeCourseRecordingSession(),
        speechFactory: () => createFrenchPracticeSpeechSession(
            deadlines: const CourseAudioDeadlines(
                setup: Duration(milliseconds: 150),
                ttsUtterance: Duration(milliseconds: 300))),
        deadlines: const CourseAudioDeadlines(
          setup: Duration(milliseconds: 150),
          cleanup: Duration(milliseconds: 200),
          completionFloor: Duration(milliseconds: 50),
          completionSlack: Duration(milliseconds: 80),
          ttsUtterance: Duration(milliseconds: 150),
        ),
      );
      final stalePending = facade.speak('quelques mots');
      await until(() => hasHeld, reason: 'stale setup held');
      final newerPending = facade.speak('bonjour');
      // While the stale setup raw operation is still held, neither
      // utterance may dispatch: the newer owner waits for quiescence.
      await pumpEventQueue();
      await pumpEventQueue();
      expect(spoken, isEmpty,
          reason: 'no utterance may dispatch while the stale setup is '
              'still held');
      gate.complete(null); // the stale setup settles as a success
      await until(() => spoken.contains('bonjour'), reason: 'newer utterance');
      expect(spoken.contains('quelques mots'), isFalse,
          reason: 'the stale utterance must never dispatch under the newer '
              'identity');
      Object? staleCaught;
      try {
        await stalePending;
      } on Object catch (error) {
        staleCaught = error;
      }
      expect(staleCaught, isA<CourseAudioCancelledException>(),
          reason: 'replacement cancels the stale speech request distinctly');
      await expectLater(newerPending, completes,
          reason: 'the newer utterance resolves on its own completion');
    });

    test(
        'replacement proceeds with the newer utterance even when the stale '
        'speech setup settles as a failure',
        () async {
      const channel = MethodChannel('flutter_tts');
      final binding = TestWidgetsFlutterBinding.instance;
      final gate = Completer<Object?>();
      var hasHeld = false;
      final spoken = <String>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        if (call.method == 'isLanguageAvailable') return true;
        if (call.method == 'speak') {
          spoken.add('${call.arguments}');
          return null;
        }
        if (!hasHeld) {
          hasHeld = true;
          return gate.future; // hold only the first (stale) setup call
        }
        return 1;
      });
      final facade = FrenchReferenceAudio(
        loadCatalog: () =>
            Future<CourseAudioCatalog>.value(fixtureCatalogue()),
        recordingFactory: () => FakeCourseRecordingSession(),
        speechFactory: () => createFrenchPracticeSpeechSession(
            deadlines: const CourseAudioDeadlines(
                setup: Duration(milliseconds: 150),
                ttsUtterance: Duration(milliseconds: 300))),
        deadlines: const CourseAudioDeadlines(
          setup: Duration(milliseconds: 150),
          cleanup: Duration(milliseconds: 200),
          completionFloor: Duration(milliseconds: 50),
          completionSlack: Duration(milliseconds: 80),
          ttsUtterance: Duration(milliseconds: 150),
        ),
      );
      final stalePending = facade.speak('quelques mots');
      await until(() => hasHeld, reason: 'stale setup held');
      final newerPending = facade.speak('bonjour');
      // While the stale setup raw operation is still held, neither
      // utterance may dispatch: the newer owner waits for quiescence.
      await pumpEventQueue();
      await pumpEventQueue();
      expect(spoken, isEmpty,
          reason: 'no utterance may dispatch while the stale setup is '
              'still held');
      gate.completeError(StateError('setup-stale')); // stale setup failure
      await until(() => spoken.contains('bonjour'), reason: 'newer utterance');
      expect(spoken.contains('quelques mots'), isFalse,
          reason: 'a failed stale setup must never dispatch the stale '
              'utterance');
      Object? staleCaught;
      try {
        await stalePending;
      } on Object catch (error) {
        staleCaught = error;
      }
      expect(staleCaught, isA<CourseAudioCancelledException>(),
          reason: 'replacement cancels the stale speech request distinctly');
      await expectLater(newerPending, completes,
          reason: 'a failed stale setup operation is fenced by quiescence '
              'and must not block the newer owner');
    });

    test(
        'a durable retirement failure blocks the next owner and keeps its '
        'stack trace',
        () async {
      final session = recording();
      final gate = Completer<void>();
      session.stopGate = gate.future;
      final h = Harness(recordings: [session]);
      final pending = h.facade.playReference('fr-word-tout');
      await until(() => session.calls.contains('start'), reason: 'dispatch');
      await h.facade.stop();
      final first = await pending;
      expect(first.outcome, CourseAudioOutcome.cancelled);
      final cause = StateError('retirement-broken');
      gate.completeError(cause);
      await pumpEventQueue();
      Object? caught;
      try {
        caught = await h.facade
            .playReference('fr-word-huit')
            .timeout(const Duration(seconds: 2));
      } on Object catch (error) {
        caught = error;
      }
      expect(caught, isA<CourseAudioResult>(),
          reason: 'the blocked replacement fails typed, not silently');
      final result = caught as CourseAudioResult;
      expect(result.outcome, CourseAudioOutcome.failed);
      expect(result.failure!.reason, CourseAudioFailureReason.cleanupFailed,
          reason: 'a failed cleanup blocks the next owner');
      expect(identical(result.failure!.cause, cause), isTrue,
          reason: 'the original retirement failure is the cause');
      expect(result.failure!.stackTrace, isNotNull,
          reason: 'the durable retirement failure must carry its '
              'stack trace for retry diagnosis');
    });
  });

  group('active catalogue failures surface typed, never TTS (I5)', () {
    test('an active invalid catalogue fails typed and never selects speech',
        () async {
      final invalid = CourseAudioException(
        CourseAudioFailure(
          reason: CourseAudioFailureReason.invalidCatalogue,
          cause: StateError('broken manifest'),
        ),
      );
      var loads = 0;
      final speechFake = speech();
      final h = Harness(
        loader: () async {
          loads++;
          if (loads == 1) {
            throw invalid;
          }
          return fixtureCatalogue();
        },
        recordings: const <FakeCourseRecordingSession>[],
        speeches: [speechFake],
      );
      Object? caught;
      try {
        await h.facade.speak('tout');
      } on Object catch (error) {
        caught = error;
      }
      expect(caught, isA<CourseAudioException>());
      expect((caught! as CourseAudioException).failure.reason,
          CourseAudioFailureReason.invalidCatalogue,
          reason: 'the catalogue failure is surfaced for Retry');
      expect(h.speechCreations, 0,
          reason: 'an active catalogue failure is not permission for TTS');
      // A retry after a working resolution may still speak uncovered text.
      await expectLater(h.facade.speak('quelques mots'), completes,
          reason: 'a later, successfully resolved request succeeds');
      expect(h.speechCreations, 1);
      expect(identical(h.lastSpeech, speechFake), isTrue,
          reason: 'only the resolved request may use the speech engine');
    });

    test(
        'an active catalogue load timeout fails as a startup timeout without '
        'selecting speech',
        () async {
      final hold = Completer<void>();
      final h = Harness(
        loader: () async {
          await hold.future;
          return fixtureCatalogue();
        },
        recordings: const <FakeCourseRecordingSession>[],
        speeches: [speech()],
      );
      Object? caught;
      try {
        await h.facade.speak('tout');
      } on Object catch (error) {
        caught = error;
      }
      // The harness deadlines bound the catalogue load at 150ms.
      expect(caught, isA<CourseAudioException>());
      expect((caught! as CourseAudioException).failure.reason,
          CourseAudioFailureReason.startupTimeout);
      expect(h.speechCreations, 0,
          reason: 'a load timeout is not permission for TTS');
      hold.complete(); // the stale success must not resurrect the request
      await pumpEventQueue();
    });

    test(
        'an active generic catalogue error on uncovered text still fails '
        'typed instead of speaking',
        () async {
      final cause = PlatformException(code: 'corrupt-store');
      final speechFake = speech();
      final h = Harness(
        loader: () async => throw cause,
        recordings: const <FakeCourseRecordingSession>[],
        speeches: [speechFake],
      );
      Object? caught;
      try {
        await h.facade.speak('quelques mots');
      } on Object catch (error) {
        caught = error;
      }
      expect(caught, isA<CourseAudioException>());
      final failure = (caught! as CourseAudioException).failure;
      expect(failure.reason, CourseAudioFailureReason.unsupportedPlayback,
          reason: 'coverage cannot be established — no implicit TTS');
      expect(identical(failure.cause, cause), isTrue,
          reason: 'the original diagnostic is preserved');
      expect(h.speechCreations, 0);
    });
  });

  group('FrenchReferenceAudio (legacy speak bridge)', () {
    test(
        'legacy unmapped text uses practice speech and resolves only on completion',
        () async {
      final session = speech();
      final rec = recording();
      final gate = Completer<void>();
      session.speakGate = gate.future;
      final h = Harness(recordings: [rec], speeches: [session]);
      final pending = h.facade.speak('quelques mots inconnus');
      await until(() => session.calls.isNotEmpty, reason: 'speech dispatch');
      expect(session.calls.first, 'speak:quelques mots inconnus');
      var settled = false;
      pending.then((_) => settled = true, onError: (_) => settled = true);
      await pumpEventQueue();
      expect(settled, isFalse,
          reason: 'the legacy bridge resolves only on completion');
      gate.complete();
      await pending;
      expect(h.recordingCreations, 0);
    });

    test('legacy mapped word plays the bundled recording by default', () async {
      final session = recording();
      final sp = speech();
      final h = Harness(recordings: [session], speeches: [sp]);
      final pending = h.facade.speak('tout');
      await until(
          () => h.lastRecording == session && session.calls.contains('start'),
          reason: 'start dispatch');
      await session.waitForStart();
      session.emitCompleted();
      await pending;
      expect(sp.calls, isEmpty,
          reason: 'covered words use the recording, not TTS');
    });

    test('legacy declared unrecorded word uses practice speech', () async {
      final session = speech();
      final h = Harness(recordings: [recording()], speeches: [session]);
      await h.facade.speak('huit');
      expect(session.calls, contains('speak:huit'));
      expect(h.recordingCreations, 0);
    });

    test(
        'legacy recording failure raises a typed exception without TTS fallback',
        () async {
      final session = recording();
      final sp = speech();
      final h = Harness(recordings: [session], speeches: [sp]);
      final pending = h.facade.speak('tout');
      await until(
          () => h.lastRecording == session && session.calls.contains('start'),
          reason: 'start dispatch');
      await session.waitForStart();
      session
          .emitError(PlatformException(code: 'wav-decode-failed'));
      Object? caught;
      try {
        await pending;
      } on Object catch (error) {
        caught = error;
      }
      expect(caught, isA<CourseAudioException>());
      final exception = caught! as CourseAudioException;
      expect(exception.failure.reason,
          CourseAudioFailureReason.unsupportedPlayback);
      expect(sp.calls, isEmpty,
          reason: 'a declared recording failure must never substitute TTS');
    });

    test('legacy cancellation throws the distinct cancellation exception',
        () async {
      final session = recording();
      final startHold = Completer<void>();
      session.startGate = startHold.future;
      final h = Harness(recordings: [session, recording()]);
      final pending = h.facade.speak('tout');
      await until(
          () => h.lastRecording == session && session.calls.contains('start'),
          reason: 'start dispatch');
      await session.waitForStart();
      await h.facade.stop();
      Object? caught;
      try {
        await pending;
      } on Object catch (error) {
        caught = error;
      }
      expect(caught, isA<CourseAudioCancelledException>(),
          reason:
              'success continuations must not be able to mark the word heard');
      expect(caught, isNot(isA<CourseAudioException>()));
      startHold.complete(); // drain the held acknowledgement
      await pumpEventQueue();
    });

    test('a newer legacy speak supersedes the older one', () async {
      final older = recording();
      final newer = recording();
      final startHold = Completer<void>();
      older.startGate = startHold.future;
      final h = Harness(recordings: [older, newer]);
      final first = h.facade.speak('tout');
      await until(
          () => h.lastRecording == older && older.calls.contains('start'),
          reason: 'older dispatch');
      await older.waitForStart();
      Object? caughtFirst;
      // A block-body handler returns null (assignable to the Null-inferred
      // `then` result type). An arrow `=> caughtFirst = e` returns the error
      // value, which this Dart version rejects with ArgumentError("onError")
      // when the future errors; the capture is identical.
      first.then((_) {}, onError: (Object e) {
        caughtFirst = e;
      });
      final second = h.facade.speak('tout');
      startHold.complete(); // the older raw work quiesces
      await _settleGate(startHold);
      await pumpEventQueue();
      await until(
          () => h.lastRecording == newer && newer.calls.contains('start'),
          reason: 'newer dispatch');
      await newer.waitForStart();
      newer.emitCompleted();
      await second;
      await pumpEventQueue();
      expect(caughtFirst, isA<CourseAudioCancelledException>());
    });

    test('legacy TTS failure raises a typed exception with the cause', () async {
      final session = speech();
      final voice = StateError(
          'Install a French voice in your device speech settings.');
      final gate = Completer<void>();
      session.speakGate = gate.future;
      final h = Harness(recordings: [recording()], speeches: [session]);
      final pending = h.facade.speak('quelques mots');
      await until(() => session.calls.isNotEmpty, reason: 'speech dispatch');
      gate.completeError(voice);
      Object? caught;
      try {
        await pending;
      } on Object catch (error) {
        caught = error;
      }
      expect(caught, isA<CourseAudioException>());
      final exception = caught! as CourseAudioException;
      expect(exception.failure.reason,
          CourseAudioFailureReason.unavailableVoice);
      expect(identical(exception.failure.cause, voice), isTrue,
          reason: 'the original voice-availability cause is preserved');
    });
  });

  group('deadline contract (applied production defaults)', () {
    test('production defaults are the approved bounds', () {
      const defaults = CourseAudioDeadlines();
      expect(defaults.setup, const Duration(seconds: 10));
      expect(defaults.cleanup, const Duration(seconds: 5));
      expect(defaults.completionFloor, const Duration(seconds: 10));
      expect(defaults.completionSlack, const Duration(seconds: 5));
      expect(defaults.ttsUtterance, const Duration(seconds: 12));
    });

    test('recording completion is max(floor, duration + slack)', () {
      const defaults = CourseAudioDeadlines();
      // 3s + 5s slack = 8s < 10s floor → floor wins (hand-derived).
      expect(
        defaults.recordingCompletion(const Duration(seconds: 3)),
        const Duration(seconds: 10));
      // 8s + 5s slack = 13s > 10s floor → duration + slack wins.
      expect(
        defaults.recordingCompletion(const Duration(seconds: 8)),
        const Duration(seconds: 13));
    });
  });

  group('round 3 (F2): owned backstops typed, source timeouts conservative',
      () {
    test(
        'a raw source utterance timeout before the facade allowance keeps '
        'the original object, message and explicit stack, and stays '
        'conservative',
        () async {
      final source = TimeoutException(
          'source utterance timeout, not an owned deadline',
          const Duration(seconds: 30));
      final explicitStack = StackTrace.fromString(
          'source-utterance-explicit-stack:fix3-f2a');
      final facade = FrenchReferenceAudio(
        loadCatalog:
            () => Future<CourseAudioCatalog>.value(fixtureCatalogue()),
        recordingFactory: () => FakeCourseRecordingSession(),
        speechFactory: () => _ExplicitSpeechFailureSession(source, explicitStack),
        deadlines: const CourseAudioDeadlines(
          setup: Duration(seconds: 3),
          cleanup: Duration(seconds: 3),
          completionFloor: Duration(milliseconds: 50),
          completionSlack: Duration(milliseconds: 80),
          ttsUtterance: Duration(seconds: 3),
        ),
      );
      Object? caught;
      try {
        await facade
            .speak('quelques mots')
            .timeout(const Duration(seconds: 2));
      } on Object catch (error) {
        caught = error;
      }
      expect(caught, isA<CourseAudioException>(),
          reason: 'the source failure is surfaced through the legacy bridge');
      final failure = (caught! as CourseAudioException).failure;
      expect(failure.reason, CourseAudioFailureReason.unsupportedPlayback,
          reason: 'a raw source timeout is the conservative bucket, never '
              'an inferred expired ownership budget');
      expect(identical(failure.cause, source), isTrue,
          reason: 'the original TimeoutException object is preserved');
      expect(
          (failure.cause as TimeoutException).message,
          'source utterance timeout, not an owned deadline',
          reason: 'the original source message is preserved verbatim');
      expect(identical(failure.stackTrace, explicitStack), isTrue,
          reason: 'the explicitly supplied source stack is forwarded, not '
              'merely present');
    });

    test('the facade speech backstop expiry is a typed owned deadline, never '
        'a raw untyped timeout', () async {
      final hold = Completer<void>();
      final facade = FrenchReferenceAudio(
        loadCatalog:
            () => Future<CourseAudioCatalog>.value(fixtureCatalogue()),
        recordingFactory: () => FakeCourseRecordingSession(),
        speechFactory:
            () => _ExplicitSpeechFailureSession(null, null, hold: hold.future),
        deadlines: const CourseAudioDeadlines(
          setup: Duration(milliseconds: 150),
          cleanup: Duration(seconds: 3),
          completionFloor: Duration(milliseconds: 50),
          completionSlack: Duration(milliseconds: 80),
          ttsUtterance: Duration(milliseconds: 200),
        ),
      );
      Object? caught;
      try {
        await facade
            .speak('quelques mots')
            .timeout(const Duration(seconds: 2));
      } on Object catch (error) {
        caught = error;
      }
      expect(caught, isA<CourseAudioException>());
      final failure = (caught! as CourseAudioException).failure;
      expect(failure.reason, CourseAudioFailureReason.completionTimeout,
          reason: 'the facade speech backstop expiry is a completion timeout');
      expect(failure.cause, isA<PhaseTimeoutException>(),
          reason: 'the backstop owns its deadline metadata (onTimeout '
              'generated) instead of surfacing a raw, untyped timeout');
      expect(
          (failure.cause as PhaseTimeoutException).phase,
          CourseAudioFailureReason.completionTimeout,
          reason: 'the owned backstop is the phase, not an inference');
      expect(failure.stackTrace, isNotNull,
          reason: 'the owned backstop failure carries its stack trace');
      hold.complete();
      await pumpEventQueue();
      await pumpEventQueue();
    });

    test('a raw source catalogue-load timeout before the setup allowance is '
        'conservative, keeping the original object, message and stack',
        () async {
      final source =
          TimeoutException('source load timeout', const Duration(seconds: 30));
      final explicitStack =
          StackTrace.fromString('source-load-explicit-stack:fix3-f2c');
      final h = Harness(
          loader: () =>
              Future<CourseAudioCatalog>.error(source, explicitStack));
      Object? caught;
      try {
        await h.facade
            .speak('quelques mots')
            .timeout(const Duration(seconds: 2));
      } on Object catch (error) {
        caught = error;
      }
      expect(caught, isA<CourseAudioException>(),
          reason: 'a load failure is surfaced through the legacy bridge');
      final failure = (caught! as CourseAudioException).failure;
      expect(failure.reason, CourseAudioFailureReason.unsupportedPlayback,
          reason: 'a raw source load timeout is conservative, never '
              'relabelled as an expired start phase');
      expect(identical(failure.cause, source), isTrue,
          reason: 'the original object is preserved');
      expect((failure.cause as TimeoutException).message, 'source load timeout',
          reason: 'the original message is preserved');
      expect(identical(failure.stackTrace, explicitStack), isTrue,
          reason: 'the explicit source stack is forwarded, not merely present');
      expect(h.speechCreations, 0,
          reason: 'no TTS engine may be selected for a load failure');
    });

    test('a raw source prepare timeout before the setup allowance is '
        'conservative, never an inferred startup phase', () async {
      final session = recording();
      final prepareHold = Completer<void>();
      session.prepareGate = prepareHold.future;
      final h = Harness(recordings: [session]);
      final pending = h.facade.playReference('fr-word-tout');
      await until(() => session.calls.contains('prepare'),
          reason: 'prepare dispatch');
      prepareHold.completeError(
          TimeoutException('source prepare timeout',
              const Duration(seconds: 30)));
      final result = await pending.timeout(const Duration(seconds: 2));
      expect(result.outcome, CourseAudioOutcome.failed);
      final failure = result.failure!;
      expect(failure.reason, CourseAudioFailureReason.unsupportedPlayback,
          reason: 'a raw source timeout during prepare is conservative, '
              'never an inferred expired setup phase');
      expect(failure.cause, isA<TimeoutException>(),
          reason: 'the original source failure is preserved');
      expect(
          (failure.cause as TimeoutException).message,
          contains('source prepare timeout'));
    });

    test('a raw source start-ack timeout before the setup allowance is '
        'conservative, never an inferred startup phase', () async {
      final session = recording();
      final startHold = Completer<void>();
      session.startGate = startHold.future;
      final h = Harness(recordings: [session]);
      final pending = h.facade.playReference('fr-word-tout');
      await until(() => session.calls.contains('start'), reason: 'dispatch');
      await session.waitForStart();
      startHold.completeError(TimeoutException('source ack timeout',
          const Duration(seconds: 30)));
      final result = await pending.timeout(const Duration(seconds: 2));
      expect(result.outcome, CourseAudioOutcome.failed);
      final failure = result.failure!;
      expect(failure.reason, CourseAudioFailureReason.unsupportedPlayback,
          reason: 'a raw source ack timeout is conservative, never an '
              'inferred expired setup phase');
      expect(failure.cause, isA<TimeoutException>(),
          reason: 'the original source failure is preserved');
      expect(
          (failure.cause as TimeoutException).message,
          contains('source ack timeout'));
    });

    test('a raw source terminal timeout before the completion floor is '
        'conservative, never an inferred floor expiry', () async {
      final session = recording();
      final h = Harness(recordings: [session]);
      final pending = h.facade.playReference('fr-word-tout');
      await until(() => session.calls.contains('start'), reason: 'dispatch');
      await session.waitForStart();
      session.emitError(TimeoutException('source terminal timeout',
          const Duration(seconds: 30)));
      final result = await pending.timeout(const Duration(seconds: 2));
      expect(result.outcome, CourseAudioOutcome.failed);
      final failure = result.failure!;
      expect(failure.reason, CourseAudioFailureReason.unsupportedPlayback,
          reason: 'a raw source timeout event is conservative, never an '
              'inferred expired completion floor');
      expect(failure.cause, isA<TimeoutException>(),
          reason: 'the original source failure is preserved');
      expect(
          (failure.cause as TimeoutException).message,
          contains('source terminal timeout'));
    });
  });

  group('round 3 (F1): successive facade sessions never cross-contaminate', () {
    test(
        'a predecessor-origin late callback cannot fail the successor, which '
        'completes only on its own raw future and not before the '
        'predecessor raw work quiesces',
        () async {
      const channel = MethodChannel('flutter_tts');
      final binding = TestWidgetsFlutterBinding.instance;
      final aGate = Completer<Object?>();
      final bGate = Completer<Object?>();
      final spoken = <String>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        if (call.method == 'isLanguageAvailable') return true;
        if (call.method == 'speak') {
          final Object? args = call.arguments;
          final Object? text = args is String
              ? args
              : (args is Map ? args['text'] : null);
          final String word = text?.toString() ?? '';
          spoken.add(word);
          if (word == 'premier') return aGate.future;
          return bGate.future; // each raw utterance stays held (web shape)
        }
        if (call.method == 'stop') return 1;
        return 1;
      });
      final facade = FrenchReferenceAudio(
        loadCatalog:
            () => Future<CourseAudioCatalog>.value(fixtureCatalogue()),
        recordingFactory: () => FakeCourseRecordingSession(),
        speechFactory: () => createFrenchPracticeSpeechSession(
            deadlines: const CourseAudioDeadlines(
                setup: Duration(milliseconds: 300),
                ttsUtterance: Duration(milliseconds: 400))),
        deadlines: const CourseAudioDeadlines(
          setup: Duration(milliseconds: 300),
          cleanup: Duration(seconds: 3),
          completionFloor: Duration(milliseconds: 50),
          completionSlack: Duration(milliseconds: 80),
          ttsUtterance: Duration(milliseconds: 400),
        ),
      );
      // A: held past its OWN utterance bound → A fails with its own typed
      // bound, and its raw work is still held when the fence must run.
      Object? aOutcome;
      final aPending = facade.speak('premier');
      unawaited(aPending.then<void>(
          (Object? value) => aOutcome = 'completed',
          onError: (Object error) => aOutcome = error));
      await until(() => spoken.contains('premier'), reason: 'A dispatch');
      final aSettle = Stopwatch()..start();
      while (aOutcome == null &&
          aSettle.elapsed < const Duration(seconds: 3)) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(aOutcome, isA<CourseAudioException>(),
          reason: 'A fails on its own utterance bound');
      expect((aOutcome! as CourseAudioException).failure.reason,
          CourseAudioFailureReason.completionTimeout,
          reason: 'A keeps its own typed owned-bound failure');
      // B is issued while A's raw utterance is still held: no unsafe
      // re-playback — B must wait until A's raw work quiesces.
      Object? bOutcome;
      final bPending = facade.speak('second');
      unawaited(bPending.then<void>(
          (Object? value) => bOutcome = 'completed',
          onError: (Object error) => bOutcome = error));
      await pumpEventQueue();
      await pumpEventQueue();
      expect(spoken.contains('second'), isFalse,
          reason: 'the successor cannot dispatch while the predecessor raw '
              'utterance is still held');
      aGate.complete(null); // A's raw utterance settles (web completion)
      await until(() => spoken.contains('second'),
          reason: 'B dispatch only after A quiesced');
      // A-origin late callback, delivered over the exact locked flutter_tts
      // global path (identity-free: it may belong to A).
      await binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter_tts',
          const StandardMethodCodec().encodeMethodCall(const MethodCall(
              'speak.onError',
              {'code': 'predecessor-failure',
               'message': 'web speech failed'})),
          (ByteData? reply) {});
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(bOutcome, isNull,
          reason: 'a predecessor-origin callback must not settle the '
              'successor request (Option 1: callbacks are never an outcome '
              'source)');
      // B completes only on its own actual raw future.
      bGate.complete(null);
      final bSettle = Stopwatch()..start();
      while (bOutcome == null &&
          bSettle.elapsed < const Duration(seconds: 3)) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(bOutcome, 'completed',
          reason: 'the successor completes via its own actual raw future '
              'and does not inherit the predecessor failure');
      expect((aOutcome as CourseAudioException).failure.reason,
          CourseAudioFailureReason.completionTimeout,
          reason: 'the predecessor keeps its own terminal result');
    });
  });

  group('round 3 (F3): held cleanup and disposal release cells', () {
    test(
        'stop with a held cleanup settles promptly as cancelled; the next '
        'owner stays blocked on the pending raw fence and proceeds only on '
        'the shared cleanup success',
        () async {
      final stale = recording();
      final newer = recording();
      final cleanupHold = Completer<void>();
      stale.stopGate = cleanupHold.future;
      var created = 0;
      final facade = FrenchReferenceAudio(
        loadCatalog:
            () => Future<CourseAudioCatalog>.value(fixtureCatalogue()),
        recordingFactory: () {
          created++;
          return created == 1 ? stale : newer;
        },
        speechFactory: () => FakeCourseSpeechSession(),
        deadlines: const CourseAudioDeadlines(
          setup: Duration(seconds: 3),
          cleanup: Duration(seconds: 3),
          completionFloor: Duration(milliseconds: 50),
          completionSlack: Duration(milliseconds: 80),
          ttsUtterance: Duration(milliseconds: 150),
        ),
      );
      final pending = facade.playReference('fr-word-tout');
      await until(() => stale.calls.contains('start'), reason: 'dispatch');
      await stale.waitForStart();
      var terminals = 0;
      unawaited(pending.then<void>(
          (CourseAudioResult _) => terminals++,
          onError: (Object _) => terminals++));
      await facade.stop();
      final result = await pending.timeout(const Duration(seconds: 2));
      expect(result.outcome, CourseAudioOutcome.cancelled,
          reason: 'stop cancels the request promptly, before the held '
              'cleanup settles — the raw fence is pending, not done');
      // The pending raw fence: the next owner cannot be created or
      // dispatched while the shared cleanup is still held.
      final next = facade.playReference('fr-word-tout');
      unawaited(next.then<void>(
          (CourseAudioResult _) {}, onError: (Object _) {}));
      await pumpEventQueue();
      await pumpEventQueue();
      expect(created, 1,
          reason: 'the next recording is not created or dispatched while '
              'the held cleanup is pending (the raw fence is pending)');
      // Shared cleanup success: the fence releases and the next owner
      // proceeds and completes.
      cleanupHold.complete();
      await until(
          () => created == 2 && newer.calls.contains('start'),
          reason: 'the next owner proceeds on the shared cleanup success');
      newer.emitCompleted();
      final nextResult = await next.timeout(const Duration(seconds: 2));
      expect(nextResult.outcome, CourseAudioOutcome.completed,
          reason: 'a successful shared cleanup lets the next owner play');
      expect(terminals, 1,
          reason: 'the stopped request published exactly one terminal');
    });

    test('stop with a held cleanup that fails on release settles the '
        'prompt as cancelled, holds the replacement on the pending fence, '
        'then durably blocks it with the exact released cause and stack',
        () async {
      final stale = recording();
      final newer = recording();
      final cause = StateError('cleanup-failed');
      final explicitStack =
          StackTrace.fromString('cleanup-explicit-stack:fix4-f3a');
      // A REAL pending cleanup: the shared retirement is held on this
      // completer and fails only when released below — the hold→failure
      // transition is what is proven, not an already-failed gate.
      final cleanupHold = Completer<void>();
      stale.stopGate = cleanupHold.future;
      var created = 0;
      final facade = FrenchReferenceAudio(
        loadCatalog:
            () => Future<CourseAudioCatalog>.value(fixtureCatalogue()),
        recordingFactory: () {
          created++;
          return created == 1 ? stale : newer;
        },
        speechFactory: () => FakeCourseSpeechSession(),
        deadlines: const CourseAudioDeadlines(
          setup: Duration(seconds: 3),
          cleanup: Duration(seconds: 3),
          completionFloor: Duration(milliseconds: 50),
          completionSlack: Duration(milliseconds: 80),
          ttsUtterance: Duration(milliseconds: 150),
        ),
      );
      final pending = facade.playReference('fr-word-tout');
      await until(() => stale.calls.contains('start'), reason: 'dispatch');
      await stale.waitForStart();
      var terminals = 0;
      unawaited(pending.then<void>(
          (CourseAudioResult _) => terminals++,
          onError: (Object _) => terminals++));
      await facade.stop();
      final result = await pending.timeout(const Duration(seconds: 2));
      expect(result.outcome, CourseAudioOutcome.cancelled,
          reason: 'stop cancels the request promptly while the shared '
              'cleanup is still pending — a held, not pre-failed, fence');
      expect(cleanupHold.isCompleted, isFalse,
          reason: 'the prompt terminal is observed before the pending '
              'cleanup settles — the hold→failure transition is real');
      expect(stale.calls.contains('stop'), isTrue,
          reason: 'retirement has started and captured the pending gate');
      // Replacement issued while held: blocked on the pending shared fence —
      // neither settled, nor created, nor dispatched.
      final next = facade.playReference('fr-word-tout');
      var nextSettled = false;
      unawaited(next.then<void>(
          (CourseAudioResult _) => nextSettled = true,
          onError: (Object _) => nextSettled = true));
      await pumpEventQueue();
      await pumpEventQueue();
      expect(nextSettled, isFalse,
          reason: 'the replacement stays held on the pending shared '
              'cleanup — it does not settle before the failure is released');
      expect(created, 1,
          reason: 'the next recording is not created or dispatched while '
              'the held cleanup is pending (the raw fence is pending)');
      // Release the held cleanup as a failure, on release.
      cleanupHold.completeError(cause, explicitStack);
      Object? nextOutcome;
      try {
        nextOutcome = await next.timeout(const Duration(seconds: 2));
      } on Object catch (error) {
        nextOutcome = error;
      }
      expect(nextOutcome, isA<CourseAudioResult>(),
          reason: 'the blocked replacement fails typed, not silently');
      final failure = (nextOutcome as CourseAudioResult).failure!;
      expect(failure.reason, CourseAudioFailureReason.cleanupFailed,
          reason: 'a failed shared cleanup blocks the next owner durably');
      expect(identical(failure.cause, cause), isTrue,
          reason: 'the explicit cleanup failure cause released at gate '
              'settlement is preserved exactly');
      expect(identical(failure.stackTrace, explicitStack), isTrue,
          reason: 'the explicitly supplied cleanup stack is forwarded '
              'exactly from the pending release, not merely present');
      expect(created, 1,
          reason: 'no replacement recording is created after the failed '
              'release');
      expect(newer.calls, isEmpty,
          reason: 'no replacement dispatch after the failed release');
      expect(terminals, 1,
          reason:
              'no second terminal is published for the stopped request');
    });

    test('dispose with a held cleanup settles promptly as cancelled; no '
        'late dispatch follows and exactly one terminal is published',
        () async {
      final stale = recording();
      final cleanupHold = Completer<void>();
      stale.stopGate = cleanupHold.future;
      final facade = FrenchReferenceAudio(
        loadCatalog:
            () => Future<CourseAudioCatalog>.value(fixtureCatalogue()),
        recordingFactory: () => stale,
        speechFactory: () => FakeCourseSpeechSession(),
        deadlines: const CourseAudioDeadlines(
          setup: Duration(seconds: 3),
          cleanup: Duration(seconds: 3),
          completionFloor: Duration(milliseconds: 50),
          completionSlack: Duration(milliseconds: 80),
          ttsUtterance: Duration(milliseconds: 150),
        ),
      );
      final pending = facade.playReference('fr-word-tout');
      await until(() => stale.calls.contains('start'), reason: 'dispatch');
      await stale.waitForStart();
      var terminals = 0;
      unawaited(pending.then<void>(
          (CourseAudioResult _) => terminals++,
          onError: (Object _) => terminals++));
      await facade.dispose();
      final result = await pending.timeout(const Duration(seconds: 2));
      expect(result.outcome, CourseAudioOutcome.cancelled,
          reason:
              'disposal cancels the request promptly while the raw '
                  'cleanup is fenced pending');
      final callsAtDispose = stale.calls.length;
      cleanupHold.complete(); // the held cleanup settles as a success
      await pumpEventQueue();
      await pumpEventQueue();
      expect(stale.calls.length, callsAtDispose,
          reason: 'no late dispatch follows once the disposal cleanup '
              'settles');
      expect(terminals, 1,
          reason: 'no second terminal is published under disposal');
      expect(
          () => facade.playReference('fr-word-tout'),
          throwsA(isA<StateError>()),
          reason: 'a disposed facade cannot accept new requests');
    });

    test('dispose with a held cleanup that fails on release keeps one '
        'prompt cancelled terminal, no late dispatch, and a shared durable '
        'failure with the exact released cause and forwarded stack',
        () async {
      final stale = recording();
      final cause = StateError('disposal-cleanup-failed');
      final explicitStack =
          StackTrace.fromString('disposal-explicit-stack:fix4-f3d');
      // A REAL pending cleanup: the shared retirement is held on this
      // completer and fails only when released below — the hold→failure
      // transition is proven, not an already-failed gate.
      final cleanupHold = Completer<void>();
      stale.stopGate = cleanupHold.future;
      final facade = FrenchReferenceAudio(
        loadCatalog:
            () => Future<CourseAudioCatalog>.value(fixtureCatalogue()),
        recordingFactory: () => stale,
        speechFactory: () => FakeCourseSpeechSession(),
        deadlines: const CourseAudioDeadlines(
          setup: Duration(seconds: 3),
          cleanup: Duration(seconds: 3),
          completionFloor: Duration(milliseconds: 50),
          completionSlack: Duration(milliseconds: 80),
          ttsUtterance: Duration(milliseconds: 150),
        ),
      );
      final pending = facade.playReference('fr-word-tout');
      await until(() => stale.calls.contains('start'), reason: 'dispatch');
      await stale.waitForStart();
      var terminals = 0;
      unawaited(pending.then<void>(
          (CourseAudioResult _) => terminals++,
          onError: (Object _) => terminals++));
      await facade.dispose();
      final result = await pending.timeout(const Duration(seconds: 2));
      expect(result.outcome, CourseAudioOutcome.cancelled,
          reason: 'disposal cancellation is prompt while the held cleanup '
              'is still pending');
      expect(cleanupHold.isCompleted, isFalse,
          reason: 'the prompt terminal is observed before the pending '
              'cleanup settles — the hold→failure transition is real');
      // Repeated retirement WHILE the retirement gate is still pending:
      // a second retirement caller of the same session must share the
      // unresolved fence instead of returning early. Invoke it, attach
      // both outcome observers immediately, pump, and assert it remains
      // unsettled — a retirement that succeeded early here would still be
      // allowed the stored error later and would slip through otherwise.
      final Future<void> repeatedRetirement = stale.dispose();
      var repeatSettled = false;
      unawaited(
          repeatedRetirement.then<void>((void _) {
            repeatSettled = true;
          }, onError: (Object _) {
            repeatSettled = true;
          }));
      await pumpEventQueue();
      await pumpEventQueue();
      expect(cleanupHold.isCompleted, isFalse,
          reason: 'the held gate is still pending when the repeated '
              'retirement is observed');
      expect(repeatSettled, isFalse,
          reason: 'the repeated retirement shares the unresolved fence and '
              'stays unsettled; it cannot succeed early before the gate '
              'settles');
      // Baseline call count taken AFTER the deliberate repeated call.
      final callsAtHeldRepeat = stale.calls.length;
      // Release the held cleanup as a failure, on release.
      cleanupHold.completeError(cause, explicitStack);
      await pumpEventQueue();
      await pumpEventQueue();
      expect(stale.calls.length, callsAtHeldRepeat,
          reason: 'no late dispatch follows once the failed cleanup '
              'settles under disposal');
      expect(terminals, 1,
          reason: 'no second terminal is published under disposal');
      // The same already-observed repeated retirement, released with the
      // failure, must settle to the shared durable failure with the exact
      // released cause and the forwarded stack — the shared fence proven
      // from a second retirement caller, not only the first one.
      Object? repeatCaught;
      StackTrace? repeatStack;
      try {
        await repeatedRetirement;
      } on Object catch (error, stackTrace) {
        repeatCaught = error;
        repeatStack = stackTrace;
      }
      expect(repeatSettled, isTrue,
          reason: 'the shared fence settles on release, so the repeated '
              'retirement settles with it');
      expect(identical(repeatCaught, cause), isTrue,
          reason: 'the repeated retirement shares the durable cleanup '
              'failure released at settlement — identical cause');
      expect(identical(repeatStack, explicitStack), isTrue,
          reason: 'the repeated retirement observes the same explicitly '
              'supplied cleanup stack, not merely present');
      // The shared durable cleanup failure is also observable by a
      // later retirement caller — with the exact released cause and the
      // forwarded stack.
      Object? sharedCaught;
      StackTrace? sharedStack;
      try {
        await stale.dispose();
      } on Object catch (error, stackTrace) {
        sharedCaught = error;
        sharedStack = stackTrace;
      }
      expect(identical(sharedCaught, cause), isTrue,
          reason: 'every retirement caller of the same session shares the '
              'durable cleanup failure released at settlement');
      expect(identical(sharedStack, explicitStack), isTrue,
          reason: 'the explicitly supplied cleanup stack is shared exactly '
              'across retirement callers, not merely present');
      expect(
          () => facade.playReference('fr-word-tout'),
          throwsA(isA<StateError>()),
          reason: 'a disposed facade cannot accept new requests');
    });
  });
}

/// Awaits the held gate's future so its settlement side effects run.
/// A planted gate failure is owned by the session under test (its
/// retirement or cancellation accounting already observed it); the drain
/// must not relitigate that failure in the test body.
Future<void> _settleGate(Completer<void> hold) async {
  try {
    await hold.future;
  } on Object {
    // A planted failure, already accounted for by the session.
  }
}

/// A native Dart object whose surface deliberately mimics a browser
/// DOMException (a string `name` property). It must never become a gesture
/// diagnosis on a non-web platform: the VM recognition boundary is
/// conservative by construction, and a Dart `.name` double is not proof of
/// the actual JS rejection path (that path is browser-only test ground).
final class _NativeRejectionLike {
  const _NativeRejectionLike({required this.message, required this.name});
  final String message;
  final String name;
}

/// A [CoursePracticeSpeechSession] double for the facade seam tests.
///
/// `speak` either returns [hold] (a held raw utterance, for the facade
/// backstop test) or fails with an explicitly supplied cause and stack
/// (for the raw source-timeout classification test). The explicit stack is
/// the forwarding evidence: the facade must carry that exact stack on the
/// stable failure, not merely a non-null one.
final class _ExplicitSpeechFailureSession implements CoursePracticeSpeechSession {
  const _ExplicitSpeechFailureSession(this.cause, this.stack, {this.hold});

  final Object? cause;
  final StackTrace? stack;
  final Future<void>? hold;

  @override
  Future<void> speak(String text) {
    final Future<void>? held = hold;
    if (held != null) return held;
    if (cause != null && stack != null) {
      Error.throwWithStackTrace(cause!, stack!);
    }
    throw StateError('speech double: no failure supplied');
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

/// A transparent facade-seam recorder for the REAL practice session: it
/// wraps the actual [createFrenchPracticeSpeechSession] result, records the
/// exact cause and stack of the real session's failed `speak` future at the
/// session boundary, and forwards that same settlement by identity (the
/// SAME future, no re-throw) — so it cannot replace the diagnostic. Unlike
/// [_ExplicitSpeechFailureSession], it never manufactures a failure; it
/// only observes the real one and passes it through to the facade.
final class _ObservedPracticeSpeechSession
    implements CoursePracticeSpeechSession {
  _ObservedPracticeSpeechSession(this._session);

  final CoursePracticeSpeechSession _session;

  /// The exact cause the real session's failed `speak` future delivered.
  Object? observedCause;

  /// The stack the real session's failed `speak` future delivered with it.
  StackTrace? observedStack;

  /// Number of `speak` attempts forwarded to the real session.
  int speakDispatches = 0;

  @override
  Future<void> speak(String text) {
    speakDispatches++;
    final Future<void> real = _session.speak(text);
    unawaited(real.then<void>(
      (Object? value) {},
      onError: (Object error, StackTrace stackTrace) {
        observedCause = error;
        observedStack = stackTrace;
      },
    ));
    return real;
  }

  @override
  Future<void> stop() => _session.stop();

  @override
  Future<void> dispose() => _session.dispose();
}
