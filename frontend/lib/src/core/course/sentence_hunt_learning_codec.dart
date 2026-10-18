import 'dart:convert';

import 'course_audio_contract.dart';
import 'course_learning_transaction.dart';
import 'lesson_policy.dart';
import 'lesson_section_session.dart';
import 'sentence_hunt_content.dart';
import 'sentence_hunt_learning_command.dart';
import 'sentence_hunt_learning_state.dart';

const List<String> _knownSentenceSectionIds = <String>[
  'en-fr-sentence-hunt-vowels',
  'en-fr-sentence-hunt-consonants',
  'en-fr-sentence-hunt-mixed',
];

final class SentenceHuntLearningCodec {
  const SentenceHuntLearningCodec({
    this.limits = const SentenceHuntLearningLimits(),
  });

  final SentenceHuntLearningLimits limits;

  String keyFor(SentenceHuntProfileScope scope) => scope.storageKey;

  String canonicalCommand(SentenceHuntLearningCommand command) =>
      sentenceHuntCanonicalCommand(command);

  String encode(SentenceHuntLearningState state) {
    try {
      limits.validate();
      _validateStateStructure(state, limits);
      final String raw = jsonEncode(_document(state));
      final int encodedBytes = utf8.encode(raw).length;
      if (encodedBytes > limits.maxDocumentBytes) {
        throw SentenceHuntUnavailableException(
          'Encoded sentence-hunt document is $encodedBytes bytes; limit is '
          '${limits.maxDocumentBytes}.',
        );
      }
      return raw;
    } on SentenceHuntUnavailableException {
      rethrow;
    } on ArgumentError catch (error) {
      throw SentenceHuntUnavailableException(error);
    } on FormatException catch (error) {
      throw SentenceHuntUnavailableException(error);
    } on StateError catch (error) {
      throw SentenceHuntUnavailableException(error);
    } on TypeError catch (error) {
      throw SentenceHuntUnavailableException(error);
    }
  }

  SentenceHuntLearningState decode(
    String raw,
    SentenceHuntProfileScope expectedScope,
    SentenceHuntCatalogue catalogue,
  ) {
    try {
      limits.validate();
      final int rawBytes = utf8.encode(raw).length;
      if (rawBytes > limits.maxDocumentBytes) {
        throw SentenceHuntUnavailableException(
          'Sentence-hunt input is $rawBytes bytes; limit is '
          '${limits.maxDocumentBytes}.',
        );
      }
      final Map<String, _SentenceSectionDescriptor> descriptors =
          _knownDescriptors(catalogue);
      final Map<String, Object?> root = _object(jsonDecode(raw), 'document');
      _exactKeys(
        root,
        const <String>[
          'schemaVersion',
          'family',
          'courseId',
          'owner',
          'revision',
          'commitOrdinal',
          'slots',
          'attempts',
          'receipts',
          'mistakes',
          'summaries',
          'completions',
          'teachingExposure',
        ],
        'document',
      );
      if (_integer(root['schemaVersion'], 'schemaVersion') != 1 ||
          _string(root['family'], 'family') != 'sentence-hunt') {
        throw const FormatException('Unsupported sentence-hunt family/schema.');
      }
      final String courseId = _string(root['courseId'], 'courseId');
      final LearningOwner owner = _readOwner(_object(root['owner'], 'owner'));
      final SentenceHuntProfileScope scope =
          SentenceHuntProfileScope(courseId: courseId, owner: owner);
      if (scope != expectedScope) {
        throw const FormatException('Sentence-hunt profile mismatch.');
      }
      final int revision = _integer(root['revision'], 'revision');
      final int commitOrdinal =
          _integer(root['commitOrdinal'], 'commitOrdinal');
      final List<SentenceHuntReceipt> receipts = _array(
        root['receipts'],
        'receipts',
      ).map((Object? value) {
        return _readReceipt(
          _object(value, 'receipt'),
          scope,
        );
      }).toList(growable: false);
      final List<SentenceHuntAttempt> attempts = _array(
        root['attempts'],
        'attempts',
      ).map((Object? value) {
        return _readAttempt(
          _object(value, 'attempt'),
          scope,
          descriptors,
        );
      }).toList(growable: false);
      final Map<SentenceHuntMistakeKey, SentenceHuntMistake> mistakes =
          _readMistakes(root['mistakes'], scope, descriptors);
      final Map<SentenceHuntSummaryKey, SentenceHuntSummary> summaries =
          _readSummaries(root['summaries'], scope, descriptors);
      final List<SentenceHuntCompletion> completions = _array(
        root['completions'],
        'completions',
      ).map((Object? value) {
        return _readCompletion(
          _object(value, 'completion'),
          scope,
          descriptors,
        );
      }).toList(growable: false);
      final Set<SentenceHuntExposureKey> exposure = _readExposure(
        root['teachingExposure'],
        scope,
        descriptors,
      );
      final Map<String, SentenceHuntSlot> slots = _readSlots(
        root['slots'],
        scope,
        descriptors,
      );
      final SentenceHuntLearningState state = SentenceHuntLearningState(
        scope: scope,
        revision: revision,
        commitOrdinal: commitOrdinal,
        slots: slots,
        attempts: attempts,
        receipts: receipts,
        mistakes: mistakes,
        summaries: summaries,
        completions: completions,
        teachingExposure: exposure,
      );
      _validateState(state, descriptors, limits);
      return state;
    } on SentenceHuntUnavailableException {
      rethrow;
    } on FormatException catch (error) {
      throw SentenceHuntUnavailableException(error);
    } on ArgumentError catch (error) {
      throw SentenceHuntUnavailableException(error);
    } on StateError catch (error) {
      throw SentenceHuntUnavailableException(error);
    } on TypeError catch (error) {
      throw SentenceHuntUnavailableException(error);
    }
  }

  Map<String, Object?> _document(SentenceHuntLearningState state) =>
      <String, Object?>{
        'schemaVersion': 1,
        'family': 'sentence-hunt',
        'courseId': state.scope.courseId,
        'owner': _ownerJson(state.scope.owner),
        'revision': state.revision,
        'commitOrdinal': state.commitOrdinal,
        'slots': <String, Object?>{
          for (final String id in state.slots.keys.toList()..sort())
            id: _slotJson(state.slots[id]!),
        },
        'attempts': <Object?>[
          for (final SentenceHuntAttempt attempt in state.attempts)
            _attemptJson(attempt),
        ],
        'receipts': <Object?>[
          for (final SentenceHuntReceipt receipt in state.receipts)
            _receiptJson(receipt),
        ],
        'mistakes': <String, Object?>{
          for (final SentenceHuntMistakeKey key
              in state.mistakes.keys.toList()..sort(_compareMistakeKeys))
            _tupleKey(<Object?>[
              key.content.sectionId,
              key.content.itemId,
              key.content.contentRevision,
            ]): <String, Object?>{
              'firstWrongAt': _date(state.mistakes[key]!.firstWrongAt),
              'latestWrongAt': _date(state.mistakes[key]!.latestWrongAt),
              'failureCount': state.mistakes[key]!.failureCount,
            },
        },
        'summaries': <String, Object?>{
          for (final SentenceHuntSummaryKey key
              in state.summaries.keys.toList()..sort(_compareSummaryKeys))
            _tupleKey(<Object?>[
              key.content.sectionId,
              key.content.itemId,
              key.content.contentRevision,
            ]): <String, Object?>{
              'firstInRun': _countJson(state.summaries[key]!.firstInRun),
              'repeatInRun': _countJson(state.summaries[key]!.repeatInRun),
              'firstTeachingExposed':
                  _countJson(state.summaries[key]!.firstTeachingExposed),
              'repeatTeachingExposed':
                  _countJson(state.summaries[key]!.repeatTeachingExposed),
            },
        },
        'completions': <Object?>[
          for (final SentenceHuntCompletion completion in state.completions)
            <String, Object?>{
              'sectionId': completion.sectionId,
              'contentRevision': completion.contentRevision,
              'policyRevision': completion.policyRevision,
              'thresholdPercent': completion.thresholdPercent,
              'committedAt': _date(completion.committedAt),
            },
        ],
        'teachingExposure': <Object?>[
          for (final SentenceHuntExposureKey key
              in state.teachingExposure.toList()..sort(_compareExposureKeys))
            <String, Object?>{
              'sectionId': key.sectionId,
              'contentRevision': key.contentRevision,
            },
        ],
      };

  Map<String, Object?> _ownerJson(LearningOwner owner) => <String, Object?>{
        'kind': owner.isGuest ? 'guest' : 'account',
        'userId': owner.userId,
      };

  LearningOwner _readOwner(Map<String, Object?> value) {
    _exactKeys(value, const <String>['kind', 'userId'], 'owner');
    final String kind = _string(value['kind'], 'owner.kind');
    final Object? rawId = value['userId'];
    if (kind == 'guest' && rawId == null) return LearningOwner.guest();
    if (kind == 'account' && rawId is String && rawId.trim().isNotEmpty) {
      return LearningOwner.account(rawId);
    }
    throw const FormatException('Invalid sentence-hunt owner.');
  }

  Map<String, Object?> _cursorJson(LearningCursorPosition cursor) =>
      <String, Object?>{
        'generation': cursor.generation,
        'sequence': cursor.sequence,
        'revision': cursor.revision,
      };

  LearningCursorPosition _readCursor(Map<String, Object?> value) {
    _exactKeys(
      value,
      const <String>['generation', 'sequence', 'revision'],
      'cursor',
    );
    return LearningCursorPosition(
      generation: _integer(value['generation'], 'cursor.generation'),
      sequence: _integer(value['sequence'], 'cursor.sequence'),
      revision: _integer(value['revision'], 'cursor.revision'),
    );
  }

  Map<String, Object?> _slotJson(SentenceHuntSlot slot) => <String, Object?>{
        'sectionId': slot.sectionId,
        'cursor': _cursorJson(slot.cursor),
        'checkpoint': <String, Object?>{
          'sessionId': slot.checkpoint.sessionId,
          'sectionFingerprint': slot.checkpoint.sectionFingerprint,
          'contentRevision': slot.checkpoint.contentRevision,
          'mode': slot.checkpoint.mode.name,
          'finished': slot.checkpoint.finished,
          'policy': slot.checkpoint.policy.toJson(),
          'runStartRound': slot.checkpoint.runStartRound,
          'session': slot.checkpoint.sessionJson,
        },
        'latestReceipt': _receiptJson(slot.latestReceipt),
      };

