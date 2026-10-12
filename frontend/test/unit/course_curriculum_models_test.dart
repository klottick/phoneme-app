import 'package:flutter_test/flutter_test.dart';

import 'package:linguist/src/core/course/course_exercise.dart';
import 'package:linguist/src/core/course/course_curriculum.dart';

void main() {
  group('subtype kind and skill', () {
    test('listening choice is a listening skill listeningChoice', () {
      final exercise = _listeningExercise();
      expect(exercise.kind, ExerciseKind.listeningChoice);
      expect(exercise.skill, SkillDimension.listening);
    });

    test('spelling choice is a spelling skill spellingChoice', () {
      final exercise = _spellingExercise();
      expect(exercise.kind, ExerciseKind.spellingChoice);
      expect(exercise.skill, SkillDimension.spelling);
    });

    test('sentence hunt is a listening skill sentenceHunt', () {
      final exercise = _sentenceHuntExercise();
      expect(exercise.kind, ExerciseKind.sentenceHunt);
      expect(exercise.skill, SkillDimension.listening);
    });

    test('read aloud is a speaking skill readAloud', () {
      final exercise = _readAloudExercise();
      expect(exercise.kind, ExerciseKind.readAloud);
      expect(exercise.skill, SkillDimension.speaking);
    });
  });

  group('scalar validation', () {
    test('empty listening choice id is rejected', () {
      expect(() => _listeningExercise(id: ''), throwsArgumentError);
    });

    test('blank audio reference id is rejected', () {
      expect(
        () => CourseAudioReference(
          id: ' ',
          kind: AudioReferenceKind.word,
          spokenText: 'tout',
        ),
        throwsArgumentError,
      );
    });

    test('blank spelling option text is rejected', () {
      expect(
        () => SpellingOption(id: 'opt-1', text: ''),
        throwsArgumentError,
      );
    });

    test('blank sentence token text is rejected', () {
      expect(
        () => SentenceToken(id: 'tok-1', text: ' ', phonemes: ['y']),
        throwsArgumentError,
      );
    });

    test('blank node title is rejected', () {
      expect(
        () => CourseNode(
          id: 'test-node',
          title: '  ',
          kind: CourseNodeKind.lesson,
          stage: CourseStage.hear,
          status: ContentStatus.authored,
          optional: false,
          prerequisiteIds: [],
          sectionIds: [],
          targetSounds: [],
        ),
        throwsArgumentError,
      );
    });

    test('blank section explanation is rejected', () {
      expect(() => _section(explanation: ''), throwsArgumentError);
    });

    test('blank phoneme coverage sound is rejected', () {
      expect(
        () => PhonemeCoverage(
          sound: ' ',
          discoveryStatus: ContentStatus.planned,
          practiceExerciseIds: [],
        ),
        throwsArgumentError,
      );
    });

    test('empty curriculum course id is rejected', () {
      expect(
        () => CourseCurriculum(
          courseId: '',
          revision: 1,
          nodes: [],
          sections: [],
          exercises: [],
          sentences: [],
          audioReferences: [],
          phonemeCoverage: [],
        ),
        throwsArgumentError,
      );
    });

    test('blank read aloud prompt text is rejected', () {
      expect(() => _readAloudExercise(promptText: ' '), throwsArgumentError);
    });

    test('blank spelling target sound is rejected', () {
      expect(
        () => SpellingChoiceExercise(
          id: 'test-spelling',
          sectionId: 'test-section',
          audioRefId: 'fr-word-bateau',
          purpose: ContentPurpose.practice,
          reviewState: ContentReviewState.pending,
          wordId: 'bateau',
          targetSound: ' ',
          options: [
            SpellingOption(id: 'opt-1', text: 'eau'),
            SpellingOption(id: 'opt-2', text: 'eauu'),
          ],
          correctOptionId: 'opt-2',
        ),
        throwsArgumentError,
      );
    });

    test('nonpositive section revision and item count are rejected', () {
      expect(() => _section(contentRevision: 0), throwsArgumentError);
      expect(() => _section(contentRevision: -1), throwsArgumentError);
      expect(() => _section(requiredItemCount: 0), throwsArgumentError);
      expect(() => _section(requiredItemCount: -3), throwsArgumentError);
    });

    test('nonpositive curriculum revision is rejected', () {
      expect(() => _catalogue(revision: 0), throwsArgumentError);
      expect(() => _catalogue(revision: -1), throwsArgumentError);
    });

    test('legacyItemId may be absent', () {
      expect(_listeningExercise().legacyItemId, isNull);
    });

    test('legacyItemId must not be blank when supplied', () {
      expect(() => _listeningExercise(legacyItemId: ' '), throwsArgumentError);
    });

    test('legacyItemId is preserved verbatim', () {
      final exercise = _listeningExercise(legacyItemId: 'Legacy-1');
      expect(exercise.legacyItemId, 'Legacy-1');
    });

    test('nonblank ids keep surrounding whitespace verbatim', () {
      final exercise = _listeningExercise(id: ' test-u ');
      expect(exercise.id, ' test-u ');
    });

    test('empty collections stay constructible for fixtures', () {
      final node = _node(
        prerequisiteIds: [],
        sectionIds: [],
        targetSounds: [],
      );
      expect(node.prerequisiteIds, isEmpty);
      final exercise = _readAloudExercise(targetSounds: []);
      expect(exercise.targetSounds, isEmpty);
      final sentence = _sentence(tokens: []);
      expect(sentence.tokens, isEmpty);
    });
  });

  group('IDs are case-sensitive and verbatim', () {
    test('lookups distinguish ids by case', () {
      final exercise = _listeningExercise(id: 'Test-u');
      final catalogue = _catalogue(exercises: [exercise]);
      expect(catalogue.exerciseById('Test-u'), same(exercise));
      expect(catalogue.exerciseById('test-u'), isNull);
      expect(catalogue.exerciseById('TEST-U'), isNull);
    });
  });

  group('mutable input collections are detached', () {
    test('choices detach from a mutable input list', () {
      final List<String> inputChoices = ['u', 'y'];
      final exercise = _listeningExercise(choices: inputChoices);
      inputChoices
        ..clear()
        ..add('i');
      expect(exercise.choices, ['u', 'y']);
      expect(() => exercise.choices.add('i'), throwsUnsupportedError);
    });

    test('spelling options detach from a mutable input list', () {
      final options = [
        SpellingOption(id: 'opt-1', text: 'eau'),
        SpellingOption(id: 'opt-2', text: 'eauu'),
      ];
      final exercise = _spellingExercise(options: options);
      options
        ..clear()
        ..add(SpellingOption(id: 'opt-3', text: 'zz'));
      expect(exercise.options.length, 2);
      expect(exercise.options[0].text, 'eau');
      expect(
          () => exercise.options.add(SpellingOption(id: 'opt-3', text: 'zz')),
          throwsUnsupportedError);
    });

    test('token phonemes detach from a mutable input list', () {
      final List<String> inputPhonemes = ['y'];
      final token =
          SentenceToken(id: 'tok-1', text: 'Tu', phonemes: inputPhonemes);
      inputPhonemes
        ..clear()
        ..add('z');
      expect(token.phonemes, ['y']);
      expect(() => token.phonemes.add('z'), throwsUnsupportedError);
    });

    test('node prerequisites detach from a mutable input list', () {
      final List<String> inputPrerequisites = ['en-fr-u-y'];
      final node = _node(prerequisiteIds: inputPrerequisites);
      inputPrerequisites
        ..clear()
        ..add('en-fr-other');
      expect(node.prerequisiteIds, ['en-fr-u-y']);
      expect(() => node.prerequisiteIds.add('en-fr-other'),
          throwsUnsupportedError);
    });

    test('catalogue sections detach from a mutable input list', () {
      final section1 = _section(id: 'sec-1');
      final section2 = _section(id: 'sec-2');
      final List<CourseSection> inputSections = [section1, section2];
      final catalogue = _catalogue(sections: inputSections);
      inputSections
        ..clear()
        ..add(_section(id: 'sec-3'));
      expect(catalogue.sections, [section1, section2]);
      expect(() => catalogue.sections.add(_section(id: 'sec-4')),
          throwsUnsupportedError);
    });

    test('catalogue exercises detach from a mutable input list', () {
      final exercises = [
        _listeningExercise(id: 'ex-1'),
        _listeningExercise(id: 'ex-2')
      ];
      final catalogue = _catalogue(exercises: exercises);
      exercises.clear();
      expect(catalogue.exercises.length, 2);
      expect(catalogue.exercises.first.id, 'ex-1');
      expect(() => catalogue.exercises.add(_listeningExercise(id: 'ex-3')),
          throwsUnsupportedError);
    });

    test('catalogue sentences detach from a mutable input list', () {
      final sentences = [
        _sentence(id: 'sent-1'),
        _sentence(id: 'sent-2'),
      ];
      final catalogue = _catalogue(sentences: sentences);
      sentences.clear();
      expect(catalogue.sentences.length, 2);
      expect(catalogue.sentences.first.id, 'sent-1');
      expect(() => catalogue.sentences.add(_sentence(id: 'sent-3')),
          throwsUnsupportedError);
    });

    test('catalogue audio references detach from a mutable input list', () {
      final audioReferences = [
        _audioReference(id: 'audio-1'),
        _audioReference(id: 'audio-2'),
      ];
      final catalogue = _catalogue(audioReferences: audioReferences);
      audioReferences.clear();
      expect(catalogue.audioReferences.length, 2);
      expect(catalogue.audioReferences.first.id, 'audio-1');
      expect(
          () => catalogue.audioReferences.add(_audioReference(id: 'audio-3')),
          throwsUnsupportedError);
    });

    test('read aloud target sounds detach from a mutable input list', () {
      final List<String> inputTargetSounds = ['o', 'u'];
      final exercise = _readAloudExercise(targetSounds: inputTargetSounds);
      inputTargetSounds
        ..clear()
        ..add('i');
      expect(exercise.targetSounds, ['o', 'u']);
      expect(() => exercise.targetSounds.add('i'), throwsUnsupportedError);
    });

    test('sentence tokens detach, including nested phonemes', () {
      final List<String> inputPhonemes = ['y'];
      final token =
          SentenceToken(id: 'tok-1', text: 'Tu', phonemes: inputPhonemes);
      final List<SentenceToken> inputTokens = [token];
      final sentence = _sentence(tokens: inputTokens);
      inputPhonemes
        ..clear()
        ..add('z');
      inputTokens
        ..clear()
        ..add(SentenceToken(id: 'tok-2', text: 'zz', phonemes: ['z']));
      expect(sentence.tokens, [token]);
      expect(sentence.tokens.first.phonemes, ['y']);
      expect(
          () => sentence.tokens
              .add(SentenceToken(id: 'tok-2', text: 'zz', phonemes: ['z'])),
          throwsUnsupportedError);
      expect(() => sentence.tokens.first.phonemes.add('z'),
          throwsUnsupportedError);
    });

    test('node section ids detach from a mutable input list', () {
      final List<String> inputSectionIds = ['sec-1'];
      final node = _node(sectionIds: inputSectionIds);
      inputSectionIds
        ..clear()
        ..add('sec-2');
      expect(node.sectionIds, ['sec-1']);
      expect(() => node.sectionIds.add('sec-2'), throwsUnsupportedError);
    });

    test('node target sounds detach from a mutable input list', () {
      final List<String> inputTargetSounds = ['u', 'y'];
      final node = _node(targetSounds: inputTargetSounds);
      inputTargetSounds
        ..clear()
        ..add('i');
      expect(node.targetSounds, ['u', 'y']);
      expect(() => node.targetSounds.add('i'), throwsUnsupportedError);
    });

    test('section exercise ids detach from a mutable input list', () {
      final List<String> inputExerciseIds = ['ex-1', 'ex-2'];
      final section = _section(exerciseIds: inputExerciseIds);
      inputExerciseIds
        ..clear()
        ..add('ex-3');
      expect(section.exerciseIds, ['ex-1', 'ex-2']);
      expect(() => section.exerciseIds.add('ex-3'), throwsUnsupportedError);
    });

    test('phoneme coverage practice ids detach from a mutable input list', () {
      final List<String> inputPracticeExerciseIds = ['ex-u-1'];
      final coverage = PhonemeCoverage(
        sound: 'u',
        discoveryStatus: ContentStatus.authored,
        practiceExerciseIds: inputPracticeExerciseIds,
      );
      inputPracticeExerciseIds
        ..clear()
        ..add('ex-u-2');
      expect(coverage.practiceExerciseIds, ['ex-u-1']);
      expect(() => coverage.practiceExerciseIds.add('ex-u-2'),
          throwsUnsupportedError);
    });

    test('catalogue nodes detach from a mutable input list', () {
      final node1 = _node(id: 'node-1');
      final node2 = _node(id: 'node-2');
      final List<CourseNode> inputNodes = [node1, node2];
      final catalogue = _catalogue(nodes: inputNodes);
      inputNodes
        ..clear()
        ..add(_node(id: 'node-3'));
      expect(catalogue.nodes, [node1, node2]);
      expect(() => catalogue.nodes.add(_node(id: 'node-4')),
          throwsUnsupportedError);
    });

    test('catalogue phoneme coverage detaches from a mutable input list', () {
      final List<PhonemeCoverage> inputCoverage = [
        _coverage(sound: 'u'),
        _coverage(sound: 'y'),
      ];
      final catalogue = _catalogue(phonemeCoverage: inputCoverage);
      inputCoverage
        ..clear()
        ..add(_coverage(sound: 'i'));
      expect(catalogue.phonemeCoverage.length, 2);
      expect(catalogue.phonemeCoverage.first.sound, 'u');
      expect(() => catalogue.phonemeCoverage.add(_coverage(sound: 'o')),
          throwsUnsupportedError);
    });

    test('catalogue deep nesting detaches options, tokens and phonemes', () {
      final option1 = SpellingOption(id: 'opt-1', text: 'eau');
      final List<SpellingOption> inputOptions = [option1];
      final exercise = SpellingChoiceExercise(
        id: 'ex-1',
        sectionId: 'sec-1',
        audioRefId: 'fr-word-bateau',
        purpose: ContentPurpose.practice,
        reviewState: ContentReviewState.pending,
        wordId: 'bateau',
        targetSound: 'o',
        options: inputOptions,
        correctOptionId: 'opt-1',
      );
      final List<String> inputPhonemes = ['y'];
      final token =
          SentenceToken(id: 'tok-1', text: 'Tu', phonemes: inputPhonemes);
      final List<SentenceToken> inputTokens = [token];
      final sentence = CourseSentence(
        id: 'sent-1',
        text: 'Tu as un jouet.',
        audioRefId: 'fr-word-tout',
        tokens: inputTokens,
        reviewState: ContentReviewState.existingCurated,
      );
      final List<CourseExercise> inputExercises = [exercise];
      final section1 = _section(id: 'sec-1', exerciseIds: ['ex-1']);
      final List<CourseSection> inputSections = [section1];
      final node1 = _node(id: 'node-1', sectionIds: ['sec-1']);
      final List<CourseNode> inputNodes = [node1];
      final catalogue = CourseCurriculum(
        courseId: 'deep-course',
        revision: 1,
        nodes: inputNodes,
        sections: inputSections,
        exercises: inputExercises,
        sentences: [sentence],
        audioReferences: [_audioReference(id: 'fr-word-tout')],
        phonemeCoverage: [],
      );
      // Mutate every level of the source tree afterward.
      inputPhonemes
        ..clear()
        ..add('z');
      inputTokens
        ..clear()
        ..add(SentenceToken(id: 'tok-2', text: 'zz', phonemes: ['z']));
      inputOptions
        ..clear()
        ..add(SpellingOption(id: 'opt-2', text: 'zz'));
      inputExercises.clear();
      inputSections.clear();
      inputNodes
        ..clear()
        ..add(_node(id: 'node-2', targetSounds: ['i']));
      // The exposed nested tree is unchanged.
      expect(catalogue.exercises, [same(exercise)]);
      expect(catalogue.sections, [section1]);
      expect(catalogue.nodes, [node1]);
      final SpellingChoiceExercise exposedExercise =
          catalogue.exercises.first as SpellingChoiceExercise;
      expect(exposedExercise.options, [option1]);
      expect(catalogue.sentences.first.tokens, [token]);
      expect(catalogue.sentences.first.tokens.first.phonemes, ['y']);
      // Exposed mutation is rejected at every nesting level.
      expect(
          () => exposedExercise.options
              .add(SpellingOption(id: 'opt-2', text: 'zz')),
          throwsUnsupportedError);
      expect(() => catalogue.nodes.first.sectionIds.add('sec-2'),
          throwsUnsupportedError);
      expect(
          () => catalogue.sentences.first.tokens
              .add(SentenceToken(id: 'tok-2', text: 'zz', phonemes: ['z'])),
          throwsUnsupportedError);
      expect(() => catalogue.sentences.first.tokens.first.phonemes.add('z'),
          throwsUnsupportedError);
    });
  });

  group('lookups keep duplicates discoverable', () {
    test('unique lookups return the exact matching record', () {
      final node = _node(id: 'node-1');
      final section = _section(id: 'sec-1');
      final exercise = _listeningExercise(id: 'ex-1');
      final sentence = _sentence(id: 'sent-1');
      final audio = _audioReference(id: 'audio-1');
      final catalogue = _catalogue(
        nodes: [node],
        sections: [section],
        exercises: [exercise],
        sentences: [sentence],
        audioReferences: [audio],
      );
      expect(catalogue.nodeById('node-1'), same(node));
      expect(catalogue.sectionById('sec-1'), same(section));
      expect(catalogue.exerciseById('ex-1'), same(exercise));
      expect(catalogue.sentenceById('sent-1'), same(sentence));
      expect(catalogue.audioReferenceById('audio-1'), same(audio));
    });

    test('absent ids are null in all five namespaces', () {
      final catalogue = _catalogue();
      expect(catalogue.nodeById('missing'), isNull);
      expect(catalogue.sectionById('missing'), isNull);
      expect(catalogue.exerciseById('missing'), isNull);
      expect(catalogue.sentenceById('missing'), isNull);
      expect(catalogue.audioReferenceById('missing'), isNull);
    });

    test('duplicate ids stay constructible and hide no list entry', () {
      final duplicateCatalogue = _duplicateCatalogue();
      expect(duplicateCatalogue.exerciseById('test-u'), isNull);
      expect(duplicateCatalogue.exercises.length, 2);
      expect(duplicateCatalogue.nodeById('dup'), isNull);
      expect(duplicateCatalogue.nodes.length, 2);
      expect(duplicateCatalogue.sectionById('dup'), isNull);
      expect(duplicateCatalogue.sections.length, 2);
      expect(duplicateCatalogue.sentenceById('dup'), isNull);
      expect(duplicateCatalogue.sentences.length, 2);
      expect(duplicateCatalogue.audioReferenceById('dup'), isNull);
      expect(duplicateCatalogue.audioReferences.length, 2);
    });
  });
}

