import 'package:flutter/material.dart';
import 'listening_exercise_contract.dart';

class ListeningExerciseFrame extends StatelessWidget {
  const ListeningExerciseFrame({
    super.key,
    required this.instruction,
    required this.state,
    required this.controls,
  });
  final String instruction;
  final ListeningExerciseState state;
  final Widget controls;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(instruction),
          const SizedBox(height: 8),
          if (state.playing) const Text('Playback in progress'),
          if (state.feedback == ListeningFeedback.correct)
            const Text('Correct'),
          if (state.feedback == ListeningFeedback.notYet) const Text('Not yet'),
          controls,
        ],
      ),
    ),
  );
}
