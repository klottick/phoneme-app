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
import 'package:linguist/src/core/course/course_audio_catalog.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
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
