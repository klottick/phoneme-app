import 'package:flutter/material.dart';
import 'listening_exercise_contract.dart';
import 'listening_exercise_frame.dart';

class SoundComparison extends StatelessWidget {
  SoundComparison(
      {super.key,
      required this.prompt,
      required this.state,
      required Set<ComparisonSample> heardSamples,
      this.selectedRelation,
      required this.onListen,
      required this.onAnswer})
      : heardSamples = Set.unmodifiable(heardSamples);
  final SoundComparisonPrompt prompt;
  final ListeningExerciseState state;
  final Set<ComparisonSample> heardSamples;
  final PhonemeRelation? selectedRelation;
  final ValueChanged<ComparisonSample> onListen;
  final ValueChanged<PhonemeRelation> onAnswer;
  @override
  Widget build(BuildContext context) {
    final locked = state.busy || state.blocked || state.answered;
    return ListeningExerciseFrame(
        instruction: prompt.instruction,
        state: state,
        controls: Column(children: [
          for (final sample in ComparisonSample.values)
            ElevatedButton(
                onPressed: locked ? null : () => onListen(sample),
                child: Text(sample == ComparisonSample.a
                    ? 'Listen to sample A'
                    : 'Listen to sample B')),
          for (final relation in PhonemeRelation.values)
            Semantics(
                key: ValueKey('relation-${relation.name}'),
                container: true,
                button: true,
                selected: selectedRelation == relation,
                child: ElevatedButton(
                    onPressed: locked || heardSamples.length != 2
                        ? null
                        : () => onAnswer(relation),
                    child: Text(relation == PhonemeRelation.same
                        ? 'Same'
                        : 'Different')))
        ]));
  }
}