  Map<String, Object?> _receiptJson(SentenceHuntReceipt receipt) =>
      <String, Object?>{
        'sectionId': receipt.sectionId,
        'token': receipt.token,
        'canonicalCommand': receipt.canonicalCommand,
        'before': _cursorJson(receipt.before),
        'after': _cursorJson(receipt.after),
        'commitOrdinal': receipt.commitOrdinal,
      };

  Map<String, SentenceHuntSlot> _readSlots(
    Object? value,
    SentenceHuntProfileScope scope,
    Map<String, _SentenceSectionDescriptor> descriptors,
  ) {
    final Map<String, Object?> rawSlots = _object(value, 'slots');
    if (rawSlots.length > sentenceHuntMaxSlots) {
      throw const FormatException('Too many sentence-hunt slots.');
    }
    final Map<String, SentenceHuntSlot> slots = <String, SentenceHuntSlot>{};
    for (final MapEntry<String, Object?> entry in rawSlots.entries) {
      final Map<String, Object?> rawSlot =
          _object(entry.value, 'slot(${entry.key})');
      _exactKeys(
        rawSlot,
        const <String>['sectionId', 'cursor', 'checkpoint', 'latestReceipt'],
        'slot',
      );
      final String sectionId = _string(rawSlot['sectionId'], 'slot.sectionId');
      if (sectionId != entry.key ||
          !_knownSentenceSectionIds.contains(sectionId)) {
        throw const FormatException('Unknown or mismatched slot section.');
      }
      final Map<String, Object?> checkpointRaw =
          _object(rawSlot['checkpoint'], 'checkpoint');
      _exactKeys(
        checkpointRaw,
        const <String>[
          'sessionId',
          'sectionFingerprint',
          'contentRevision',
          'mode',
          'finished',
          'policy',
          'runStartRound',
          'session',
        ],
        'checkpoint',
      );
      final String fingerprint = _string(
          checkpointRaw['sectionFingerprint'], 'checkpoint.sectionFingerprint');
      final int contentRevision = _positive(
          checkpointRaw['contentRevision'], 'checkpoint.contentRevision');
      final _SentenceSectionDescriptor descriptor = _descriptor(
        descriptors,
        sectionId,
        contentRevision,
        fingerprint,
      );
      final LessonPolicy policy =
          _readPolicy(checkpointRaw['policy'], 'checkpoint.policy');
      if (policy.completionThresholdPercent != descriptor.thresholdPercent) {
        throw const FormatException(
            'Checkpoint policy differs from its registered descriptor.');
      }
      final String sessionId =
          _string(checkpointRaw['sessionId'], 'checkpoint.sessionId');
      final SentenceHuntRunMode mode = _enum(
        SentenceHuntRunMode.values,
        checkpointRaw['mode'],
        'checkpoint.mode',
      );
      final bool finished =
          _boolean(checkpointRaw['finished'], 'checkpoint.finished');
      final int runStartRound =
          _positive(checkpointRaw['runStartRound'], 'checkpoint.runStartRound');
      final Map<String, Object?> sessionRaw =
          _object(checkpointRaw['session'], 'checkpoint.session');
      final LessonSectionSession session = _readSession(
        sessionRaw,
        descriptor,
      );
      if (session.sessionId != sessionId ||
          session.contentRevision != contentRevision ||
          session.policy.completionThresholdPercent !=
              policy.completionThresholdPercent ||
          runStartRound > session.round ||
          (finished && session.phase != LessonSectionPhase.debrief)) {
        throw const FormatException('Checkpoint/session mismatch.');
      }
      final SentenceHuntCheckpoint checkpoint = SentenceHuntCheckpoint(
        scope: scope,
        sessionId: sessionId,
        sectionFingerprint: fingerprint,
        contentRevision: contentRevision,
        mode: mode,
        finished: finished,
        policy: policy,
        sessionJson: session.toJson().cast<String, Object?>(),
        runStartRound: runStartRound,
      );
      final LearningCursorPosition cursor =
          _readCursor(_object(rawSlot['cursor'], 'slot.cursor'));
      final SentenceHuntReceipt latest = _readReceipt(
        _object(rawSlot['latestReceipt'], 'slot.latestReceipt'),
        scope,
      );
      if (latest.sectionId != sectionId || latest.after != cursor) {
        throw const FormatException('Slot latest receipt/cursor mismatch.');
      }
      slots[sectionId] = SentenceHuntSlot(
        sectionId: sectionId,
        checkpoint: checkpoint,
        cursor: cursor,
        latestReceipt: latest,
      );
    }
    return slots;
  }

  LessonSectionSession _readSession(
    Map<String, Object?> sessionRaw,
    _SentenceSectionDescriptor descriptor,
  ) {
    const List<String> fields = <String>[
      'version',
      'sessionId',
      'contentRevision',
      'itemIds',
      'queue',
      'position',
      'round',
      'attemptCount',
      'phase',
      'submittedThisRound',
      'lastCorrect',
      'answered',
      'latestAnswers',
      'policy',
    ];
    _exactKeys(sessionRaw, fields, 'session');
    for (final String key in const <String>[
      'version',
      'contentRevision',
      'position',
      'round',
      'attemptCount',
    ]) {
      _integer(sessionRaw[key], 'session.$key');
    }
    for (final String key in const <String>[
      'itemIds',
      'queue',
      'submittedThisRound',
    ]) {
      _stringList(sessionRaw[key], 'session.$key', unique: true);
    }
    _string(sessionRaw['sessionId'], 'session.sessionId');
    _string(sessionRaw['phase'], 'session.phase');
    if (sessionRaw['lastCorrect'] != null) {
      _boolean(sessionRaw['lastCorrect'], 'session.lastCorrect');
    }
    _boolean(sessionRaw['answered'], 'session.answered');
    final Map<String, Object?> latestAnswers =
        _object(sessionRaw['latestAnswers'], 'session.latestAnswers');
    for (final MapEntry<String, Object?> entry in latestAnswers.entries) {
      _boolean(entry.value, 'session.latestAnswers.${entry.key}');
    }
    _readPolicy(sessionRaw['policy'], 'session.policy');
    return LessonSectionSession.fromJson(
      Map<String, dynamic>.from(sessionRaw),
      itemIds: descriptor.items
          .map((SentenceHuntItemDescriptor item) => item.identity.itemId)
          .toList(growable: false),
      contentRevision: descriptor.contentRevision,
    );
  }

  SentenceHuntReceipt _readReceipt(
    Map<String, Object?> value,
    SentenceHuntProfileScope scope,
  ) {
    _exactKeys(
      value,
      const <String>[
        'sectionId',
        'token',
        'canonicalCommand',
        'before',
        'after',
        'commitOrdinal',
      ],
      'receipt',
    );
    final String sectionId = _string(value['sectionId'], 'receipt.sectionId');
    final String token = _string(value['token'], 'receipt.token');
    final String canonical =
        _string(value['canonicalCommand'], 'receipt.canonicalCommand');
    final LearningCursorPosition before =
        _readCursor(_object(value['before'], 'receipt.before'));
    final LearningCursorPosition after =
        _readCursor(_object(value['after'], 'receipt.after'));
    final int ordinal =
        _positive(value['commitOrdinal'], 'receipt.commitOrdinal');
    return SentenceHuntReceipt(
      scope: scope,
      sectionId: sectionId,
      token: token,
      canonicalCommand: canonical,
      before: before,
      after: after,
      commitOrdinal: ordinal,
    );
  }

  SentenceHuntLearningCommand _readCanonicalCommand(
    String raw,
    SentenceHuntProfileScope scope,
    Map<String, _SentenceSectionDescriptor>? descriptors,
  ) {
    final Map<String, Object?> value = _object(jsonDecode(raw), 'command');
    const List<String> orderedFields = <String>[
      'schemaVersion',
      'family',
      'courseId',
      'owner',
      'authGeneration',
      'sectionId',
      'sectionFingerprint',
      'generation',
      'sequence',
      'revision',
      'token',
      'submittedAt',
      'action',
    ];
    _exactKeys(value, orderedFields, 'command', ordered: true);
    if (_integer(value['schemaVersion'], 'command.schemaVersion') != 1 ||
        _string(value['family'], 'command.family') != 'sentence-hunt' ||
        _string(value['courseId'], 'command.courseId') != scope.courseId ||
        _readOwner(_object(value['owner'], 'command.owner')) != scope.owner) {
      throw const FormatException('Canonical command scope mismatch.');
    }
    final String sectionId = _string(value['sectionId'], 'command.sectionId');
    final String fingerprint =
        _string(value['sectionFingerprint'], 'command.sectionFingerprint');
    final _SentenceSectionDescriptor? descriptor = descriptors == null
        ? null
        : _descriptorByFingerprint(descriptors, sectionId, fingerprint);
    final Map<String, Object?> actionRaw = _object(value['action'], 'action');
    final String kind = _string(actionRaw['kind'], 'action.kind');
    final SentenceHuntAction action;
    switch (kind) {
      case 'start':
        _exactKeys(
          actionRaw,
          const <String>[
            'kind',
            'sessionId',
            'policy',
            'mode',
            'replaceExisting',
          ],
          'action',
        );
        action = StartSentenceHuntRun(
          sessionId: _string(actionRaw['sessionId'], 'action.sessionId'),
          policy: _readPolicy(actionRaw['policy'], 'action.policy'),
          mode: _enum(
            SentenceHuntRunMode.values,
            actionRaw['mode'],
            'action.mode',
          ),
          replaceExisting:
              _boolean(actionRaw['replaceExisting'], 'action.replaceExisting'),
        );
        break;
      case 'answer':
        _exactKeys(
          actionRaw,
          const <String>[
            'kind',
            'content',
            'selectedTokenIds',
            'expectedTokenIdsSnapshot',
            'playback',
          ],
          'action',
        );
        final SentenceHuntContentIdentity identity =
            _readContent(_object(actionRaw['content'], 'action.content'));
        final List<String> selected = _stringList(
            actionRaw['selectedTokenIds'], 'action.selectedTokenIds',
            unique: true);
        final List<String> expected = _stringList(
          actionRaw['expectedTokenIdsSnapshot'],
          'action.expectedTokenIdsSnapshot',
          unique: true,
        );
        final SentenceHuntPlaybackObservation playback = _readPlayback(
          _object(actionRaw['playback'], 'action.playback'),
          scope,
        );
        action = AnswerSentenceHuntItem(SentenceHuntAnswer(
          content: identity,
          selectedTokenIds: selected,
          expectedTokenIdsSnapshot: expected,
          playback: playback,
        ));
        if (descriptor != null) {
          _validateAnswerAgainstDescriptor(
            action as AnswerSentenceHuntItem,
            descriptor,
          );
        }
        break;
      case 'advance':
        _exactKeys(actionRaw, const <String>['kind'], 'action');
        action = const AdvanceSentenceHuntItem();
        break;
      case 'review':
        _exactKeys(actionRaw, const <String>['kind'], 'action');
        action = const ReviewSentenceHuntMistakes();
        break;
      case 'finish':
        _exactKeys(actionRaw, const <String>['kind'], 'action');
        action = const FinishSentenceHuntRun();
        break;
      default:
        throw const FormatException('Unknown sentence-hunt action.');
    }
    final SentenceHuntLearningCommand command = SentenceHuntLearningCommand(
      scope: scope,
      authGeneration:
          _integer(value['authGeneration'], 'command.authGeneration'),
      sectionId: sectionId,
      sectionFingerprint: fingerprint,
      expected: LearningCursorPosition(
        generation: _integer(value['generation'], 'command.generation'),
        sequence: _integer(value['sequence'], 'command.sequence'),
        revision: _integer(value['revision'], 'command.revision'),
      ),
      token: _string(value['token'], 'command.token'),
      submittedAt: _utc(value['submittedAt'], 'command.submittedAt'),
      action: action,
    );
    if (sentenceHuntCanonicalCommand(command) != raw) {
      throw const FormatException('Noncanonical sentence-hunt command.');
    }
    // Descriptor lookup is intentionally done even for non-answer actions; a
    // historical receipt must remain bound to a retained immutable identity.
    if (descriptor != null && descriptor.sectionId != sectionId) {
      throw const FormatException('Unknown command section identity.');
    }
    return command;
  }

