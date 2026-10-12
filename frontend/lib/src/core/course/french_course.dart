import 'course_content_validator.dart';
import 'course_curriculum.dart';
import 'course_exercise.dart';

class LanguageCourse {
  const LanguageCourse(
      this.id, this.sourceLanguage, this.targetLanguage, this.title);
  final String id, sourceLanguage, targetLanguage, title;
}

const frenchCourse =
    LanguageCourse('en-fr', 'en', 'fr', 'French for English speakers');

class CourseWord {
  const CourseWord(this.text, this.meaning, this.ipa, this.sounds, this.hint);
  final String text, meaning, ipa, hint;
  final List<String> sounds;
  bool contains(String sound) => sounds.contains(sound.replaceAll('/', ''));
}

// Citation pronunciations in contemporary metropolitan French. Membership is
// curated: spelling alone cannot determine whether a word contains a phoneme.
const frenchWords = [
  CourseWord('tout', 'all', 'tu', ['t', 'u'], 'ou'),
  CourseWord('rouge', 'red', 'ʁuʒ', ['ʁ', 'u', 'ʒ'], 'ou'),
  CourseWord('vous', 'you', 'vu', ['v', 'u'], 'ou'),
  CourseWord('doux', 'soft', 'du', ['d', 'u'], 'ou'),
  CourseWord('loup', 'wolf', 'lu', ['l', 'u'], 'ou'),
  CourseWord('soupe', 'soup', 'sup', ['s', 'u', 'p'], 'ou'),
  CourseWord('tu', 'you', 'ty', ['t', 'y'], 'u'),
  CourseWord('rue', 'street', 'ʁy', ['ʁ', 'y'], 'u'),
  CourseWord('lune', 'moon', 'lyn', ['l', 'y', 'n'], 'u'),
  CourseWord('jus', 'juice', 'ʒy', ['ʒ', 'y'], 'u'),
  CourseWord('mur', 'wall', 'myʁ', ['m', 'y', 'ʁ'], 'u'),
  CourseWord('plume', 'feather', 'plym', ['p', 'l', 'y', 'm'], 'u'),
  CourseWord('lit', 'bed', 'li', ['l', 'i'], 'i'),
  CourseWord('si', 'if', 'si', ['s', 'i'], 'i'),
  CourseWord('vite', 'quickly', 'vit', ['v', 'i', 't'], 'i'),
  CourseWord('île', 'island', 'il', ['i', 'l'], 'î'),
  CourseWord('beau', 'beautiful', 'bo', ['b', 'o'], 'eau'),
  CourseWord('mot', 'word', 'mo', ['m', 'o'], 'o'),
  CourseWord('eau', 'water', 'o', ['o'], 'eau'),
  CourseWord('dos', 'back', 'do', ['d', 'o'], 'o'),
  CourseWord('bon', 'good', 'bɔ̃', ['b', 'ɔ̃'], 'on'),
  CourseWord('nom', 'name', 'nɔ̃', ['n', 'ɔ̃'], 'om'),
  CourseWord('banc', 'bench', 'bɑ̃', ['b', 'ɑ̃'], 'an'),
  CourseWord('sans', 'without', 'sɑ̃', ['s', 'ɑ̃'], 'an'),
];

CourseWord wordByText(String text) =>
    frenchWords.firstWhere((w) => w.text == text);

class CourseLesson {
  const CourseLesson(
      this.id, this.title, this.explanation, this.sounds, this.words);
  final String id, title, explanation;
  final List<String> sounds, words;
}

const frenchLessons = [
  CourseLesson(
      'en-fr-vowels',
      'Keep French vowels steady',
      'English vowels often glide. In French, hold one steady mouth position. '
          'Compare lit /i/ and beau /o/: avoid adding an English-style “y” or “w” at the end. '
          'English comparisons are starting points, not exact equivalents.',
      ['i', 'o'],
      ['lit', 'beau', 'vite', 'mot']),
  CourseLesson(
      'en-fr-u-y',
      'Tu or tout?',
      'French /u/ in tout is close to the vowel in English “food”, but keep it steady. '
          'For /y/ in tu, hold your tongue as for /i/ and round your lips. '
          'English has no direct equivalent of /y/. French “ou” and “u” represent different sounds.',
      ['u', 'y'],
      ['tout', 'tu', 'rouge', 'rue', 'vous', 'lune']),
  CourseLesson(
      'en-fr-nasal',
      'Let vowels resonate',
      'Compare beau /bo/, bon /bɔ̃/ and banc /bɑ̃/. For nasal vowels, air passes '
          'through the nose as well as the mouth. Do not add an English /n/ at the end. '
          'The tilde marks a nasal vowel; these are different vowel sounds, not just different spellings.',
      ['o', 'ɔ̃', 'ɑ̃'],
      ['beau', 'bon', 'banc', 'nom', 'sans']),
  CourseLesson(
      'en-fr-r',
      'Meet the French R',
      'French /ʁ/ is made near the back of the mouth, unlike most English R sounds. '
          'Listen to rue and rouge; keep your tongue tip relaxed. French R varies by speaker—'
          'aim for comfortable, clear speech rather than forcing a harsh sound.',
      ['ʁ', 'u', 'y'],
      ['rue', 'rouge', 'mur']),
  CourseLesson(
      'en-fr-mix',
      'Mix your new sounds',
      'Listen first, then identify the vowel. Keep /u/ and /y/ distinct, hold vowels steady, '
          'and let nasal vowels resonate. Say the words and compare your recording with the reference.',
      ['u', 'y', 'i', 'o', 'ɔ̃', 'ɑ̃'],
      ['tout', 'tu', 'lit', 'beau', 'bon', 'banc']),
];

