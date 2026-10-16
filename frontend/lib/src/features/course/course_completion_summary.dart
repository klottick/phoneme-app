import '../../core/course/course_attempt.dart';
import '../../core/course/course_learning_registry.dart';
import '../../core/course/course_learning_state.dart';
import '../../core/course/french_course.dart';

/// A detached view of committed lesson completions for Home and Progress.
class CourseCompletionSummary {
  CourseCompletionSummary._({
    required Set<String> completedExistingLessonIds,
    required this.discoveryComplete,
  }) : completedExistingLessonIds =
            Set.unmodifiable(completedExistingLessonIds);

  factory CourseCompletionSummary.fromState({
    required CourseLearningState state,
    required LearningRegistry registry,
  }) {
    final currentRevisions = <String, int>{
      for (final lesson in frenchLessons)
        lesson.id: registry.require('lesson:${lesson.id}').contentRevision,
    };
    final existing = <String>{};
    var discoveryComplete = false;
    for (final completion in state.completions) {
      if (currentRevisions[completion.lessonId] != completion.contentRevision) {
        continue;
      }
      existing.add(completion.lessonId);
      if (completion.lessonId == 'en-fr-u-y' &&
          completion.policyKind == CompletionPolicyKind.discoveryThreshold) {
        discoveryComplete = true;
      }
    }
    return CourseCompletionSummary._(
      completedExistingLessonIds: existing,
      discoveryComplete: discoveryComplete,
    );
  }

  final Set<String> completedExistingLessonIds;
  final bool discoveryComplete;

  int get existingComplete => completedExistingLessonIds.length;
  int get existingTotal => frenchLessons.length;
  int get discoveryCompleteCount => discoveryComplete ? 1 : 0;
  int get discoveryTotal => 1;
}
