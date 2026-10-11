import 'package:flutter/material.dart';

import '../../core/course/lesson_section.dart';
import '../../core/course/lesson_section_session.dart';

/// Stateless view of one discovery listening section session.
///
/// Renders the pure [session] state against the authored [section] content:
/// the active listening puzzle (practice-TTS playback cue, /u//y/ choices,
/// immediate `Correct`/`Not yet` feedback) and the end-of-round debrief
/// (explanation, score, threshold, unresolved words, Finish, review).
///
/// `heard` reports whether playback completed for the current exercise item;
/// `busy` reports that a callback (playback, save, retry) is in flight; a
/// non-null `error` blocks progression and completion and exposes
/// `onRetrySave`.
///
/// All actions are lifted to the owner: [onListen], [onAnswer], [onNext],
/// [onReview], [onFinish], [onRetrySave]. This widget performs no I/O, never
/// initializes audio, never writes progress, and mutates nothing.
class DiscoverySectionView extends StatelessWidget {
  const DiscoverySectionView({
    super.key,
    required this.section,
    required this.session,
    required this.heard,
    required this.busy,
    required this.error,
    required this.onListen,
    required this.onAnswer,
    required this.onNext,
    required this.onReview,
    required this.onFinish,
    required this.onRetrySave,
  });

  final LessonSection section;
  final LessonSectionSession session;
  final bool heard;
  final bool busy;
  final String? error;
  final VoidCallback onListen;
  final ValueChanged<String> onAnswer;
  final VoidCallback onNext;
  final VoidCallback onReview;
  final VoidCallback onFinish;
  final VoidCallback onRetrySave;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color divider = Theme.of(context).dividerColor;
    final List<Widget> children = session.phase == LessonSectionPhase.exercise
        ? _exerciseChildren(textTheme, divider)
        : _debriefChildren(textTheme, divider);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }

  TextStyle? _colored(TextStyle? base, Color color) =>
      base?.copyWith(color: color) ?? TextStyle(color: color);

  List<Widget> _errorChildren(TextTheme textTheme) {
    return [
      const SizedBox(height: 24),
      Text(
        error!,
        style: _colored(textTheme.bodyMedium, Colors.red),
      ),
      TextButton(
        onPressed: busy ? null : onRetrySave,
        child: const Text('Retry saving'),
      ),
    ];
  }

  List<Widget> _exerciseChildren(TextTheme textTheme, Color divider) {
    final bool answered = session.answered;
    final bool inError = error != null;
    final bool canListen = !answered && !heard && !busy && !inError;
    final bool canAnswer = heard && !answered && !busy && !inError;
    final bool canNext = answered && !busy && !inError;
    final bool isLast = session.position == session.queue.length - 1;
    final bool correct = session.answered && session.lastCorrect == true;
    return [
      Text(section.title, style: textTheme.titleLarge),
      const SizedBox(height: 6),
      Text(_progressLabel(), style: textTheme.bodyMedium),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Listen to the French word, then choose the sound you hear.',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Practice audio: spoken by this device.',
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: canListen ? onListen : null,
        child: const Text('Listen to the word'),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 10,
        children: [
          for (final String sound in section.sounds)
            TextButton(
              onPressed: canAnswer ? () => onAnswer(sound) : null,
              child: Text('/$sound/'),
            ),
        ],
      ),
      if (answered) ...[
        const SizedBox(height: 20),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              correct ? Icons.check_circle : Icons.close,
              size: 20,
              color: correct ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(
              correct ? 'Correct' : 'Not yet',
              style: _colored(
                  textTheme.titleMedium, correct ? Colors.green : Colors.red),
            ),
          ],
        ),
      ],
      if (inError) ..._errorChildren(textTheme),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: canNext ? onNext : null,
        child: Text(isLast ? 'See section explanation' : 'Next word'),
      ),
    ];
  }

  List<Widget> _debriefChildren(TextTheme textTheme, Color divider) {
    final bool inError = error != null;
    final bool canFinish = session.canComplete && !busy && !inError;
    final bool canReview = !busy && !inError;
    final int total = session.itemIds.length;
    final List<String> unresolvedWords =
        _sectionWordFor(session.unresolvedItemIds);
    return [
      Text('Section debrief', style: textTheme.titleLarge),
      const SizedBox(height: 16),
      Text(section.explanation, style: textTheme.bodyLarge),
      const SizedBox(height: 16),
      Text('You got ${session.correctCount} of $total correct.',
          style: textTheme.titleMedium),
      Text(
        'Passing needs ${session.policy.requiredCorrect(total)} of $total correct.',
        style: textTheme.bodyMedium,
      ),
      if (unresolvedWords.isEmpty)
        Text('Every word is correct now.', style: textTheme.bodyMedium)
      else ...[
        const SizedBox(height: 16),
        Text('Unresolved words:', style: textTheme.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final String word in unresolvedWords)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: divider),
                ),
                child: Text(word, style: textTheme.bodyMedium),
              ),
          ],
        ),
      ],
      if (inError) ..._errorChildren(textTheme),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: canFinish ? onFinish : null,
        child: const Text('Finish section'),
      ),
      if (unresolvedWords.isNotEmpty) ...[
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: canReview ? onReview : null,
          child: const Text('Review mistakes'),
        ),
      ],
    ];
  }

  String _progressLabel() {
    final String item =
        'item ${session.position + 1} of ${session.queue.length}';
    return session.round == 1
        ? item[0].toUpperCase() + item.substring(1)
        : 'Review round ${session.round} · $item';
  }

  /// The section words whose item IDs the session still reports unresolved.
  List<String> _sectionWordFor(List<String> itemIds) {
    final Map<String, String> wordById = {
      for (final LessonSectionItem item in section.items) item.id: item.word,
    };
    return [
      for (final String id in itemIds)
        if (wordById[id] != null) wordById[id]!,
    ];
  }
}
