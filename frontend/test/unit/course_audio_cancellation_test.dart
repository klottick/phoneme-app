import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio.dart';

void main() {
  const channel = MethodChannel('flutter_tts');
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  void install(Object? Function(MethodCall) dispatch) {
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => dispatch(call));
  }

  tearDown(() =>
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

  Future<void> pumpUntil(bool Function() reached) async {
    for (var i = 0; i < 2000 && !reached(); i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(reached(), isTrue, reason: 'the mocked channel was not reached');
  }

  String? speakText(MethodCall call) {
    final args = call.arguments;
    return args is Map ? (args['text'] as String?) : (args as String?);
  }

  test('stop cancels a speak that is still awaiting language availability',
      () async {
    final calls = <MethodCall>[];
    final availability = Completer<bool>();
    install((call) {
      calls.add(call);
      if (call.method == 'isLanguageAvailable') return availability.future;
      if (call.method == 'speak') {
        throw StateError('a departed screen must not start speaking after stop');
      }
      return 1;
    });

    final audio = FrenchWordAudio();
    final pending = audio.speak('tout');
    await pumpUntil(() => calls.any((c) => c.method == 'isLanguageAvailable'));
    await audio.stop();
    availability.complete(true);

    await expectLater(pending, completes,
        reason: 'an abandoned setup must not hang or publish a failure');
    expect(calls.where((c) => c.method == 'speak'), isEmpty,
        reason: 'the departed screen must not start speaking after its stop');
  });

  test('stop cancels a speak mid-setup without a stale failure', () async {
    final calls = <MethodCall>[];
    final setup = Completer<Object>();
    install((call) {
      calls.add(call);
      if (call.method == 'isLanguageAvailable') return true;
      if (call.method == 'setSpeechRate') return setup.future;
      if (call.method == 'speak') {
        throw StateError('a cancelled speak must not reach the platform call');
      }
      return 1;
    });

    final audio = FrenchWordAudio();
    final pending = audio.speak('tout');
    await pumpUntil(() => calls.any((c) => c.method == 'setSpeechRate'));
    await audio.stop();
    setup.complete(1);

    await expectLater(pending, completes,
        reason: 'an abandoned setup must not publish a stale failure');
    expect(calls.where((c) => c.method == 'speak'), isEmpty,
        reason: 'a cancelled speak must not run its queued setup');
  });

  test('a newer speak supersedes an older one and the old one fails silently',
      () async {
    final calls = <MethodCall>[];
    final utterances = <String, Completer<Object?>>{
      'un': Completer<Object?>(),
      'deux': Completer<Object?>(),
    };
    install((call) {
      calls.add(call);
      if (call.method == 'isLanguageAvailable') return true;
      if (call.method == 'speak') {
        final word = utterances.keys
            .singleWhere((String w) => speakText(call) == w);
        return utterances[word]!.future;
      }
      return 1;
    });

    final audio = FrenchWordAudio();
    final older = audio.speak('un');
    await pumpUntil(() => calls.any(
        (c) => c.method == 'speak' && speakText(c) == 'un'));
    final newer = audio.speak('deux');
    await pumpUntil(() => calls.any(
        (c) => c.method == 'speak' && speakText(c) == 'deux'));

    utterances['deux']!.complete(1);
    await expectLater(newer, completes,
        reason: 'the superseding request must still complete');
    utterances['un']!.complete(0);
    await expectLater(older, completes,
        reason: 'a superseded request must not publish a stale failure');

    expect(speakText(calls.where((c) => c.method == 'speak').last), 'deux',
        reason: 'overlapping requests must converge on the newest utterance');
  });
}
