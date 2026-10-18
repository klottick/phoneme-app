import '../../core/course/french_sentence_exercises.dart';
import '../../core/course/lesson_section_session.dart';
import '../../core/course/sentence_hunt_content.dart';
import '../../core/course/sentence_hunt_learning_state.dart';

enum SentenceHuntSectionStatus { unavailable, notStarted, resumable, completed }

final class SentenceHuntMistakeProgress {
  const SentenceHuntMistakeProgress({
    required this.sectionId,
    required this.itemId,
    required this.failureCount,
  });

  final String sectionId;
  final String itemId;
  final int failureCount;
}

/// Per-item sentence evidence, kept separate from phoneme and comparison data.
final class SentenceHuntItemProgress {
  const SentenceHuntItemProgress({
    required this.itemId,
    required this.firstInRunCorrect,
    required this.firstInRunTotal,
    required this.repeatInRunCorrect,
    required this.repeatInRunTotal,
    required this.firstTeachingExposedCorrect,
    required this.firstTeachingExposedTotal,
    required this.repeatTeachingExposedCorrect,
    required this.repeatTeachingExposedTotal,
  });

  final String itemId;
  final int firstInRunCorrect;
  final int firstInRunTotal;
  final int repeatInRunCorrect;
  final int repeatInRunTotal;
  final int firstTeachingExposedCorrect;
  final int firstTeachingExposedTotal;
  final int repeatTeachingExposedCorrect;
  final int repeatTeachingExposedTotal;

  int get correctAnswers => firstInRunCorrect + repeatInRunCorrect;
  int get totalAnswers => firstInRunTotal + repeatInRunTotal;
  int get teachingExposedAnswers =>
      firstTeachingExposedTotal + repeatTeachingExposedTotal;
}

final class SentenceHuntSectionProgress {
  SentenceHuntSectionProgress({
    required this.id,
    required this.title,
    required this.status,
    required this.latestCorrectCount,
    required this.latestAnsweredItemCount,
    required this.totalItemCount,
    required this.savedThresholdPercent,
    required this.correctAnswerCount,
    required this.totalAnswerCount,
    required this.exposedAnswerCount,
    required List<SentenceHuntItemProgress> items,
    required List<SentenceHuntMistakeProgress> mistakes,
  })  : items = List<SentenceHuntItemProgress>.unmodifiable(items),
        mistakes = List<SentenceHuntMistakeProgress>.unmodifiable(mistakes);

  final String id;
  final String title;
  final SentenceHuntSectionStatus status;

  /// Null when a saved checkpoint cannot be safely interpreted for this content.
  final int? latestCorrectCount;
  final int? latestAnsweredItemCount;
  final int totalItemCount;
  final int? savedThresholdPercent;
  final int correctAnswerCount;
  final int totalAnswerCount;
  final int exposedAnswerCount;
  final List<SentenceHuntItemProgress> items;
  final List<SentenceHuntMistakeProgress> mistakes;

  String get statusLabel => switch (status) {
        SentenceHuntSectionStatus.unavailable => 'Unavailable',
        SentenceHuntSectionStatus.notStarted => 'Not started',
        SentenceHuntSectionStatus.resumable => 'Resumable',
        SentenceHuntSectionStatus.completed => 'Completed',
      };

  String get latestResultLabel {
    final int? correct = latestCorrectCount;
    final int? answered = latestAnsweredItemCount;
    if (correct == null || answered == null) return 'Saved result unavailable';
    return 'Latest saved run: $correct/$totalItemCount correct · '
        '$answered/$totalItemCount attempted';
  }
}

/// Current registered sentence-hunt progress; it never contributes to legacy
/// identification, comparison, sound-summary, or mastery totals.
final class SentenceHuntProgressSummary {
  SentenceHuntProgressSummary._({
    required List<SentenceHuntSectionProgress> sections,
    required this.correctAnswers,
    required this.totalAnswers,
    required this.exposedAnswerCount,
  }) : sections = List<SentenceHuntSectionProgress>.unmodifiable(sections);

