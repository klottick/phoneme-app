import 'package:flutter/material.dart';
import 'package:linguist/src/core/course/course_exercise.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';

class SentenceHuntSectionDebrief extends StatelessWidget {
  const SentenceHuntSectionDebrief({
    super.key,
    required this.section,
    required this.session,
    required this.latestAttempts,
    required this.busy,
    required this.canReview,
    required this.canFinish,
    required this.completionEligible,
    required this.reviewOnly,
    required this.finished,
    required this.error,
    required this.conflict,
    required this.onReviewMistakes,
    required this.onFinish,
    required this.onRetrySave,
    required this.onReload,
  });

  final SentenceHuntSection section;
  final LessonSectionSession session;
  final List<SentenceHuntAttempt>? latestAttempts;
  final bool busy;
  final bool canReview;
  final bool canFinish;
  final bool completionEligible;
  final bool reviewOnly;
  final bool finished;
  final String? error;
  final String? conflict;
  final VoidCallback onReviewMistakes;
  final VoidCallback onFinish;
  final VoidCallback onRetrySave;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final bool unavailable = error != null || conflict != null;
    final bool mayReview = canReview && !busy && !unavailable;
    final bool mayFinish = canFinish &&
        !busy &&
        !unavailable &&
        !finished &&
        (reviewOnly || completionEligible);
    final int requiredCorrect =
        session.policy.requiredCorrect(section.items.length);

    return Column(
      key: const ValueKey<String>('sentence-hunt-section-debrief'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Sentence hunt debrief',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
            'You got ${session.correctCount} of ${section.items.length} correct.'),
        Text(
            'Passing needs $requiredCorrect of ${section.items.length} correct.'),
        Text(completionEligible
            ? 'Completion is eligible.'
            : 'Completion is not eligible yet.'),
        if (reviewOnly)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child:
                Text('Review-only practice does not count toward completion.'),
          ),
        if (finished)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('This saved sentence-hunt run is finished.'),
          ),
        const SizedBox(height: 12),
        const Text(
            'Answer keys and teaching notes are shown here after this debrief was saved.'),
        const SizedBox(height: 12),
        for (final SentenceHuntItem item in section.items)
          _itemDebrief(context, item),
        if (error != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(error!),
          if (latestAttempts != null)
            TextButton(
              onPressed: busy ? null : onRetrySave,
              child: const Text('Retry saving'),
            ),
        ],
        if (conflict != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(conflict!),
          TextButton(
            onPressed: busy ? null : onReload,
            child: const Text('Reload saved progress'),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton(
              onPressed: mayFinish ? onFinish : null,
              child: const Text('Finish'),
            ),
            if (canReview)
              OutlinedButton(
                onPressed: mayReview ? onReviewMistakes : null,
                child: const Text('Review mistakes'),
              ),
          ],
        ),
        if (busy) const Text('Saving progress…'),
      ],
    );
  }

  Widget _itemDebrief(BuildContext context, SentenceHuntItem item) {
    final bool? savedCorrect = session.latestAnswers[item.identity.itemId];
    final SentenceHuntAttempt? attempt = _attemptFor(item, savedCorrect);
    final Map<String, String> words = <String, String>{
      for (final SentenceToken token in item.sentence.tokens)
        token.id: token.text,
    };
    final List<String> keyWords = <String>[
      for (final String id in item.expectedTokenIds)
        if (words[id] != null) words[id]!,
    ];
    final List<String> missed = <String>[
      if (attempt != null)
        for (final String id in item.expectedTokenIds)
          if (!attempt.selectedTokenIds.contains(id) && words[id] != null)
            words[id]!,
    ];
    final List<String> extras = <String>[
      if (attempt != null)
        for (final String id in attempt.selectedTokenIds)
          if (!item.expectedTokenIds.contains(id) && words[id] != null)
            words[id]!,
    ];
    return Card(
      key: ValueKey<String>('sentence-hunt-debrief-${item.identity.itemId}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(item.identity.itemId,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(item.targetLabel),
            const SizedBox(height: 4),
            Text(item.sentence.text),
            const SizedBox(height: 4),
            Text('Words with target: ${keyWords.join(', ')}'),
            Text(item.debriefNote),
            if (attempt != null && attempt.correct)
              const Text('Saved answer: correct'),
            if (attempt != null && !attempt.correct) ...<Widget>[
              if (missed.isNotEmpty) Text('You missed: ${missed.join(', ')}'),
              if (extras.isNotEmpty)
                Text('Other word${extras.length == 1 ? '' : 's'} selected: '
                    '${extras.join(', ')}'),
              if (attempt.teachingExposed)
                const Text('Teaching was shown before this attempt.'),
            ],
          ],
        ),
      ),
    );
  }

  SentenceHuntAttempt? _attemptFor(
    SentenceHuntItem item,
    bool? savedCorrect,
  ) {
    if (savedCorrect == null || latestAttempts == null) return null;
    for (final SentenceHuntAttempt attempt in latestAttempts!.reversed) {
      if (attempt.content == item.identity &&
          attempt.correct == savedCorrect &&
          _sameOrder(attempt.expectedTokenIds, item.expectedTokenIds) &&
          attempt.selectedTokenIds.every(item.selectableTokenIds.contains)) {
        return attempt;
      }
    }
    return null;
  }

  bool _sameOrder(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
