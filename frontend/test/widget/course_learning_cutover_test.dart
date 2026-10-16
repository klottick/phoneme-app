import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_persistence.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_store.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_transition.dart';
import 'package:linguist/src/features/arcade/arcade_screen.dart';
import 'package:linguist/src/features/course/course_lesson_screen.dart';
import 'package:linguist/src/features/course/course_progress_screen.dart';
import 'package:linguist/src/features/course/discovery_lesson_screen.dart';
import 'package:linguist/src/features/drills/drill_screen.dart';
import 'package:linguist/src/features/home/home_screen.dart';

class _SilentAudio implements CourseAudio {
  @override
  Future<void> speak(String word) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('all learning surfaces use same committed typed state',
      (tester) async {
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
    });
    final scope =
        LearningScope(courseId: 'en-fr', owner: LearningOwner.guest());
    final auth =
        LearningAuthScope(owner: scope.owner, generation: 0, ready: true);
    var tokenNumber = 0;
    final store = CourseLearningRepository(
      scope: scope,
      authGeneration: 0,
      currentAuth: () => auth,
      backendOwner: () => LearningOwner.guest(),
      persistence: PreferencesLearningPersistence(),
      transitions: LearningTransitionEngine(LearningRegistry.french()),
      clock: () => DateTime.utc(2026, 10, 15),
      newToken: () => (++tokenNumber).toRadixString(36).padLeft(22, '0'),
      random: Random(1),
    );
    var state = await store.load();
    await store.submit(store.prepare(
      state: state,
      activityId: 'lesson:en-fr-u-y',
      action: StartLearningRun(options: RunOptions()),
    ));
    state = await store.load();
    await store.submit(store.prepare(
      state: state,
      activityId: 'lesson:en-fr-u-y',
      action: ChooseSound(
        selectedSound: 'u',
        audioSource: AttemptAudioSource.pendingRecording,
      ),
    ));
    final surfaces = <Widget Function()>[
      () => const HomeScreen(),
      () => const CourseProgressScreen(),
      () => const DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
      () => const CourseLessonScreen(lessonId: 'en-fr-vowels'),
      () => const DrillScreen(),
      () => const ArcadeScreen(silent: true),
    ];
    for (var index = 0; index < surfaces.length; index++) {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          courseLearningStoreProvider.overrideWithValue(store),
          courseAudioProvider.overrideWithValue(_SilentAudio()),
        ],
        child: MaterialApp(home: surfaces[index]()),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      if (index == 1) {
        expect(find.textContaining('/u/'), findsWidgets,
            reason: 'progress reads the committed typed attempt');
      }
      await tester.pumpWidget(const SizedBox());
    }

    final committed = await store.load();
    expect(committed.history, hasLength(1));
    expect(committed.completions, isEmpty);
    expect(
        committed.summaries.values
            .fold<int>(0, (sum, count) => sum + count.total),
        1);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('course.v1.en-fr'), oldCourse);
    expect(preferences.getString('arcade.v1.en-fr.sound'), oldArcade);
    expect(preferences.getString('arcade.v1.en-fr.word'), '{"score":44}');
    expect(preferences.getString('auth.token'), 'keep-auth');
    expect(preferences.getString('profile.name'), 'keep-profile');
    expect(preferences.getInt('streak.days'), 7);
  });
}
