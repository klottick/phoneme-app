// FR-03 Task 3 (fix round 2, R3): browser-only verification of the web
// recognition boundary.
//
// These tests exercise genuine browser rejections: a real DOMException
// (the exact name the browser uses for `play()`/AudioContext autoplay
// rejections) rejected by a JSPromise and converted via `toDart()` — the
// same untranslated shape the locked recording web path delivers. They
// also cover the safe-rejection shapes (unknown name, missing `name`,
// non-string `name`, misleading non-object sources, a throwing `name`
// getter) and the facade's cause/stack preservation for the recognized
// rejection.
//
// They do NOT run on the VM: the VM stub is conservative by construction
// and a Dart `.name` double through it is not proof of the actual JS
// rejection path. This file is skipped at run time on non-browser
// platforms and only executes under `flutter test --platform chrome`.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/browser_rejection_boundary.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_audio_catalog.dart';
import 'package:linguist/src/core/course/course_exercise.dart';
import 'package:linguist/src/core/course/course_reference_audio.dart';

import '../support/fake_course_recording_session.dart';
import '../support/fake_course_speech_session.dart';

/// A JS value that stands in for a resolved promise, so the caller can tell
/// a resolution from a rejection.
final class _ResolvedSentinel {
  @override
  String toString() => 'promise unexpectedly resolved';
}

Future<Object?> _capturedRejection(JSAny? reason) async {
  final JSPromise<JSAny?> promise = JSPromise<JSAny?>(
      (JSFunction resolve, JSFunction reject) {
    reject.callAsFunction(reject, reason);
  }.toJS);
  try {
    await promise.toDart;
    return _ResolvedSentinel();
  } on Object catch (error) {
    return error;
  }
}

JSObject _domException(String message, String name) {
  final JSFunction constructor = globalContext['DOMException'] as JSFunction;
  return constructor.callAsConstructor<JSObject>(message.toJS, name.toJS);
}

/// Minimal fixture catalogue: one recorded word (`fr-word-tout`).
CourseAudioCatalog _fixtureCatalogue() => CourseAudioCatalog(
      references: [
        CourseAudioReference(
            id: 'fr-word-tout',
            kind: AudioReferenceKind.word,
            spokenText: 'tout'),
      ],
      entries: [
        CourseAudioEntry(
          reference: CourseAudioReference(
              id: 'fr-word-tout',
              kind: AudioReferenceKind.word,
              spokenText: 'tout'),
          recordings: {
            CourseAudioVariant.normal: CourseAudioRecording(
              assetKey: 'assets/audio/fr/words/fr-word-tout.wav',
              byteLength: 44100,
              duration: const Duration(milliseconds: 100),
              source: CourseAudioSource.unverifiedRecording,
            ),
          },
          credit: CourseAudioCredit(
            referenceId: 'fr-word-tout',
            spokenText: 'tout',
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
          ),
        ),
      ],
    );

Future<void> _until(bool Function() condition,
    {String reason = 'condition'}) async {
  final stopwatch = Stopwatch()..start();
  while (!condition()) {
    if (stopwatch.elapsed > const Duration(seconds: 5)) {
      fail('timed out waiting for $reason');
    }
    await pumpEventQueue();
  }
}

