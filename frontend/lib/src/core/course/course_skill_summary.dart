import 'course_attempt.dart';

class SummaryKey {
  SummaryKey(
      {required this.sound,
      required this.skill,
      required this.origin,
      required this.presentation,
      required Set<AssistanceFlag> assistance})
      : assistance = Set.unmodifiable(assistance);
  final String sound;
  final LearningSkill skill;
  final AttemptOrigin origin;
  final AttemptPresentation presentation;
  final Set<AssistanceFlag> assistance;
  @override
  bool operator ==(Object o) =>
      o is SummaryKey &&
      sound == o.sound &&
      skill == o.skill &&
      origin == o.origin &&
      presentation == o.presentation &&
      assistance.length == o.assistance.length &&
      assistance.containsAll(o.assistance);
  @override
  int get hashCode => Object.hash(sound, skill, origin, presentation,
      Object.hashAll(assistance.map((e) => e.index).toList()..sort()));
}

class SkillCount {
  SkillCount({required this.total, required this.correct}) {
    if (total < 0 || correct < 0 || correct > total)
      throw ArgumentError('Invalid skill count');
  }
  final int total;
  final int correct;
}

Map<SummaryKey, SkillCount> addAttemptCounts(
    Map<SummaryKey, SkillCount> previous, Iterable<CourseAttempt> attempts) {
  final out = Map<SummaryKey, SkillCount>.of(previous);
  for (final a in attempts) {
    for (final sound in a.targetSounds.toSet()) {
      final k = SummaryKey(
          sound: sound,
          skill: a.skill,
          origin: a.origin,
          presentation: a.presentation,
          assistance: a.assistance);
      final old = out[k] ?? SkillCount(total: 0, correct: 0);
      out[k] = SkillCount(
          total: old.total + 1, correct: old.correct + (a.correct ? 1 : 0));
    }
  }
  return Map.unmodifiable(out);
}