// ---------------------------------------------------------------------------
// FR-01 catalogue
//
// The [frenchCurriculum] is the sole author of the ten pilot exercise
// definitions; the live pilot section is projected from it. The legacy
// course/word/lesson exports above remain the values of record and are
// reused, never re-authorized: the pilot re-uses its lesson's title and
// explanation and the exercises derive from the existing [frenchWords].
// Planned stages and sounds stay explicit readiness issues, and the audio
// declarations assert only the labeled practice-TTS fallback, never device
// voice availability.
// ---------------------------------------------------------------------------

/// The ten pilot words with their expected sounds, in authored order: the
/// expected sounds alternate u/y.
const List<String> _frenchPilotWordIds = [
  'tout',
  'tu',
  'rouge',
  'rue',
  'vous',
  'lune',
  'doux',
  'jus',
  'loup',
  'mur',
];
const List<String> _frenchPilotExpectedSounds = [
  'u',
  'y',
  'u',
  'y',
  'u',
  'y',
  'u',
  'y',
  'u',
  'y',
];

/// The declared coverage inventory in the approved order: u, y, i, o, ɔ̃, ɑ̃, ʁ.
const List<String> _frenchCoverageSounds = ['u', 'y', 'i', 'o', 'ɔ̃', 'ɑ̃', 'ʁ'];

CourseLesson _pilotLesson() => frenchLessons.firstWhere(
      (CourseLesson lesson) => lesson.id == 'en-fr-u-y',
      orElse: () => throw StateError(
          'The pilot lesson en-fr-u-y is missing from the course.'),
    );

final List<CourseExercise> _frenchPilotExercises = [
  for (var i = 0; i < _frenchPilotWordIds.length; i++)
    ListeningChoiceExercise(
      id: 'en-fr-u-y-listening-${_frenchPilotWordIds[i]}',
      sectionId: 'en-fr-u-y-listening',
      audioRefId: 'fr-word-${_frenchPilotWordIds[i]}',
      purpose: ContentPurpose.practice,
      reviewState: ContentReviewState.existingCurated,
      wordId: _frenchPilotWordIds[i],
      expectedSound: _frenchPilotExpectedSounds[i],
      choices: const ['u', 'y'],
      legacyItemId: _frenchPilotWordIds[i],
    ),
];

final List<CourseSection> _frenchSections = [
  CourseSection(
    id: 'en-fr-u-y-listening',
    nodeId: 'en-fr-u-y',
    title: _pilotLesson().title,
    explanation: _pilotLesson().explanation,
    contentRevision: 1,
    exerciseIds: [
      for (final String word in _frenchPilotWordIds) 'en-fr-u-y-listening-$word',
    ],
    requiredItemCount: _frenchPilotWordIds.length,
  ),
];