  SentenceHuntPlaybackObservation _readPlayback(
    Map<String, Object?> value,
    SentenceHuntProfileScope scope,
  ) {
    _exactKeys(
      value,
      const <String>[
        'referenceId',
        'outcome',
        'source',
        'runGeneration',
        'round',
        'uiGeneration',
        'content',
      ],
      'playback',
    );
    return SentenceHuntPlaybackObservation(
      scope: scope,
      content: _readContent(_object(value['content'], 'playback.content')),
      runGeneration:
          _positive(value['runGeneration'], 'playback.runGeneration'),
      round: _positive(value['round'], 'playback.round'),
      uiGeneration: _integer(value['uiGeneration'], 'playback.uiGeneration'),
      referenceId: _string(value['referenceId'], 'playback.referenceId'),
      outcome: _enum(
        CourseAudioOutcome.values,
        value['outcome'],
        'playback.outcome',
      ),
      source: _enum(
        CourseAudioSource.values,
        value['source'],
        'playback.source',
      ),
    );
  }

  SentenceHuntContentIdentity _readContent(Map<String, Object?> value) {
    _exactKeys(
      value,
      const <String>[
        'sectionId',
        'itemId',
        'sentenceId',
        'audioRefId',
        'annotationHash',
        'contentRevision',
        'annotationRevision',
      ],
      'content',
    );
    return SentenceHuntContentIdentity(
      sectionId: _string(value['sectionId'], 'content.sectionId'),
      itemId: _string(value['itemId'], 'content.itemId'),
      sentenceId: _string(value['sentenceId'], 'content.sentenceId'),
      audioRefId: _string(value['audioRefId'], 'content.audioRefId'),
      annotationHash:
          _string(value['annotationHash'], 'content.annotationHash'),
      contentRevision:
          _positive(value['contentRevision'], 'content.contentRevision'),
      annotationRevision:
          _positive(value['annotationRevision'], 'content.annotationRevision'),
    );
  }

  Map<SentenceHuntMistakeKey, SentenceHuntMistake> _readMistakes(
    Object? value,
    SentenceHuntProfileScope scope,
    Map<String, _SentenceSectionDescriptor> descriptors,
  ) {
    final Map<String, Object?> raw = _object(value, 'mistakes');
    if (raw.length > limits.maxAggregateEntries) {
      throw const FormatException('Too many sentence-hunt mistakes.');
    }
    final Map<SentenceHuntMistakeKey, SentenceHuntMistake> result =
        <SentenceHuntMistakeKey, SentenceHuntMistake>{};
    for (final MapEntry<String, Object?> entry in raw.entries) {
      final List<Object?> tuple = _readTuple(entry.key, 3, 'mistake key');
      final String sectionId = _string(tuple[0], 'mistake.sectionId');
      final String itemId = _string(tuple[1], 'mistake.itemId');
      final int revision = _positive(tuple[2], 'mistake.contentRevision');
      final SentenceHuntContentIdentity content = _resolveItem(
        descriptors,
        sectionId,
        itemId,
        revision,
      ).identity;
      if (_tupleKey(<Object?>[sectionId, itemId, revision]) != entry.key) {
        throw const FormatException('Noncanonical sentence-hunt mistake key.');
      }
      final Map<String, Object?> mistakeRaw = _object(entry.value, 'mistake');
      _exactKeys(
        mistakeRaw,
        const <String>['firstWrongAt', 'latestWrongAt', 'failureCount'],
        'mistake',
      );
      final SentenceHuntMistakeKey key =
          SentenceHuntMistakeKey(scope: scope, content: content);
      if (result.containsKey(key)) {
        throw const FormatException(
            'Duplicate sentence-hunt mistake identity.');
      }
      result[key] = SentenceHuntMistake(
        key: key,
        firstWrongAt: _utc(mistakeRaw['firstWrongAt'], 'firstWrongAt'),
        latestWrongAt: _utc(mistakeRaw['latestWrongAt'], 'latestWrongAt'),
        failureCount: _positive(mistakeRaw['failureCount'], 'failureCount'),
      );
    }
    return result;
  }

  Map<SentenceHuntSummaryKey, SentenceHuntSummary> _readSummaries(
    Object? value,
    SentenceHuntProfileScope scope,
    Map<String, _SentenceSectionDescriptor> descriptors,
  ) {
    final Map<String, Object?> raw = _object(value, 'summaries');
    if (raw.length > limits.maxAggregateEntries) {
      throw const FormatException('Too many sentence-hunt summaries.');
    }
    final Map<SentenceHuntSummaryKey, SentenceHuntSummary> result =
        <SentenceHuntSummaryKey, SentenceHuntSummary>{};
    for (final MapEntry<String, Object?> entry in raw.entries) {
      final List<Object?> tuple = _readTuple(entry.key, 3, 'summary key');
      final String sectionId = _string(tuple[0], 'summary.sectionId');
      final String itemId = _string(tuple[1], 'summary.itemId');
      final int revision = _positive(tuple[2], 'summary.contentRevision');
      final SentenceHuntContentIdentity content = _resolveItem(
        descriptors,
        sectionId,
        itemId,
        revision,
      ).identity;
      if (_tupleKey(<Object?>[sectionId, itemId, revision]) != entry.key) {
        throw const FormatException('Noncanonical sentence-hunt summary key.');
      }
      final Map<String, Object?> summaryRaw = _object(entry.value, 'summary');
      _exactKeys(
        summaryRaw,
        const <String>[
          'firstInRun',
          'repeatInRun',
          'firstTeachingExposed',
          'repeatTeachingExposed',
        ],
        'summary',
      );
      final SentenceHuntSummaryKey key =
          SentenceHuntSummaryKey(scope: scope, content: content);
      if (result.containsKey(key)) {
        throw const FormatException(
            'Duplicate sentence-hunt summary identity.');
      }
      result[key] = SentenceHuntSummary(
        key: key,
        firstInRun: _readCount(summaryRaw['firstInRun'], 'firstInRun'),
        repeatInRun: _readCount(summaryRaw['repeatInRun'], 'repeatInRun'),
        firstTeachingExposed: _readCount(
            summaryRaw['firstTeachingExposed'], 'firstTeachingExposed'),
        repeatTeachingExposed: _readCount(
            summaryRaw['repeatTeachingExposed'], 'repeatTeachingExposed'),
      );
    }
    return result;
  }

  SentenceHuntCounts _readCount(Object? value, String name) {
    final Map<String, Object?> raw = _object(value, name);
    _exactKeys(raw, const <String>['correct', 'total'], name);
    return SentenceHuntCounts(
      correct: _integer(raw['correct'], '$name.correct'),
      total: _integer(raw['total'], '$name.total'),
    );
  }

  Map<String, Object?> _countJson(SentenceHuntCounts counts) =>
      <String, Object?>{'correct': counts.correct, 'total': counts.total};

  List<Object?> _readTuple(String key, int length, String name) {
    final Object? raw;
    try {
      raw = jsonDecode(key);
    } on FormatException {
      throw FormatException('$name must be a JSON tuple.');
    }
    if (raw is! List || raw.length != length) {
      throw FormatException('$name has the wrong tuple shape.');
    }
    return raw.cast<Object?>();
  }

  SentenceHuntCompletion _readCompletion(
    Map<String, Object?> value,
    SentenceHuntProfileScope scope,
    Map<String, _SentenceSectionDescriptor> descriptors,
  ) {
    _exactKeys(
      value,
      const <String>[
        'sectionId',
        'contentRevision',
        'policyRevision',
        'thresholdPercent',
        'committedAt',
      ],
      'completion',
    );
    final String sectionId =
        _string(value['sectionId'], 'completion.sectionId');
    final int revision =
        _positive(value['contentRevision'], 'completion.contentRevision');
    final int policyRevision =
        _positive(value['policyRevision'], 'completion.policyRevision');
    final int threshold =
        _positive(value['thresholdPercent'], 'completion.thresholdPercent');
    if (threshold > 100 ||
        !descriptors.values.any((_SentenceSectionDescriptor d) =>
            d.sectionId == sectionId &&
            d.contentRevision == revision &&
            d.policyRevision == policyRevision &&
            d.thresholdPercent == threshold)) {
      throw const FormatException('Unknown sentence-hunt completion identity.');
    }
    return SentenceHuntCompletion(
      scope: scope,
      sectionId: sectionId,
      contentRevision: revision,
      policyRevision: policyRevision,
      thresholdPercent: threshold,
      committedAt: _utc(value['committedAt'], 'completion.committedAt'),
    );
  }

