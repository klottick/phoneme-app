import 'package:flutter/material.dart';

import '../../core/course/course_audio.dart';
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
    this.notice,
    this.conflict,
    this.onReload,
    this.onPractiseAgain,
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

  /// Optional recovery notice rendered inside the same scrolling content as
  /// the controls (so large accessibility text cannot overflow the screen),
  /// for example after a corrupt saved state was replaced by a fresh attempt.
  final String? notice;

  /// Non-null when the store rejected a checkpoint as a typed stale-session
  /// conflict ([LessonSectionConflictException]); blocks every progression
  /// action and exposes the explicit `Reload saved progress` action. This is
  /// distinct from [error], which is for transient save failures with a
  /// `Retry saving` action instead.
  final String? conflict;
  final VoidCallback? onReload;

  /// Optional debrief-only action that starts a fresh practice attempt
  /// (explicit 'Practise again'). Null hides the control; non-null shows it
  /// in the debrief whether or not unresolved words remain.
  final VoidCallback? onPractiseAgain;
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
    final String? notice = this.notice;
    if (notice != null) {
      // The notice shares the scrolling content with the controls so that
      // large accessibility text cannot push the exercise off a small screen.
      children.insert(0, Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.orange.shade100,
        child: Text(
          notice,
          style: const TextStyle(color: Colors.black87),
        ),
      ));
    }
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

  List<Widget> _conflictChildren(TextTheme textTheme) {
    return [
      const SizedBox(height: 24),
      Text(
        conflict!,
        style: _colored(textTheme.bodyMedium, Colors.orange.shade700),
      ),
      TextButton(
        onPressed: busy || onReload == null ? null : onReload,
        child: const Text('Reload saved progress'),
      ),
    ];
  }

  /// A typed stale-session conflict blocks progression just like a save
  /// error, but its recovery is the explicit reload, not a retry.
  bool _inConflict() => conflict != null;

  List<Widget> _exerciseChildren(TextTheme textTheme, Color divider) {
    final bool answered = session.answered;
    final bool inConflict = _inConflict();
    final bool inError = error != null || inConflict;
    final bool canListen = !answered && !heard && !busy && !inError;
    final bool canAnswer = heard && !answered && !busy && !inError;
    final bool canNext = answered && !busy && !inError;
    final bool isLast = session.position == session.queue.length - 1;
    final bool correct = session.answered && session.lastCorrect == true;
    return [
      // Neutral title while the item is hidden: the word-bearing authored
      // title belongs to the debrief, so it must not leak during practice.
      Text('Listening practice', style: textTheme.titleLarge),
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
            // Exact shared alpha disclosure (I1): the default shared player
            // selects the bundled unverified pending recordings for these
            // covered words first, so the old unconditional device-source
            // claim was false; the exact shared label is what stays pinned.
            Text(alphaAudioDisclosure, style: textTheme.bodySmall),
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
            // The label may wrap at large accessibility text instead of
            // pushing the row past the viewport width.
            Flexible(
              child: Text(
                correct ? 'Correct' : 'Not yet',
                style: _colored(
                    textTheme.titleMedium, correct ? Colors.green : Colors.red),
              ),
            ),
          ],
        ),
      ],
      if (error != null) ..._errorChildren(textTheme),
      if (inConflict) ..._conflictChildren(textTheme),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: canNext ? onNext : null,
        child: Text(isLast ? 'See section explanation' : 'Next word'),
      ),
    ];
  }

  List<Widget> _debriefChildren(TextTheme textTheme, Color divider) {
    final bool inConflict = _inConflict();
    final bool inError = error != null || inConflict;
    final bool canFinish = session.canComplete && !busy && !inError;
    final bool canReview = !busy && !inError;
    final int total = session.itemIds.length;
    final List<String> unresolvedWords =
        _sectionWordFor(session.unresolvedItemIds);
    return [
      // The word-bearing authored title is only revealed together with its
      // explanation at the debrief.
      Text(section.title, style: textTheme.titleLarge),
      const SizedBox(height: 8),
      Text('Section debrief', style: textTheme.bodyMedium),
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
      if (error != null) ..._errorChildren(textTheme),
      if (inConflict) ..._conflictChildren(textTheme),
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
      if (onPractiseAgain != null) ...[
        const SizedBox(height: 10),
        OutlinedButton(
          // Explicit only: the screen persists the fresh zero-attempt
          // identity before the exercise is exposed, so disable while that
          // save (or any error state) is unresolved.
          onPressed:
              onPractiseAgain != null && !busy && !inError ? onPractiseAgain : null,
          child: const Text('Practise again'),
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
