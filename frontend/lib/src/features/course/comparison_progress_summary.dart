import '../../core/course/comparison_content.dart';
import '../../core/course/comparison_learning_state.dart';

class ComparisonProgressSummary {
  ComparisonProgressSummary._({
    required this.completedRuns,
    required this.uniqueAttemptedPairs,
    required this.correctAnswers,
    required this.totalAnswers,
    required this.afterDebriefAnswers,
    required List<ComparisonPairMistake> unresolvedMistakes,
    required this.hasCurrentRevisionCompletion,
  }) : unresolvedMistakes = List.unmodifiable(unresolvedMistakes);

  factory ComparisonProgressSummary.fromState({
    required ComparisonLearningState state,
    required ComparisonCatalogue catalogue,
  }) {
    const activity = comparisonActivityId;
    final revision = catalogue.contentRevision;
    final pairs = catalogue.exercises.map((e) => e.id).toSet();
    final buckets = state.summaries.values.where((summary) {
      final key = summary.key;
      return key.scope == state.scope &&
          key.activityId == activity &&
          key.contentRevision == revision &&
          pairs.contains(key.pairId);
    });
    var correct = 0, total = 0, after = 0;
    final exposed = <String>{};
    for (final bucket in buckets) {
      final first = bucket.firstInRun;
      final repeat = bucket.repeatInRun;
      correct += first.correct + repeat.correct;
      total += first.total + repeat.total;
      after += bucket.afterDebrief.total;
      if (first.total + repeat.total > 0) exposed.add(bucket.key.pairId);
    }
    final mistakes = state.mistakes.values
        .where((mistake) =>
            mistake.scope == state.scope &&
            mistake.key.activityId == activity &&
            mistake.key.contentRevision == revision &&
            pairs.contains(mistake.key.pairId))
        .toList()
      ..sort((a, b) => catalogue.exercises
          .indexWhere((e) => e.id == a.key.pairId)
          .compareTo(
              catalogue.exercises.indexWhere((e) => e.id == b.key.pairId)));
    final identities = <(String, int, int, int)>{};
    for (final completion in state.completions) {
      if (completion.scope == state.scope &&
          completion.activityId == activity &&
          completion.contentRevision == revision) {
        identities.add((
          completion.activityId,
          completion.contentRevision,
          completion.policyRevision,
          completion.thresholdPercent
        ));
      }
    }
    return ComparisonProgressSummary._(
      completedRuns: identities.length,
      uniqueAttemptedPairs: exposed.length,
      correctAnswers: correct,
      totalAnswers: total,
      afterDebriefAnswers: after,
      unresolvedMistakes: mistakes,
      hasCurrentRevisionCompletion: identities.isNotEmpty,
    );
  }

  final int completedRuns, uniqueAttemptedPairs, correctAnswers, totalAnswers;
  final int afterDebriefAnswers;
  final List<ComparisonPairMistake> unresolvedMistakes;
  int get unresolvedPairCount => unresolvedMistakes.length;
  final bool hasCurrentRevisionCompletion;

  String get practiceLabel => 'Comparison practice, not phoneme mastery';
  String get pairsLabel =>
      'Comparison pairs attempted: $uniqueAttemptedPairs/10';
  String get answersLabel =>
      'Comparison answers: $correctAnswers/$totalAnswers';
  String get afterDebriefLabel =>
      'After-debrief comparison answers: $afterDebriefAnswers';
  String get completionLabel =>
      'Comparison completion policies: $completedRuns';
  String get unresolvedLabel =>
      'Unresolved comparison pairs: $unresolvedPairCount';
}