  Set<SentenceHuntExposureKey> _readExposure(
    Object? value,
    SentenceHuntProfileScope scope,
    Map<String, _SentenceSectionDescriptor> descriptors,
  ) {
    final List<Object?> rows = _array(value, 'teachingExposure');
    if (rows.length > limits.maxAggregateEntries) {
      throw const FormatException('Too many teaching-exposure identities.');
    }
    final Set<SentenceHuntExposureKey> result = <SentenceHuntExposureKey>{};
    for (final Object? row in rows) {
      final Map<String, Object?> raw = _object(row, 'teachingExposure[]');
      _exactKeys(
          raw, const <String>['sectionId', 'contentRevision'], 'exposure');
      final String sectionId = _string(raw['sectionId'], 'exposure.sectionId');
      final int revision =
          _positive(raw['contentRevision'], 'exposure.contentRevision');
      if (!descriptors.values.any((_SentenceSectionDescriptor d) =>
          d.sectionId == sectionId && d.contentRevision == revision)) {
        throw const FormatException('Unknown teaching-exposure identity.');
      }
      final SentenceHuntExposureKey key = SentenceHuntExposureKey(
        scope: scope,
        sectionId: sectionId,
        contentRevision: revision,
      );
      if (!result.add(key)) {
        throw const FormatException('Duplicate teaching-exposure identity.');
      }
    }
    return result;
  }

  SentenceHuntAttempt _readAttempt(
    Map<String, Object?> value,
    SentenceHuntProfileScope scope,
    Map<String, _SentenceSectionDescriptor> descriptors,
  ) {
    _exactKeys(
      value,
      const <String>[
        'content',
        'runGeneration',
        'round',
        'sequence',
        'selectedTokenIds',
        'expectedTokenIds',
        'correct',
        'presentation',
        'teachingExposed',
        'playback',
        'answeredAt',
        'committedAt',
      ],
      'attempt',
    );
    final SentenceHuntContentIdentity content =
        _readContent(_object(value['content'], 'attempt.content'));
    final SentenceHuntItemDescriptor item =
        _resolveIdentity(descriptors, content);
    final List<String> selected = _stringList(
      value['selectedTokenIds'],
      'attempt.selectedTokenIds',
      unique: true,
    );
    final List<String> expected = _stringList(
      value['expectedTokenIds'],
      'attempt.expectedTokenIds',
      unique: true,
    );
    final bool correct = _boolean(value['correct'], 'attempt.correct');
    final SentenceHuntPlaybackObservation playback = _readPlayback(
      _object(value['playback'], 'attempt.playback'),
      scope,
    );
    final List<String> canonical = _canonicalStoredSelection(item, selected);
    if (!_sameList(canonical, selected) ||
        !_sameList(expected, item.expectedTokenIds) ||
        correct != _equalSet(selected, expected)) {
      throw const FormatException('Attempt selection or grade mismatch.');
    }
    return SentenceHuntAttempt(
      scope: scope,
      content: content,
      runGeneration: _positive(value['runGeneration'], 'attempt.runGeneration'),
      round: _positive(value['round'], 'attempt.round'),
      sequence: _positive(value['sequence'], 'attempt.sequence'),
      selectedTokenIds: selected,
      expectedTokenIds: expected,
      correct: correct,
      presentation: _enum(
        AttemptPresentation.values,
        value['presentation'],
        'attempt.presentation',
      ),
      teachingExposed:
          _boolean(value['teachingExposed'], 'attempt.teachingExposed'),
      playback: playback,
      answeredAt: _utc(value['answeredAt'], 'attempt.answeredAt'),
      committedAt: _utc(value['committedAt'], 'attempt.committedAt'),
    );
  }

  Map<String, Object?> _attemptJson(SentenceHuntAttempt attempt) =>
      <String, Object?>{
        'content': _contentJson(attempt.content),
        'runGeneration': attempt.runGeneration,
        'round': attempt.round,
        'sequence': attempt.sequence,
        'selectedTokenIds': attempt.selectedTokenIds,
        'expectedTokenIds': attempt.expectedTokenIds,
        'correct': attempt.correct,
        'presentation': attempt.presentation.name,
        'teachingExposed': attempt.teachingExposed,
        'playback': _playbackJson(attempt.playback),
        'answeredAt': _date(attempt.answeredAt),
        'committedAt': _date(attempt.committedAt),
      };

  Map<String, Object?> _playbackJson(
          SentenceHuntPlaybackObservation playback) =>
      <String, Object?>{
        'referenceId': playback.referenceId,
        'outcome': playback.outcome.name,
        'source': playback.source.name,
        'runGeneration': playback.runGeneration,
        'round': playback.round,
        'uiGeneration': playback.uiGeneration,
        'content': _contentJson(playback.content),
      };

  Map<String, Object?> _contentJson(SentenceHuntContentIdentity identity) =>
      <String, Object?>{
        'sectionId': identity.sectionId,
        'itemId': identity.itemId,
        'sentenceId': identity.sentenceId,
        'audioRefId': identity.audioRefId,
        'annotationHash': identity.annotationHash,
        'contentRevision': identity.contentRevision,
        'annotationRevision': identity.annotationRevision,
      };

  String _tupleKey(List<Object?> tuple) => jsonEncode(tuple);
}

final class _SentenceSectionDescriptor {
  const _SentenceSectionDescriptor({
    required this.sectionId,
    required this.kind,
    required this.contentRevision,
    required this.policyRevision,
    required this.thresholdPercent,
    required this.fingerprint,
    required this.items,
  });

  final String sectionId;
  final String kind;
  final int contentRevision;
  final int policyRevision;
  final int thresholdPercent;
  final String fingerprint;
  final List<SentenceHuntItemDescriptor> items;
}

final class SentenceHuntItemDescriptor {
  const SentenceHuntItemDescriptor({
    required this.identity,
    required this.selectableTokenIds,
    required this.expectedTokenIds,
  });

  final SentenceHuntContentIdentity identity;
  final List<String> selectableTokenIds;
  final List<String> expectedTokenIds;
}

Map<String, _SentenceSectionDescriptor> _knownDescriptors(
    SentenceHuntCatalogue catalogue) {
  final Map<String, _SentenceSectionDescriptor> descriptors =
      <String, _SentenceSectionDescriptor>{};
  for (final SentenceHuntSection section in catalogue.sections) {
    final _SentenceSectionDescriptor descriptor = _parseFingerprint(
      section.sectionFingerprint,
      sectionId: section.id,
    );
    if (descriptor.contentRevision != section.contentRevision ||
        descriptor.policyRevision != section.policyRevision ||
        descriptor.thresholdPercent !=
            section.policy.completionThresholdPercent ||
        descriptor.items.length != section.items.length) {
      throw const FormatException('Current section descriptor mismatch.');
    }
    for (var index = 0; index < section.items.length; index++) {
      final SentenceHuntItem item = section.items[index];
      final SentenceHuntItemDescriptor parsed = descriptor.items[index];
      if (item.identity != parsed.identity ||
          !_sameList(item.selectableTokenIds, parsed.selectableTokenIds) ||
          !_sameList(item.expectedTokenIds, parsed.expectedTokenIds)) {
        throw const FormatException('Current item descriptor mismatch.');
      }
    }
    _insertDescriptor(descriptors, descriptor);
  }
  for (final SentenceHuntHistoricalDescriptor historical
      in catalogue.historicalSections) {
    if (!_knownSentenceSectionIds.contains(historical.sectionId)) {
      throw const FormatException('Unknown historical sentence section.');
    }
    final _SentenceSectionDescriptor descriptor = _parseFingerprint(
      historical.sectionFingerprint,
      sectionId: historical.sectionId,
    );
    if (descriptor.kind != historical.kind.name ||
        descriptor.contentRevision != historical.contentRevision ||
        descriptor.policyRevision != historical.policyRevision ||
        descriptor.thresholdPercent != historical.completionThresholdPercent) {
      throw const FormatException('Historical section descriptor mismatch.');
    }
    _insertDescriptor(descriptors, descriptor);
  }
  return descriptors;
}

void _insertDescriptor(
  Map<String, _SentenceSectionDescriptor> descriptors,
  _SentenceSectionDescriptor descriptor,
) {
  final String key = _descriptorKey(
    descriptor.sectionId,
    descriptor.contentRevision,
    descriptor.fingerprint,
  );
  final _SentenceSectionDescriptor? old = descriptors[key];
  if (old != null && !_sameDescriptor(old, descriptor)) {
    throw const FormatException('Conflicting sentence section descriptors.');
  }
  descriptors[key] = descriptor;
}

