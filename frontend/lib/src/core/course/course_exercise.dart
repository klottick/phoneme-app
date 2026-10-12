/// Immutable exercise, sentence and audio-reference contracts for the
/// FR-01 catalogue.
///
/// This module is pure Dart: it imports no French content, providers,
/// storage, widgets or audio plugins. Only local scalar misuse throws
/// `ArgumentError` (blank required strings, blank supplied aliases);
/// relationship rules — membership, distinctness, answer keys — belong to
/// the content validator, so invalid fixtures remain constructible.
/// Collections are detached from caller state and exposed unmodifiable.
library;

/// The skill axis an exercise targets.
enum SkillDimension { listening, spelling, speaking }

/// The concrete exercise shapes available in FR-01.
enum ExerciseKind {
  listeningChoice,
  spellingChoice,
  sentenceHunt,
  readAloud,
}

/// Intended use of an authored item.
enum ContentPurpose { practice, assessment }

/// Human review state of an authored item.
enum ContentReviewState { existingCurated, pending, reviewed }

/// The kind of audio a reference declares.
enum AudioReferenceKind { word, sound, sentence, paragraph }

/// Rejects empty and all-whitespace strings without touching valid ones.
String _nonblank(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'must be a nonblank string');
  }
  return value;
}

/// Rejects a blank supplied nullable alias; absent (null) is allowed.
String? _nonblankIfPresent(String? value, String name) {
  if (value == null) return null;
  return _nonblank(value, name);
}

/// Sealed base for the four FR-01 exercise kinds. [kind] and [skill] are
/// fixed by the concrete subtype; callers can never supply them.
sealed class CourseExercise {
  CourseExercise({
    required String id,
    required String sectionId,
    required String audioRefId,
    required this.purpose,
    required this.reviewState,
  })  : id = _nonblank(id, 'id'),
        sectionId = _nonblank(sectionId, 'sectionId'),
        audioRefId = _nonblank(audioRefId, 'audioRefId');

  final String id;
  final String sectionId;
  final String audioRefId;
  final ContentPurpose purpose;
  final ContentReviewState reviewState;

  /// Fixed by the subtype; never caller supplied.
  ExerciseKind get kind;

  /// Fixed by the subtype; never caller supplied.
  SkillDimension get skill;
}

/// Choose the target sound of a word from ordered phoneme labels.
final class ListeningChoiceExercise extends CourseExercise {
  ListeningChoiceExercise({
    required super.id,
    required super.sectionId,
    required super.audioRefId,
    required super.purpose,
    required super.reviewState,
    required String wordId,
    required String expectedSound,
    required List<String> choices,
    String? legacyItemId,
  })  : wordId = _nonblank(wordId, 'wordId'),
        expectedSound = _nonblank(expectedSound, 'expectedSound'),
        choices = List.unmodifiable(choices),
        legacyItemId = _nonblankIfPresent(legacyItemId, 'legacyItemId');

  final String wordId;

  /// The target phoneme label, without slash decoration.
  final String expectedSound;

  /// Ordered phoneme labels, without slash decoration.
  final List<String> choices;

  /// Pilot saved-ID compatibility alias; not an alternative catalogue
  /// identity. May be absent, but must not be blank when supplied.
  final String? legacyItemId;

  @override
  ExerciseKind get kind => ExerciseKind.listeningChoice;

  @override
  SkillDimension get skill => SkillDimension.listening;
}

/// One spelling option value.
final class SpellingOption {
  SpellingOption({required String id, required String text})
      : id = _nonblank(id, 'id'),
        text = _nonblank(text, 'text');

  final String id;
  final String text;
}

/// Choose the option with the spelling of the word's explicit target sound.
final class SpellingChoiceExercise extends CourseExercise {
  SpellingChoiceExercise({
    required super.id,
    required super.sectionId,
    required super.audioRefId,
    required super.purpose,
    required super.reviewState,
    required String wordId,
    required String targetSound,
    required List<SpellingOption> options,
    required String correctOptionId,
  })  : wordId = _nonblank(wordId, 'wordId'),
        targetSound = _nonblank(targetSound, 'targetSound'),
        options = List.unmodifiable(options),
        correctOptionId = _nonblank(correctOptionId, 'correctOptionId');

  final String wordId;

  /// The phoneme this task teaches, explicit and curated.
  final String targetSound;

  /// Ordered option values.
  final List<SpellingOption> options;

  /// The id of the single correct option, if any; validated downstream.
  final String correctOptionId;

  @override
  ExerciseKind get kind => ExerciseKind.spellingChoice;

  @override
  SkillDimension get skill => SkillDimension.spelling;
}

/// Locate a target sound inside a contextual sentence.
final class SentenceHuntExercise extends CourseExercise {
  SentenceHuntExercise({
    required super.id,
    required super.sectionId,
    required super.audioRefId,
    required super.purpose,
    required super.reviewState,
    required String sentenceId,
    required String targetSound,
  })  : sentenceId = _nonblank(sentenceId, 'sentenceId'),
        targetSound = _nonblank(targetSound, 'targetSound');

  final String sentenceId;

  /// The phoneme to find in the sentence tokens.
  final String targetSound;

  @override
  ExerciseKind get kind => ExerciseKind.sentenceHunt;

  @override
  SkillDimension get skill => SkillDimension.listening;
}

/// Read-aloud prompt contract; not a correctness key or validated grader.
final class ReadAloudExercise extends CourseExercise {
  ReadAloudExercise({
    required super.id,
    required super.sectionId,
    required super.audioRefId,
    required super.purpose,
    required super.reviewState,
    required String promptText,
    required List<String> targetSounds,
  })  : promptText = _nonblank(promptText, 'promptText'),
        targetSounds = List.unmodifiable(targetSounds);

  final String promptText;

  /// Phoneme labels the prompt should exercise.
  final List<String> targetSounds;

  @override
  ExerciseKind get kind => ExerciseKind.readAloud;

  @override
  SkillDimension get skill => SkillDimension.speaking;
}

/// One authored token within a sentence.
final class SentenceToken {
  SentenceToken({
    required String id,
    required String text,
    required List<String> phonemes,
  })  : id = _nonblank(id, 'id'),
        text = _nonblank(text, 'text'),
        phonemes = List.unmodifiable(phonemes);

  final String id;
  final String text;

  /// Full phoneme annotations; punctuation tokens may have an empty list.
  final List<String> phonemes;
}

/// One accepted contextual pronunciation, ordered under its audio reference.
final class CourseSentence {
  CourseSentence({
    required String id,
    required String text,
    required String audioRefId,
    required List<SentenceToken> tokens,
    required this.reviewState,
  })  : id = _nonblank(id, 'id'),
        text = _nonblank(text, 'text'),
        audioRefId = _nonblank(audioRefId, 'audioRefId'),
        tokens = List.unmodifiable(tokens);

  final String id;

  /// The exact authored sentence text; punctuation and spacing included.
  final String text;
  final String audioRefId;

  /// Ordered tokens, each appearing in order within [text].
  final List<SentenceToken> tokens;
  final ContentReviewState reviewState;
}

/// A stable audio content identity; does not declare recording existence.
final class CourseAudioReference {
  CourseAudioReference({
    required String id,
    required this.kind,
    required String spokenText,
  })  : id = _nonblank(id, 'id'),
        spokenText = _nonblank(spokenText, 'spokenText');

  final String id;
  final AudioReferenceKind kind;

  /// The exact spoken text this reference declares.
  final String spokenText;
}