CourseCurriculum _duplicateCatalogue() {
  return _catalogue(
    nodes: [_node(id: 'dup'), _node(id: 'dup')],
    sections: [_section(id: 'dup'), _section(id: 'dup')],
    exercises: [
      _listeningExercise(id: 'test-u'),
      _listeningExercise(id: 'test-u'),
    ],
    sentences: [_sentence(id: 'dup'), _sentence(id: 'dup')],
    audioReferences: [
      _audioReference(id: 'dup'),
      _audioReference(id: 'dup'),
    ],
  );
}

CourseCurriculum _catalogue({
  int revision = 1,
  List<CourseNode>? nodes,
  List<CourseSection>? sections,
  List<CourseExercise>? exercises,
  List<CourseSentence>? sentences,
  List<CourseAudioReference>? audioReferences,
  List<PhonemeCoverage>? phonemeCoverage,
}) {
  return CourseCurriculum(
    courseId: 'test-course',
    revision: revision,
    nodes: nodes ?? [_node()],
    sections: sections ?? [_section()],
    exercises: exercises ?? [_listeningExercise()],
    sentences: sentences ?? [_sentence()],
    audioReferences: audioReferences ?? [_audioReference()],
    phonemeCoverage: phonemeCoverage ?? [],
  );
}

PhonemeCoverage _coverage({
  String sound = 'u',
  List<String> practiceExerciseIds = const ['ex-u-1'],
}) {
  return PhonemeCoverage(
    sound: sound,
    discoveryStatus:
        sound == 'u' ? ContentStatus.authored : ContentStatus.planned,
    practiceExerciseIds: practiceExerciseIds,
  );
}

