import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/features/course/course_lesson_screen.dart';

class _LessonAudio implements CourseAudio {
  @override
  Future<void> speak(String word) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  for (final stage in [
    'directory',
    'permission',
    'start-permission',
    'start',
    'active'
  ]) {
    testWidgets('leaving a lesson releases recording during $stage',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
      const recordChannel = MethodChannel('com.llfbandit.record/messages');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final gate = Completer<void>();
      final activeCaptures = <String>{};
      final liveRecorders = <String>{};
      final startedRecorders = <String>[];
      final eventChannels = <MethodChannel>[];
      final operations = <String>[];
      var permissionRequests = 0;

      messenger.setMockMethodCallHandler(pathChannel, (call) async {
        if (stage == 'directory') await gate.future;
        return '/tmp/opencode';
      });
      messenger.setMockMethodCallHandler(recordChannel, (call) async {
        operations.add(call.method);
        final id = (call.arguments as Map)['recorderId'] as String;
        switch (call.method) {
          case 'create':
            liveRecorders.add(id);
            final events = MethodChannel('com.llfbandit.record/events/$id');
            eventChannels.add(events);
            messenger.setMockMethodCallHandler(events, (call) async {
              operations.add('events.${call.method}');
              return null;
            });
            return null;
          case 'hasPermission':
            permissionRequests++;
            if (stage == 'permission' ||
                (stage == 'start-permission' && permissionRequests == 2)) {
              await gate.future;
            }
            return true;
          case 'start':
            startedRecorders.add(id);
            if (stage == 'start') await gate.future;
            activeCaptures.add(id);
            return null;
          case 'isRecording':
            return activeCaptures.contains(id);
          case 'stop':
          case 'cancel':
            activeCaptures.remove(id);
            return '/tmp/opencode/recording.wav';
          case 'dispose':
            activeCaptures.remove(id);
            liveRecorders.remove(id);
            return null;
          default:
            throw StateError('Unexpected recorder operation: ${call.method}');
        }
      });
      addTearDown(() async {
        if (!gate.isCompleted) gate.complete();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        messenger.setMockMethodCallHandler(pathChannel, null);
        messenger.setMockMethodCallHandler(recordChannel, null);
        for (final events in eventChannels) {
          messenger.setMockMethodCallHandler(events, null);
        }
      });

      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(ProviderScope(
        overrides: [courseAudioProvider.overrideWithValue(_LessonAudio())],
        child: MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: Builder(builder: (context) {
              return TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const CourseLessonScreen(
                        lessonId: 'en-fr-vowels'))),
                child: const Text('Open lesson'),
              );
            }),
          ),
        ),
      ));
      await tester.tap(find.text('Open lesson'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listen to French word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/i/'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Record yourself'), 200);
      await tester.tap(find.text('Record yourself'));
      await tester.pumpAndSettle();
      if (stage == 'start') expect(startedRecorders, hasLength(1));
      if (stage == 'active') expect(activeCaptures, hasLength(1));

      // Pop the lesson without destroying its parent ProviderScope. This models
      // real navigation rather than hiding the leak with whole-app teardown.
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      gate.complete();
      await tester.pumpAndSettle();
      // Stream cancellation uses a root-zone future; fake-time pumping alone
      // cannot resume it. Yield the real event loop, then drain fake microtasks.
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();

      expect(activeCaptures, isEmpty,
          reason: 'No microphone capture may outlive the lesson.');
      expect(liveRecorders, isEmpty,
          reason: 'The departing lesson must release its own recorder: '
              '$operations');
      if (stage == 'directory' ||
          stage == 'permission' ||
          stage == 'start-permission') {
        expect(startedRecorders, isEmpty,
            reason: 'A departed lesson must not start microphone capture.');
      }
    });
  }
}