_SentenceSectionDescriptor _parseFingerprint(
  String fingerprint, {
  required String sectionId,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(fingerprint);
  } on FormatException {
    throw const FormatException('Section fingerprint is invalid JSON.');
  }
  if (decoded is! Map<String, dynamic> ||
      _canonicalJson(decoded) != fingerprint) {
    throw const FormatException('Section fingerprint is not canonical JSON.');
  }
  final Map<String, Object?> root = _object(decoded, 'section fingerprint');
  _exactKeys(root, const <String>['items', 'section'], 'section fingerprint');
  final Map<String, Object?> section =
      _object(root['section'], 'fingerprint.section');
  _exactKeys(
    section,
    const <String>[
      'id',
      'kind',
      'contentRevision',
      'policyRevision',
      'completionThresholdPercent',
    ],
    'fingerprint.section',
  );
  final String embeddedId = _string(section['id'], 'fingerprint.section.id');
  final String kind = _string(section['kind'], 'fingerprint.section.kind');
  if (embeddedId != sectionId ||
      !_knownSentenceSectionIds.contains(sectionId) ||
      !const <String>{'vowels', 'consonants', 'mixed'}.contains(kind)) {
    throw const FormatException('Fingerprint section identity is unknown.');
  }
  final int contentRevision =
      _positive(section['contentRevision'], 'fingerprint.contentRevision');
  final int policyRevision =
      _positive(section['policyRevision'], 'fingerprint.policyRevision');
  final int threshold = _positive(
      section['completionThresholdPercent'], 'fingerprint.thresholdPercent');
  if (threshold > 100) {
    throw const FormatException('Fingerprint threshold is out of range.');
  }
  final List<Object?> rows = _array(root['items'], 'fingerprint.items');
  if (rows.length != 5) {
    throw const FormatException('Fingerprint must retain all five items.');
  }
  final List<SentenceHuntItemDescriptor> items = <SentenceHuntItemDescriptor>[];
  final Set<String> itemIds = <String>{};
  for (final Object? row in rows) {
    final Map<String, Object?> item = _object(row, 'fingerprint.item');
    _exactKeys(
      item,
      const <String>[
        'id',
        'sentenceId',
        'audioRefId',
        'purpose',
        'targetSound',
        'targetLabel',
        'text',
        'debriefNote',
        'annotationRevision',
        'annotationHash',
        'tokens',
        'expectedTokenIds',
        'originalSha256',
        'clipSha256',
      ],
      'fingerprint.item',
    );
    final String itemId = _string(item['id'], 'fingerprint.item.id');
    if (!itemIds.add(itemId)) {
      throw const FormatException('Duplicate item identity in fingerprint.');
    }
    final String sentenceId =
        _string(item['sentenceId'], 'fingerprint.item.sentenceId');
    final String referenceId =
        _string(item['audioRefId'], 'fingerprint.item.audioRefId');
    if (_string(item['purpose'], 'fingerprint.item.purpose') != 'practice') {
      throw const FormatException('Unknown sentence item purpose.');
    }
    _string(item['targetSound'], 'fingerprint.item.targetSound');
    _string(item['targetLabel'], 'fingerprint.item.targetLabel');
    _string(item['text'], 'fingerprint.item.text');
    _string(item['debriefNote'], 'fingerprint.item.debriefNote');
    final int annotationRevision =
        _positive(item['annotationRevision'], 'fingerprint.annotationRevision');
    final String annotationHash =
        _string(item['annotationHash'], 'fingerprint.annotationHash');
    final String originalHash =
        _string(item['originalSha256'], 'fingerprint.originalSha256');
    final String clipHash =
        _string(item['clipSha256'], 'fingerprint.clipSha256');
    if (!_isSha256(annotationHash) ||
        !_isSha256(originalHash) ||
        !_isSha256(clipHash)) {
      throw const FormatException('Fingerprint contains malformed hashes.');
    }
    final List<Object?> tokens = _array(item['tokens'], 'fingerprint.tokens');
    if (tokens.isEmpty) {
      throw const FormatException('Fingerprint item has no selectable words.');
    }
    final List<String> selectable = <String>[];
    for (final Object? tokenValue in tokens) {
      final Map<String, Object?> token =
          _object(tokenValue, 'fingerprint.token');
      _exactKeys(
          token, const <String>['id', 'text', 'phonemes'], 'fingerprint.token');
      final String tokenId = _string(token['id'], 'fingerprint.token.id');
      _string(token['text'], 'fingerprint.token.text');
      final List<String> phonemes =
          _stringList(token['phonemes'], 'fingerprint.token.phonemes');
      if (phonemes.isEmpty || selectable.contains(tokenId)) {
        throw const FormatException('Malformed selectable sentence token.');
      }
      selectable.add(tokenId);
    }
    final List<String> expected = _stringList(
      item['expectedTokenIds'],
      'fingerprint.expectedTokenIds',
      unique: true,
    );
    if (expected.isEmpty ||
        expected.any((String id) => !selectable.contains(id))) {
      throw const FormatException(
          'Fingerprint key is not a selectable token set.');
    }
    items.add(SentenceHuntItemDescriptor(
      identity: SentenceHuntContentIdentity(
        sectionId: sectionId,
        itemId: itemId,
        sentenceId: sentenceId,
        audioRefId: referenceId,
        annotationHash: annotationHash,
        contentRevision: contentRevision,
        annotationRevision: annotationRevision,
      ),
      selectableTokenIds: List<String>.unmodifiable(selectable),
      expectedTokenIds: List<String>.unmodifiable(expected),
    ));
  }
  return _SentenceSectionDescriptor(
    sectionId: sectionId,
    kind: kind,
    contentRevision: contentRevision,
    policyRevision: policyRevision,
    thresholdPercent: threshold,
    fingerprint: fingerprint,
    items: List<SentenceHuntItemDescriptor>.unmodifiable(items),
  );
}

void _validateAnswerAgainstDescriptor(
  AnswerSentenceHuntItem action,
  _SentenceSectionDescriptor descriptor,
) {
  final SentenceHuntAnswer answer = action.answer;
  final SentenceHuntItemDescriptor item = _resolveIdentity(
    <String, _SentenceSectionDescriptor>{
      _descriptorKey(descriptor.sectionId, descriptor.contentRevision,
          descriptor.fingerprint): descriptor,
    },
    answer.content,
  );
  if (!_sameList(answer.expectedTokenIdsSnapshot, item.expectedTokenIds) ||
      !_sameList(_canonicalStoredSelection(item, answer.selectedTokenIds),
          answer.selectedTokenIds)) {
    throw const FormatException('Canonical answer is not registered.');
  }
  final SentenceHuntPlaybackObservation playback = answer.playback;
  if (playback.content != answer.content ||
      playback.referenceId != answer.content.audioRefId ||
      playback.outcome != CourseAudioOutcome.completed ||
      playback.source != CourseAudioSource.reviewedRecording) {
    throw const FormatException('Canonical answer has invalid playback facts.');
  }
}

final class _SentenceHuntStructuralIndex {
  const _SentenceHuntStructuralIndex({
    required this.receiptsById,
    required this.commandsById,
    required this.latestCommandsBySection,
  });

  final Map<String, SentenceHuntReceipt> receiptsById;
  final Map<String, SentenceHuntLearningCommand> commandsById;
  final Map<String, SentenceHuntLearningCommand> latestCommandsBySection;
}

/// Checks document-wide consistency without deciding whether any content key
/// is registered. It is shared by encode and decode; registry membership stays
/// in the decode-side validation below, which has an explicit catalogue.
_SentenceHuntStructuralIndex _validateStateStructure(
  SentenceHuntLearningState state,
  SentenceHuntLearningLimits limits,
) {
  _validateBounds(state, limits);
  if (state.revision != state.commitOrdinal) {
    throw const FormatException('Document counters are inconsistent.');
  }
  final int retainedReceiptCount = state.commitOrdinal < limits.maxReceipts
      ? state.commitOrdinal
      : limits.maxReceipts;
  if (state.receipts.length != retainedReceiptCount) {
    throw const FormatException('Receipt history is incomplete.');
  }

  final Map<String, SentenceHuntReceipt> receiptsById =
      <String, SentenceHuntReceipt>{};
  final Map<String, SentenceHuntLearningCommand> commandsById =
      <String, SentenceHuntLearningCommand>{};
  final Map<String, SentenceHuntLearningCommand> latestCommandsBySection =
      <String, SentenceHuntLearningCommand>{};
  final Map<String, SentenceHuntReceipt> previousReceiptBySection =
      <String, SentenceHuntReceipt>{};
  final Set<String> tokens = <String>{};
  var expectedReceiptOrdinal = state.commitOrdinal - state.receipts.length + 1;
  for (final SentenceHuntReceipt receipt in state.receipts) {
    if (receipt.commitOrdinal != expectedReceiptOrdinal) {
      throw const FormatException('Receipt history has a gap.');
    }
    expectedReceiptOrdinal++;
    final SentenceHuntReceipt? previous =
        previousReceiptBySection[receipt.sectionId];
    if (previous != null && previous.after != receipt.before) {
      throw const FormatException('Receipt cursors are discontinuous.');
    }
    final SentenceHuntLearningCommand command =
        _readCommandForStructure(receipt.canonicalCommand, state.scope);
    _validateReceiptCommandStructure(command, receipt);
    final String id = _attemptId(
      receipt.sectionId,
      receipt.after.generation,
      receipt.after.sequence,
    );
    if (!tokens.add(receipt.token) || receiptsById.containsKey(id)) {
      throw const FormatException('Duplicate sentence-hunt receipt.');
    }
    receiptsById[id] = receipt;
    commandsById[id] = command;
    previousReceiptBySection[receipt.sectionId] = receipt;
    latestCommandsBySection[receipt.sectionId] = command;
    if (!state.slots.containsKey(receipt.sectionId)) {
      throw const FormatException('Receipt has no retained section slot.');
    }
  }

  for (final SentenceHuntAttempt attempt in state.attempts) {
    if (attempt.sequence > state.commitOrdinal ||
        attempt.playback.scope != state.scope ||
        attempt.playback.content != attempt.content ||
        attempt.playback.referenceId != attempt.content.audioRefId ||
        attempt.playback.outcome != CourseAudioOutcome.completed ||
        attempt.playback.source != CourseAudioSource.reviewedRecording) {
      throw const FormatException('Attempt has invalid structural evidence.');
    }
    final SentenceHuntExposureKey exposureKey = SentenceHuntExposureKey(
      scope: state.scope,
      sectionId: attempt.content.sectionId,
      contentRevision: attempt.content.contentRevision,
    );
    if (attempt.teachingExposed &&
        !state.teachingExposure.contains(exposureKey)) {
      throw const FormatException(
          'Attempt exposure lacks durable section exposure.');
    }
    final String id = _attemptId(
      attempt.content.sectionId,
      attempt.runGeneration,
      attempt.sequence,
    );
    final SentenceHuntReceipt? receipt = receiptsById[id];
    if (receipt != null) {
      final SentenceHuntLearningCommand command = commandsById[id]!;
      if (command.action is! AnswerSentenceHuntItem ||
          command.sectionId != attempt.content.sectionId ||
          receipt.after.generation != attempt.runGeneration ||
          receipt.after.sequence != attempt.sequence) {
        throw const FormatException('Attempt links to a non-answer receipt.');
      }
      final SentenceHuntAnswer answer =
          (command.action as AnswerSentenceHuntItem).answer;
      if (answer.content != attempt.content ||
          !_sameList(answer.selectedTokenIds, attempt.selectedTokenIds) ||
          !_sameList(
              answer.expectedTokenIdsSnapshot, attempt.expectedTokenIds) ||
          command.submittedAt != attempt.answeredAt ||
          !_samePlayback(answer.playback, attempt.playback)) {
        throw const FormatException('Attempt/receipt evidence differs.');
      }
    }
  }
  _validateSummaryCoverage(state);
  for (final SentenceHuntSlot slot in state.slots.values) {
    final SentenceHuntReceipt latest = slot.latestReceipt;
    final String id = _attemptId(
      latest.sectionId,
      latest.after.generation,
      latest.after.sequence,
    );
    final SentenceHuntReceipt? retained = receiptsById[id];
    if (latest.sectionId != slot.sectionId ||
        latest.scope != state.scope ||
        latest.commitOrdinal > state.commitOrdinal ||
        latest.after != slot.cursor ||
        (retained != null && !_sameReceipt(retained, latest))) {
      throw const FormatException('Slot latest receipt is inconsistent.');
    }
    for (final SentenceHuntReceipt receipt in state.receipts) {
      if (receipt.sectionId == slot.sectionId &&
          receipt.commitOrdinal > latest.commitOrdinal) {
        throw const FormatException(
            'Slot receipt is not latest for its section.');
      }
    }
    final SentenceHuntLearningCommand command = commandsById[id] ??
        _readCommandForStructure(latest.canonicalCommand, state.scope);
    _validateReceiptCommandStructure(command, latest);
    if (command.sectionFingerprint != slot.checkpoint.sectionFingerprint) {
      throw const FormatException('Slot receipt and checkpoint keys differ.');
    }
    final Object? rawItemIds = slot.checkpoint.sessionJson['itemIds'];
    if (rawItemIds is! List ||
        rawItemIds.length != 5 ||
        rawItemIds.any((Object? value) => value is! String)) {
      throw const FormatException('Checkpoint session item ids are invalid.');
    }
    final List<String> itemIds = rawItemIds.cast<String>();
    if (itemIds.toSet().length != itemIds.length) {
      throw const FormatException(
          'Checkpoint session item ids are duplicated.');
    }
    final LessonSectionSession session = LessonSectionSession.fromJson(
      _mutableJson(slot.checkpoint.sessionJson) as Map<String, dynamic>,
      itemIds: itemIds,
      contentRevision: slot.checkpoint.contentRevision,
    );
    if (session.sessionId != slot.checkpoint.sessionId ||
        session.contentRevision != slot.checkpoint.contentRevision ||
        session.policy.completionThresholdPercent !=
            slot.checkpoint.policy.completionThresholdPercent ||
        slot.checkpoint.runStartRound > session.round ||
        (slot.checkpoint.finished &&
            session.phase != LessonSectionPhase.debrief)) {
      throw const FormatException(
          'Checkpoint/session metadata is inconsistent.');
    }
    _validateLatestSlotStructure(state, slot, command, session);
    latestCommandsBySection[slot.sectionId] = command;
  }
  return _SentenceHuntStructuralIndex(
    receiptsById: receiptsById,
    commandsById: commandsById,
    latestCommandsBySection: latestCommandsBySection,
  );
}

