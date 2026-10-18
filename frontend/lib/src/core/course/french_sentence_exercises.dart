/// Frozen identities and role declarations for the FR08 sentence-hunt group.
///
/// This file contains no authored sentence text, keys, review evidence, or
/// recordings. Runtime exercise content comes exclusively from the strictly
/// validated sentence package.
const String sentenceHuntGroupId = 'en-fr-sentence-hunt';

enum SentenceHuntTargetRole { vowel, consonant }

final class SentenceHuntItemSpecification {
  const SentenceHuntItemSpecification({
    required this.id,
    required this.sentenceId,
    required this.audioRefId,
    required this.targetRole,
  });

  final String id;
  final String sentenceId;
  final String audioRefId;
  final SentenceHuntTargetRole targetRole;
}

final class SentenceHuntSectionSpecification {
  const SentenceHuntSectionSpecification({
    required this.id,
    required this.kind,
    required this.items,
  });

  final String id;
  final String kind;
  final List<SentenceHuntItemSpecification> items;
}

const List<SentenceHuntSectionSpecification> sentenceHuntSectionSpecifications =
    <SentenceHuntSectionSpecification>[
  SentenceHuntSectionSpecification(
    id: 'en-fr-sentence-hunt-vowels',
    kind: 'vowels',
    items: <SentenceHuntItemSpecification>[
      SentenceHuntItemSpecification(
        id: 'fr08-vowel-01',
        sentenceId: 'fr08-vowel-01-sentence',
        audioRefId: 'fr08-vowel-01-audio',
        targetRole: SentenceHuntTargetRole.vowel,
      ),
      SentenceHuntItemSpecification(
        id: 'fr08-vowel-02',
        sentenceId: 'fr08-vowel-02-sentence',
        audioRefId: 'fr08-vowel-02-audio',
        targetRole: SentenceHuntTargetRole.vowel,
      ),
      SentenceHuntItemSpecification(
        id: 'fr08-vowel-03',
        sentenceId: 'fr08-vowel-03-sentence',
        audioRefId: 'fr08-vowel-03-audio',
        targetRole: SentenceHuntTargetRole.vowel,
      ),
      SentenceHuntItemSpecification(
        id: 'fr08-vowel-04',
        sentenceId: 'fr08-vowel-04-sentence',
        audioRefId: 'fr08-vowel-04-audio',
        targetRole: SentenceHuntTargetRole.vowel,
      ),
      SentenceHuntItemSpecification(
        id: 'fr08-vowel-05',
        sentenceId: 'fr08-vowel-05-sentence',
        audioRefId: 'fr08-vowel-05-audio',
        targetRole: SentenceHuntTargetRole.vowel,
      ),
    ],
  ),
  SentenceHuntSectionSpecification(
    id: 'en-fr-sentence-hunt-consonants',
    kind: 'consonants',
    items: <SentenceHuntItemSpecification>[
      SentenceHuntItemSpecification(
        id: 'fr08-consonant-01',
        sentenceId: 'fr08-consonant-01-sentence',
        audioRefId: 'fr08-consonant-01-audio',
        targetRole: SentenceHuntTargetRole.consonant,
      ),
      SentenceHuntItemSpecification(
        id: 'fr08-consonant-02',
        sentenceId: 'fr08-consonant-02-sentence',
        audioRefId: 'fr08-consonant-02-audio',
        targetRole: SentenceHuntTargetRole.consonant,
      ),
      SentenceHuntItemSpecification(
        id: 'fr08-consonant-03',
        sentenceId: 'fr08-consonant-03-sentence',
        audioRefId: 'fr08-consonant-03-audio',
        targetRole: SentenceHuntTargetRole.consonant,
      ),
      SentenceHuntItemSpecification(
        id: 'fr08-consonant-04',
        sentenceId: 'fr08-consonant-04-sentence',
        audioRefId: 'fr08-consonant-04-audio',
        targetRole: SentenceHuntTargetRole.consonant,
      ),
      SentenceHuntItemSpecification(
        id: 'fr08-consonant-05',
        sentenceId: 'fr08-consonant-05-sentence',
        audioRefId: 'fr08-consonant-05-audio',
        targetRole: SentenceHuntTargetRole.consonant,
      ),
    ],
  ),
  SentenceHuntSectionSpecification(
    id: 'en-fr-sentence-hunt-mixed',
    kind: 'mixed',
    items: <SentenceHuntItemSpecification>[
      SentenceHuntItemSpecification(
        id: 'fr08-mixed-01',
        sentenceId: 'fr08-mixed-01-sentence',
        audioRefId: 'fr08-mixed-01-audio',
        targetRole: SentenceHuntTargetRole.vowel,
      ),
      SentenceHuntItemSpecification(
        id: 'fr08-mixed-02',
        sentenceId: 'fr08-mixed-02-sentence',
        audioRefId: 'fr08-mixed-02-audio',
        targetRole: SentenceHuntTargetRole.vowel,
      ),
      SentenceHuntItemSpecification(
        id: 'fr08-mixed-03',
        sentenceId: 'fr08-mixed-03-sentence',
        audioRefId: 'fr08-mixed-03-audio',
        targetRole: SentenceHuntTargetRole.consonant,
      ),
      SentenceHuntItemSpecification(
        id: 'fr08-mixed-04',
        sentenceId: 'fr08-mixed-04-sentence',
        audioRefId: 'fr08-mixed-04-audio',
        targetRole: SentenceHuntTargetRole.consonant,
      ),
      SentenceHuntItemSpecification(
        id: 'fr08-mixed-05',
        sentenceId: 'fr08-mixed-05-sentence',
        audioRefId: 'fr08-mixed-05-audio',
        targetRole: SentenceHuntTargetRole.consonant,
      ),
    ],
  ),
];
