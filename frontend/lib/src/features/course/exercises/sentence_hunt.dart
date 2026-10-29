import 'package:flutter/material.dart';

import '../../../core/widgets/purposeful_motion.dart';

import 'listening_exercise_contract.dart';

final class SentenceHuntDisplayToken {
  const SentenceHuntDisplayToken({
    required this.id,
    required this.text,
    required this.selectable,
  });

  final String id;
  final String text;
  final bool selectable;
}

final class SentenceHuntPrompt {
  SentenceHuntPrompt({
    required this.itemId,
    required this.targetLabel,
    required this.targetIpa,
    required List<SentenceHuntDisplayToken> displayTokens,
    required this.instruction,
  }) : displayTokens = List<SentenceHuntDisplayToken>.unmodifiable(
         displayTokens,
       ) {
    if (itemId.trim().isEmpty ||
        targetLabel.trim().isEmpty ||
        targetIpa.trim().isEmpty ||
        instruction.trim().isEmpty ||
        this.displayTokens.isEmpty ||
        this.displayTokens.any((token) => token.id.trim().isEmpty) ||
        this.displayTokens.map((token) => token.id).toSet().length !=
            this.displayTokens.length) {
      throw ArgumentError('Sentence-hunt prompt is invalid.');
    }
  }

  final String itemId;
  final String targetLabel;
  final String targetIpa;
  final List<SentenceHuntDisplayToken> displayTokens;
  final String instruction;
}

class SentenceHunt extends StatelessWidget {
  const SentenceHunt({
    super.key,
    required this.prompt,
    required this.state,
    required this.selectedTokenIds,
    required this.canSubmit,
    required this.onPlay,
    required this.onToggleToken,
    required this.onSubmit,
  });

  final SentenceHuntPrompt prompt;
  final ListeningExerciseState state;
  final Set<String> selectedTokenIds;
  final bool canSubmit;
  final VoidCallback onPlay;
  final ValueChanged<String> onToggleToken;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final bool enabled = !state.busy && !state.blocked && !state.answered;
    final Set<String> selected = selectedTokenIds;
    final int wordCount = prompt.displayTokens
        .where((token) => token.selectable)
        .length;
    var wordPosition = 0;
    final List<InlineSpan> transcript = <InlineSpan>[];
    for (final SentenceHuntDisplayToken token in prompt.displayTokens) {
      if (!token.selectable) {
        transcript.add(TextSpan(text: token.text));
        continue;
      }
      wordPosition++;
      final bool isSelected = selected.contains(token.id);
      final String label =
          'Word $wordPosition of $wordCount: ${token.text}'
          '${isSelected ? ', selected' : ''}';
      final VoidCallback? onToggle = enabled
          ? () => onToggleToken(token.id)
          : null;
      transcript.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Semantics(
            key: ValueKey<String>('sentence-word-${token.id}'),
            button: true,
            label: label,
            selected: isSelected,
            enabled: enabled,
            onTap: onToggle,
            child: ExcludeSemantics(
              child: TextButton(
                onPressed: onToggle,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  minimumSize: const Size(48, 48),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  backgroundColor: isSelected
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : null,
                  side: BorderSide(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    if (isSelected) const Icon(Icons.check, size: 18),
                    Text(token.text),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final VoidCallback? onPlay = enabled ? this.onPlay : null;
    final VoidCallback? onSubmit = enabled && canSubmit ? this.onSubmit : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              prompt.targetLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              prompt.targetIpa,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(prompt.instruction),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(children: transcript),
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onPlay,
              icon: Icon(state.playing ? Icons.volume_up : Icons.play_arrow),
              label: Text(
                state.playing ? 'Playing sentence…' : 'Play sentence',
              ),
            ),
            PurposefulSwitcher(
              child: switch (state.feedback) {
                ListeningFeedback.correct => const Padding(
                  key: ValueKey<String>('sentence-feedback-correct'),
                  padding: EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Icon(Icons.check_circle_outline),
                      Text('Correct'),
                    ],
                  ),
                ),
                ListeningFeedback.notYet => const Padding(
                  key: ValueKey<String>('sentence-feedback-not-yet'),
                  padding: EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Icon(Icons.info_outline),
                      Text('Not yet'),
                    ],
                  ),
                ),
                null => const SizedBox.shrink(
                  key: ValueKey<String>('sentence-feedback-none'),
                ),
              },
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: onSubmit,
              child: const Text('Submit answer'),
            ),
          ],
        ),
      ),
    );
  }
}