  factory SentenceHuntProgressSummary.fromState({
    required SentenceHuntState state,
    required SentenceHuntCatalogue catalogue,
  }) {
    if (state.scope.courseId != 'en-fr') {
      throw ArgumentError.value(state.scope.courseId, 'state.scope.courseId');
    }

    final List<SentenceHuntSectionProgress> sections =
        <SentenceHuntSectionProgress>[];
    for (final SentenceHuntSectionSpecification specification
        in sentenceHuntSectionSpecifications) {
      SentenceHuntSection? section;
      try {
        section = catalogue.section(specification.id);
      } on Object {
        // A malformed registered sibling is unavailable, not an empty section.
      }
      final bool available =
          section != null && catalogue.isAvailable(specification.id);
      final SentenceHuntSlot? slot = state.slots[specification.id];
      final bool slotMatches = section != null &&
          slot != null &&
          slot.checkpoint.scope == state.scope &&
          slot.checkpoint.sectionFingerprint == section.sectionFingerprint &&
          slot.checkpoint.contentRevision == section.contentRevision;
      final bool completed = section != null &&
          state.completions.any((SentenceHuntCompletion completion) =>
              completion.scope == state.scope &&
              completion.sectionId == section!.id &&
              completion.contentRevision == section.contentRevision &&
              completion.policyRevision == section.policyRevision &&
              completion.thresholdPercent ==
                  section.policy.completionThresholdPercent);

      final SentenceHuntSectionStatus status;
      if (!available || (slot != null && !slotMatches)) {
        status = SentenceHuntSectionStatus.unavailable;
      } else if (completed) {
        status = SentenceHuntSectionStatus.completed;
      } else if (slot != null) {
        status = SentenceHuntSectionStatus.resumable;
      } else {
        status = SentenceHuntSectionStatus.notStarted;
      }

      int? latestCorrect;
      int? latestAnswered;
      int? savedThreshold;
      if (slot == null) {
        latestCorrect = 0;
        latestAnswered = 0;
      } else if (slotMatches) {
        savedThreshold = slot.checkpoint.policy.completionThresholdPercent;
        try {
          final LessonSectionSession session = LessonSectionSession.fromJson(
            Map<String, dynamic>.from(slot.checkpoint.sessionJson),
            itemIds: section.items
                .map((SentenceHuntItem item) => item.identity.itemId)
                .toList(growable: false),
            contentRevision: section.contentRevision,
          );
          latestCorrect = session.correctCount;
          latestAnswered = session.answeredItemCount;
        } on Object {
          // Corrupt or stale local details remain unknown instead of becoming 0.
        }
      }

      final List<SentenceHuntItemProgress> itemProgress =
          <SentenceHuntItemProgress>[];
      final List<SentenceHuntMistakeProgress> mistakes =
          <SentenceHuntMistakeProgress>[];
      if (section != null) {
        for (final SentenceHuntItem item in section.items) {
          final SentenceHuntSummary? savedSummary =
              _summaryFor(state, item.identity);
          final SentenceHuntCounts first = savedSummary?.firstInRun ??
              SentenceHuntCounts(correct: 0, total: 0);
          final SentenceHuntCounts repeat = savedSummary?.repeatInRun ??
              SentenceHuntCounts(correct: 0, total: 0);
          final SentenceHuntCounts firstExposed =
              savedSummary?.firstTeachingExposed ??
                  SentenceHuntCounts(correct: 0, total: 0);
          final SentenceHuntCounts repeatExposed =
              savedSummary?.repeatTeachingExposed ??
                  SentenceHuntCounts(correct: 0, total: 0);
          itemProgress.add(SentenceHuntItemProgress(
            itemId: item.identity.itemId,
            firstInRunCorrect: first.correct,
            firstInRunTotal: first.total,
            repeatInRunCorrect: repeat.correct,
            repeatInRunTotal: repeat.total,
            firstTeachingExposedCorrect: firstExposed.correct,
            firstTeachingExposedTotal: firstExposed.total,
            repeatTeachingExposedCorrect: repeatExposed.correct,
            repeatTeachingExposedTotal: repeatExposed.total,
          ));

          final SentenceHuntMistake? mistake =
              _mistakeFor(state, item.identity);
          if (mistake != null) {
            mistakes.add(SentenceHuntMistakeProgress(
              sectionId: specification.id,
              itemId: item.identity.itemId,
              failureCount: mistake.failureCount,
            ));
          }
        }
      }

      final int sectionCorrect = itemProgress.fold<int>(
          0,
          (int total, SentenceHuntItemProgress item) =>
              total + item.correctAnswers);
      final int sectionAnswers = itemProgress.fold<int>(
          0,
          (int total, SentenceHuntItemProgress item) =>
              total + item.totalAnswers);
      final int exposedAnswers = itemProgress.fold<int>(
          0,
          (int total, SentenceHuntItemProgress item) =>
              total + item.teachingExposedAnswers);
      sections.add(SentenceHuntSectionProgress(
        id: specification.id,
        title: _titleFor(specification),
        status: status,
        latestCorrectCount: latestCorrect,
        latestAnsweredItemCount: latestAnswered,
        totalItemCount: 5,
        savedThresholdPercent:
            savedThreshold ?? section?.policy.completionThresholdPercent,
        correctAnswerCount: sectionCorrect,
        totalAnswerCount: sectionAnswers,
        exposedAnswerCount: exposedAnswers,
        items: itemProgress,
        mistakes: mistakes,
      ));
    }

    return SentenceHuntProgressSummary._(
      sections: sections,
      correctAnswers: sections.fold<int>(
          0,
          (int total, SentenceHuntSectionProgress section) =>
              total + section.correctAnswerCount),
      totalAnswers: sections.fold<int>(
          0,
          (int total, SentenceHuntSectionProgress section) =>
              total + section.totalAnswerCount),
      exposedAnswerCount: sections.fold<int>(
          0,
          (int total, SentenceHuntSectionProgress section) =>
              total + section.exposedAnswerCount),
    );
  }

