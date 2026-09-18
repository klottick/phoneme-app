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
}
