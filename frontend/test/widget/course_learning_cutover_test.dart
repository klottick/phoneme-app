import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/learning_database_qualification_app.dart'
    show LearningDatabaseQualificationApp;
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabaseHandle;
import 'package:linguist/src/features/arcade/arcade_screen.dart';
import 'package:linguist/src/features/course/course_lesson_screen.dart';
import 'package:linguist/src/features/course/course_progress_screen.dart';
import 'package:linguist/src/features/course/discovery_lesson_screen.dart';
import 'package:linguist/src/features/drills/drill_screen.dart';
import 'package:linguist/src/features/home/home_screen.dart';
import '../support/sqlite_learning_test_harness.dart';

class _SilentAudio implements CourseAudio {
  @override
  Future<void> speak(String word) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('qualification app exposes scoped controls and frozen commands', (
    tester,
  ) async {
    final tempDir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('learning-qualification-widget-'),
    ))!;
    final file = File('${tempDir.path}/phoneme_learning.sqlite');
    final handle = LearningDatabaseHandle(
      open: () => openFileLearningTestDatabase(file),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await handle.close();
      await tempDir.delete(recursive: true);
    });

    await tester.pumpWidget(
      LearningDatabaseQualificationApp(
        database: handle,
        runId: 'widget-control-test',
        backendName: 'file-backed native SQLite',
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('learning-storage-backend')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('learning-storage-run-id')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('learning-storage-run-id')),
          )
          .data,
      'widget-control-test',
    );
    for (final String key in <String>[
      'learning-storage-seed-retention',
      'learning-storage-verify-retention',
      'learning-storage-prepare-command-a',
      'learning-storage-prepare-command-b',
      'learning-storage-submit-command-a',
      'learning-storage-submit-command-b',
      'learning-storage-discard-ack',
      'learning-storage-replay-frozen-command',
      'learning-storage-replay-input',
      'learning-storage-frozen-command',
      'learning-storage-result',
    ]) {
      expect(find.byKey(ValueKey<String>(key)), findsOneWidget, reason: key);
    }

    Future<void> tapControl(String key) async {
      final Finder control = find.byKey(ValueKey<String>(key));
      await tester.ensureVisible(control);
      await tester.tap(control);
      await tester.pumpAndSettle();
    }

    await tapControl('learning-storage-prepare-command-a');
    final SelectableText frozenCommand = tester.widget<SelectableText>(
      find.byKey(const ValueKey<String>('learning-storage-frozen-command')),
    );
    final Map<String, dynamic> payloadA =
        jsonDecode(frozenCommand.data!) as Map<String, dynamic>;
    await tapControl('learning-storage-prepare-command-b');
    final SelectableText frozenCommandB = tester.widget<SelectableText>(
      find.byKey(const ValueKey<String>('learning-storage-frozen-command')),
    );
    final Map<String, dynamic> payloadB =
        jsonDecode(frozenCommandB.data!) as Map<String, dynamic>;
    expect(payloadB['scope'], payloadA['scope']);
    expect(payloadB['token'], isNot(payloadA['token']));

    await tapControl('learning-storage-discard-ack');
    await tapControl('learning-storage-submit-command-a');
    expect(find.textContaining('acknowledgment discarded'), findsOneWidget);
    await tapControl('learning-storage-submit-command-b');
    expect(find.textContaining('conflict'), findsOneWidget);

    final Finder replayInput = find.byKey(
      const ValueKey<String>('learning-storage-replay-input'),
    );
    await tester.ensureVisible(replayInput);
    await tester.enterText(replayInput, frozenCommand.data!);
    await tapControl('learning-storage-replay-frozen-command');
    final SelectableText result = tester.widget<SelectableText>(
      find.byKey(const ValueKey<String>('learning-storage-result')),
    );
    expect(result.data, contains('duplicate=true'));
    expect(result.data, contains('attempts=1'));
    expect(result.data, contains('unchanged=true'));
    expect(result.data, contains('cursor='));
  });

  testWidgets('all learning surfaces use same committed typed state', (
    tester,
  ) async {
    const legacyLearningSentinelKey = 'course.learning.v2.sentinel';
    const legacyLearningSentinelValue = '{leave-this-value-alone}';
    const oldCourse =
        '{"lessons":["en-fr-u-y"],"evidence":{"listening:u":{"attempts":8,"correct":7}},"pending":[{"event":"legacy"}]}';
    const oldArcade = '{"session":{"remaining":17,"score":91}}';
    SharedPreferences.setMockInitialValues({
      'course.v1.en-fr': oldCourse,
      'arcade.v1.en-fr.sound': oldArcade,
      'arcade.v1.en-fr.word': '{"score":44}',
      'auth.token': 'keep-auth',
      'profile.name': 'keep-profile',
      'streak.days': 7,
      legacyLearningSentinelKey: legacyLearningSentinelValue,
    });
    final tempDir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('learning-cutover-'),
    ))!;
    final file = File('${tempDir.path}/phoneme_learning.sqlite');
    final handle = LearningDatabaseHandle(
      open: () => openFileLearningTestDatabase(file),
    );
    final owner = LearningOwner.guest();
    final tracker = LearningAuthTracker(owner: owner, ready: true);
    final container = ProviderContainer(
      overrides: [
        learningAuthScopeProvider.overrideWith((ref) => tracker),
        learningDatabaseHandleProvider.overrideWithValue(handle),
        courseAudioProvider.overrideWithValue(_SilentAudio()),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await handle.close();
      await tempDir.delete(recursive: true);
    });
    final store = container.read(courseLearningStoreProvider);
    var state = await store.load();
    await store.submit(
      store.prepare(
        state: state,
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions()),
      ),
    );
    state = await store.load();
    await store.submit(
      store.prepare(
        state: state,
        activityId: 'lesson:en-fr-u-y',
        action: ChooseSound(
          selectedSound: 'u',
          audioSource: AttemptAudioSource.pendingRecording,
        ),
      ),
    );
    final surfaces = <Widget Function()>[
      () => const HomeScreen(),
      () => const CourseProgressScreen(),
      () => const DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
      () => const CourseLessonScreen(lessonId: 'en-fr-vowels'),
      () => const DrillScreen(),
      () => const ArcadeScreen(silent: true),
    ];
    for (var index = 0; index < surfaces.length; index++) {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: surfaces[index]()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      if (index == 1) {
        expect(
          find.textContaining('/u/'),
          findsWidgets,
          reason: 'progress reads the committed typed attempt',
        );
      }
      await tester.pumpWidget(const SizedBox());
    }

    final committed = await store.load();
    expect(committed.history, hasLength(1));
    expect(committed.completions, isEmpty);
    expect(
      committed.summaries.values.fold<int>(
        0,
        (sum, count) => sum + count.total,
      ),
      1,
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('course.v1.en-fr'), oldCourse);
    expect(preferences.getString('arcade.v1.en-fr.sound'), oldArcade);
    expect(preferences.getString('arcade.v1.en-fr.word'), '{"score":44}');
    expect(preferences.getString('auth.token'), 'keep-auth');
    expect(preferences.getString('profile.name'), 'keep-profile');
    expect(preferences.getInt('streak.days'), 7);
    expect(
      preferences.getString(legacyLearningSentinelKey),
      legacyLearningSentinelValue,
    );
  });
}
