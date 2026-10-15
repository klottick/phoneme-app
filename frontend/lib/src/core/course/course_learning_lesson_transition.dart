import 'course_attempt.dart';
import 'course_learning_checkpoint.dart';
import 'course_learning_command.dart';
import 'course_learning_error.dart';
import 'course_learning_registry.dart';
import 'french_course.dart';
import 'lesson_section_session.dart';

class LessonMutation {
  const LessonMutation({
    required this.snapshot,
    this.answerItem,
    this.selectedChoice,
    this.feedback = const LearningFeedback.none(),
  });

  final ActivitySnapshot snapshot;
  final LearningSourceItem? answerItem;
  final String? selectedChoice;
  final LearningFeedback feedback;
}

LessonMutation transitionLesson({
  required LearningActivityDefinition definition,
  required ActivitySnapshot snapshot,
  required LearningAction action,
}) {
  if (definition.kind == LearningActivityKind.discovery) {
    final checkpoint = snapshot as DiscoveryCheckpoint;
    final session = checkpoint.session;
    switch (action) {
      case ChooseSound(:final selectedSound):
        final alias = session.currentItemId;
        if (session.phase != LessonSectionPhase.exercise ||
            alias == null ||
            session.answered) {
          throw const LearningInvalidCommandException();
        }
        final item = _sourceForAlias(definition, alias);
        if (!item.choices.contains(selectedSound)) {
          throw const LearningInvalidCommandException();
        }
        final correct = selectedSound == item.expectedChoice;
        session.submit(correct);
        return LessonMutation(
          snapshot: DiscoveryCheckpoint(session: session),
          answerItem: item,
          selectedChoice: selectedSound,
          feedback: LearningFeedback(
            message: correct ? 'Correct' : 'Not yet',
            points: 0,
            cascades: 0,
            bonus: 0,
            correct: correct,
          ),
        );
      case AdvanceLesson():
        session.advance();
        return LessonMutation(snapshot: DiscoveryCheckpoint(session: session));
      case ReviewDiscoveryMistakes():
        session.reviewMistakes();
        return LessonMutation(snapshot: DiscoveryCheckpoint(session: session));
      case _:
        throw const LearningInvalidCommandException();
    }
  }

  if (definition.kind == LearningActivityKind.legacyLesson) {
    final checkpoint = snapshot as LegacyLessonCheckpoint;
    switch (action) {
      case ChooseSound(:final selectedSound):
        if (checkpoint.finished ||
            checkpoint.wordIndex < 0 ||
            checkpoint.wordIndex >= definition.items.length ||
            checkpoint.selectedSound != null) {
          throw const LearningInvalidCommandException();
        }
        final item = definition.items[checkpoint.wordIndex];
        if (!item.choices.contains(selectedSound)) {
          throw const LearningInvalidCommandException();
        }
        final correct = selectedSound == item.expectedChoice;
        final word = wordByText(item.audioText!);
        return LessonMutation(
          snapshot: LegacyLessonCheckpoint(
            wordIndex: checkpoint.wordIndex,
            selectedSound: selectedSound,
            finished: false,
          ),
          answerItem: item,
          selectedChoice: selectedSound,
          feedback: LearningFeedback(
            message:
                '${correct ? 'Yes!' : 'Listen again:'} ${word.text} /${word.ipa}/ — ${word.meaning}',
            points: 0,
            cascades: 0,
            bonus: 0,
            correct: correct,
          ),
        );
      case AdvanceLesson():
        if (checkpoint.finished || checkpoint.selectedSound == null) {
          throw const LearningInvalidCommandException();
        }
        return LessonMutation(
          snapshot: LegacyLessonCheckpoint(
            wordIndex: checkpoint.wordIndex + 1,
            selectedSound: null,
            finished: false,
          ),
        );
      case FinishLearningActivity():
        if (checkpoint.finished ||
            checkpoint.wordIndex != definition.items.length) {
          throw const LearningInvalidCommandException();
        }
        return LessonMutation(
          snapshot: LegacyLessonCheckpoint(
            wordIndex: checkpoint.wordIndex,
            selectedSound: null,
            finished: true,
          ),
        );
      case ObserveAssistance():
        return LessonMutation(snapshot: snapshot);
      case _:
        throw const LearningInvalidCommandException();
    }
  }
  throw const LearningInvalidCommandException();
}

LearningSourceItem _sourceForAlias(
    LearningActivityDefinition definition, String alias) {
  for (final item in definition.items) {
    if (item.sessionAlias == alias) return item;
  }
  // The session is validated against the authored alias order on start and
  // restore. Failing closed here prevents a saved alias becoming evidence.
  throw const LearningInvalidCommandException();
}
