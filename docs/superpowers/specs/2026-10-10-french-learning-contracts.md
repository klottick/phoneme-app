# French learning contracts — FR-01 revision 1

Design authority: [approved FR-01 migration spec](2026-10-11-french-curriculum-design.md).
These exact signatures support the proposed execution plan. They become the
worker handoff after that plan is reviewed. Later evidence/audio/UI tickets still
require their own approved designs; this is not a contract for unimplemented APIs.

## Construction conventions

Every constructor below uses named `required` arguments unless a default or `?`
is explicitly shown. All exposed fields are final and have the corresponding
argument type. Collections are deeply detached/unmodifiable; objects inside
collections are immutable. Empty required scalar strings (including all-whitespace)
and nonpositive revision/count arguments throw ArgumentError, without normalizing
valid IDs/texts. Supplied nullable aliases must also be nonempty. Empty collections
are permitted for validator fixtures/planned nodes; relationship rules belong to
the validator. No copyWith, persistence JSON, reflection or generated code needed.

## course_exercise.dart

Enums are exactly those in the design: SkillDimension, ExerciseKind,
ContentPurpose, ContentReviewState, AudioReferenceKind.

```dart
// Sealed base: only these four final subtypes; constructors are public below.
// Common final fields: String id, sectionId, audioRefId;
// ContentPurpose purpose; ContentReviewState reviewState;
// Getters: ExerciseKind get kind; SkillDimension get skill;
sealed class CourseExercise { /* field/getter contract above */ }

ListeningChoiceExercise({required String id, required String sectionId,
  required String audioRefId, required ContentPurpose purpose,
  required ContentReviewState reviewState, required String wordId,
  required String expectedSound, required List<String> choices,
  String? legacyItemId});
SpellingChoiceExercise({required String id, required String sectionId,
  required String audioRefId, required ContentPurpose purpose,
  required ContentReviewState reviewState, required String wordId,
  required String targetSound, required List<SpellingOption> options,
  required String correctOptionId});
SentenceHuntExercise({required String id, required String sectionId,
  required String audioRefId, required ContentPurpose purpose,
  required ContentReviewState reviewState, required String sentenceId,
  required String targetSound});
ReadAloudExercise({required String id, required String sectionId,
  required String audioRefId, required ContentPurpose purpose,
  required ContentReviewState reviewState, required String promptText,
  required List<String> targetSounds});
SpellingOption({required String id, required String text});
SentenceToken({required String id, required String text,
  required List<String> phonemes});
CourseSentence({required String id, required String text,
  required String audioRefId, required List<SentenceToken> tokens,
  required ContentReviewState reviewState});
CourseAudioReference({required String id, required AudioReferenceKind kind,
  required String spokenText});
```

SpellingChoiceExercise exposes its choice list as `options`. The subtype getter
values are fixed by the approved spec; no caller-supplied skill/kind can conflict.

## course_curriculum.dart

Enums: CourseStage {hear, find, spell, assess}, CourseNodeKind {lesson, review,
game, articulation, assessment}, ContentStatus {authored, planned}.

```dart
CourseNode({required String id, required String title,
  required CourseNodeKind kind, required CourseStage stage,
  required ContentStatus status, required bool optional,
  required List<String> prerequisiteIds, required List<String> sectionIds,
  required List<String> targetSounds});
CourseSection({required String id, required String nodeId,
  required String title, required String explanation,
  required int contentRevision, required List<String> exerciseIds,
  required int requiredItemCount});
PhonemeCoverage({required String sound, required ContentStatus discoveryStatus,
  required List<String> practiceExerciseIds});
CourseCurriculum({required String courseId, required int revision,
  required List<CourseNode> nodes, required List<CourseSection> sections,
  required List<CourseExercise> exercises, required List<CourseSentence> sentences,
  required List<CourseAudioReference> audioReferences,
  required List<PhonemeCoverage> phonemeCoverage});
// Instance methods on CourseCurriculum; null means absent OR duplicate ID.
CourseNode? nodeById(String id);
CourseSection? sectionById(String id);
CourseExercise? exerciseById(String id);
CourseSentence? sentenceById(String id);
CourseAudioReference? audioReferenceById(String id);
```

## course_content_validator.dart

```dart
enum AudioResourceStatus { missing, practiceTts, reviewedRecording }
CourseContentDiagnostic({required String code, required String recordId,
  required String message, ContentPurpose? use});
CourseValidationReport({required List<CourseContentDiagnostic> errors,
  required List<CourseContentDiagnostic> readinessIssues});
// Report getter: bool get isStructurallyValid => errors.isEmpty;
CourseValidationReport validateCourseContent(CourseCurriculum curriculum, {
  required Map<String, List<String>> citationPhonemes,
  required Set<String> exposedWordIds,
  required Map<String, AudioResourceStatus> audioResources,
});
```

Errors have use=null; readiness issues have non-null use. No diagnostic aliases
or inferred grading scores. Deterministic order: structural namespaces, nodes,
sections, exercises, sentences, coverage; then readiness nodes, coverage,
exercises/sentences, audio references. Within each phase use authored list order;
skip checks whose required record is absent/ambiguous, but report independent
issues. Diagnostics repeat identically for identical inputs. Codes are frozen
by the task tables in the execution plan, not by message wording.

## French catalogue and pilot projection

Exports from french_course.dart, with final unmodifiable input maps/sets:

```dart
final CourseCurriculum frenchCurriculum;
final Map<String, List<String>> frenchCitationPhonemes;
final Set<String> frenchExposedWordIds;
final Map<String, AudioResourceStatus> frenchAudioResources;
final CourseValidationReport frenchCurriculumValidation;
```

French audio resources declare every legacy word's existing labeled practice-TTS
fallback, not whether the current device actually has a voice. The declaration
cannot remove reviewed-recording readiness warnings or silently enable an exam.
Legacy French exports are unchanged. Catalogue construction never imports
lesson_section.dart (no initialization cycle).

Additional constructor in lesson_section.dart:

```dart
factory LessonSection.fromCurriculum(CourseCurriculum curriculum,
    {required String lessonId});
```

This helper checks the shape needed to project one authored lesson/section of
practice listening choices: IDs, ownership, distinct aliases, consistent choices,
exact required count, expected sound in choices. Unsupported/dangling/ambiguous
input throws StateError, never a partial projection. Production additionally
checks frenchCurriculumValidation.isStructurallyValid before building the cached
pilot projection; resource readiness issues do not block existing practice.

The unchanged external bridge is frenchUySection and sectionForLesson(String):
only en-fr-u-y returns the cached section. Old saved item IDs, contentRevision 1
and session serialization version 1 remain unchanged. No general new routes.
