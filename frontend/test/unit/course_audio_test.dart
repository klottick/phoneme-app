import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
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

  testWidgets(
      'R2: the owned utterance deadline expiry is the typed completionTimeout '
          'phase (the direct caller may still catch a TimeoutException)',
      (tester) async {
    final gate = Completer<Object?>();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'isLanguageAvailable') return true;
      if (call.method == 'speak') {
        return gate.future; // the raw utterance is held past the allowance
      }
      return 1;
    });
    const Duration allowance = Duration(milliseconds: 200);
    final audio = FrenchWordAudio(const CourseAudioDeadlines(
        setup: Duration(seconds: 30), ttsUtterance: allowance));
    final pending = audio
        .speak('mot')
        .then<Object?>(
            (Object? value) => null, onError: (Object error) => error);
    await tester.pump();
    // Held raw work settles only from the owned deadline, not from a source.
    await tester.pump(allowance + const Duration(milliseconds: 50));
    final Object? outcome = await pending;
    expect(outcome, isA<PhaseTimeoutException>(),
        reason:
            'the expired allowance is reported as the typed owned deadline');
    expect((outcome! as PhaseTimeoutException).phase,
        CourseAudioFailureReason.completionTimeout,
        reason: 'the utterance phase is what expired, not the setup phase');
    expect(outcome, isA<TimeoutException>(),
        reason: 'the direct caller may still catch a TimeoutException');
    expect((outcome as PhaseTimeoutException).duration, allowance,
        reason: 'the phase carries the owned allowance, not an inferred one');
    gate.complete(null); // release the held raw work for the fence
    await tester.pump();
  });

  test('R2: a source timeout settling before the allowance is conservatively '
      'preserved and is not relabelled as the owned phase', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'isLanguageAvailable') return true;
      if (call.method == 'speak') {
        // A genuine source (platform) timeout that settles before this
        // adapter's allowance. It is delivered as the source's own failure,
        // and must not be relabelled as an expired phase of this adapter.
        throw TimeoutException('source-timed-out',
            const Duration(milliseconds: 1));
      }
      return 1;
    });
    final audio = FrenchWordAudio(const CourseAudioDeadlines(
        setup: Duration(seconds: 30), ttsUtterance: Duration(seconds: 30)));
    Object? caught;
    try {
      await audio.speak('mot');
    } on Object catch (error) {
      caught = error;
    }
    expect(caught, isNot(isA<PhaseTimeoutException>()),
        reason:
            'an arbitrary source timeout must not be relabelled as this '
                'adapter expired phase');
    // The source failure is preserved as delivered: the channel carries the
    // source diagnostic (it is never a phase of this adapter).
    expect(caught, isA<PlatformException>(),
        reason: 'the source timeout reaches the direct caller as the source '
            'diagnostic, not as a phase of this adapter');
    expect((caught! as PlatformException).message, contains('source-timed-out'),
        reason: 'the original source diagnostic is preserved');
    // Round-3 honesty note (F2): this test is channel-TRANSPORT coverage —
    // the mock handler's throw crosses the (mocked) MethodChannel, so the
    // direct caller sees the source diagnostic wrapped in a Platform
    // envelope. It preserves the envelope text but does NOT demonstrate raw
    // object identity. Raw identity (object, message, source stack with no
    // envelope) is demonstrated by the FlutterTts subclass seam tests below,
    // where the source crosses the real adapter pipeline.
  });

  // F2 round 3 (coverage, not a new behavior RED): an injected FlutterTts
  // subclass fails its own method with the EXACT supplied timeout object and
  // stack — this proves the source crosses the REAL adapter pipeline (no
  // MethodChannel envelope in between), preserving object, message and source
  // stack. The channel-mock envelope tests above remain separate
  // channel-transport coverage; they do not demonstrate raw identity.
  test('F2: an injected source utterance timeout through the real adapter '
      'pipeline is preserved by object, message and source stack', () async {
    final source = TimeoutException(
        'source utterance timeout, real pipeline',
        const Duration(seconds: 30));
    final explicitStack =
        StackTrace.fromString('source-subclass-frame:fix3-f2-utterance');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'isLanguageAvailable') return true;
      return 1;
    });
    final audio = FrenchWordAudio(
        const CourseAudioDeadlines(
            setup: Duration(seconds: 30),
            ttsUtterance: Duration(seconds: 30)),
        _SourceTimeoutTts('speak', source, explicitStack));
    Object? caught;
    StackTrace? caughtStack;
    try {
      await audio.speak('mot');
    } on Object catch (error, errorStack) {
      caught = error;
      caughtStack = errorStack;
    }
    expect(identical(caught, source), isTrue,
        reason: 'the source TimeoutException object is preserved by the real '
            'adapter pipeline (no re-wrap, no channel envelope)');
    expect(
        (caught as TimeoutException).message,
        'source utterance timeout, real pipeline',
        reason: 'the original source message is preserved verbatim');
    expect(caught, isNot(isA<PhaseTimeoutException>()),
        reason: 'never relabelled as this adapter expired phase');
    expect(caughtStack, isNotNull, reason: 'the failure carries a stack');
    expect(caughtStack.toString(), contains('source-subclass-frame'),
        reason: 'the explicitly supplied source stack is forwarded — the '
            'source crossed the real pipeline, not a platform channel');
  });

  test('F2: an injected source setup timeout through the real adapter '
      'pipeline is likewise preserved by object, message and stack',
      () async {
    final source = TimeoutException(
        'source setup timeout, real pipeline', const Duration(seconds: 30));
    final explicitStack =
        StackTrace.fromString('source-setup-subclass-frame:fix3-f2');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'isLanguageAvailable') return true;
      return 1;
    });
    final audio = FrenchWordAudio(
        const CourseAudioDeadlines(
            setup: Duration(seconds: 30),
            ttsUtterance: Duration(seconds: 30)),
        _SourceTimeoutTts('setLanguage', source, explicitStack));
    Object? caught;
    StackTrace? caughtStack;
    try {
      await audio.speak('mot');
    } on Object catch (error, errorStack) {
      caught = error;
      caughtStack = errorStack;
    }
    expect(identical(caught, source), isTrue,
        reason: 'the source setup timeout object is preserved by the real '
            'adapter pipeline (no re-wrap, no channel envelope)');
    expect(
        (caught as TimeoutException).message,
        'source setup timeout, real pipeline');
    expect(caught, isNot(isA<PhaseTimeoutException>()),
        reason: 'never relabelled as this adapter expired phase');
    expect(caughtStack, isNotNull, reason: 'the failure carries a stack');
    expect(caughtStack.toString(), contains('source-setup-subclass-frame'),
        reason: 'the explicitly supplied source stack is forwarded');
  });

  testWidgets(
      'R4: the real direct TTS default 10-second setup allowance is applied '
      'behaviorally while a raw setup call is held',
      (tester) async {
    final gate = Completer<Object?>();
    var hasHeld = false;
    var utterances = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'isLanguageAvailable') return true;
      if (call.method == 'speak') {
        utterances++;
        return null; // web completion shape
      }
      if (!hasHeld) {
        hasHeld = true;
        return gate.future; // hold a raw setup call past the public bound
      }
      return 1;
    });
    final audio = FrenchWordAudio(); // production defaults (setup 10s)
    final Future<void> pending = audio.speak('mot');
    var settled = false;
    // Terminal observer attached BEFORE any fake-time advance; both
    // callbacks agree on the inferred result type (no value-returning
    // mismatch in the error handler).
    pending.then((_) => settled = true, onError: (Object error) => settled = true);
    await tester.pump();
    expect(hasHeld, isTrue, reason: 'the raw setup call is held');
    await tester.pump(const Duration(seconds: 9));
    await tester.pump(); // yield before the pending assertion
    expect(settled, isFalse,
        reason:
            'inside the default 10s setup allowance the direct request '
                'remains pending; an early setup timeout cannot pass');
    await tester.pump(const Duration(seconds: 2)); // past the 10s default
    Object? outcome;
    try {
      await pending;
    } on Object catch (error) {
      outcome = error;
    }
    expect(outcome, isA<PhaseTimeoutException>(),
        reason: 'the expired default setup allowance is the typed owned '
            'deadline of this adapter');
    expect(
        (outcome! as PhaseTimeoutException).phase,
        CourseAudioFailureReason.startupTimeout,
        reason: 'the setup phase is what expired');
    expect(outcome, isA<TimeoutException>(),
        reason: 'the direct caller may still catch a TimeoutException');
    expect(utterances, 0,
        reason: 'a held setup must never start an utterance');
    gate.complete(null); // the stale raw setup settles after the public bound
    await tester.pump();
    await tester.pump();
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

    test('retirement rethrow preserves the original cleanup throw stack',
        () async {
      final platformError = PlatformException(code: 'stop-broken');
      var stopCalls = 0;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        if (call.method == 'stop') {
          stopCalls++;
          if (stopCalls >= 2) throw platformError;
          return 1;
        }
        if (call.method == 'isLanguageAvailable') return true;
        if (call.method == 'speak') return null;
        return 1;
      });
      final session = createFrenchPracticeSpeechSession();
      await session.speak('mot');
      Object? caught;
      StackTrace? stack;
      try {
        await session.stop();
      } on Object catch (error, errorStack) {
        caught = error;
        stack = errorStack;
      }
      expect(caught, isA<PlatformException>(),
          reason: 'the original cleanup failure is the retirement cause');
      expect(stack, isNotNull, reason: 'the rethrow carries a stack trace');
      final String trace = stack.toString();
      final String firstFrame =
          trace.split('\n').first; // the original throw site, if preserved
      expect(firstFrame, contains('package:flutter'),
          reason:
              'the platform-delivered error keeps its original boundary '
              'stack instead of a session rethrow frame replacing it');
      expect(firstFrame, isNot(contains('course_audio.dart')),
          reason: 'a session rethrow must not become the leading frame');
    });

    test('R1: an uncorrelated stale speech-error callback is drained and does '
        'not fail the newer direct request (Option 1: such callbacks are '
        'never an outcome source; they drain by the locked handler)', () async {
      final olderGate = Completer<Object?>();
      final newerGate = Completer<Object?>();
      final spoken = <String>[];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        if (call.method == 'isLanguageAvailable') return true;
        if (call.method == 'speak') {
          final Object? args = call.arguments;
          final Object? text = args is String
              ? args
              : (args is Map ? args['text'] : null);
          spoken.add(text?.toString() ?? '');
          // Each raw utterance stays unresolved (the locked web engine shape).
          if (text == 'un') return olderGate.future;
          if (text == 'deux') return newerGate.future;
        }
        return 1;
      });
      final audio = FrenchWordAudio(const CourseAudioDeadlines(
          setup: Duration(seconds: 30), ttsUtterance: Duration(seconds: 30)));
      final older = audio.speak('un');
      unawaited(older.then<void>((Object? value) {},
          onError: (Object error) {}));
      final wait1 = Stopwatch()..start();
      while (spoken.isEmpty && wait1.elapsed < const Duration(seconds: 5)) {
        await Future<void>.delayed(Duration.zero);
      }
      final newer = audio.speak('deux');
      unawaited(newer.then<void>((Object? value) {},
          onError: (Object error) {}));
      final wait2 = Stopwatch()..start();
      while (spoken.length < 2 && wait2.elapsed < const Duration(seconds: 5)) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(spoken, containsAll(<String>['un', 'deux']),
          reason: 'both utterances must be dispatched and held');

      // The identity-free callback (it may belong to the superseded older
      // utterance) is delivered via the locked channel machinery while the
      // newer direct request is still pending.
      await binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter_tts',
          const StandardMethodCodec().encodeMethodCall(const MethodCall(
              'speak.onError',
              {'code': 'stale-speech-failure',
               'message': 'older utterance failed'})),
          (ByteData? reply) {});
      // Quiescence must stay fenced while both raw utterances are unresolved.
      var quiesced = false;
      unawaited(audio.quiesce().then<void>(
          (Object? value) => quiesced = true,
          onError: (Object error) => quiesced = true));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(quiesced, isFalse,
          reason: 'unresolved raw work must keep quiescence fenced');

      // Release both raw utterances (web completion shape).
      olderGate.complete(null);
      newerGate.complete(null);
      await expectLater(
          newer,
          completes,
          reason:
              'an uncorrelated, identity-free callback must not fail the '
                  'newer direct request (direct overlap / quiet-stale '
                  'semantics are preserved)');
      await expectLater(
          older,
          completes,
          reason:
              'the superseded older request drains quietly rather than '
                  'failing on the stale callback');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(quiesced, isTrue,
          reason: 'quiescence settles once both raw utterances have settled');
    });

    test('F1: a practice session is single-attempt: a second speak is '
        'rejected before dispatch, permanently, even after the first '
        'attempt fails', () async {
      final firstGate = Completer<Object?>();
      final retryGate = Completer<Object?>();
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
          return word == 'premier' ? firstGate.future : retryGate.future;
        }
        return 1;
      });
      final session = createFrenchPracticeSpeechSession(
          deadlines: const CourseAudioDeadlines(
              setup: Duration(seconds: 30),
              ttsUtterance: Duration(seconds: 30)));
      final first = session.speak('premier');
      unawaited(first.then<void>((Object? value) {},
          onError: (Object error) {}));
      final dispatch = Stopwatch()..start();
      while (!spoken.contains('premier') &&
          dispatch.elapsed < const Duration(seconds: 5)) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(spoken, ['premier'],
          reason: 'the first attempt dispatches once');

      // A second attempt on the same session must be rejected before
      // init/dispatch, not rerouted.
      final second = session.speak('second');
      unawaited(second.then<void>((Object? value) {},
          onError: (Object error) {}));
      expect(spoken, ['premier'],
          reason: 'a rejected retry must not dispatch a second utterance');

      // The first attempt fails; the session stays permanently consumed.
      firstGate.completeError(StateError('first-attempt-failed'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final retry = session.speak('retry');
      unawaited(retry.then<void>((Object? value) {},
          onError: (Object error) {}));
      retryGate.complete(null); // release any baseline-dispatched utterance
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(spoken, ['premier'],
          reason:
              'a failed first attempt permanently consumes the single-'
                  'attempt session; no further utterance dispatches');
      await expectLater(second, throwsA(isA<StateError>()),
          reason: 'the second attempt is rejected, not silently re-dispatched');
      await expectLater(retry, throwsA(isA<StateError>()),
          reason: 'a failed first attempt does not reopen the session');
      await expectLater(session.dispose(), completes,
          reason: 'retirement still settles the single-attempt session');
    });

    test('F1 (approved alpha override "Option 1"): a real speech-error '
        'callback never settles the session speak while its raw utterance '
        'is held; only the owned utterance bound fails it — a timeout may '
        'fail, never count as playback — and the raw utterance stays fenced',
        () async {
      final gate = Completer<Object?>();
      var dispatched = false;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        if (call.method == 'speak') {
          dispatched = true;
          return gate.future; // raw utterance stays unresolved (web shape)
        }
        if (call.method == 'stop') return 1;
        if (call.method == 'isLanguageAvailable') return true;
        return 1;
      });
      final session = createFrenchPracticeSpeechSession(
          deadlines: const CourseAudioDeadlines(
              setup: Duration(milliseconds: 300),
              ttsUtterance: Duration(milliseconds: 600)));
      final pending = session.speak('mot');
      var settled = false;
      Object? outcome;
      unawaited(pending.then<void>(
            (Object? value) {
              outcome = 'completed';
              settled = true;
            },
            onError: (Object error) {
              outcome = error;
              settled = true;
            },
          ));
      final stopwatch = Stopwatch()..start();
      while (!dispatched && stopwatch.elapsed < const Duration(seconds: 5)) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(dispatched, isTrue, reason: 'the utterance must be dispatched');
      // A real inbound speech-error callback, delivered through the exact
      // locked flutter_tts global path (identity-free: it may belong to any
      // engine). The binding user override (Option 1: "callback-only
      // failures may timeout, not immediate error, and never completion")
      // replaces the former prompt-callback settlement test: a callback may
      // fail the request only by letting its OWN bounded grace window
      // elapse, and it never completes it.
      await binding.defaultBinaryMessenger.handlePlatformMessage(
          'flutter_tts',
          const StandardMethodCodec().encodeMethodCall(const MethodCall(
              'speak.onError',
              {'code': 'speech-engine-failure',
               'message': 'web speech failed'})),
          (ByteData? reply) {});
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(settled, isFalse,
          reason:
              'a callback-only failure must not complete or fail the '
                  'pending request immediately; only the raw method future '
                      'or the owned bound may settle it');
      // The owned utterance bound (600ms) is the unique failure source.
      final settle = Stopwatch()..start();
      while (!settled && settle.elapsed < const Duration(seconds: 3)) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(settled, isTrue,
          reason: 'the owned bound does fail the request');
      expect(outcome, isA<PhaseTimeoutException>(),
          reason:
              'the failure is the typed owned deadline — never a callback '
                  'diagnosis and never a completion (a timeout never counts '
                      'as heard playback)');
      expect(
          (outcome! as PhaseTimeoutException).phase,
          CourseAudioFailureReason.completionTimeout,
          reason: 'the utterance bound expired, not an invented phase');
      // Retirement must fence the still-unresolved raw utterance.
      final retirement = session.dispose();
      var retired = false;
      unawaited(retirement.then<void>(
          (Object? value) => retired = true,
          onError: (Object error) => retired = true));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(retired, isFalse,
          reason:
              'the shared retirement must not declare quiescence while the '
                  'raw utterance is unresolved');
      gate.complete(null);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(retired, isTrue,
          reason: 'the fence releases once the raw utterance settles');
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

/// A [FlutterTts] subclass for the F2 direct-pipeline identity tests: the
/// designated method (`'speak'` or `'setLanguage'`) fails with the exact
/// supplied cause and stack. All other methods keep the locked implementation
/// (routing to the test channel mock), so the source crosses the REAL adapter
/// pipeline with no MethodChannel envelope between it and the throw site.
class _SourceTimeoutTts extends FlutterTts {
  _SourceTimeoutTts(this.method, this.cause, this.stack);

  final String method;
  final Object cause;
  final StackTrace stack;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    if (method == 'speak') {
      Error.throwWithStackTrace(cause, stack);
    }
    return super.speak(text);
  }

  @override
  Future<dynamic> setLanguage(String language) async {
    if (method == 'setLanguage') {
      Error.throwWithStackTrace(cause, stack);
    }
    return super.setLanguage(language);
  }
}
