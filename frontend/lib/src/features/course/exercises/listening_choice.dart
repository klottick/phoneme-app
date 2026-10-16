import 'package:flutter/material.dart';
import 'listening_exercise_contract.dart';
import 'listening_exercise_frame.dart';

class ListeningChoice extends StatelessWidget {
  const ListeningChoice(
      {super.key,
      required this.prompt,
      required this.state,
      required this.heard,
      this.selectedChoiceId,
      required this.onListen,
      required this.onAnswer});
  final ListeningChoicePrompt prompt;
  final ListeningExerciseState state;
  final bool heard;
  final String? selectedChoiceId;
  final VoidCallback onListen;
  final ValueChanged<String> onAnswer;
  @override
  Widget build(BuildContext context) {
    final locked = state.busy || state.blocked || state.answered;
    return ListeningExerciseFrame(
        instruction: prompt.instruction,
        state: state,
        controls: Column(children: [
          FilledButton(
              onPressed: locked ? null : onListen,
              child: const Text('Listen to the word')),
          for (final choice in prompt.choices)
            MergeSemantics(
                child: Semantics(
                    key: ValueKey('choice-${choice.id}'),
                    container: true,
                    button: true,
                    selected: selectedChoiceId == choice.id,
                    child: TextButton(
                        onPressed:
                            locked || !heard ? null : () => onAnswer(choice.id),
                        child: Text(choice.label))))
        ]));
  }
}
