enum ComparisonSample { a, b }

enum PhonemeRelation { same, different }

enum ListeningFeedback { correct, notYet }

void _required(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'must not be blank');
  }
}

final class ListeningChoiceOption {
  ListeningChoiceOption({required this.id, required this.label}) {
    _required(id, 'id');
    _required(label, 'label');
  }
  final String id;
  final String label;
}

final class ListeningChoicePrompt {
  ListeningChoicePrompt(
      {required this.id,
      required this.instruction,
      required List<ListeningChoiceOption> choices})
      : choices = List.unmodifiable(choices) {
    _required(id, 'id');
    _required(instruction, 'instruction');
    if (choices.length < 2) {
      throw ArgumentError.value(
          choices, 'choices', 'at least two choices required');
    }
    if (choices.map((choice) => choice.id).toSet().length != choices.length ||
        choices.map((choice) => choice.label).toSet().length !=
            choices.length) {
      throw ArgumentError.value(
          choices, 'choices', 'choice IDs and labels must be unique');
    }
  }
  final String id;
  final String instruction;
  final List<ListeningChoiceOption> choices;
}

final class SoundComparisonPrompt {
  SoundComparisonPrompt(
      {required this.id,
      required this.instruction,
      required this.sampleAReferenceId,
      required this.sampleBReferenceId}) {
    _required(id, 'id');
    _required(instruction, 'instruction');
    _required(sampleAReferenceId, 'sampleAReferenceId');
    _required(sampleBReferenceId, 'sampleBReferenceId');
  }
  final String id;
  final String instruction;
  final String sampleAReferenceId;
  final String sampleBReferenceId;
}

final class ListeningExerciseState {
  ListeningExerciseState(
      {this.busy = false,
      this.playing = false,
      this.blocked = false,
      this.answered = false,
      this.feedback}) {
    if (playing && !busy) throw ArgumentError('playing requires busy');
    if (feedback != null && !answered) {
      throw ArgumentError('feedback requires answered');
    }
  }
  final bool busy;
  final bool playing;
  final bool blocked;
  final bool answered;
  final ListeningFeedback? feedback;
}
