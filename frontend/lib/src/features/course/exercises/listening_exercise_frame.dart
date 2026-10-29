import 'package:flutter/material.dart';
import '../../../core/widgets/purposeful_motion.dart';
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
          PurposefulSwitcher(
            child: state.playing
                ? const Text(
                    'Playback in progress',
                    key: ValueKey<String>('playback-in-progress'),
                  )
                : const SizedBox.shrink(key: ValueKey<String>('playback-idle')),
          ),
          PurposefulSwitcher(
            child: switch (state.feedback) {
              ListeningFeedback.correct => const Text(
                'Correct',
                key: ValueKey<String>('feedback-correct'),
              ),
              ListeningFeedback.notYet => const Text(
                'Not yet',
                key: ValueKey<String>('feedback-not-yet'),
              ),
              null => const SizedBox.shrink(
                key: ValueKey<String>('feedback-none'),
              ),
            },
          ),
          controls,
        ],
      ),
    ),
  );
}