void _validateState(
  SentenceHuntLearningState state,
  Map<String, _SentenceSectionDescriptor> descriptors,
  SentenceHuntLearningLimits limits,
) {
  final _SentenceHuntStructuralIndex structural =
      _validateStateStructure(state, limits);
  for (final SentenceHuntReceipt receipt in state.receipts) {
    final String id = _attemptId(
      receipt.sectionId,
      receipt.after.generation,
      receipt.after.sequence,
    );
    _validateReceiptCommand(
      structural.commandsById[id]!,
      receipt,
      descriptors,
    );
  }
  for (final SentenceHuntAttempt attempt in state.attempts) {
    final SentenceHuntItemDescriptor item =
        _resolveIdentity(descriptors, attempt.content);
    if (!_sameList(attempt.expectedTokenIds, item.expectedTokenIds) ||
        !_sameList(_canonicalStoredSelection(item, attempt.selectedTokenIds),
            attempt.selectedTokenIds) ||
        attempt.correct !=
            _equalSet(attempt.selectedTokenIds, item.expectedTokenIds)) {
      throw const FormatException(
          'Attempt is not bound to known sentence content.');
    }
    if (structural.receiptsById.containsKey(_attemptId(
      attempt.content.sectionId,
      attempt.runGeneration,
      attempt.sequence,
    ))) {
      final String id = _attemptId(
        attempt.content.sectionId,
        attempt.runGeneration,
        attempt.sequence,
      );
      final SentenceHuntReceipt receipt = structural.receiptsById[id]!;
      final SentenceHuntLearningCommand command = structural.commandsById[id]!;
      if (command.action is! AnswerSentenceHuntItem ||
          receipt.after.generation != attempt.runGeneration ||
          receipt.after.sequence != attempt.sequence) {
        throw const FormatException('Attempt links to a non-answer receipt.');
      }
    }
  }
  for (final SentenceHuntMistake mistake in state.mistakes.values) {
    _resolveIdentity(descriptors, mistake.content);
  }
  for (final SentenceHuntSummary summary in state.summaries.values) {
    _resolveIdentity(descriptors, summary.content);
  }
  for (final SentenceHuntExposureKey exposure in state.teachingExposure) {
    _descriptorForRevision(
        descriptors, exposure.sectionId, exposure.contentRevision);
  }
  for (final SentenceHuntCompletion completion in state.completions) {
    if (!descriptors.values.any((_SentenceSectionDescriptor descriptor) =>
        descriptor.sectionId == completion.sectionId &&
        descriptor.contentRevision == completion.contentRevision &&
        descriptor.policyRevision == completion.policyRevision &&
        descriptor.thresholdPercent == completion.thresholdPercent)) {
      throw const FormatException('Completion has an unknown policy identity.');
    }
  }
  for (final SentenceHuntSlot slot in state.slots.values) {
    final _SentenceSectionDescriptor descriptor = _descriptor(
      descriptors,
      slot.sectionId,
      slot.checkpoint.contentRevision,
      slot.checkpoint.sectionFingerprint,
    );
    _validateLatestSlot(
      state,
      slot,
      descriptor,
      descriptors,
      structural.receiptsById,
      structural.latestCommandsBySection[slot.sectionId]!,
    );
  }
}

void _validateBounds(
  SentenceHuntLearningState state,
  SentenceHuntLearningLimits limits,
) {
  if (state.attempts.length > limits.maxAttempts ||
      state.receipts.length > limits.maxReceipts ||
      state.mistakes.length > limits.maxAggregateEntries ||
      state.summaries.length > limits.maxAggregateEntries ||
      state.completions.length > limits.maxAggregateEntries ||
      state.teachingExposure.length > limits.maxAggregateEntries ||
      state.slots.length > sentenceHuntMaxSlots) {
    throw const FormatException(
        'Sentence-hunt state exceeds configured bounds.');
  }
}

void _validateSummaryCoverage(SentenceHuntLearningState state) {
  final Map<SentenceHuntSummaryKey, List<int>> retained =
      <SentenceHuntSummaryKey, List<int>>{};
  for (final SentenceHuntAttempt attempt in state.attempts) {
    final SentenceHuntSummaryKey key = SentenceHuntSummaryKey(
      scope: state.scope,
      content: attempt.content,
    );
    final List<int> counts =
        retained.putIfAbsent(key, () => List<int>.filled(8, 0));
    final bool first = attempt.presentation == AttemptPresentation.firstInRun;
    final bool exposed = attempt.teachingExposed;
    final int base = first ? 0 : 2;
    counts[base]++;
    if (attempt.correct) counts[base + 1]++;
    if (exposed) {
      counts[first ? 4 : 6]++;
      if (attempt.correct) counts[first ? 5 : 7]++;
    }
  }
  for (final MapEntry<SentenceHuntSummaryKey, List<int>> entry
      in retained.entries) {
    final SentenceHuntSummary? summary = state.summaries[entry.key];
    if (summary == null ||
        summary.firstInRun.total < entry.value[0] ||
        summary.firstInRun.correct < entry.value[1] ||
        summary.repeatInRun.total < entry.value[2] ||
        summary.repeatInRun.correct < entry.value[3] ||
        summary.firstTeachingExposed.total < entry.value[4] ||
        summary.firstTeachingExposed.correct < entry.value[5] ||
        summary.repeatTeachingExposed.total < entry.value[6] ||
        summary.repeatTeachingExposed.correct < entry.value[7]) {
      throw const FormatException('Summary undercounts retained attempts.');
    }
  }
}

SentenceHuntLearningCommand _readCommandForStructure(
  String raw,
  SentenceHuntProfileScope scope,
) =>
    const SentenceHuntLearningCodec()._readCanonicalCommand(raw, scope, null);

void _validateReceiptCommand(
  SentenceHuntLearningCommand command,
  SentenceHuntReceipt receipt,
  Map<String, _SentenceSectionDescriptor> descriptors,
) {
  _validateReceiptCommandStructure(command, receipt);
  final _SentenceSectionDescriptor descriptor = _descriptorByFingerprint(
    descriptors,
    command.sectionId,
    command.sectionFingerprint,
  );
  if (command.action case final AnswerSentenceHuntItem answer) {
    _validateAnswerAgainstDescriptor(answer, descriptor);
    if (answer.answer.playback.runGeneration != receipt.after.generation) {
      throw const FormatException('Receipt answer generation mismatch.');
    }
  } else if (command.action case StartSentenceHuntRun(:final policy)) {
    if (policy.completionThresholdPercent != descriptor.thresholdPercent) {
      throw const FormatException(
          'Start policy differs from its registered descriptor.');
    }
  }
}

void _validateReceiptCommandStructure(
  SentenceHuntLearningCommand command,
  SentenceHuntReceipt receipt,
) {
  if (command.scope != receipt.scope ||
      command.sectionId != receipt.sectionId ||
      command.token != receipt.token ||
      command.expected != receipt.before ||
      !_reachableActionCursor(command.action, receipt.before, receipt.after)) {
    throw const FormatException('Receipt header is not reachable.');
  }
  if (command.action case AnswerSentenceHuntItem(:final answer)) {
    _validateAnswerStructure(answer, command.scope);
    if (answer.content.sectionId != command.sectionId ||
        answer.playback.runGeneration != receipt.after.generation) {
      throw const FormatException('Receipt answer identity is inconsistent.');
    }
  }
}