CourseAudioReference _audioReference({String id = 'fr-word-tout'}) {
  return CourseAudioReference(
    id: id,
    kind: AudioReferenceKind.word,
    spokenText: 'tout',
  );
}

CourseSentence _sentence({
  String id = 'test-sentence',
  List<SentenceToken>? tokens,
}) {
  return CourseSentence(
    id: id,
    text: 'Tu as un jouet.',
    audioRefId: 'fr-word-tout',
    tokens: tokens ??
        [
          SentenceToken(id: 'tok-1', text: 'Tu', phonemes: ['y']),
          SentenceToken(id: 'tok-2', text: 'jouet', phonemes: ['z', 'u']),
        ],
    reviewState: ContentReviewState.existingCurated,
  );
}

CourseNode _node({
  String id = 'test-node',
  List<String>? prerequisiteIds,
  List<String>? sectionIds,
  List<String>? targetSounds,
}) {
  return CourseNode(
    id: id,
    title: 'Test node',
    kind: CourseNodeKind.lesson,
    stage: CourseStage.hear,
    status: ContentStatus.authored,
    optional: false,
    prerequisiteIds: prerequisiteIds ?? ['en-fr-u-y'],
    sectionIds: sectionIds ?? ['test-section'],
    targetSounds: targetSounds ?? ['u', 'y'],
  );
}

