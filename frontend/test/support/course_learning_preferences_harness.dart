import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_persistence.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_store.dart';
import 'package:linguist/src/core/course/course_learning_sync.dart';
import 'package:linguist/src/core/course/course_learning_transition.dart';

/// Production repository and preferences adapter with deterministic command
/// identities for storage integration regressions.
class PreferencesLearningHarness {
  PreferencesLearningHarness({
    LearningOwner? owner,
    LearningPersistence? persistence,
    LearningCloudTransport? cloud,
  })  : owner = owner ?? LearningOwner.guest(),
        auth = LearningAuthScope(
            owner: owner ?? LearningOwner.guest(), generation: 0, ready: true) {
    scope = LearningScope(courseId: 'en-fr', owner: this.owner);
    store = CourseLearningRepository(
      scope: scope,
      authGeneration: 0,
      currentAuth: () => auth,
      backendOwner: () => this.owner,
      persistence: persistence ??
          PreferencesLearningPersistence(
              preferences: SharedPreferences.getInstance),
      transitions: LearningTransitionEngine(LearningRegistry.french()),
      cloud: cloud,
      clock: () => DateTime.utc(2026, 10, 15),
      newToken: () => _token(++_tokenCounter),
      random: Random(1),
    );
  }

  final LearningOwner owner;
  final LearningAuthScope auth;
  late final LearningScope scope;
  late final CourseLearningRepository store;
  int _tokenCounter = 0;

  Future<LearningCommit> start(String activityId) async => store.submit(
        store.prepare(
          state: await store.load(),
          activityId: activityId,
          action: StartLearningRun(options: RunOptions()),
        ),
      );

  Future<LearningCommit> answerPilot(String sound) async => store.submit(
        store.prepare(
          state: await store.load(),
          activityId: 'lesson:en-fr-u-y',
          action: ChooseSound(
            selectedSound: sound,
            audioSource: AttemptAudioSource.pendingRecording,
          ),
        ),
      );
}

String _token(int value) => value.toRadixString(16).padLeft(22, '0');