void _validateAnswerStructure(
  SentenceHuntAnswer answer,
  SentenceHuntProfileScope scope,
) {
  final SentenceHuntPlaybackObservation playback = answer.playback;
  if (answer.expectedTokenIdsSnapshot.isEmpty ||
      answer.selectedTokenIds.toSet().length !=
          answer.selectedTokenIds.length ||
      answer.expectedTokenIdsSnapshot.toSet().length !=
          answer.expectedTokenIdsSnapshot.length ||
      answer.selectedTokenIds.any((String id) => id.trim().isEmpty) ||
      answer.expectedTokenIdsSnapshot.any((String id) => id.trim().isEmpty) ||
      playback.scope != scope ||
      playback.content != answer.content ||
      playback.referenceId != answer.content.audioRefId ||
      playback.outcome != CourseAudioOutcome.completed ||
      playback.source != CourseAudioSource.reviewedRecording) {
    throw const FormatException('Answer has invalid structural evidence.');
  }
}

void _validateLatestSlotStructure(
  SentenceHuntLearningState state,
  SentenceHuntSlot slot,
  SentenceHuntLearningCommand command,
  LessonSectionSession session,
) {
  switch (command.action) {
    case final StartSentenceHuntRun start:
      if (slot.checkpoint.finished ||
          slot.checkpoint.sessionId != start.sessionId ||
          slot.checkpoint.mode != start.mode ||
          slot.checkpoint.policy.completionThresholdPercent !=
              start.policy.completionThresholdPercent ||
          session.policy.completionThresholdPercent !=
              start.policy.completionThresholdPercent) {
        throw const FormatException('Latest Start metadata differs from slot.');
      }
      if (start.mode == SentenceHuntRunMode.practice) {
        final Object? rawItemIds = slot.checkpoint.sessionJson['itemIds'];
        final List<String> itemIds = (rawItemIds as List).cast<String>();
        final LessonSectionSession fresh = LessonSectionSession(
          itemIds: itemIds,
          sessionId: start.sessionId,
          contentRevision: slot.checkpoint.contentRevision,
          policy: start.policy,
        );
        if (jsonEncode(fresh.toJson()) != jsonEncode(session.toJson())) {
          throw const FormatException('Latest practice Start is not fresh.');
        }
      } else if (session.round != slot.checkpoint.runStartRound ||
          session.phase != LessonSectionPhase.exercise ||
          session.round < 2) {
        throw const FormatException('Latest review-only Start is unreachable.');
      }
    case AnswerSentenceHuntItem(:final answer):
      final String? currentId = session.currentItemId;
      final bool correct =
          _equalSet(answer.selectedTokenIds, answer.expectedTokenIdsSnapshot);
      if (slot.checkpoint.finished ||
          currentId != answer.content.itemId ||
          answer.content.sectionId != slot.sectionId ||
          !session.answered ||
          session.round != answer.playback.round ||
          session.lastCorrect != correct ||
          session.latestAnswers[currentId] != correct) {
        throw const FormatException('Latest answer consequences mismatch.');
      }
    case AdvanceSentenceHuntItem():
      if (slot.checkpoint.finished ||
          session.answered ||
          session.position == 0) {
        throw const FormatException(
            'Latest Advance lacks a submitted queue prefix.');
      }
    case ReviewSentenceHuntMistakes():
      if (slot.checkpoint.finished ||
          session.phase != LessonSectionPhase.exercise ||
          session.round < 2) {
        throw const FormatException(
            'Latest Review did not start a review round.');
      }
    case FinishSentenceHuntRun():
      if (!slot.checkpoint.finished ||
          session.phase != LessonSectionPhase.debrief) {
        throw const FormatException('Latest Finish is not a finished debrief.');
      }
      if (slot.checkpoint.mode == SentenceHuntRunMode.practice &&
          session.canComplete &&
          !state.completions.any((SentenceHuntCompletion completion) =>
              completion.sectionId == slot.sectionId &&
              completion.contentRevision == slot.checkpoint.contentRevision &&
              completion.thresholdPercent ==
                  slot.checkpoint.policy.completionThresholdPercent)) {
        throw const FormatException(
            'Eligible practice finish lacks completion.');
      }
  }
}

bool _reachableActionCursor(
  SentenceHuntAction action,
  LearningCursorPosition before,
  LearningCursorPosition after,
) {
  if (!_validCursor(before) || !_validCursor(after)) return false;
  final bool start = action is StartSentenceHuntRun;
  if (start) {
    if (before.generation == 0) {
      return before.sequence == 0 &&
          before.revision == 0 &&
          after.generation == 1 &&
          after.sequence == 1 &&
          after.revision == 0;
    }
    return before.generation < sentenceHuntMaxSafeInteger &&
        before.sequence < sentenceHuntMaxSafeInteger &&
        after.generation == before.generation + 1 &&
        after.sequence == before.sequence + 1 &&
        after.revision == 0;
  }
  return before.generation > 0 &&
      before.sequence < sentenceHuntMaxSafeInteger &&
      before.revision < sentenceHuntMaxSafeInteger &&
      after.generation == before.generation &&
      after.sequence == before.sequence + 1 &&
      after.revision == before.revision + 1;
}

bool _validCursor(LearningCursorPosition cursor) =>
    cursor.generation >= 0 &&
    cursor.generation <= sentenceHuntMaxSafeInteger &&
    cursor.sequence >= 0 &&
    cursor.sequence <= sentenceHuntMaxSafeInteger &&
    cursor.revision >= 0 &&
    cursor.revision <= sentenceHuntMaxSafeInteger;

void _validateLatestSlot(
  SentenceHuntLearningState state,
  SentenceHuntSlot slot,
  _SentenceSectionDescriptor descriptor,
  Map<String, _SentenceSectionDescriptor> descriptors,
  Map<String, SentenceHuntReceipt> receiptsById,
  SentenceHuntLearningCommand command,
) {
  final SentenceHuntReceipt receipt = slot.latestReceipt;
  if (receipt.commitOrdinal > state.commitOrdinal ||
      receipt.after != slot.cursor ||
      receipt.sectionId != slot.sectionId) {
    throw const FormatException('Slot latest receipt is inconsistent.');
  }
  _validateReceiptCommand(command, receipt, descriptors);
  if (command.sectionFingerprint != descriptor.fingerprint) {
    throw const FormatException('Slot receipt and checkpoint keys differ.');
  }
  final LessonSectionSession session = LessonSectionSession.fromJson(
    _mutableJson(slot.checkpoint.sessionJson) as Map<String, dynamic>,
    itemIds: descriptor.items
        .map((SentenceHuntItemDescriptor item) => item.identity.itemId)
        .toList(growable: false),
    contentRevision: descriptor.contentRevision,
  );
  switch (command.action) {
    case final StartSentenceHuntRun start:
      if (slot.checkpoint.sessionId != start.sessionId ||
          slot.checkpoint.mode != start.mode ||
          slot.checkpoint.policy.completionThresholdPercent !=
              start.policy.completionThresholdPercent) {
        throw const FormatException('Latest Start metadata differs from slot.');
      }
      if (start.mode == SentenceHuntRunMode.practice) {
        final LessonSectionSession fresh = LessonSectionSession(
          itemIds: descriptor.items
              .map((SentenceHuntItemDescriptor item) => item.identity.itemId)
              .toList(growable: false),
          sessionId: start.sessionId,
          contentRevision: descriptor.contentRevision,
          policy: start.policy,
        );
        if (jsonEncode(fresh.toJson()) != jsonEncode(session.toJson())) {
          throw const FormatException('Latest practice Start is not fresh.');
        }
      } else if (session.round <= slot.checkpoint.runStartRound - 1 ||
          session.phase != LessonSectionPhase.exercise) {
        throw const FormatException('Latest review-only Start is unreachable.');
      }
      if (slot.checkpoint.finished) {
        throw const FormatException('Latest Start cannot be finished.');
      }
    case AnswerSentenceHuntItem(:final answer):
      final SentenceHuntItemDescriptor item =
          _resolveIdentity(descriptors, answer.content);
      final bool correct =
          _equalSet(answer.selectedTokenIds, item.expectedTokenIds);
      final String? currentId = session.currentItemId;
      if (currentId != answer.content.itemId ||
          !session.answered ||
          session.round != answer.playback.round ||
          session.lastCorrect != correct ||
          session.latestAnswers[currentId] != correct) {
        throw const FormatException('Latest answer consequences mismatch.');
      }
      final SentenceHuntAttempt? attempt = state.attempts
          .where((SentenceHuntAttempt candidate) =>
              candidate.content.sectionId == slot.sectionId &&
              candidate.runGeneration == receipt.after.generation &&
              candidate.sequence == receipt.after.sequence)
          .firstOrNull;
      if (attempt != null &&
          (attempt.content != answer.content ||
              attempt.correct != correct ||
              !_sameList(attempt.selectedTokenIds, answer.selectedTokenIds))) {
        throw const FormatException('Latest attempt differs from answer.');
      }
    case AdvanceSentenceHuntItem():
      if (session.answered || session.position == 0) {
        throw const FormatException(
            'Latest Advance lacks a submitted queue prefix.');
      }
    case ReviewSentenceHuntMistakes():
      if (session.phase != LessonSectionPhase.exercise || session.round < 2) {
        throw const FormatException(
            'Latest Review did not start a review round.');
      }
    case FinishSentenceHuntRun():
      if (!slot.checkpoint.finished ||
          session.phase != LessonSectionPhase.debrief) {
        throw const FormatException('Latest Finish is not a finished debrief.');
      }
      if (slot.checkpoint.mode == SentenceHuntRunMode.practice &&
          session.canComplete &&
          !state.completions.any((SentenceHuntCompletion completion) =>
              completion.sectionId == slot.sectionId &&
              completion.contentRevision == descriptor.contentRevision &&
              completion.policyRevision == descriptor.policyRevision &&
              completion.thresholdPercent ==
                  slot.checkpoint.policy.completionThresholdPercent)) {
        throw const FormatException(
            'Eligible practice finish lacks completion.');
      }
  }
  for (final SentenceHuntReceipt retained in state.receipts) {
    if (retained.sectionId == slot.sectionId &&
        retained.commitOrdinal > receipt.commitOrdinal) {
      throw const FormatException(
          'Slot receipt is not latest for its section.');
    }
  }
  final SentenceHuntReceipt? retained = receiptsById[_attemptId(
    slot.sectionId,
    slot.cursor.generation,
    slot.cursor.sequence,
  )];
  if (retained != null && !_sameReceipt(retained, receipt)) {
    throw const FormatException('Slot latest receipt differs from history.');
  }
}

