import 'package:flutter/material.dart';

import '../../core/course/lesson_section.dart';
import '../../core/course/lesson_section_session.dart';
import '../../core/course/lesson_debrief_content.dart';
import 'exercises/listening_choice.dart';
import 'exercises/listening_exercise_contract.dart';
import 'lesson_section_debrief.dart';

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
  DiscoverySectionView({
    super.key,
    required this.section,
    required this.session,
    required this.heard,
    required this.busy,
    this.playing = false,
    this.selectedSound,
    required this.error,
    this.notice,
    this.conflict,
    this.onReload,
    this.onPractiseAgain,
    List<LessonDebriefEntry> teachingEntries = const [],
    required this.onListen,
    required this.onAnswer,
    required this.onNext,
    required this.onReview,
    required this.onFinish,
    required this.onRetrySave,
  }) : teachingEntries = List.unmodifiable(teachingEntries);

  final LessonSection section;
  final LessonSectionSession session;
  final bool heard;
  final bool busy;
  final bool playing;
  final String? selectedSound;
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
  final List<LessonDebriefEntry> teachingEntries;
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
        : [
            LessonSectionDebrief(
              section: section,
              session: session,
              teachingEntries: teachingEntries,
              busy: busy,
              error: error,
              conflict: conflict,
              onReload: onReload,
              onPractiseAgain: onPractiseAgain,
              onReview: onReview,
              onFinish: onFinish,
              onRetrySave: onRetrySave,
            )
          ];
    final String? notice = this.notice;
    if (notice != null) {
      // The notice shares the scrolling content with the controls so that
      // large accessibility text cannot push the exercise off a small screen.
      children.insert(
          0,
          Container(
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
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: session.phase == LessonSectionPhase.debrief ? 8 : 16,
      ),
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
    final bool canNext = answered && !busy && !inError;
    final bool isLast = session.position == session.queue.length - 1;
    return [
      // Neutral title while the item is hidden: the word-bearing authored
      // title belongs to the debrief, so it must not leak during practice.
      Text('Listening practice', style: textTheme.titleLarge),
      const SizedBox(height: 6),
      Text(_progressLabel(), style: textTheme.bodyMedium),
      const SizedBox(height: 20),
      ListeningChoice(
        prompt: ListeningChoicePrompt(
          id: session.currentItemId!,
          instruction:
              'Listen to the French word, then choose the sound you hear.',
          choices: section.sounds
              .map((sound) =>
                  ListeningChoiceOption(id: sound, label: '/$sound/'))
              .toList(),
        ),
        state: ListeningExerciseState(
          busy: busy,
          playing: playing,
          blocked: inError,
          answered: answered,
          feedback: answered
              ? (session.lastCorrect == true
                  ? ListeningFeedback.correct
                  : ListeningFeedback.notYet)
              : null,
        ),
        heard: heard,
        selectedChoiceId: selectedSound,
        onListen: onListen,
        onAnswer: onAnswer,
      ),
      if (error != null) ..._errorChildren(textTheme),
      if (inConflict) ..._conflictChildren(textTheme),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: canNext ? onNext : null,
        child: Text(isLast ? 'See section explanation' : 'Next word'),
      ),
    ];
  }

  String _progressLabel() {
    final String item =
        'item ${session.position + 1} of ${session.queue.length}';
    return session.round == 1
        ? item[0].toUpperCase() + item.substring(1)
        : 'Review round ${session.round} · $item';
  }
}