final List<CourseNode> _frenchNodes = [
  CourseNode(
    id: 'en-fr-u-y',
    title: _pilotLesson().title,
    kind: CourseNodeKind.lesson,
    stage: CourseStage.hear,
    status: ContentStatus.authored,
    optional: false,
    prerequisiteIds: const [],
    sectionIds: const ['en-fr-u-y-listening'],
    targetSounds: const ['u', 'y'],
  ),
  // Optional planned side-quests: hear stage, no prerequisites, all seven
  // declared sounds reserved for their future content.
  CourseNode(
    id: 'en-fr-targeted-review',
    title: 'Targeted review',
    kind: CourseNodeKind.review,
    stage: CourseStage.hear,
    status: ContentStatus.planned,
    optional: true,
    prerequisiteIds: const [],
    sectionIds: const [],
    targetSounds: _frenchCoverageSounds,
  ),
  CourseNode(
    id: 'en-fr-games',
    title: 'Games',
    kind: CourseNodeKind.game,
    stage: CourseStage.hear,
    status: ContentStatus.planned,
    optional: true,
    prerequisiteIds: const [],
    sectionIds: const [],
    targetSounds: _frenchCoverageSounds,
  ),
  CourseNode(
    id: 'en-fr-articulation',
    title: 'Articulation coaching',
    kind: CourseNodeKind.articulation,
    stage: CourseStage.hear,
    status: ContentStatus.planned,
    optional: true,
    prerequisiteIds: const [],
    sectionIds: const [],
    targetSounds: _frenchCoverageSounds,
  ),
  // Planned required main stages with the approved prerequisite chain.
  CourseNode(
    id: 'en-fr-find-sounds',
    title: 'Find sounds in context',
    kind: CourseNodeKind.lesson,
    stage: CourseStage.find,
    status: ContentStatus.planned,
    optional: false,
    prerequisiteIds: const ['en-fr-u-y'],
    sectionIds: const [],
    targetSounds: _frenchCoverageSounds,
  ),
  CourseNode(
    id: 'en-fr-connect-spellings',
    title: 'Connect sounds and spellings',
    kind: CourseNodeKind.lesson,
    stage: CourseStage.spell,
    status: ContentStatus.planned,
    optional: false,
    prerequisiteIds: const ['en-fr-find-sounds'],
    sectionIds: const [],
    targetSounds: _frenchCoverageSounds,
  ),
  CourseNode(
    id: 'en-fr-checkpoint',
    title: 'Check your progress',
    kind: CourseNodeKind.assessment,
    stage: CourseStage.assess,
    status: ContentStatus.planned,
    optional: false,
    prerequisiteIds: const ['en-fr-connect-spellings'],
    sectionIds: const [],
    targetSounds: _frenchCoverageSounds,
  ),
];

final List<PhonemeCoverage> _frenchPhonemeCoverage = [
  PhonemeCoverage(
    sound: 'u',
    discoveryStatus: ContentStatus.authored,
    practiceExerciseIds: [
      for (var i = 0; i < _frenchPilotWordIds.length; i += 2)
        'en-fr-u-y-listening-${_frenchPilotWordIds[i]}',
    ],
  ),
  PhonemeCoverage(
    sound: 'y',
    discoveryStatus: ContentStatus.authored,
    practiceExerciseIds: [
      for (var i = 1; i < _frenchPilotWordIds.length; i += 2)
        'en-fr-u-y-listening-${_frenchPilotWordIds[i]}',
    ],
  ),
  for (var i = 2; i < _frenchCoverageSounds.length; i++)
    PhonemeCoverage(
      sound: _frenchCoverageSounds[i],
      discoveryStatus: ContentStatus.planned,
      practiceExerciseIds: const [],
    ),
];

/// Word audio identities for the entire legacy vocabulary: declared spoken
/// texts are the unchanged word texts, so games' future resource needs stay
/// visible. No reviewed recording is claimed.
final List<CourseAudioReference> _frenchWordAudioReferences = [
  for (final CourseWord word in frenchWords)
    CourseAudioReference(
      id: 'fr-word-${word.text}',
      kind: AudioReferenceKind.word,
      spokenText: word.text,
    ),
];

/// The immutable French curriculum: course `en-fr`, revision 1, one authored
/// pilot listening section, no sentences, no assessment content.
final CourseCurriculum frenchCurriculum = CourseCurriculum(
  courseId: frenchCourse.id,
  revision: 1,
  nodes: _frenchNodes,
  sections: _frenchSections,
  exercises: _frenchPilotExercises,
  sentences: const [],
  audioReferences: _frenchWordAudioReferences,
  phonemeCoverage: _frenchPhonemeCoverage,
);

Map<String, List<String>> _frenchCitationPhonemes() {
  final Map<String, List<String>> citationPhonemes =
      <String, List<String>>{};
  for (final CourseWord word in frenchWords) {
    citationPhonemes[word.text] = List.unmodifiable(word.sounds);
  }
  return Map.unmodifiable(citationPhonemes);
}

/// Curated citation phonemes for every legacy word (keyed by word text);
/// the membership a word exercise may be validated against.
final Map<String, List<String>> frenchCitationPhonemes =
    _frenchCitationPhonemes();

/// Every legacy word stays exposed: practice words and legacy game words, so
/// a known word never becomes a silent held-out assessment item.
final Set<String> frenchExposedWordIds = Set.unmodifiable({
  for (final CourseWord word in frenchWords) word.text,
});

/// Declared audio availability: each word carries the existing labeled
/// practice-TTS fallback. This is a resource declaration, not a claim that
/// the current device has a French voice, and it cannot silence missing
/// reviewed recordings or enable an exam.
final Map<String, AudioResourceStatus> frenchAudioResources = Map.unmodifiable({
  for (final CourseWord word in frenchWords)
    'fr-word-${word.text}': AudioResourceStatus.practiceTts,
});

/// Synchronous structural and readiness validation of the authored
/// catalogue, computed before the pilot bridge projects it.
final CourseValidationReport frenchCurriculumValidation =
    validateCourseContent(
  frenchCurriculum,
  citationPhonemes: frenchCitationPhonemes,
  exposedWordIds: frenchExposedWordIds,
  audioResources: frenchAudioResources,
);
