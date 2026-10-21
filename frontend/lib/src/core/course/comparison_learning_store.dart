import 'comparison_learning_command.dart';
import 'comparison_learning_state.dart';

export 'course_learning_error.dart' show ComparisonUnavailableException;

abstract interface class ComparisonLearningStore {
  ComparisonProfileScope get scope;
  Future<ComparisonLearningState> load();
  Future<ComparisonLearningState> retryLoad();
  ComparisonLearningCommand prepare({
    required ComparisonLearningState state,
    required String activityId,
    required ComparisonAction action,
  });
  Future<ComparisonCommit> submit(ComparisonLearningCommand command);
}

final class ComparisonCommit {
  const ComparisonCommit({
    required this.state,
    required this.slot,
    required this.duplicate,
  });

  final ComparisonLearningState state;
  final ComparisonSlot slot;
  final bool duplicate;
}
