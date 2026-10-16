import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/features/course/exercises/listening_exercise_contract.dart';
import '../support/listening_comparison_harness.dart';

ListeningChoiceOption _option(String id, String label) =>
    ListeningChoiceOption(id: id, label: label);

SoundComparisonPrompt _comparison({
  String id = 'comparison',
  String instruction = 'Compare sounds',
  String a = 'ref-a',
  String b = 'ref-b',
}) =>
    SoundComparisonPrompt(
      id: id,
      instruction: instruction,
      sampleAReferenceId: a,
      sampleBReferenceId: b,
    );

void main() {
  test('choice option rejects blank id', () {
    expect(() => _option(' ', 'label'), throwsArgumentError);
  });

  test('choice option rejects blank label', () {
    expect(() => _option('id', '\t'), throwsArgumentError);
  });

  test('identification prompt rejects blank id', () {
    expect(
        () => ListeningChoicePrompt(
              id: '',
              instruction: 'Listen',
              choices: [_option('a', 'A'), _option('b', 'B')],
            ),
        throwsArgumentError);
  });

  test('identification prompt rejects blank instruction', () {
    expect(
        () => ListeningChoicePrompt(
              id: 'id',
              instruction: '  ',
              choices: [_option('a', 'A'), _option('b', 'B')],
            ),
        throwsArgumentError);
  });

  test('comparison prompt rejects blank id', () {
    expect(() => _comparison(id: '\n'), throwsArgumentError);
  });

  test('comparison prompt rejects blank instruction', () {
    expect(() => _comparison(instruction: ' '), throwsArgumentError);
  });

  test('comparison prompt rejects blank sample A reference', () {
    expect(() => _comparison(a: ' '), throwsArgumentError);
  });

  test('comparison prompt rejects blank sample B reference', () {
    expect(() => _comparison(b: '\t'), throwsArgumentError);
  });

  test('duplicate choice IDs are rejected independently of labels', () {
    expect(
        () => ListeningChoicePrompt(
              id: 'id',
              instruction: 'Listen',
              choices: [_option('same', 'A'), _option('same', 'B')],
            ),
        throwsArgumentError);
  });

  test('duplicate choice labels are rejected independently of IDs', () {
    expect(
        () => ListeningChoicePrompt(
              id: 'id',
              instruction: 'Listen',
              choices: [_option('a', 'same'), _option('b', 'same')],
            ),
        throwsArgumentError);
  });

  test('zero identification choices are rejected', () {
    expect(
        () => ListeningChoicePrompt(
              id: 'id',
              instruction: 'Listen',
              choices: const [],
            ),
        throwsArgumentError);
  });

  test('one identification choice is rejected', () {
    expect(
        () => ListeningChoicePrompt(
              id: 'id',
              instruction: 'Listen',
              choices: [_option('a', 'A')],
            ),
        throwsArgumentError);
  });

  test('identification choices detach and expose an unmodifiable list', () {
    final original = [_option('a', 'A'), _option('b', 'B')];
    final prompt = ListeningChoicePrompt(
        id: 'id', instruction: 'Listen', choices: original);
    original.clear();
    expect(prompt.choices.map((choice) => choice.id), ['a', 'b']);
    expect(() => prompt.choices.clear(), throwsUnsupportedError);
  });

  test('three opaque phoneme labels retain exact order and spelling', () {
    final prompt = ListeningChoicePrompt(
      id: 'id',
      instruction: 'Listen',
      choices: [
        _option('one', '/ʁ/'),
        _option('two', '/v/'),
        _option('three', '/ɔ̃/')
      ],
    );
    expect(
        prompt.choices.map((choice) => choice.label), ['/ʁ/', '/v/', '/ɔ̃/']);
  });

  test('playing without busy is rejected', () {
    expect(() => ListeningExerciseState(playing: true), throwsArgumentError);
  });

  test('feedback on unanswered state is rejected', () {
    expect(() => ListeningExerciseState(feedback: ListeningFeedback.correct),
        throwsArgumentError);
  });

  test('answered state may omit feedback', () {
    expect(ListeningExerciseState(answered: true).feedback, isNull);
  });

  test('comparison sample slots may refer to identical IDs', () {
    expect(_comparison(a: 'same-ref', b: 'same-ref').sampleAReferenceId,
        'same-ref');
  });

  test('fixture rejects each blank target declaration', () {
    for (final invalid in [
      {
        'targetLocationA': '',
        'targetLocationB': 'final',
        'targetPhonemeA': 'u',
        'targetPhonemeB': 'u'
      },
      {
        'targetLocationA': 'first',
        'targetLocationB': ' ',
        'targetPhonemeA': 'u',
        'targetPhonemeB': 'u'
      },
      {
        'targetLocationA': 'first',
        'targetLocationB': 'first',
        'targetPhonemeA': '\t',
        'targetPhonemeB': 'u'
      },
      {
        'targetLocationA': 'first',
        'targetLocationB': 'first',
        'targetPhonemeA': 'u',
        'targetPhonemeB': ' '
      },
    ]) {
      expect(
          () => ComparisonFixture(
                prompt: _comparison(),
                targetLocationA: invalid['targetLocationA']!,
                targetLocationB: invalid['targetLocationB']!,
                targetPhonemeA: invalid['targetPhonemeA']!,
                targetPhonemeB: invalid['targetPhonemeB']!,
                expected: PhonemeRelation.same,
              ),
          throwsArgumentError);
    }
  });

  test('fixture rejects inconsistent declared phoneme relation', () {
    expect(
        () => ComparisonFixture(
              prompt: _comparison(),
              targetLocationA: 'first',
              targetLocationB: 'first',
              targetPhonemeA: 'u',
              targetPhonemeB: 'y',
              expected: PhonemeRelation.same,
            ),
        throwsArgumentError);
  });
}
