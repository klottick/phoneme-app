import 'package:linguist/src/core/course/course_exercise.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';

void main() {
  group('sentence-hunt exact-set scoring', () {
    late SentenceHuntItem item;

    setUp(() {
      item = SentenceHuntItem(
        identity: const SentenceHuntContentIdentity(
          sectionId: 'en-fr-sentence-hunt-vowels',
          itemId: 'fr08-vowel-01',
          sentenceId: 'fr08-vowel-01-sentence',
          audioRefId: 'fr08-vowel-01-audio',
          annotationHash:
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
          contentRevision: 1,
          annotationRevision: 1,
        ),
        exercise: SentenceHuntExercise(
          id: 'fr08-vowel-01',
          sectionId: 'en-fr-sentence-hunt-vowels',
          audioRefId: 'fr08-vowel-01-audio',
          purpose: ContentPurpose.practice,
          reviewState: ContentReviewState.reviewed,
          sentenceId: 'fr08-vowel-01-sentence',
          targetSound: 'ɑ̃',
        ),
        sentence: CourseSentence(
          id: 'fr08-vowel-01-sentence',
          text: 'Tu vois tout, tu souris.',
          audioRefId: 'fr08-vowel-01-audio',
          reviewState: ContentReviewState.reviewed,
          tokens: <SentenceToken>[
            SentenceToken(
                id: 'first', text: 'Tu', phonemes: <String>['t', 'ɑ̃']),
            SentenceToken(
                id: 'second', text: 'vois', phonemes: <String>['v', 'w', 'a']),
            SentenceToken(
                id: 'distractor', text: 'tout', phonemes: <String>['t', 'i']),
            SentenceToken(
                id: 'repeated', text: 'tu', phonemes: <String>['t', 'ɑ̃']),
            SentenceToken(
                id: 'final',
                text: 'souris',
                phonemes: <String>['s', 'u', 'ʁ', 'i']),
          ],
        ),
        reference: CourseAudioReference(
          id: 'fr08-vowel-01-audio',
          kind: AudioReferenceKind.sentence,
          spokenText: 'Tu vois tout, tu souris.',
        ),
        targetLabel: 'French vowel /ɑ̃/',
        debriefNote: 'Synthetic unit-test note.',
        selectableTokenIds: <String>[
          'first',
          'second',
          'distractor',
          'repeated',
          'final',
        ],
        expectedTokenIds: <String>['first', 'repeated'],
      );
    });

    test('accepts both repeated /ɑ̃/ tokens in any submission order', () {
      final List<String> reversed = <String>[
        item.expectedTokenIds.last,
        item.expectedTokenIds.first,
      ];

      expect(canonicalSentenceSelection(item, reversed), item.expectedTokenIds);
      expect(scoreSentenceSelection(item, reversed), isTrue);
    });

    test('omitted, extra, all, and empty selections are wrong', () {
      final String first = item.expectedTokenIds.first;
      final String repeated = item.expectedTokenIds.last;
      final String distractor = item.selectableTokenIds.firstWhere(
        (String id) => !item.expectedTokenIds.contains(id),
      );

      expect(scoreSentenceSelection(item, <String>[first]), isFalse);
      expect(
          scoreSentenceSelection(item, <String>[first, repeated, distractor]),
          isFalse);
      expect(scoreSentenceSelection(item, item.selectableTokenIds), isFalse);
      expect(scoreSentenceSelection(item, const <String>[]), isFalse);
    });

    test(
        'canonical selection rejects duplicates, unknown and nonselectable ids',
        () {
      final String id = item.expectedTokenIds.first;

      expect(
        () => canonicalSentenceSelection(item, <String>[id, id]),
        throwsArgumentError,
      );
      expect(
        () => canonicalSentenceSelection(item, <String>['not-an-id']),
        throwsArgumentError,
      );
      expect(
        () => canonicalSentenceSelection(item, <String>['.']),
        throwsArgumentError,
      );
    });

    test('returns detached unmodifiable authored-order selections', () {
      final List<String> input = <String>[
        item.expectedTokenIds.last,
        item.expectedTokenIds.first,
      ];
      final List<String> selected = canonicalSentenceSelection(item, input);
      input.clear();

      expect(selected, item.expectedTokenIds);
      expect(() => selected.add('later'), throwsUnsupportedError);
      expect(() => item.expectedTokenIds.add('later'), throwsUnsupportedError);
    });

    test('content identity has value equality and a stable hash', () {
      final SentenceHuntContentIdentity sameIdentity =
          SentenceHuntContentIdentity(
        sectionId: item.identity.sectionId,
        itemId: item.identity.itemId,
        sentenceId: item.identity.sentenceId,
        audioRefId: item.identity.audioRefId,
        annotationHash: item.identity.annotationHash,
        contentRevision: item.identity.contentRevision,
        annotationRevision: item.identity.annotationRevision,
      );

      expect(sameIdentity, item.identity);
      expect(sameIdentity.hashCode, item.identity.hashCode);
      expect(
        SentenceHuntContentIdentity(
          sectionId: item.identity.sectionId,
          itemId: item.identity.itemId,
          sentenceId: item.identity.sentenceId,
          audioRefId: item.identity.audioRefId,
          annotationHash: item.identity.annotationHash,
          contentRevision: item.identity.contentRevision + 1,
          annotationRevision: item.identity.annotationRevision,
        ),
        isNot(item.identity),
      );
    });
  });
}
