import 'sentence_hunt_learning_command.dart';
import 'sentence_hunt_learning_state.dart';

export 'sentence_hunt_learning_state.dart'
    show SentenceHuntCapacityException, SentenceHuntUnavailableException;

abstract interface class SentenceHuntLearningStore {
  SentenceHuntProfileScope get scope;
  Future<SentenceHuntState> load();
  Future<SentenceHuntState> retryLoad();
  SentenceHuntCommand prepare({
    required SentenceHuntState state,
    required String sectionId,
    required SentenceHuntAction action,
  });
  Future<SentenceHuntCommit> submit(SentenceHuntCommand command);
}

final class SentenceHuntCommit {
  const SentenceHuntCommit({
    required this.state,
    required this.slot,
    required this.duplicate,
  });

  final SentenceHuntState state;
  final SentenceHuntSlot slot;
  final bool duplicate;
}