  final List<SentenceHuntSectionProgress> sections;
  final int correctAnswers;
  final int totalAnswers;
  final int exposedAnswerCount;

  int get completedSectionCount => sections
      .where((SentenceHuntSectionProgress section) =>
          section.status == SentenceHuntSectionStatus.completed)
      .length;

  List<SentenceHuntMistakeProgress> get unresolvedMistakes =>
      List<SentenceHuntMistakeProgress>.unmodifiable(
        sections
            .expand((SentenceHuntSectionProgress section) => section.mistakes),
      );

  String get practiceLabel => 'Sentence practice, not phoneme mastery';
  String get completionLabel =>
      'Sentence sections completed: $completedSectionCount/3';
  String get answersLabel =>
      'Sentence practice answers: $correctAnswers/$totalAnswers';
  String get exposedAnswersLabel =>
      'After-debrief sentence answers: $exposedAnswerCount';
}

String _titleFor(SentenceHuntSectionSpecification specification) =>
    switch (specification.kind) {
      'vowels' => 'Vowels',
      'consonants' => 'Consonants',
      _ => 'Mixed review',
    };

SentenceHuntSummary? _summaryFor(
  SentenceHuntState state,
  SentenceHuntContentIdentity content,
) {
  for (final SentenceHuntSummary summary in state.summaries.values) {
    if (summary.scope == state.scope && summary.content == content) {
      return summary;
    }
  }
  return null;
}

SentenceHuntMistake? _mistakeFor(
  SentenceHuntState state,
  SentenceHuntContentIdentity content,
) {
  for (final SentenceHuntMistake mistake in state.mistakes.values) {
    if (mistake.scope == state.scope && mistake.content == content) {
      return mistake;
    }
  }
  return null;
}
