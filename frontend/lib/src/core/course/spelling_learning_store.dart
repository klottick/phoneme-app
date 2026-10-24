import 'spelling_learning_command.dart';
import 'spelling_learning_state.dart';

abstract interface class SpellingLearningStore {
  SpellingProfileScope get scope;

  Future<SpellingLearningState> load();

  Future<SpellingLearningState> retryLoad();

  SpellingLearningCommand prepare({
    required SpellingLearningState state,
    required SpellingAction action,
  });

  Future<SpellingCommit> submit(SpellingLearningCommand command);
}

final class SpellingCommit {
  const SpellingCommit({
    required this.state,
    required this.slot,
    required this.duplicate,
  });

  final SpellingLearningState state;
  final SpellingSlot slot;
  final bool duplicate;
}