/// A throwing `name` getter source: a plain Dart closure converted with
/// `.toJS` (no `@JSExport` needed for local conversion — the SDK's own
/// `Future.toJS` uses the same pattern). When the browser evaluates this
/// getter it must be rejected safely, never allowed to crash recognition.
void _throwingNameGetter() {
  throw StateError('a throwing name getter must be rejected safely');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('browser rejection boundary (genuine web rejections via toDart)', () {
    test('recognizes the exact DOMException name NotAllowedError', () async {
      final Object? error =
          await _capturedRejection(_domException('play() rejected', 'NotAllowedError'));
      expect(error, isNot(_ResolvedSentinel()),
          reason: 'the rejection arrives through toDart, not a resolution');
      expect(isBrowserAutoplayRejection(error), isTrue,
          reason: 'a genuine browser NotAllowedError must be recognized');
    });

    test('safely rejects a DOMException with an unknown name', () async {
      final Object? error =
          await _capturedRejection(_domException('aborted', 'AbortError'));
      expect(isBrowserAutoplayRejection(error), isFalse,
          reason: 'an other-name DOMException is a different failure');
    });

    test('safely rejects an object without a name property', () async {
      final Object? error = await _capturedRejection(JSObject());
      expect(isBrowserAutoplayRejection(error), isFalse,
          reason: 'a missing name is never invented into a rejection');
    });

    test('safely rejects a non-string name', () async {
      final Object? error = await _capturedRejection(
          JSObject()..['name'] = 42.toJS);
      expect(isBrowserAutoplayRejection(error), isFalse,
          reason: 'a non-string name is not a DOMException name');
    });

    test('safely rejects misleading non-object sources', () async {
      for (final JSAny? misleading in <JSAny?>[
        'NotAllowedError'.toJS, // the exact name as a plain string
        42.toJS // an unrelated number
      ]) {
        final Object? error = await _capturedRejection(misleading);
        expect(isBrowserAutoplayRejection(error), isFalse,
            reason: 'string/number shapes are not source-shaped rejections');
      }
    });

    test('safely rejects a throwing name getter without throwing', () async {
      final JSObject throwing = JSObject();
      final JSObject objectConstructor =
          globalContext['Object'] as JSObject;
      final JSFunction defineProperty =
          objectConstructor['defineProperty'] as JSFunction;
      final JSObject descriptor = JSObject()
        ..['get'] = _throwingNameGetter.toJS;
      defineProperty.callAsFunction(defineProperty, throwing, 'name'.toJS,
          descriptor);
      final Object? error = await _capturedRejection(throwing);
      expect(isBrowserAutoplayRejection(error), isFalse,
          reason: 'a throwing name getter is a safe rejection, not a crash');
    });

    test('does not invent a diagnosis for a native Dart object', () async {
      final Object error = Object();
      expect(isBrowserAutoplayRejection(error), isFalse,
          reason: 'native objects are not browser diagnostics on any '
              'platform, web included');
    });

    test('the facade keeps the original cause through the recognized '
        'rejection', () async {
      final Object? cause = await _capturedRejection(
          _domException('play() rejected', 'NotAllowedError'));
      expect(cause, isNotNull);
      final session = FakeCourseRecordingSession();
      final facade = FrenchReferenceAudio(
        loadCatalog: () => Future<CourseAudioCatalog>.value(_fixtureCatalogue()),
        recordingFactory: () => session,
        speechFactory: () => FakeCourseSpeechSession(),
        deadlines: const CourseAudioDeadlines(
          setup: Duration(milliseconds: 150),
          cleanup: Duration(milliseconds: 200),
          completionFloor: Duration(milliseconds: 50),
          completionSlack: Duration(milliseconds: 80),
          ttsUtterance: Duration(milliseconds: 150),
        ),
      );
      final pending = facade.playReference('fr-word-tout');
      await _until(() => session.calls.contains('start'), reason: 'dispatch');
      await session.waitForStart();
      session.emitError(cause!);
      final result = await pending;
      expect(result.outcome, CourseAudioOutcome.failed,
          reason: 'the recognized rejection is a failed outcome, not '
              'silence or success');
      expect(result.failure!.reason, CourseAudioFailureReason.userGestureRequired,
          reason: 'the exact browser rejection maps to the gesture '
              'diagnosis');
      expect(identical(result.failure!.cause, cause), isTrue,
          reason: 'the original cause object is preserved');
      expect(result.failure!.stackTrace, isNotNull,
          reason: 'the failure carries a stack trace for diagnosis');
    });
  });
}
