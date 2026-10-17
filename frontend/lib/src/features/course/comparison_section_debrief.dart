import 'package:flutter/material.dart';

import '../../core/course/comparison_content.dart';
import '../../core/course/lesson_section_session.dart';

/// Controlled debrief for a comparison session. The containing screen owns
/// persistence, session transitions, and scrolling.
class ComparisonSectionDebrief extends StatelessWidget {
  const ComparisonSectionDebrief({
    super.key,
    required this.catalogue,
    required this.session,
    required this.busy,
    required this.error,
    required this.conflict,
    required this.canFinish,
    required this.onReview,
    required this.onFinish,
    required this.onRetrySave,
    required this.onReload,
    this.onPractiseAgain,
  });

  final ComparisonCatalogue catalogue;
  final LessonSectionSession session;
  final bool busy, canFinish;
  final String? error, conflict;
  final VoidCallback onReview, onFinish, onRetrySave, onReload;
  final VoidCallback? onPractiseAgain;

  static const _rule = 'Compare only the designated sound in each sample. '
      'Same means those two target phonemes are identical; Different means '
      'they are not. Ignore the rest of the word.';

  @override
  Widget build(BuildContext context) {
    final unresolvedNotes = catalogue.notesFor(session.unresolvedItemIds);
    final unavailable = error != null || conflict != null;
    final canAct = !busy && !unavailable;
    final mayFinish = canFinish && session.canComplete && canAct;
    final mayReview = session.unresolvedItemIds.isNotEmpty && canAct;
    final total = session.itemIds.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comparison debrief',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(_rule),
        const SizedBox(height: 12),
        Text('You got ${session.correctCount} of $total correct.'),
        Text(
            'Passing needs ${session.policy.requiredCorrect(total)} of $total correct.'),
        if (unresolvedNotes.isEmpty)
          const Text('Every comparison is correct now.'),
        if (unresolvedNotes.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Unresolved comparisons:'),
          const SizedBox(height: 4),
          for (final note in unresolvedNotes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(note),
            ),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!),
          TextButton(
            onPressed: busy ? null : onRetrySave,
            child: const Text('Retry saving'),
          ),
        ],
        if (conflict != null) ...[
          const SizedBox(height: 12),
          Text(conflict!),
          TextButton(
            onPressed: busy ? null : onReload,
            child: const Text('Reload saved progress'),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: mayFinish ? onFinish : null,
              child: const Text('Finish comparison'),
            ),
            if (session.unresolvedItemIds.isNotEmpty)
              OutlinedButton(
                onPressed: mayReview ? onReview : null,
                child: const Text('Review unresolved pairs'),
              ),
            if (onPractiseAgain != null)
              OutlinedButton(
                onPressed: canAct ? onPractiseAgain : null,
                child: const Text('Practise again'),
              ),
          ],
        ),
        if (busy) const Text('Saving progress…'),
      ],
    );
  }
}
