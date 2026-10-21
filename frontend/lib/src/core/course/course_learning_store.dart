import 'course_attempt.dart';
import 'course_learning_command.dart';
import 'course_learning_state.dart';
import 'course_learning_sync.dart';

abstract class CourseLearningStore {
  LearningScope get scope;
  Future<CourseLearningState> load();
  Future<CourseLearningState> retryLoad();
  LearningCommand prepare({
    required CourseLearningState state,
    required String activityId,
    required LearningAction action,
  });
  Future<LearningCommit> submit(LearningCommand command);
  Future<SupportedSyncResult> sync();
}

class LearningCommit {
  const LearningCommit({
    required this.state,
    required this.slot,
    required this.duplicate,
  });

  final CourseLearningState state;
  final ActivitySlot slot;
  final bool duplicate;
}