CourseSection _section({
  String id = 'test-section',
  String explanation = 'Test explanation.',
  int contentRevision = 1,
  int requiredItemCount = 1,
  List<String>? exerciseIds,
}) {
  return CourseSection(
    id: id,
    nodeId: 'test-node',
    title: 'Test section',
    explanation: explanation,
    contentRevision: contentRevision,
    exerciseIds: exerciseIds ?? ['test-u'],
    requiredItemCount: requiredItemCount,
  );
}

ListeningChoiceExercise _listeningExercise({
  String id = 'test-u',
  List<String>? choices,
  String? legacyItemId,
}) {
  return ListeningChoiceExercise(
    id: id,
    sectionId: 'test-section',
    audioRefId: 'fr-word-tout',
    purpose: ContentPurpose.practice,
    reviewState: ContentReviewState.existingCurated,
    wordId: 'tout',
    expectedSound: 'u',
    choices: choices ?? ['u', 'y'],
    legacyItemId: legacyItemId,
  );
}

SpellingChoiceExercise _spellingExercise({List<SpellingOption>? options}) {
  return SpellingChoiceExercise(
    id: 'test-spelling',
    sectionId: 'test-section',
    audioRefId: 'fr-word-bateau',
    purpose: ContentPurpose.practice,
    reviewState: ContentReviewState.pending,
    wordId: 'bateau',
    targetSound: 'o',
    options: options ??
        [
          SpellingOption(id: 'opt-1', text: 'eau'),
          SpellingOption(id: 'opt-2', text: 'eauu'),
        ],
    correctOptionId: 'opt-2',
  );
}

SentenceHuntExercise _sentenceHuntExercise() {
  return SentenceHuntExercise(
    id: 'test-hunt',
    sectionId: 'test-section',
    audioRefId: 'fr-sentence-1',
    purpose: ContentPurpose.practice,
    reviewState: ContentReviewState.pending,
    sentenceId: 'test-sentence',
    targetSound: 'o',
  );
}

ReadAloudExercise _readAloudExercise({
  String promptText = 'Dis bonjour.',
  List<String>? targetSounds,
}) {
  return ReadAloudExercise(
    id: 'test-read',
    sectionId: 'test-section',
    audioRefId: 'fr-para-1',
    purpose: ContentPurpose.practice,
    reviewState: ContentReviewState.pending,
    promptText: promptText,
    targetSounds: targetSounds ?? ['o'],
  );
}
