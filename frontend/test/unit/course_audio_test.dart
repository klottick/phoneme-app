import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio.dart';

void main() {
  const channel = MethodChannel('flutter_tts');
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  void mockSpeech(Future<dynamic> Function() speak, {bool available = true}) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'isLanguageAvailable') return available;
      if (call.method == 'speak') return speak();
      return 1;
    });
  }

  tearDown(() =>
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

  test('accepts web null completion from the TTS channel', () async {
    mockSpeech(() async => null);
    await expectLater(FrenchWordAudio().speak('tout'), completes);
  });
  test('accepts native success completion', () async {
    mockSpeech(() async => 1);
    await expectLater(FrenchWordAudio().speak('tout'), completes);
  });
  test('rejects an explicit playback failure', () async {
    mockSpeech(() async => 0);
    await expectLater(FrenchWordAudio().speak('tout'), throwsStateError);
  });
  test('propagates platform errors', () async {
    mockSpeech(() async => throw PlatformException(code: 'audio-unavailable'));
    await expectLater(
        FrenchWordAudio().speak('tout'), throwsA(isA<PlatformException>()));
  });
  test('rejects an unavailable French voice before playing', () async {
    mockSpeech(() async => fail('Must not speak without a French voice'),
        available: false);
    await expectLater(FrenchWordAudio().speak('tout'), throwsStateError);
  });
  testWidgets('times out if the browser never completes playback',
      (tester) async {
    final pending = Completer<dynamic>();
    mockSpeech(() => pending.future);
    final expectation = expectLater(
        FrenchWordAudio().speak('tout'), throwsA(isA<TimeoutException>()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));
    await expectation;
    pending.complete(null);
    await tester.pump();
  });

  testWidgets('applies the injected setup bound and runs nothing further',
      (tester) async {
    final gate = Completer<Object?>();
    var held = false;
    final calls = <String>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      calls.add(call.method);
      if (call.method == 'setLanguage' && !held) {
        held = true;
        return gate.future;
      }
      if (call.method == 'isLanguageAvailable') return true;
      return 1;
    });

    final audio = FrenchWordAudio(const CourseAudioDeadlines(
        setup: Duration(milliseconds: 300)));
    final pending = audio
        .speak('mot')
        .then<Object?>((_) => 'completed', onError: (Object e) => e);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final outcome = await pending;
    expect(outcome, isA<TimeoutException>(),
        reason: 'the setup phase is bounded by the setup allowance');
    final atFailure = calls.length;
    gate.complete(1); // the held setup call settles late
    await tester.pump();
    await tester.pump();
    expect(calls.length, atFailure,
        reason: 'a failed (timed-out) setup must not run later setup or '
            'speech');
  });

  group('FrenchPracticeSpeechSession (bounded real adapter)', () {
    test('rejects nonpositive deadlines at construction', () {
      expect(
        () => createFrenchPracticeSpeechSession(
            deadlines:
                const CourseAudioDeadlines(ttsUtterance: Duration.zero)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('lazy: a stop with no utterance initializes no TTS', () async {
      var channelCalls = 0;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        channelCalls++;
        return call.method == 'isLanguageAvailable' ? true : 1;
      });
      final session = createFrenchPracticeSpeechSession();
      await session.stop();
      expect(channelCalls, 0,
          reason: 'a stop with no initialized TTS must not initialize it');
    });

    test('lazy: a dispose with no utterance initializes no TTS', () async {
      var channelCalls = 0;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        channelCalls++;
        return call.method == 'isLanguageAvailable' ? true : 1;
      });
      final session = createFrenchPracticeSpeechSession();
      await session.dispose();
      expect(channelCalls, 0,
          reason: 'a dispose with no initialized TTS must not initialize it');
    });

    test('speak completes on an actual utterance completion', () async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        if (call.method == 'isLanguageAvailable') return true;
        if (call.method == 'speak') return null; // web completion value
        return 1;
      });
      final session = createFrenchPracticeSpeechSession();
      await expectLater(session.speak('mot'), completes);
      await session.dispose();
    });

    test('speak surfaces the French-voice cause unchanged', () async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        if (call.method == 'isLanguageAvailable') return false;
        if (call.method == 'speak') {
          fail('must not speak without a French voice');
        }
        return 1;
      });
      final session = createFrenchPracticeSpeechSession();
      Object? caught;
      try {
        await session.speak('mot');
      } on Object catch (error) {
        caught = error;
      }
      expect(caught, isA<StateError>(),
          reason: 'the direct adapter voice-availability cause is preserved');
      expect(caught!.toString(), contains('French voice'));
      await session.stop();
    });

    test('speak surfaces platform errors unchanged', () async {
      final platformError =
          PlatformException(code: 'speech-unsupported');
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        if (call.method == 'isLanguageAvailable') return true;
        if (call.method == 'speak') throw platformError;
        return 1;
      });
      final session = createFrenchPracticeSpeechSession();
      await expectLater(
        session.speak('mot'),
        throwsA((Object error) =>
            identical(error, platformError) ||
            error.toString().contains('speech-unsupported')),
      );
      await session.stop();
    });

    test('a retired session rejects further speech', () async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        if (call.method == 'isLanguageAvailable') return true;
        return 1;
      });
      final session = createFrenchPracticeSpeechSession();
      await session.stop();
      expect(session.speak('mot'), throwsA(isA<StateError>()),
          reason: 'a retired session is permanently single-use');
    });

    test('repeated stop/dispose calls share one retirement outcome', () async {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        if (call.method == 'isLanguageAvailable') return true;
        if (call.method == 'speak') return null;
        return 1;
      });
      final session = createFrenchPracticeSpeechSession();
      await session.speak('mot');
      final first = session.stop();
      final second = session.stop();
      final third = session.dispose();
      await expectLater(first, completes);
      await expectLater(second,
          completes,
          reason:
              'repeated retirement callers await one shared outcome');
      await expectLater(third, completes);
    });

    test('retirement propagates a stop cleanup failure to every caller',
        () async {
      final gate = Completer<Object?>();
      final platformError = PlatformException(code: 'stop-broken');
      var stopCalls = 0;
      var dispatched = false;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        if (call.method == 'isLanguageAvailable') return true;
        if (call.method == 'speak') {
          dispatched = true;
          return gate.future;
        }
        if (call.method == 'stop') {
          stopCalls++;
          // The setup's replacement stop succeeds; the retirement's own
          // stop is the raw control call that fails cleanup.
          if (stopCalls >= 2) throw platformError;
          return 1;
        }
        return 1;
      });
      final session = createFrenchPracticeSpeechSession();
      final pending = session.speak('mot');
      unawaited(pending.then<void>((Object? value) {},
          onError: (Object error) {}));
      // Wait until the utterance dispatch is pending on the gate.
      final stopwatch = Stopwatch()..start();
      while (!dispatched && stopwatch.elapsed < const Duration(seconds: 5)) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(dispatched, isTrue, reason: 'the utterance must be dispatched');

      final firstStop = session.stop();
      final secondStop = session.stop();
      gate.complete(null); // the abandoned utterance settles (raw fence)
      Object? firstCaught;
      try {
        await firstStop;
      } on Object catch (error) {
        firstCaught = error;
      }
      Object? secondCaught;
      try {
        await secondStop;
      } on Object catch (error) {
        secondCaught = error;
      }
      expect(firstCaught, isA<PlatformException>(),
          reason:
              'a stop cleanup failure must not be reported as quiescence');
      expect(
          (firstCaught as PlatformException).code, 'stop-broken');
      expect(secondCaught, isA<PlatformException>(),
          reason: 'every retirement caller shares the failure');
      expect(identical(secondCaught, firstCaught), isTrue,
          reason: 'the shared failure must keep the original diagnostic');
      await expectLater(pending, completes,
          reason: 'the abandoned utterance drains quietly');
    });

    testWidgets('retirement fences a held utterance before quiescence',
        (tester) async {
      final gate = Completer<Object?>();
      var held = false;
      var dispatched = false;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        if (call.method == 'speak') {
          if (!held) {
            held = true;
            dispatched = true;
          }
          return gate.future;
        }
        if (call.method == 'isLanguageAvailable') return true;
        return 1;
      });

      final session = createFrenchPracticeSpeechSession();
      final pending = session.speak('mot').then<void>(
        (Object? value) {},
        onError: (Object error) {},
      );
      await tester.pump();
      // The utterance dispatch is raw work; quiescence must fence it.
      // A zero-pump elapses the fake clock; `Future.delayed(zero)` would
      // otherwise wait on a fake timer that a duration-less pump never fires.
      await tester.pump(Duration.zero);
      expect(dispatched, isTrue);
      final stopFuture = session.stop();
      var settled = false;
      unawaited(stopFuture.then<void>(
        (Object? value) => settled = true,
        onError: (Object error) => settled = true,
      ));
      await tester.pump();
      expect(settled, isFalse,
          reason:
              'quiescence must await the held raw utterance, not a timed-out '
              'public future');
      gate.complete(null); // release the held utterance (web completion)
      await tester.pump();
      await tester.pump();
      expect(settled, isTrue,
          reason: 'quiescence settles once every raw operation has settled');
      await expectLater(pending, completes,
          reason: 'the abandoned utterance drains quietly');
    });

    testWidgets(
        'retirement fences the raw stop control call before quiescence',
        (tester) async {
      final stopGate = Completer<Object?>();
      var stopCalls = 0;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        if (call.method == 'stop') {
          stopCalls++;
          // The first stop is the setup replacement; the held one is the
          // retirement's own raw control call.
          return stopCalls == 1 ? 1 : stopGate.future;
        }
        if (call.method == 'isLanguageAvailable') return true;
        if (call.method == 'speak') return null;
        return 1;
      });

      final session = createFrenchPracticeSpeechSession();
      final pending = session.speak('mot').then<void>(
        (Object? value) {},
        onError: (Object error) {},
      );
      await tester.pump();
      await tester.pump();
      final stopFuture = session.stop();
      var settled = false;
      unawaited(stopFuture.then<void>(
        (Object? value) => settled = true,
        onError: (Object error) => settled = true,
      ));
      await tester.pump();
      expect(settled, isFalse,
          reason: 'quiescence must include the raw stop control call');
      stopGate.complete(1);
      await tester.pump();
      await tester.pump();
      expect(settled, isTrue);
      await expectLater(pending, completes);
    });

    testWidgets('an active setup timeout rejects while the session stays quiet',
        (tester) async {
      final gate = Completer<Object?>();
      var held = false;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
            if (call.method == 'setLanguage' && !held) {
              held = true;
              return gate.future;
            }
            if (call.method == 'isLanguageAvailable') return true;
            return 1;
          });
      final session = createFrenchPracticeSpeechSession(
          deadlines: const CourseAudioDeadlines(
              setup: Duration(milliseconds: 300)));
      final pending = session.speak('mot').then<Object?>(
          (_) => 'completed', onError: (Object e) => e);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final outcome = await pending;
      expect(outcome, isA<TimeoutException>(),
          reason: 'the session inherits the bounded adapter setup');
      gate.complete(1);
      await tester.pump();
      await tester.pump();
      await expectLater(session.stop(), completes,
          reason: 'a failed setup leaves no held raw work for the fence');
    });
  });
}
