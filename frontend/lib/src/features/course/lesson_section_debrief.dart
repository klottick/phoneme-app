import 'package:flutter/material.dart';

import '../../core/course/lesson_debrief_content.dart';
import '../../core/course/lesson_section.dart';
import '../../core/course/lesson_section_session.dart';

/// Controlled debrief presentation; scrolling and session ownership remain
/// with the containing discovery screen.
class LessonSectionDebrief extends StatelessWidget {
  LessonSectionDebrief({
    super.key,
    required this.section,
    required this.session,
    required List<LessonDebriefEntry> teachingEntries,
    required this.busy,
    required this.error,
    this.conflict,
    this.onReload,
    this.onPractiseAgain,
    required this.onReview,
    required this.onFinish,
    required this.onRetrySave,
  }) : teachingEntries = List.unmodifiable(teachingEntries);

  final LessonSection section;
  final LessonSectionSession session;
  final List<LessonDebriefEntry> teachingEntries;
  final bool busy;
  final String? error;
  final String? conflict;
  final VoidCallback? onReload;
  final VoidCallback? onPractiseAgain;
  final VoidCallback onReview;
  final VoidCallback onFinish;
  final VoidCallback onRetrySave;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final divider = Theme.of(context).dividerColor;
    final inConflict = conflict != null;
    final inError = error != null || inConflict;
    final canFinish = session.canComplete && !busy && !inError;
    final canReview = !busy && !inError;
    final total = session.itemIds.length;
    final unresolved = [
      for (final item in section.items)
        if (session.unresolvedItemIds.contains(item.id)) item,
    ];
    final entries = {for (final entry in teachingEntries) entry.itemId: entry};
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(section.title, style: textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('Section debrief', style: textTheme.bodyMedium),
        const SizedBox(height: 8),
        Text(section.explanation, style: textTheme.bodyLarge),
        const SizedBox(height: 8),
        Text('You got ${session.correctCount} of $total correct.',
            style: textTheme.titleMedium),
        Text(
            'Passing needs ${session.policy.requiredCorrect(total)} of $total correct.',
            style: textTheme.bodyMedium),
        if (unresolved.isEmpty)
          Text('Every word is correct now.', style: textTheme.bodyMedium),
        if (error != null) ...[
          const SizedBox(height: 24),
          Text(error!,
              style: textTheme.bodyMedium?.copyWith(color: Colors.red)),
          TextButton(
              onPressed: busy ? null : onRetrySave,
              child: const Text('Retry saving')),
        ],
        if (inConflict) ...[
          const SizedBox(height: 24),
          Text(conflict!,
              style: textTheme.bodyMedium
                  ?.copyWith(color: Colors.orange.shade700)),
          TextButton(
              onPressed: busy || onReload == null ? null : onReload,
              child: const Text('Reload saved progress')),
        ],
        const SizedBox(height: 8),
        FilledButton(
            onPressed: canFinish ? onFinish : null,
            child: const Text('Finish section')),
        if (unresolved.isNotEmpty) ...[
          const SizedBox(height: 4),
          OutlinedButton(
              onPressed: canReview ? onReview : null,
              child: const Text('Review mistakes')),
        ],
        if (onPractiseAgain != null) ...[
          const SizedBox(height: 10),
          OutlinedButton(
              onPressed: !busy && !inError ? onPractiseAgain : null,
              child: const Text('Practise again')),
        ],
        if (unresolved.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Unresolved words:', style: textTheme.bodyMedium),
          const SizedBox(height: 4),
          for (final item in unresolved)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: divider)),
                  child: Text(item.word, style: textTheme.bodyMedium),
                ),
                if (entries[item.id] case final entry?) ...[
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(entry.text, style: textTheme.bodyMedium)),
                ],
              ]),
            ),
        ],
      ],
    );
  }
}
