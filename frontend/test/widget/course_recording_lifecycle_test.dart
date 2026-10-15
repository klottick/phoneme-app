import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/features/course/course_lesson_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _LessonAudio implements CourseAudio {
  final List<String> spoken = <String>[];

  @override
  Future<void> speak(String word) async {
    spoken.add(word);
  }

  @override
  Future<void> stop() async {}
}

class _HeldFinishPreferences extends InMemorySharedPreferencesStore {
  _HeldFinishPreferences() : super.withData(const <String, Object>{});

  final Completer<bool> finishWrite = Completer<bool>();
  int finishWrites = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.course.v1.en-fr' &&
        value is String &&
        value.contains('"en-fr-vowels"')) {
      finishWrites++;
      if (!finishWrite.isCompleted) await finishWrite.future;
    }
    return super.setValue(valueType, key, value);
  }
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
                    builder: (_) =>
                        const CourseLessonScreen(lessonId: 'en-fr-vowels'))),
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

  // ---------- R1 (fix round 2): suspension during a held recorder startup ----------

  for (final stage in ['directory', 'permission', 'start']) {
    testWidgets(
        'suspension during a held $stage startup keeps Record, Next and '
        'Listen blocked until the original startup settles', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
      const recordChannel = MethodChannel('com.llfbandit.record/messages');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final gate = Completer<void>();
      final liveRecorders = <String>{};
      final startedRecorders = <String>[];
      final activeCaptures = <String>{};
      final eventChannels = <MethodChannel>[];
      var permissionRequests = 0;
      var directoryRequests = 0;

      messenger.setMockMethodCallHandler(pathChannel, (call) async {
        directoryRequests++;
        if (stage == 'directory') await gate.future;
        return '/tmp/opencode';
      });
      messenger.setMockMethodCallHandler(recordChannel, (call) async {
        final id = (call.arguments as Map)['recorderId'] as String;
        switch (call.method) {
          case 'create':
            liveRecorders.add(id);
            final events = MethodChannel('com.llfbandit.record/events/$id');
            eventChannels.add(events);
            messenger.setMockMethodCallHandler(events, (call) async {
              return null;
            });
            return null;
          case 'hasPermission':
            permissionRequests++;
            if (stage == 'permission') await gate.future;
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
        overrides: <Override>[
          courseAudioProvider.overrideWithValue(_LessonAudio())
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: Builder(builder: (context) {
              return TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        const CourseLessonScreen(lessonId: 'en-fr-vowels'))),
                child: const Text('Open lesson'),
              );
            }),
          ),
        ),
      ));
      await tester.tap(find.text('Open lesson'));
      await tester.pumpAndSettle();
      // Listen + answer: the recorder controls exist, and the screen's
      // retained `_audio` still references the COMPLETED listen — exactly
      // the R1 scenario where retained audio is not an ownership test.
      await tester.tap(find.text('Listen to French word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/i/'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Record yourself'), 200);
      await tester.tap(find.text('Record yourself'));
      await tester.pumpAndSettle();
      // The startup is GENUINELY held at the $stage boundary.
      if (stage == 'directory') {
        expect(directoryRequests, 1,
            reason: 'the original documents-directory request is held');
      } else {
        expect(liveRecorders, isNotEmpty,
            reason: 'a recorder exists while its startup is held');
      }
      if (stage == 'start') {
        expect(activeCaptures, isEmpty,
            reason: 'the start is held before capture becomes active');
      } else {
        expect(startedRecorders, isEmpty,
            reason: 'no start dispatch before the $stage gate');
      }

      // Suspend and resume while the startup is genuinely held (R1).
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(
          tester
              .widget<OutlinedButton>(find.ancestor(
                  of: find.text('Record yourself'),
                  matching: find.byType(OutlinedButton)))
              .onPressed,
          isNull,
          reason: 'the pending recorder startup owns the busy state; a '
              'suspension must not release it (R1)');
      expect(
          tester
              .widget<FilledButton>(find.ancestor(
                  of: find.text('Next word'),
                  matching: find.byType(FilledButton)))
              .onPressed,
          isNull,
          reason: 'item navigation must stay blocked until the startup '
              'settles (R1)');
      expect(
          tester
              .widget<FilledButton>(find.ancestor(
                  of: find.byIcon(Icons.volume_up),
                  matching: find.byType(FilledButton)))
              .onPressed,
          isNull,
          reason: 'listening must stay blocked while the recorder startup '
              'is in flight (R1)');
      expect(startedRecorders, hasLength(stage == 'start' ? 1 : 0),
          reason: 'no duplicate start dispatch while the gate is held');

      // Release the hold: the ORIGINAL operation alone finishes, with exact
      // counts and no second record action.
      gate.complete();
      await tester.pumpAndSettle();
      expect(activeCaptures, hasLength(1),
          reason: 'the original startup becomes active on its own');
      expect(startedRecorders, hasLength(1),
          reason: 'exactly one start: no second record action was admitted');
      expect(permissionRequests, 2,
          reason: 'the startup check and the start check ran exactly once '
              'each');
      expect(
          tester
              .widget<OutlinedButton>(find.ancestor(
                  of: find.text('Stop recording'),
                  matching: find.byType(OutlinedButton)))
              .onPressed,
          isNotNull,
          reason: 'the original recording finished and is controllable');
    });
  }

  testWidgets(
      'a suspended held permission denial finishes the original operation '
      'alone, retryable, with no capture', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    const recordChannel = MethodChannel('com.llfbandit.record/messages');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final gate = Completer<void>();
    final activeCaptures = <String>{};
    final startedRecorders = <String>[];
    final eventChannels = <MethodChannel>[];
    var permissionRequests = 0;

    messenger.setMockMethodCallHandler(pathChannel, (call) async {
      return '/tmp/opencode';
    });
    messenger.setMockMethodCallHandler(recordChannel, (call) async {
      final id = (call.arguments as Map)['recorderId'] as String;
      switch (call.method) {
        case 'create':
          final events = MethodChannel('com.llfbandit.record/events/$id');
          eventChannels.add(events);
          messenger.setMockMethodCallHandler(events, (call) async {
            return null;
          });
          return null;
        case 'hasPermission':
          permissionRequests++;
          if (permissionRequests == 1) await gate.future;
          return true;
        case 'start':
          startedRecorders.add(id);
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
        overrides: <Override>[
          courseAudioProvider.overrideWithValue(_LessonAudio())
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: Builder(builder: (context) {
              return TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        const CourseLessonScreen(lessonId: 'en-fr-vowels'))),
                child: const Text('Open lesson'),
              );
            }),
          ),
        )));
    await tester.tap(find.text('Open lesson'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listen to French word'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('/i/'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Record yourself'), 200);
    await tester.tap(find.text('Record yourself'));
    await tester.pumpAndSettle();
    // Held at the permission gate; nothing has started.
    expect(permissionRequests, 1);
    expect(startedRecorders, isEmpty);

    // Suspend and resume while the permission await is held (R1).
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(
        tester
            .widget<OutlinedButton>(find.ancestor(
                of: find.text('Record yourself'),
                matching: find.byType(OutlinedButton)))
            .onPressed,
        isNull,
        reason: 'the held permission await owns the busy state; suspension '
            'must not release it (R1)');
    expect(
        tester
            .widget<FilledButton>(find.ancestor(
                of: find.text('Next word'),
                matching: find.byType(FilledButton)))
            .onPressed,
        isNull,
        reason: 'item navigation must stay blocked while the permission '
            'await is held (R1)');

    // The permission gate releases as a genuine denial (observer: the
    // screen's own catch is the handler); the ORIGINAL operation finishes
    // alone into a retryable state.
    gate.completeError(StateError('microphone permission denied'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Recording unavailable'), findsOneWidget,
        reason: 'a failed startup surfaces the retryable guidance');
    expect(startedRecorders, isEmpty,
        reason: 'a denied startup never starts capture');
    expect(activeCaptures, isEmpty,
        reason: 'no microphone capture may remain active');
    expect(permissionRequests, 1,
        reason: 'no second startup attempt was admitted');
    expect(
        tester
            .widget<OutlinedButton>(find.ancestor(
                of: find.text('Record yourself'),
                matching: find.byType(OutlinedButton)))
            .onPressed,
        isNotNull,
        reason: 'after the failure the record control is retryable again');
  });

  testWidgets(
      'suspension during held Finish persistence preserves save-owned busy '
      'and cached actions cannot start duplicate work', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = _HeldFinishPreferences();
    SharedPreferencesStorePlatform.instance = preferences;

    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    const recordChannel = MethodChannel('com.llfbandit.record/messages');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var directoryRequests = 0;
    var permissionRequests = 0;
    final eventChannels = <MethodChannel>[];
    messenger.setMockMethodCallHandler(pathChannel, (call) async {
      directoryRequests++;
      return '/tmp/opencode';
    });
    messenger.setMockMethodCallHandler(recordChannel, (call) async {
      final id = (call.arguments as Map)['recorderId'] as String;
      switch (call.method) {
        case 'create':
          final events = MethodChannel('com.llfbandit.record/events/$id');
          eventChannels.add(events);
          messenger.setMockMethodCallHandler(events, (call) async => null);
          return null;
        case 'hasPermission':
          permissionRequests++;
          return false;
        case 'dispose':
          return null;
        default:
          throw StateError('Unexpected recorder operation: ${call.method}');
      }
    });
    addTearDown(() async {
      if (!preferences.finishWrite.isCompleted) {
        preferences.finishWrite.complete(true);
      }
      messenger.setMockMethodCallHandler(pathChannel, null);
      messenger.setMockMethodCallHandler(recordChannel, null);
      for (final events in eventChannels) {
        messenger.setMockMethodCallHandler(events, null);
      }
      await SharedPreferences.getInstance();
    });

    final audio = _LessonAudio();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ProviderScope(
      overrides: <Override>[courseAudioProvider.overrideWithValue(audio)],
      child: MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(
          body: Builder(builder: (context) {
            return TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      const CourseLessonScreen(lessonId: 'en-fr-vowels'))),
              child: const Text('Open lesson'),
            );
          }),
        ),
      ),
    ));
    await tester.tap(find.text('Open lesson'));
    await tester.pumpAndSettle();

    for (var item = 0; item < 4; item++) {
      final sound = <String>['i', 'o', 'i', 'o'][item];
      await tester.scrollUntilVisible(find.text('Listen to French word'), -200);
      await tester.tap(find.text('Listen to French word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/$sound/'));
      await tester.pumpAndSettle();
      if (item < 3) {
        await tester.scrollUntilVisible(find.text('Next word'), 200);
        await tester.tap(find.text('Next word'));
        await tester.pumpAndSettle();
      }
    }

    await tester.scrollUntilVisible(find.text('Record yourself'), 200);
    final FilledButton listenButton = tester.widget<FilledButton>(find.ancestor(
        of: find.byIcon(Icons.volume_up), matching: find.byType(FilledButton)));
    final OutlinedButton recordButton = tester.widget<OutlinedButton>(
        find.ancestor(
            of: find.text('Record yourself'),
            matching: find.byType(OutlinedButton)));
    final FilledButton finishButton = tester.widget<FilledButton>(find.ancestor(
        of: find.text('Finish'), matching: find.byType(FilledButton)));
    final void Function()? cachedListen = listenButton.onPressed;
    final void Function()? cachedRecord = recordButton.onPressed;
    final void Function()? cachedFinish = finishButton.onPressed;
    expect(cachedListen, isNotNull);
    expect(cachedRecord, isNotNull);
    expect(cachedFinish, isNotNull);
    final spokenBeforeFinish = List<String>.of(audio.spoken);

    // Enter the real last-item Finish save and verify the underlying
    // preferences write remains pending across frames.
    cachedFinish!();
    await tester.pump();
    await tester.pump();
    expect(preferences.finishWrites, 1,
        reason: 'Finish reaches the actual held completion persistence write');
    expect(preferences.finishWrite.isCompleted, isFalse);

    // Saved enabled callbacks are invoked before and after lifecycle frames;
    // no control repaint is relied on for admission safety.
    cachedListen!();
    cachedRecord!();
    cachedFinish();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    cachedListen();
    cachedRecord();
    cachedFinish();
    await tester.pump();

    expect(audio.spoken, spokenBeforeFinish,
        reason: 'save-owned busy rejects cached Listen through suspension');
    expect(directoryRequests, 0,
        reason: 'save-owned busy rejects cached Record through suspension');
    expect(permissionRequests, 0);
    expect(preferences.finishWrites, 1,
        reason: 'cached Finish cannot dispatch another completion write');
    expect(find.text('Open lesson'), findsNothing,
        reason: 'the held original save cannot exit before release');
    final listenAfterSuspend = tester.widget<FilledButton>(find.ancestor(
        of: find.byIcon(Icons.volume_up), matching: find.byType(FilledButton)));
    final recordAfterSuspend = tester.widget<OutlinedButton>(find.ancestor(
        of: find.text('Record yourself'),
        matching: find.byType(OutlinedButton)));
    final finishAfterSuspend = tester.widget<FilledButton>(find.ancestor(
        of: find.text('Finish'), matching: find.byType(FilledButton)));
    expect(listenAfterSuspend.onPressed, isNull);
    expect(recordAfterSuspend.onPressed, isNull);
    expect(finishAfterSuspend.onPressed, isNull);

    preferences.finishWrite.complete(true);
    await tester.pumpAndSettle();
    expect(preferences.finishWrites, 1,
        reason: 'the original Finish write completes exactly once');
    expect(find.text('Open lesson'), findsOneWidget,
        reason: 'successful persistence exits the lesson exactly once');
    expect(tester.takeException(), isNull);
  });
}
