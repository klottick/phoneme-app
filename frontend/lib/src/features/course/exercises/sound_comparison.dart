import 'package:flutter/material.dart';
import '../../../core/widgets/purposeful_motion.dart';
import 'listening_exercise_contract.dart';
import 'listening_exercise_frame.dart';

class SoundComparison extends StatelessWidget {
  SoundComparison({
    super.key,
    required this.prompt,
    required this.state,
    required Set<ComparisonSample> heardSamples,
    this.playingSample,
    this.selectedRelation,
    this.answerAcknowledged = false,
    required this.onListen,
    required this.onAnswer,
  }) : heardSamples = Set.unmodifiable(heardSamples);
  final SoundComparisonPrompt prompt;
  final ListeningExerciseState state;
  final Set<ComparisonSample> heardSamples;
  final ComparisonSample? playingSample;
  final PhonemeRelation? selectedRelation;
  final bool answerAcknowledged;
  final ValueChanged<ComparisonSample> onListen;
  final ValueChanged<PhonemeRelation> onAnswer;

  @override
  Widget build(BuildContext context) {
    final locked = state.busy || state.blocked || state.answered;
    return PurposefulSwitcher(
      child: ListeningExerciseFrame(
        key: ValueKey('comparison-problem-${prompt.id}'),
        instruction: prompt.instruction,
        state: state,
        controls: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final sample in ComparisonSample.values) ...<Widget>[
                    if (sample != ComparisonSample.a) const SizedBox(width: 12),
                    Expanded(child: _sampleCard(context, sample, locked)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Same or different?',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final relation in PhonemeRelation.values) ...<Widget>[
                    if (relation != PhonemeRelation.same)
                      const SizedBox(width: 12),
                    Expanded(child: _relationCard(context, relation, locked)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sampleCard(
    BuildContext context,
    ComparisonSample sample,
    bool locked,
  ) {
    final bool heard = heardSamples.contains(sample);
    final bool playing = playingSample == sample;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color background = playing
        ? colors.primaryContainer
        : heard
        ? colors.secondaryContainer
        : colors.surfaceContainerHighest;
    final Color foreground = playing
        ? colors.onPrimaryContainer
        : heard
        ? colors.onSecondaryContainer
        : colors.onSurface;
    final String label = sample == ComparisonSample.a
        ? 'Listen to sample A'
        : 'Listen to sample B';
    final String status = answerAcknowledged
        ? 'Answered'
        : playing
        ? 'Playing'
        : heard
        ? 'Heard'
        : 'Not heard';

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ElevatedButton(
        onPressed: locked ? null : () => onListen(sample),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(136),
          padding: const EdgeInsets.all(12),
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background,
          disabledForegroundColor: foreground,
          elevation: 0,
          shape: const RoundedRectangleBorder(),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              playing ? Icons.volume_up_rounded : Icons.volume_up_outlined,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Semantics(
              value: status,
              child: ExcludeSemantics(
                child: Text(
                  status,
                  style: Theme.of(context).textTheme.labelMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _relationCard(
    BuildContext context,
    PhonemeRelation relation,
    bool locked,
  ) {
    final bool isSame = relation == PhonemeRelation.same;
    final bool selected = selectedRelation == relation;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color background = selected
        ? colors.secondaryContainer
        : colors.surface;
    final Color foreground = selected
        ? colors.onSecondaryContainer
        : colors.onSurface;
    final String label = isSame ? 'Same' : 'Different';
    final bool enabled = !locked && heardSamples.length == 2;

    return MergeSemantics(
      child: Semantics(
        key: ValueKey<String>('relation-${relation.name}'),
        container: true,
        button: true,
        selected: selected,
        child: OutlinedButton(
          onPressed: enabled ? () => onAnswer(relation) : null,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(92),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            backgroundColor: background,
            foregroundColor: foreground,
            disabledBackgroundColor: background,
            disabledForegroundColor: foreground,
            side: BorderSide(
              color: selected ? colors.primary : colors.outline,
              width: selected ? 3 : 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ExcludeSemantics(
                child: Text(
                  isSame ? '=' : '≠',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (selected) ...<Widget>[
                    const Icon(Icons.check_circle, size: 20),
                    const SizedBox(width: 6),
                  ],
                  Flexible(child: Text(label, textAlign: TextAlign.center)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
