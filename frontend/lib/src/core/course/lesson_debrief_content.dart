import 'course_curriculum.dart';
import 'course_exercise.dart';
import 'lesson_section.dart';

class LessonTeachingNote {
  const LessonTeachingNote(
      {required this.sectionId, required this.exerciseId, required this.text});
  final String sectionId;
  final String exerciseId;
  final String text;
}

class LessonTeachingDiagnostic {
  const LessonTeachingDiagnostic({required this.code, required this.recordId});
  final String code;
  final String recordId;
}

class LessonTeachingValidationException implements Exception {
  LessonTeachingValidationException(List<LessonTeachingDiagnostic> diagnostics)
      : diagnostics = List.unmodifiable(diagnostics);
  final List<LessonTeachingDiagnostic> diagnostics;
}

List<LessonTeachingDiagnostic> validateLessonDebriefContent(
    CourseCurriculum curriculum,
    {required String lessonId,
    required List<LessonTeachingNote> notes}) {
  final LessonSection section;
  try {
    section = LessonSection.fromCurriculum(curriculum, lessonId: lessonId);
  } catch (_) {
    return List.unmodifiable(
        [LessonTeachingDiagnostic(code: 'source.invalid', recordId: lessonId)]);
  }
  final diagnostics = <LessonTeachingDiagnostic>[];
  final ids = <String>{};
  for (final note in notes) {
    final exercise = curriculum.exerciseById(note.exerciseId);
    if (!ids.add(note.exerciseId)) {
      diagnostics.add(LessonTeachingDiagnostic(
          code: 'note.duplicate', recordId: note.exerciseId));
    }
    if (note.text.trim().isEmpty) {
      diagnostics.add(LessonTeachingDiagnostic(
          code: 'note.blank', recordId: note.exerciseId));
    }
    if (exercise == null) {
      diagnostics.add(LessonTeachingDiagnostic(
          code: 'note.unknownExercise', recordId: note.exerciseId));
    }
    if (note.sectionId != sectionIdFor(curriculum, lessonId) ||
        (exercise != null && exercise.sectionId != note.sectionId)) {
      diagnostics.add(LessonTeachingDiagnostic(
          code: 'note.sectionMismatch', recordId: note.exerciseId));
    }
  }
  for (final item in section.items) {
    final exercise = curriculum.exercises
        .where((e) => e is ListeningChoiceExercise && e.legacyItemId == item.id)
        .first;
    if (!ids.contains(exercise.id)) {
      diagnostics.add(LessonTeachingDiagnostic(
          code: 'note.missing', recordId: exercise.id));
    }
  }
  return List.unmodifiable(diagnostics);
}

String? sectionIdFor(CourseCurriculum curriculum, String lessonId) {
  final node = curriculum.nodeById(lessonId);
  return node?.sectionIds.length == 1 ? node!.sectionIds.single : null;
}

class LessonDebriefEntry {
  const LessonDebriefEntry(
      {required this.itemId, required this.word, required this.text});
  final String itemId;
  final String word;
  final String text;
}

class LessonDebriefContent {
  LessonDebriefContent._(
      {required this.lessonId,
      required this.contentRevision,
      required List<LessonDebriefEntry> entries})
      : entries = List.unmodifiable(entries);
  final String lessonId;
  final int contentRevision;
  final List<LessonDebriefEntry> entries;

  factory LessonDebriefContent.fromCurriculum(CourseCurriculum curriculum,
      {required String lessonId, required List<LessonTeachingNote> notes}) {
    final diagnostics = validateLessonDebriefContent(curriculum,
        lessonId: lessonId, notes: notes);
    if (diagnostics.isNotEmpty) {
      throw LessonTeachingValidationException(diagnostics);
    }
    final section =
        LessonSection.fromCurriculum(curriculum, lessonId: lessonId);
    final byId = {for (final note in notes) note.exerciseId: note};
    final entries = <LessonDebriefEntry>[];
    for (final item in section.items) {
      final exercise = curriculum.exercises
          .where(
              (e) => e is ListeningChoiceExercise && e.legacyItemId == item.id)
          .single as ListeningChoiceExercise;
      entries.add(LessonDebriefEntry(
          itemId: exercise.legacyItemId!,
          word: exercise.wordId,
          text: byId[exercise.id]!.text));
    }
    return LessonDebriefContent._(
        lessonId: lessonId,
        contentRevision: section.contentRevision,
        entries: entries);
  }

  List<LessonDebriefEntry> forUnresolved(Iterable<String> itemIds) {
    final requested = itemIds.toList();
    if (requested.toSet().length != requested.length ||
        requested.any((id) => !entries.any((e) => e.itemId == id))) {
      throw ArgumentError('Unknown or duplicate item alias');
    }
    return List.unmodifiable(
        entries.where((e) => requested.contains(e.itemId)));
  }
}
