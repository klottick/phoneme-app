import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio.dart';

void main() {
  const channel = MethodChannel('flutter_tts');
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  const boundaries = [
    'isLanguageAvailable',
    'stop',
    'setLanguage',
    'setSpeechRate',
    'awaitSpeakCompletion',
    'speak',
  ];

  PlatformException stalePlatformError() =>
      PlatformException(code: 'cancelled-old-platform-call');
  Object successFor(String method) =>
      method == 'isLanguageAvailable' ? true : 1;
  String textOf(MethodCall call) {
    final args = call.arguments;
    return args is Map ? args['text'] as String : args as String;
  }

  tearDown(() =>
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

  /// Hold the first call to [boundary] on [gate], cancel via [stop], then
  /// release [gate] with the requested outcome. The abandoned request must
  /// settle quietly and dispatch no further channel call (no later setup and
  /// no speech).
  Future<void> cancelledAt(
      String boundary, void Function(Completer<Object?>) release) async {
    final calls = <MethodCall>[];
    final entered = Completer<void>();
    final gate = Completer<Object?>();
    var held = false;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      calls.add(call);
      if (call.method == boundary && !held) {
        held = true;
        entered.complete();
        return gate.future;
      }
      if (call.method == 'isLanguageAvailable') return true;
      return 1;
    });

    final audio = FrenchWordAudio();
    final pending = audio.speak('mot');
    await entered.future; // the request is held at [boundary]
    await audio.stop(); // cancel: the setup must be invalidated now
    final atCancel = calls.length;
    release(gate); // resume the held call with the requested outcome
    await expectLater(pending, completes,
        reason: 'a cancelled setup must settle quietly, not hang or publish a '
            'failure');
    expect(calls.length, atCancel,
        reason: 'a cancelled setup held at $boundary must not run later setup '
            'or speech');
  }

  for (final boundary in boundaries) {
    test(
        'a stopped setup held at $boundary runs nothing further on success',
        () => cancelledAt(
            boundary, (gate) => gate.complete(successFor(boundary))));
    test(
        'a stopped setup held at $boundary drains a platform error quietly',
        () => cancelledAt(
            boundary, (gate) => gate.completeError(stalePlatformError())));
  }

  test('a superseded platform error drains while the newest still succeeds',
      () async {
    final entered = Completer<void>();
    final oldGate = Completer<Object?>();
    var oldHeld = false;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'isLanguageAvailable') return true;
      if (call.method == 'speak') {
        final text = textOf(call);
        if (text == 'deux') return 1; // the newest utterance: succeed
        if (!oldHeld) {
          oldHeld = true;
          entered.complete();
        }
        return oldGate.future; // the older utterance: held pending
      }
      return 1;
    });

    final audio = FrenchWordAudio();
    final older = audio.speak('un');
    await entered
        .future; // the older is mid-utterance; the newest now supersedes
    final newer = audio.speak('deux');
    await expectLater(newer, completes,
        reason: 'the superseding request must still complete');
    oldGate.completeError(PlatformException(code: 'stale-older-utterance'));
    await expectLater(older, completes,
        reason: 'a superseded request must not publish a stale failure');
  });

  test(
      'a superseded explicit failure code drains while the newest still succeeds',
      () async {
    final entered = Completer<void>();
    final oldGate = Completer<Object?>();
    var oldHeld = false;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'isLanguageAvailable') return true;
      if (call.method == 'speak') {
        final text = textOf(call);
        if (text == 'deux') return 1; // the newest utterance: succeed
        if (!oldHeld) {
          oldHeld = true;
          entered.complete();
        }
        return oldGate.future; // the older utterance: held pending
      }
      return 1;
    });

    final audio = FrenchWordAudio();
    final older = audio.speak('un');
    await entered
        .future; // the older is mid-utterance; the newest now supersedes
    final newer = audio.speak('deux');
    await expectLater(newer, completes,
        reason: 'the superseding request must still complete');
    oldGate.complete(0); // the superseded utterance reports an explicit failure
    await expectLater(older, completes,
        reason:
            'a superseded failure code must not be republished as a failure');
  });

  testWidgets(
      'a superseded utterance timeout drains while the newest still succeeds',
      (tester) async {
    final oldGate = Completer<Object?>();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'isLanguageAvailable') return true;
      if (call.method == 'speak') {
        final text = textOf(call);
        if (text == 'deux') return 1; // the newest utterance: succeed
        return oldGate.future; // the older utterance: pending until its timeout
      }
      return 1;
    });

    final audio = FrenchWordAudio();
    final older =
        audio.speak('un').then<Object?>((_) => null, onError: (Object e) => e);
    await tester.pump(); // let the older request reach its (gated) utterance
    final newer = audio.speak('deux');
    await expectLater(newer, completes,
        reason: 'the superseding request must still complete');
    await tester.pump(
        const Duration(seconds: 12)); // the older utterance's timeout elapses
    final olderOutcome = await older;
    oldGate.complete(null); // drain the mock gate
    await tester.pump();
    expect(olderOutcome, isNull,
        reason:
            'a superseded request must not publish a stale timeout failure');
  });
}