Map<String, Object?> _object(Object? value, String name) {
  if (value is! Map || value.keys.any((Object? key) => key is! String)) {
    throw FormatException('$name must be a string-keyed JSON object.');
  }
  return <String, Object?>{
    for (final MapEntry<Object?, Object?> entry in value.entries)
      entry.key as String: entry.value,
  };
}

List<Object?> _array(Object? value, String name) {
  if (value is! List) throw FormatException('$name must be an array.');
  return value.cast<Object?>();
}

void _exactKeys(
  Map<String, Object?> value,
  List<String> expected,
  String name, {
  bool ordered = false,
}) {
  if (value.length != expected.length ||
      value.keys.any((String key) => !expected.contains(key)) ||
      expected.any((String key) => !value.containsKey(key)) ||
      (ordered && !_sameList(value.keys.toList(), expected))) {
    throw FormatException(
        '$name has unknown, missing, or out-of-order fields.');
  }
}

String _string(Object? value, String name) {
  if (value is! String) throw FormatException('$name must be a string.');
  return value;
}

bool _boolean(Object? value, String name) {
  if (value is! bool) throw FormatException('$name must be a boolean.');
  return value;
}

int _integer(Object? value, String name) {
  if (value is! int || value < 0 || value > sentenceHuntMaxSafeInteger) {
    throw FormatException('$name must be a safe nonnegative integer.');
  }
  return value;
}

int _positive(Object? value, String name) {
  final int integer = _integer(value, name);
  if (integer == 0) throw FormatException('$name must be positive.');
  return integer;
}

List<String> _stringList(Object? value, String name, {bool unique = false}) {
  final List<Object?> raw = _array(value, name);
  final List<String> result = <String>[];
  final Set<String> seen = <String>{};
  for (final Object? element in raw) {
    if (element is! String || element.trim().isEmpty) {
      throw FormatException('$name must contain nonblank strings.');
    }
    if (unique && !seen.add(element)) {
      throw FormatException('$name contains a duplicate.');
    }
    result.add(element);
  }
  return result;
}

LessonPolicy _readPolicy(Object? value, String name) {
  final Map<String, Object?> raw = _object(value, name);
  _exactKeys(raw, const <String>['completionThresholdPercent'], name);
  return LessonPolicy.fromJson(Map<String, dynamic>.from(raw));
}

T _enum<T extends Enum>(List<T> values, Object? value, String name) {
  final String raw = _string(value, name);
  for (final T candidate in values) {
    if (candidate.name == raw) return candidate;
  }
  throw FormatException('$name has an unknown variant.');
}

DateTime _utc(Object? value, String name) {
  final String raw = _string(value, name);
  final DateTime? date = DateTime.tryParse(raw);
  if (date == null || !date.isUtc || date.toIso8601String() != raw) {
    throw FormatException('$name must be canonical UTC ISO-8601.');
  }
  return date;
}

String _date(DateTime value) {
  if (!value.isUtc) throw ArgumentError('Timestamp must be UTC.');
  return value.toIso8601String();
}

String _descriptorKey(String sectionId, int revision, String fingerprint) =>
    jsonEncode(<Object?>[sectionId, revision, fingerprint]);

_SentenceSectionDescriptor _descriptor(
  Map<String, _SentenceSectionDescriptor> descriptors,
  String sectionId,
  int revision,
  String fingerprint,
) {
  final _SentenceSectionDescriptor? result =
      descriptors[_descriptorKey(sectionId, revision, fingerprint)];
  if (result == null) {
    throw const FormatException('Unknown content fingerprint.');
  }
  return result;
}

_SentenceSectionDescriptor _descriptorByFingerprint(
  Map<String, _SentenceSectionDescriptor> descriptors,
  String sectionId,
  String fingerprint,
) {
  for (final _SentenceSectionDescriptor descriptor in descriptors.values) {
    if (descriptor.sectionId == sectionId &&
        descriptor.fingerprint == fingerprint) {
      return descriptor;
    }
  }
  throw const FormatException('Unknown historical command fingerprint.');
}

_SentenceSectionDescriptor _descriptorForRevision(
  Map<String, _SentenceSectionDescriptor> descriptors,
  String sectionId,
  int revision,
) {
  for (final _SentenceSectionDescriptor descriptor in descriptors.values) {
    if (descriptor.sectionId == sectionId &&
        descriptor.contentRevision == revision) {
      return descriptor;
    }
  }
  throw const FormatException('Unknown historical section revision.');
}

SentenceHuntItemDescriptor _resolveItem(
  Map<String, _SentenceSectionDescriptor> descriptors,
  String sectionId,
  String itemId,
  int revision,
) {
  SentenceHuntItemDescriptor? result;
  for (final _SentenceSectionDescriptor descriptor in descriptors.values) {
    if (descriptor.sectionId != sectionId ||
        descriptor.contentRevision != revision) {
      continue;
    }
    for (final SentenceHuntItemDescriptor item in descriptor.items) {
      if (item.identity.itemId != itemId) continue;
      if (result != null && result.identity != item.identity) {
        throw const FormatException('Ambiguous historical content key.');
      }
      result = item;
    }
  }
  if (result == null) {
    throw const FormatException('Unknown historical item key.');
  }
  return result;
}

SentenceHuntItemDescriptor _resolveIdentity(
  Map<String, _SentenceSectionDescriptor> descriptors,
  SentenceHuntContentIdentity identity,
) {
  for (final _SentenceSectionDescriptor descriptor in descriptors.values) {
    if (descriptor.sectionId != identity.sectionId ||
        descriptor.contentRevision != identity.contentRevision) {
      continue;
    }
    for (final SentenceHuntItemDescriptor item in descriptor.items) {
      if (item.identity == identity) {
        return item;
      }
    }
  }
  throw const FormatException('Unknown sentence-hunt content identity.');
}

List<String> _canonicalStoredSelection(
  SentenceHuntItemDescriptor item,
  Iterable<String> ids,
) {
  final Set<String> selectable = item.selectableTokenIds.toSet();
  final Set<String> selected = <String>{};
  for (final String id in ids) {
    if (!selectable.contains(id) || !selected.add(id)) {
      throw const FormatException(
          'Selection has unknown or duplicate token IDs.');
    }
  }
  return <String>[
    for (final String id in item.selectableTokenIds)
      if (selected.contains(id)) id,
  ];
}

bool _equalSet(List<String> a, List<String> b) =>
    a.length == b.length && a.toSet().containsAll(b);

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

bool _sameDescriptor(
  _SentenceSectionDescriptor a,
  _SentenceSectionDescriptor b,
) =>
    a.sectionId == b.sectionId &&
    a.kind == b.kind &&
    a.contentRevision == b.contentRevision &&
    a.policyRevision == b.policyRevision &&
    a.thresholdPercent == b.thresholdPercent &&
    a.fingerprint == b.fingerprint;

bool _samePlayback(
  SentenceHuntPlaybackObservation a,
  SentenceHuntPlaybackObservation b,
) =>
    a.scope == b.scope &&
    a.content == b.content &&
    a.runGeneration == b.runGeneration &&
    a.round == b.round &&
    a.uiGeneration == b.uiGeneration &&
    a.referenceId == b.referenceId &&
    a.outcome == b.outcome &&
    a.source == b.source;

String _attemptId(String sectionId, int generation, int sequence) =>
    jsonEncode(<Object?>[sectionId, generation, sequence]);

bool _sameReceipt(SentenceHuntReceipt a, SentenceHuntReceipt b) =>
    a.scope == b.scope &&
    a.sectionId == b.sectionId &&
    a.token == b.token &&
    a.canonicalCommand == b.canonicalCommand &&
    a.before == b.before &&
    a.after == b.after &&
    a.commitOrdinal == b.commitOrdinal;

int _compareMistakeKeys(SentenceHuntMistakeKey a, SentenceHuntMistakeKey b) =>
    _compareContent(a.content, b.content);

int _compareSummaryKeys(SentenceHuntSummaryKey a, SentenceHuntSummaryKey b) =>
    _compareContent(a.content, b.content);

int _compareContent(
    SentenceHuntContentIdentity a, SentenceHuntContentIdentity b) {
  final int section = a.sectionId.compareTo(b.sectionId);
  if (section != 0) return section;
  final int item = a.itemId.compareTo(b.itemId);
  if (item != 0) return item;
  return a.contentRevision.compareTo(b.contentRevision);
}

int _compareExposureKeys(SentenceHuntExposureKey a, SentenceHuntExposureKey b) {
  final int section = a.sectionId.compareTo(b.sectionId);
  return section != 0
      ? section
      : a.contentRevision.compareTo(b.contentRevision);
}

bool _isSha256(String value) => RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

String _canonicalJson(Object? value) => jsonEncode(_canonicalValue(value));

Object? _canonicalValue(Object? value) {
  if (value is Map) {
    final List<String> keys = value.keys.cast<String>().toList()..sort();
    return <String, Object?>{
      for (final String key in keys) key: _canonicalValue(value[key]),
    };
  }
  if (value is List) {
    return <Object?>[
      for (final Object? element in value) _canonicalValue(element),
    ];
  }
  return value;
}

Object? _mutableJson(Object? value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final MapEntry<Object?, Object?> entry in value.entries)
        entry.key as String: _mutableJson(entry.value),
    };
  }
  if (value is List) {
    final List<Object?> copy =
        value.map<Object?>((Object? item) => _mutableJson(item)).toList();
    return copy.every((Object? item) => item is String)
        ? copy.cast<String>()
        : copy;
  }
  return value;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final Iterator<T> iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
