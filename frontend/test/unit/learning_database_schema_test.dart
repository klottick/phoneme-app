import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_checkpoint.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/french_comparison_content.dart';
import 'package:linguist/src/core/course/french_course.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/features/arcade/sound_match_engine.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart';
import 'package:linguist/src/core/course/storage/learning_tables.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../support/learning_migration_failure_probe.dart';
import '../support/sqlite_learning_test_harness.dart';

const List<String> _indexNames = <String>[
  'ux_learning_scopes_owner_course_family',
  'ux_learning_content_bindings_identity',
  'ux_learning_runs_scope_activity',
  'ux_learning_runs_scope_latest_receipt_token',
  'ux_learning_attempts_scope_attempt',
  'ux_learning_attempts_command_batch',
  'ux_learning_attempt_values_attempt_field_ordinal',
  'ux_learning_attempt_evidence_attempt_index',
  'ux_learning_command_receipts_scope_token',
  'ux_learning_command_receipts_activity_cursor',
  'ux_learning_mistakes_identity',
  'ux_learning_summaries_identity_bucket',
  'ux_learning_completions_identity',
  'ux_learning_exposure_identity',
  'ux_learning_best_scores_scope_activity',
  'ux_supported_sync_outbox_scope_event',
  'ux_supported_sync_outbox_scope_enqueue_order',
  'ix_learning_attempts_scope_commit_batch',
  'ix_learning_receipts_scope_commit_ordinal',
  'ix_learning_runs_scope_cursor',
];

const List<String> _triggerBases = <String>[
  'trg_learning_content_bindings_scope_family',
  'trg_learning_runs_scope_binding_family',
  'trg_learning_attempts_scope_family',
  'trg_learning_attempt_values_scope_family',
  'trg_learning_attempt_evidence_scope_family',
  'trg_learning_mistakes_scope_family',
  'trg_learning_summaries_scope_family',
  'trg_learning_completions_scope_family',
  'trg_learning_exposure_scope_family',
  'trg_supported_sync_outbox_account_course',
];

const Set<String> _integerColumns = <String>{
  'id',
  'scope_id',
  'schema_version',
  'revision',
  'commit_ordinal',
  'content_revision',
  'policy_revision',
  'annotation_revision',
  'run_generation',
  'sequence',
  'cursor_revision',
  'content_binding_id',
  'finished',
  'threshold_percent',
  'run_start_round',
  'latest_receipt_before_generation',
  'latest_receipt_before_sequence',
  'latest_receipt_before_cursor_revision',
  'latest_receipt_commit_ordinal',
  'command_sequence',
  'batch_index',
  'item_occurrence',
  'answered_at_us',
  'committed_at_us',
  'correct',
  'assistance_mask',
  'round',
  'after_debrief',
  'teaching_exposed',
  'ordinal',
  'int_value',
  'bool_value',
  'evidence_index',
  'ui_generation',
  'before_generation',
  'before_sequence',
  'before_cursor_revision',
  'after_generation',
  'after_sequence',
  'after_cursor_revision',
  'result_generation',
  'result_sequence',
  'result_cursor_revision',
  'first_wrong_at_us',
  'latest_wrong_at_us',
  'failure_count',
  'last_run_generation',
  'total',
  'presentations',
  'score',
  'enqueue_commit_ordinal',
  'enqueue_event_index',
};

const Map<String, Set<String>> _nullableColumns = <String, Set<String>>{
  'learning_scopes': <String>{},
  'learning_content_bindings': <String>{
    'policy_kind',
    'policy_revision',
    'catalogue_fingerprint',
    'section_fingerprint',
    'annotation_hash',
    'annotation_revision',
  },
  'learning_runs': <String>{
    'run_mode',
    'session_id',
    'policy_revision',
    'threshold_percent',
    'run_start_round',
  },
  'learning_attempts': <String>{
    'item_id',
    'item_occurrence',
    'skill',
    'origin',
    'presentation',
    'assistance_mask',
    'content_state',
    'audio_source',
    'round',
    'after_debrief',
    'teaching_exposed',
    'selected_relation',
    'expected_relation',
    'section_id',
    'sentence_id',
    'annotation_hash',
    'annotation_revision',
  },
  'learning_attempt_values': <String>{'text_value', 'int_value', 'bool_value'},
  'learning_attempt_evidence': <String>{
    'slot',
    'reference_id',
    'outcome',
    'source',
    'activity_id',
    'run_generation',
    'round',
    'pair_id',
    'ui_generation',
    'section_id',
    'item_id',
    'sentence_id',
    'audio_ref_id',
    'annotation_hash',
    'annotation_revision',
    'content_revision',
  },
  'learning_command_receipts': <String>{},
  'learning_mistakes': <String>{
    'activity_id',
    'item_id',
    'target_sound',
    'skill',
    'pair_id',
    'section_id',
    'sentence_id',
    'audio_ref_id',
    'annotation_hash',
    'annotation_revision',
    'first_wrong_attempt_id',
    'latest_wrong_attempt_id',
    'last_run_generation',
  },
  'learning_summaries': <String>{
    'activity_id',
    'sound',
    'skill',
    'origin',
    'presentation',
    'assistance_mask',
    'pair_id',
    'section_id',
    'item_id',
    'sentence_id',
    'audio_ref_id',
    'annotation_hash',
    'annotation_revision',
    'content_revision',
  },
  'learning_completions': <String>{},
  'learning_exposure': <String>{
    'activity_id',
    'item_id',
    'target_sound',
    'section_id',
    'content_revision',
    'presentations',
    'assistance_mask',
  },
  'learning_best_scores': <String>{},
  'supported_sync_outbox': <String>{
    'sound',
    'skill',
    'correct',
    'activity',
    'lesson_id',
    'game',
    'score',
  },
};

Future<LearningDatabase> _openDatabase() async {
  final directory = await Directory.systemTemp.createTemp('learning-schema-');
  addTearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });
  return openFileLearningTestDatabase(
    File('${directory.path}/learning.sqlite'),
  );
}

Future<File> _createVersionOneFile(Directory directory, String name) async {
  final file = File('${directory.path}/$name.sqlite');
  final database = await openFileLearningTestDatabase(file);
  await database.customSelect('SELECT 1').getSingle();
  await database.close();
  return file;
}

void _rewriteSchemaSql(
  sqlite.Database raw, {
  required String objectType,
  required String objectName,
  required String remove,
}) {
  final rows = raw.select(
    'SELECT sql FROM sqlite_schema WHERE type = ? AND name = ?',
    <Object?>[objectType, objectName],
  );
  if (rows.length != 1) {
    throw StateError('Expected exactly one $objectType $objectName.');
  }
  final String original = rows.single['sql'] as String;
  final String changed = original.replaceFirst(remove, '');
  if (changed == original) {
    throw StateError('Did not find schema fragment to remove: $remove');
  }
  raw.execute('PRAGMA writable_schema = ON');
  raw.execute(
    'UPDATE sqlite_schema SET sql = ? WHERE type = ? AND name = ?',
    <Object?>[changed, objectType, objectName],
  );
  raw.execute('PRAGMA writable_schema = OFF');
  raw.execute('PRAGMA schema_version = 99');
}

Future<void> _expectVersionOneFileRejectedUnchanged(File file) async {
  final List<int> before = await file.readAsBytes();
  final database = await openFileLearningTestDatabase(file);
  try {
    await expectLater(
      database.customSelect('SELECT 1').getSingle(),
      throwsA(isA<LearningCorruptException>()),
    );
  } finally {
    await database.close();
  }
  expect(await file.readAsBytes(), orderedEquals(before));
}

String _checkpointJsonWithUtf8ByteLength(int byteLength) {
  const String prefix = '{"payload":"';
  const String suffix = '"}';
  final int payloadBytes =
      byteLength - utf8.encode(prefix).length - utf8.encode(suffix).length;
  if (payloadBytes < 0) {
    throw ArgumentError.value(byteLength, 'byteLength', 'too small');
  }
  final String multibytePayload = List<String>.filled(
    payloadBytes ~/ 2,
    'é',
  ).join();
  final String payload = '$multibytePayload${payloadBytes.isOdd ? 'a' : ''}';
  final String json = jsonEncode(<String, String>{'payload': payload});
  if (utf8.encode(json).length != byteLength) {
    throw StateError('JSON did not encode to the requested UTF-8 byte length.');
  }
  return json;
}

Map<String, String> _maxCurrentCheckpointFixtures() {
  const int maxSafeInteger = 9007199254740991;
  const String sessionId = 'AAAAAAAAAAAAAAAAAAAAAA';
  final policy = LessonPolicy(completionThresholdPercent: 100);

  LessonSectionSession maxSession(
    List<String> itemIds, {
    required int contentRevision,
  }) {
    final session = LessonSectionSession(
      itemIds: itemIds,
      sessionId: sessionId,
      contentRevision: contentRevision,
      policy: policy,
    );
    for (final _ in itemIds) {
      session
        ..submit(false)
        ..advance();
    }
    session.reviewMistakes();
    final json = session.toJson();
    final int round = maxSafeInteger ~/ itemIds.length + 1;
    json['round'] = round;
    json['attemptCount'] = itemIds.length * (round - 1);
    return LessonSectionSession.fromJson(
      json,
      itemIds: itemIds,
      contentRevision: contentRevision,
    );
  }

  Map<String, Object?> courseSnapshot(ActivitySnapshot snapshot) =>
      switch (snapshot) {
        final DiscoveryCheckpoint value => <String, Object?>{
          'kind': 'discovery',
          'session': value.session.toJson(),
        },
        final LegacyLessonCheckpoint value => <String, Object?>{
          'kind': 'legacyLesson',
          'wordIndex': value.wordIndex,
          'selectedSound': value.selectedSound,
          'finished': value.finished,
        },
        final DrillCheckpoint value => <String, Object?>{
          'kind': 'drill',
          'pairIds': value.pairIds,
          'index': value.index,
          'correct': value.correct,
          'ended': value.ended,
        },
        final SoundGameCheckpoint value => <String, Object?>{
          'kind': 'soundGame',
          'board': <String, Object?>{
            'board': value.board.board,
            'stars': (value.board.stars.toList()..sort()),
          },
          'clock': <String, Object?>{
            'remaining': value.clock.remaining,
            'round': value.clock.round,
            'score': value.clock.score,
            'paused': value.clock.paused,
          },
        },
        final WordGameCheckpoint value => <String, Object?>{
          'kind': 'wordGame',
          'board': <String, Object?>{
            'board': value.board.board,
            'target': value.board.target,
            'moves': value.board.moves,
            'combo': value.board.combo,
            'stars': (value.board.stars.toList()..sort()),
            'obstacles': (value.board.obstacles.toList()..sort()),
          },
          'clock': <String, Object?>{
            'remaining': value.clock.remaining,
            'round': value.clock.round,
            'score': value.clock.score,
            'paused': value.clock.paused,
          },
        },
      };

  final registry = LearningRegistry.french();
  final result = <String, String>{};
  for (final definition in registry.activities) {
    final ActivitySnapshot snapshot = switch (definition.kind.name) {
      'discovery' => DiscoveryCheckpoint(
        session: maxSession(
          definition.items.map((item) => item.sessionAlias!).toList(),
          contentRevision: definition.contentRevision,
        ),
      ),
      'legacyLesson' => LegacyLessonCheckpoint(
        wordIndex: definition.items.length - 1,
        selectedSound: definition.items
            .map((item) => item.expectedChoice)
            .whereType<String>()
            .reduce(
              (left, right) =>
                  utf8.encode(left).length >= utf8.encode(right).length
                  ? left
                  : right,
            ),
        finished: true,
      ),
      'drill' => DrillCheckpoint(
        pairIds: definition.items.map((item) => item.id).toList(),
        index: definition.items.length,
        correct: definition.items.length,
        ended: true,
      ),
      'soundGame' => SoundGameCheckpoint(
        board: SoundBoardState(
          board: SoundMatchEngine(random: math.Random(0)).snapshot().board,
          stars: Set<int>.from(List<int>.generate(36, (index) => index)),
        ),
        clock: ArcadeClockState(
          remaining: 60,
          round: maxSafeInteger,
          score: maxSafeInteger,
          paused: true,
        ),
      ),
      'wordGame' => _maxWordCheckpoint(),
      _ => throw StateError('Unhandled course fixture ${definition.kind.name}'),
    };
    result[definition.kind.name] = jsonEncode(courseSnapshot(snapshot));
  }

  final comparisonCatalogue = loadFrenchComparisonCatalogue();
  final comparisonIds = comparisonCatalogue.exercises
      .map((exercise) => exercise.id)
      .toList();
  final comparisonSession = maxSession(
    comparisonIds,
    contentRevision: comparisonCatalogue.contentRevision,
  );
  final comparisonCheckpoint = ComparisonCheckpoint(
    scope: ComparisonProfileScope(
      courseId: 'en-fr',
      owner: LearningOwner.guest(),
    ),
    sessionId: comparisonSession.sessionId,
    contentRevision: comparisonCatalogue.contentRevision,
    policy: policy,
    sessionJson: comparisonSession.toJson(),
  );
  result['comparison'] = jsonEncode(<String, Object?>{
    'sessionId': comparisonCheckpoint.sessionId,
    'contentRevision': comparisonCheckpoint.contentRevision,
    'policy': comparisonCheckpoint.policy.toJson(),
    'session': comparisonCheckpoint.sessionJson,
  });

  const packagePath = 'assets/audio/fr-sentences';
  final sentenceCatalogue = decodeFrenchSentencePackage(
    manifestJson: File('$packagePath/manifest.json').readAsStringSync(),
    provenanceJson: File('$packagePath/provenance.json').readAsStringSync(),
    annotationsJson: File('$packagePath/annotations.json').readAsStringSync(),
    sourceEvidenceJson: File(
      '$packagePath/source-evidence.json',
    ).readAsStringSync(),
  );
  final sentenceSection = sentenceCatalogue.sections.reduce(
    (left, right) =>
        utf8.encode(left.sectionFingerprint).length >=
            utf8.encode(right.sectionFingerprint).length
        ? left
        : right,
  );
  final sentenceSession = maxSession(
    sentenceSection.items.map((item) => item.identity.itemId).toList(),
    contentRevision: sentenceSection.contentRevision,
  );
  final sentenceCheckpoint = SentenceHuntCheckpoint(
    scope: SentenceHuntProfileScope(
      courseId: 'en-fr',
      owner: LearningOwner.guest(),
    ),
    sessionId: sentenceSession.sessionId,
    sectionFingerprint: sentenceSection.sectionFingerprint,
    contentRevision: sentenceSection.contentRevision,
    mode: SentenceHuntRunMode.practice,
    finished: true,
    policy: policy,
    sessionJson: sentenceSession.toJson(),
    runStartRound: 1,
  );
  result['sentence-hunt'] = jsonEncode(<String, Object?>{
    'sessionId': sentenceCheckpoint.sessionId,
    'sectionFingerprint': sentenceCheckpoint.sectionFingerprint,
    'contentRevision': sentenceCheckpoint.contentRevision,
    'mode': sentenceCheckpoint.mode.name,
    'finished': sentenceCheckpoint.finished,
    'policy': sentenceCheckpoint.policy.toJson(),
    'runStartRound': sentenceCheckpoint.runStartRound,
    'session': sentenceCheckpoint.sessionJson,
  });
  return result;
}

WordGameCheckpoint _maxWordCheckpoint() {
  const int maxSafeInteger = 9007199254740991;
  const int moves = maxSafeInteger - (maxSafeInteger % 4);
  final String target = (moves ~/ 4).isEven ? 'u' : 'y';
  final List<CourseWord> eligibleWords = frenchWords
      .where((word) => word.contains(target))
      .toList();
  eligibleWords.sort(
    (left, right) =>
        utf8.encode(right.text).length.compareTo(utf8.encode(left.text).length),
  );
  final String longestWord = eligibleWords.first.text;
  return WordGameCheckpoint(
    board: WordBoardState(
      board: List<String>.filled(16, longestWord),
      target: target,
      moves: moves,
      combo: moves,
      stars: Set<int>.from(List<int>.generate(16, (index) => index)),
      obstacles: const <int>{0, 1},
    ),
    clock: ArcadeClockState(
      remaining: 60,
      round: maxSafeInteger,
      score: maxSafeInteger,
      paused: true,
    ),
  );
}

Future<void> _insertValidCourseMistake(LearningDatabase database) =>
    insertRow(database, 'learning_mistakes', <String, Object?>{
      'scope_id': 1,
      'family': 'course',
      'activity_id': 'course-a',
      'item_id': 'item-a',
      'target_sound': 'ɛ',
      'skill': 'listening',
      'pair_id': null,
      'section_id': null,
      'sentence_id': null,
      'audio_ref_id': null,
      'annotation_hash': null,
      'annotation_revision': null,
      'content_revision': 1,
      'first_wrong_attempt_id': 'attempt-course',
      'latest_wrong_attempt_id': 'attempt-course',
      'first_wrong_at_us': 100,
      'latest_wrong_at_us': 101,
      'failure_count': 1,
      'last_run_generation': 1,
    });

Map<String, Object?> _courseMistake({
  String family = 'course',
  String? activityId = 'course-a',
  String? itemId = 'item-a',
  String? targetSound = 'ɛ',
  String? skill = 'listening',
  String? pairId,
  String? sectionId,
  String? sentenceId,
  String? audioRefId,
  String? annotationHash,
  int? annotationRevision,
  String? firstWrongAttemptId = 'attempt-course',
  String? latestWrongAttemptId = 'attempt-course',
  int failureCount = 1,
}) => <String, Object?>{
  'scope_id': 1,
  'family': family,
  'activity_id': activityId,
  'item_id': itemId,
  'target_sound': targetSound,
  'skill': skill,
  'pair_id': pairId,
  'section_id': sectionId,
  'sentence_id': sentenceId,
  'audio_ref_id': audioRefId,
  'annotation_hash': annotationHash,
  'annotation_revision': annotationRevision,
  'content_revision': 1,
  'first_wrong_attempt_id': firstWrongAttemptId,
  'latest_wrong_attempt_id': latestWrongAttemptId,
  'first_wrong_at_us': 100,
  'latest_wrong_at_us': 101,
  'failure_count': failureCount,
  'last_run_generation': 1,
};

Map<String, Object?> _courseSummary({
  String family = 'course',
  String? activityId,
  String? sound = 'ɛ',
  String? skill = 'listening',
  String? origin = 'practice',
  String? presentation = 'firstInRun',
  int? assistanceMask = 0,
  String? pairId,
  String? sectionId,
  String? itemId,
  String? sentenceId,
  String? audioRefId,
  String? annotationHash,
  int? annotationRevision,
  int? contentRevision,
  String bucket = 'all',
  int correct = 1,
  int total = 1,
}) => <String, Object?>{
  'scope_id': 1,
  'family': family,
  'activity_id': activityId,
  'sound': sound,
  'skill': skill,
  'origin': origin,
  'presentation': presentation,
  'assistance_mask': assistanceMask,
  'pair_id': pairId,
  'section_id': sectionId,
  'item_id': itemId,
  'sentence_id': sentenceId,
  'audio_ref_id': audioRefId,
  'annotation_hash': annotationHash,
  'annotation_revision': annotationRevision,
  'content_revision': contentRevision,
  'bucket': bucket,
  'correct': correct,
  'total': total,
};

Map<String, Object?> _courseExposure({
  int scopeId = 1,
  String family = 'course',
  String? activityId = 'course-a',
  String? itemId = 'item-a',
  String? targetSound = 'ɛ',
  String? sectionId,
  int? contentRevision,
  int? presentations = 1,
  int? assistanceMask = 0,
}) => <String, Object?>{
  'scope_id': scopeId,
  'family': family,
  'activity_id': activityId,
  'item_id': itemId,
  'target_sound': targetSound,
  'section_id': sectionId,
  'content_revision': contentRevision,
  'presentations': presentations,
  'assistance_mask': assistanceMask,
};

Map<String, Object?> _courseOutbox({
  int scopeId = 1,
  String eventId = 'event-1',
  int enqueueCommitOrdinal = 1,
  int enqueueEventIndex = 0,
  String userId = ' account-42 ',
  String courseId = 'en-fr',
  String kind = 'answer',
  String? sound = 'ɛ',
  String? skill = 'listening',
  int? correct = 1,
  String? activity = 'discovery',
  String? lessonId,
  String? game,
  int? score,
}) => <String, Object?>{
  'scope_id': scopeId,
  'event_id': eventId,
  'enqueue_commit_ordinal': enqueueCommitOrdinal,
  'enqueue_event_index': enqueueEventIndex,
  'user_id': userId,
  'course_id': courseId,
  'kind': kind,
  'sound': sound,
  'skill': skill,
  'correct': correct,
  'activity': activity,
  'lesson_id': lessonId,
  'game': game,
  'score': score,
};

void main() {
  group('LearningDatabase schema v1', () {
    test('constructs measured current typed checkpoint sizing fixtures', () {
      final fixtures = _maxCurrentCheckpointFixtures();
      final sizes = <String, int>{
        for (final entry in fixtures.entries)
          entry.key: utf8.encode(entry.value).length,
      };

      expect(sizes.keys.toSet(), <String>{
        'legacyLesson',
        'discovery',
        'drill',
        'soundGame',
        'wordGame',
        'comparison',
        'sentence-hunt',
      });
      expect(sizes['sentence-hunt'], 11066);
      expect(
        sizes.values.reduce((left, right) => left > right ? left : right),
        11066,
      );
      expect(
        sizes.values.every((size) => size <= learningMaxCheckpointBytes),
        isTrue,
      );
    });

    test(
      'accepts exact UTF-8 checkpoint budget and rejects one byte over on INSERT',
      () async {
        final database = await _openDatabase();
        addTearDown(database.close);
        await createCoreLearningRows(database);

        final String exactJson = _checkpointJsonWithUtf8ByteLength(
          learningMaxCheckpointBytes,
        );
        final String oversizedJson = _checkpointJsonWithUtf8ByteLength(
          learningMaxCheckpointBytes + 1,
        );
        expect(learningMaxCheckpointBytes, 1048576);
        expect(utf8.encode(exactJson).length, learningMaxCheckpointBytes);
        expect(exactJson.length, lessThan(learningMaxCheckpointBytes));
        expect(
          utf8.encode(oversizedJson).length,
          learningMaxCheckpointBytes + 1,
        );
        expect(oversizedJson.length, lessThan(learningMaxCheckpointBytes));

        await insertBinding(
          database,
          id: 109,
          scopeId: 1,
          activityId: 'budget-exact',
          catalogueFingerprint: 'catalogue-1',
        );
        await insertBinding(
          database,
          id: 110,
          scopeId: 1,
          activityId: 'budget-over',
          catalogueFingerprint: 'catalogue-1',
        );
        await insertRow(
          database,
          'learning_runs',
          runRow(
            scopeId: 1,
            activityId: 'budget-exact',
            activityKind: 'discovery',
            contentBindingId: 109,
            token: 'EEEEEEEEEEEEEEEEEEEEEE',
            checkpointJson: exactJson,
          ),
        );
        await expectSqlRejected(
          insertRow(
            database,
            'learning_runs',
            runRow(
              scopeId: 1,
              activityId: 'budget-over',
              activityKind: 'discovery',
              contentBindingId: 110,
              token: 'FFFFFFFFFFFFFFFFFFFFFF',
              checkpointJson: oversizedJson,
            ),
          ),
        );
      },
    );

    test(
      'rejects one-byte-over UTF-8 checkpoint UPDATE and rolls back transaction',
      () async {
        final database = await _openDatabase();
        addTearDown(database.close);
        await createCoreLearningRows(database);

        final String exactJson = _checkpointJsonWithUtf8ByteLength(
          learningMaxCheckpointBytes,
        );
        final String oversizedJson = _checkpointJsonWithUtf8ByteLength(
          learningMaxCheckpointBytes + 1,
        );
        expect(utf8.encode(exactJson).length, learningMaxCheckpointBytes);
        expect(
          utf8.encode(oversizedJson).length,
          learningMaxCheckpointBytes + 1,
        );
        await updateRows(
          database,
          'learning_runs',
          <String, Object?>{'checkpoint_json': exactJson},
          where: 'scope_id = ? AND activity_id = ?',
          whereArgs: <Object?>[1, 'course-a'],
        );
        await expectLater(
          database.transaction(() async {
            await updateRows(
              database,
              'learning_scopes',
              <String, Object?>{'revision': 1, 'commit_ordinal': 1},
              where: 'id = ?',
              whereArgs: <Object?>[1],
            );
            await updateRows(
              database,
              'learning_runs',
              <String, Object?>{'checkpoint_json': oversizedJson},
              where: 'scope_id = ? AND activity_id = ?',
              whereArgs: <Object?>[1, 'course-a'],
            );
          }),
          throwsA(anything),
        );

        final revision = await database
            .customSelect('SELECT revision FROM learning_scopes WHERE id = 1')
            .getSingle();
        final checkpoint = await database
            .customSelect(
              'SELECT checkpoint_json FROM learning_runs '
              "WHERE scope_id = 1 AND activity_id = 'course-a'",
            )
            .getSingle();
        expect(revision.read<int>('revision'), 0);
        expect(checkpoint.read<String>('checkpoint_json'), exactJson);
      },
    );

    test('retains checkpoint JSON-object and storage-class checks', () async {
      final database = await _openDatabase();
      addTearDown(database.close);
      await createCoreLearningRows(database);

      for (final invalidJson in <String>['not-json', '[]', 'null']) {
        await expectSqlRejected(
          updateRows(
            database,
            'learning_runs',
            <String, Object?>{'checkpoint_json': invalidJson},
            where: 'scope_id = ? AND activity_id = ?',
            whereArgs: <Object?>[1, 'course-a'],
          ),
        );
      }
      await expectSqlRejected(
        database.customStatement(
          'UPDATE learning_runs SET checkpoint_json = NULL '
          "WHERE scope_id = 1 AND activity_id = 'course-a'",
        ),
      );
      await expectSqlRejected(
        database.customStatement(
          "UPDATE learning_runs SET checkpoint_json = CAST('{}' AS BLOB) "
          "WHERE scope_id = 1 AND activity_id = 'course-a'",
        ),
      );
      final checkpoint = await database
          .customSelect(
            'SELECT checkpoint_json FROM learning_runs '
            "WHERE scope_id = 1 AND activity_id = 'course-a'",
          )
          .getSingle();
      expect(checkpoint.read<String>('checkpoint_json'), '{}');
    });

    test(
      'creates the exact normalized schema and queries a verified empty file',
      () async {
        final database = await _openDatabase();
        addTearDown(database.close);

        expect(database.schemaVersion, 1);
        expect(await tableNames(database), orderedEquals(learningTableNames));
        expect(await pragmaUserVersion(database), 1);
        expect(await hasNoLearningRows(database), isTrue);
        expect(
          await database
              .customSelect('PRAGMA foreign_keys')
              .getSingle()
              .then((row) => row.read<int>('foreign_keys')),
          1,
        );

        for (final entry in learningColumnNames.entries) {
          final rows = await database
              .customSelect('PRAGMA table_info(${entry.key})')
              .get();
          expect(
            rows.map((row) => row.read<String>('name')).toList(),
            orderedEquals(entry.value),
            reason: entry.key,
          );
          for (final row in rows) {
            final String column = row.read<String>('name');
            expect(
              row.read<String>('type'),
              _integerColumns.contains(column) ? 'INTEGER' : 'TEXT',
              reason: '${entry.key}.$column SQL type',
            );
            final bool isId = column == 'id';
            final bool nullable = _nullableColumns[entry.key]!.contains(column);
            expect(
              row.read<int>('notnull'),
              !nullable && !isId ? 1 : 0,
              reason: '${entry.key}.$column nullability',
            );
            if (isId) {
              expect(row.read<int>('pk'), 1, reason: '${entry.key}.$column PK');
            }
          }
        }

        final List<String> indexes = _indexNames.toList()..sort();
        expect(
          await namedSchemaObjects(database, 'index'),
          orderedEquals(indexes),
        );
        final List<String> triggers = <String>[
          for (final base in _triggerBases) '${base}_insert',
          for (final base in _triggerBases) '${base}_update',
          'trg_learning_scopes_identity_immutable_update',
        ]..sort();
        expect(
          await namedSchemaObjects(database, 'trigger'),
          orderedEquals(triggers),
        );

        final orderIndex = await database
            .customSelect(
              "SELECT sql FROM sqlite_schema WHERE type = 'index' "
              "AND name = 'ux_supported_sync_outbox_scope_enqueue_order'",
            )
            .getSingle();
        expect(
          orderIndex.read<String>('sql'),
          contains('(scope_id, enqueue_commit_ordinal, enqueue_event_index)'),
        );
        expect(
          await columnNames(database, 'supported_sync_outbox'),
          containsAll(<String>[
            'enqueue_commit_ordinal',
            'enqueue_event_index',
          ]),
        );
      },
    );

    test(
      'checks owner encoding and prevents persisted scope identity changes',
      () async {
        final database = await _openDatabase();
        addTearDown(database.close);
        await createCoreLearningRows(database);

        final owner = await database
            .customSelect('SELECT owner_id FROM learning_scopes WHERE id = 1')
            .getSingle();
        expect(owner.read<String>('owner_id'), ' account-42 ');

        await expectSqlRejected(
          insertScope(
            database,
            id: 20,
            ownerKind: 'guest',
            ownerId: 'not-empty',
            courseId: 'en-fr',
            family: 'course',
          ),
        );
        await expectSqlRejected(
          insertScope(
            database,
            id: 21,
            ownerKind: 'account',
            ownerId: '   ',
            courseId: 'en-fr',
            family: 'course',
          ),
        );
        await expectSqlRejected(
          insertScope(
            database,
            id: 22,
            ownerKind: 'service',
            ownerId: 'account-22',
            courseId: 'en-fr',
            family: 'course',
          ),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_scopes',
            <String, Object?>{'owner_id': 'another-owner'},
            where: 'id = ?',
            whereArgs: <Object?>[1],
          ),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_scopes',
            <String, Object?>{'family': 'comparison'},
            where: 'id = ?',
            whereArgs: <Object?>[1],
          ),
        );
        await updateRows(
          database,
          'learning_scopes',
          <String, Object?>{'revision': 2, 'commit_ordinal': 1},
          where: 'id = ?',
          whereArgs: <Object?>[1],
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_scopes',
            <String, Object?>{'revision': -1},
            where: 'id = ?',
            whereArgs: <Object?>[1],
          ),
        );
        await expectSqlRejected(
          insertScope(
            database,
            id: 23,
            ownerKind: 'guest',
            ownerId: '',
            courseId: 'en-fr',
            family: 'course',
            revision: 0,
            commitOrdinal: 1,
          ),
        );
        await expectSqlRejected(
          insertScope(
            database,
            id: 24,
            ownerKind: 'guest',
            ownerId: '',
            courseId: 'en-fr',
            family: 'invalid-family',
          ),
        );
      },
    );

    test(
      'normalizes binding identity and enforces family shape on insert/update',
      () async {
        final database = await _openDatabase();
        addTearDown(database.close);
        await createCoreLearningRows(database);

        await expectSqlRejected(
          insertBinding(
            database,
            id: 120,
            scopeId: 1,
            activityId: 'course-a',
            catalogueFingerprint: 'catalogue-1',
          ),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_content_bindings',
            <String, Object?>{'activity_id': 'course-a'},
            where: 'id = ?',
            whereArgs: <Object?>[108],
          ),
        );
        await expectSqlRejected(
          insertBinding(
            database,
            id: 121,
            scopeId: 1,
            activityId: 'bad-course-binding',
            sectionFingerprint: 'not-course-content',
          ),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_content_bindings',
            <String, Object?>{'section_fingerprint': 'not-course-content'},
            where: 'id = ?',
            whereArgs: <Object?>[101],
          ),
        );
        await expectSqlRejected(
          insertBinding(
            database,
            id: 122,
            scopeId: 2,
            activityId: 'bad-comparison-binding',
            catalogueFingerprint: 'not-comparison-content',
          ),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_content_bindings',
            <String, Object?>{
              'catalogue_fingerprint': 'not-comparison-content',
            },
            where: 'id = ?',
            whereArgs: <Object?>[102],
          ),
        );
        await expectSqlRejected(
          insertBinding(
            database,
            id: 123,
            scopeId: 3,
            activityId: 'bad-sentence-binding',
            catalogueFingerprint: 'not-sentence-content',
          ),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_content_bindings',
            <String, Object?>{'catalogue_fingerprint': 'not-sentence-content'},
            where: 'id = ?',
            whereArgs: <Object?>[103],
          ),
        );
        await expectSqlRejected(
          insertBinding(
            database,
            id: 124,
            scopeId: 1,
            activityId: 'invalid-content-revision',
            contentRevision: 0,
          ),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_content_bindings',
            <String, Object?>{'content_revision': 0},
            where: 'id = ?',
            whereArgs: <Object?>[101],
          ),
        );
      },
    );

    test(
      'binds each run to its own scope and scopes latest receipt tokens',
      () async {
        final database = await _openDatabase();
        addTearDown(database.close);
        await createCoreLearningRows(database);

        final runWithWrongBinding = runRow(
          scopeId: 1,
          activityId: 'course-b',
          activityKind: 'discovery',
          contentBindingId: 102,
          token: 'DDDDDDDDDDDDDDDDDDDDDD',
        );
        await expectSqlRejected(
          insertRow(database, 'learning_runs', runWithWrongBinding),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_runs',
            <String, Object?>{'content_binding_id': 102},
            where: 'scope_id = ? AND activity_id = ?',
            whereArgs: <Object?>[1, 'course-a'],
          ),
        );
        final invalidKind = runRow(
          scopeId: 1,
          activityId: 'course-b',
          activityKind: 'comparison',
          contentBindingId: 108,
          token: 'EEEEEEEEEEEEEEEEEEEEEE',
        );
        await expectSqlRejected(
          insertRow(database, 'learning_runs', invalidKind),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_runs',
            <String, Object?>{'activity_kind': 'comparison'},
            where: 'scope_id = ? AND activity_id = ?',
            whereArgs: <Object?>[1, 'course-a'],
          ),
        );

        final duplicateToken = runRow(
          scopeId: 1,
          activityId: 'course-b',
          activityKind: 'drill',
          contentBindingId: 108,
          token: 'AAAAAAAAAAAAAAAAAAAAAA',
        );
        await expectSqlRejected(
          insertRow(database, 'learning_runs', duplicateToken),
        );
        await insertRow(
          database,
          'learning_runs',
          runRow(
            scopeId: 1,
            activityId: 'course-b',
            activityKind: 'drill',
            contentBindingId: 108,
            token: 'DDDDDDDDDDDDDDDDDDDDDD',
          ),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_runs',
            <String, Object?>{'latest_receipt_token': 'AAAAAAAAAAAAAAAAAAAAAA'},
            where: 'scope_id = ? AND activity_id = ?',
            whereArgs: <Object?>[1, 'course-b'],
          ),
        );

        await expectSqlRejected(
          updateRows(
            database,
            'learning_runs',
            <String, Object?>{'finished': 2},
            where: 'scope_id = ? AND activity_id = ?',
            whereArgs: <Object?>[1, 'course-a'],
          ),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_runs',
            <String, Object?>{'checkpoint_json': 'not-json'},
            where: 'scope_id = ? AND activity_id = ?',
            whereArgs: <Object?>[1, 'course-a'],
          ),
        );
      },
    );

    test(
      'checks attempt shapes, answer values and family-specific evidence',
      () async {
        final database = await _openDatabase();
        addTearDown(database.close);
        await createCoreLearningRows(database);

        final wrongCourseAttempt = courseAttemptRow(
          scopeId: 1,
          attemptId: 'wrong-course-attempt',
          answerKind: 'comparisonPair',
        );
        await expectSqlRejected(
          insertRow(database, 'learning_attempts', wrongCourseAttempt),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_attempts',
            <String, Object?>{'answer_kind': 'comparisonPair'},
            where: 'scope_id = ? AND attempt_id = ?',
            whereArgs: <Object?>[1, 'attempt-course'],
          ),
        );
        final missingCourseItem = courseAttemptRow(
          scopeId: 1,
          attemptId: 'missing-item-attempt',
        )..['item_id'] = null;
        await expectSqlRejected(
          insertRow(database, 'learning_attempts', missingCourseItem),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_attempts',
            <String, Object?>{'correct': 2},
            where: 'scope_id = ? AND attempt_id = ?',
            whereArgs: <Object?>[1, 'attempt-course'],
          ),
        );

        await expectSqlRejected(
          insertRow(database, 'learning_attempt_values', <String, Object?>{
            'scope_id': 1,
            'attempt_id': 'attempt-course',
            'field': 'selected_sound',
            'ordinal': 1,
            'value_type': 'int',
            'text_value': 'text-is-not-an-integer',
            'int_value': null,
            'bool_value': null,
          }),
        );
        await expectSqlRejected(
          insertRow(database, 'learning_attempt_values', <String, Object?>{
            'scope_id': 1,
            'attempt_id': 'attempt-course',
            'field': 'selected_token_id',
            'ordinal': 1,
            'value_type': 'text',
            'text_value': 'sentence-token',
            'int_value': null,
            'bool_value': null,
          }),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_attempt_values',
            <String, Object?>{'field': 'selected_token_id'},
            where: 'scope_id = ? AND attempt_id = ? AND field = ?',
            whereArgs: <Object?>[1, 'attempt-course', 'selected_sound'],
          ),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_attempt_values',
            <String, Object?>{'text_value': null},
            where: 'scope_id = ? AND attempt_id = ? AND field = ?',
            whereArgs: <Object?>[1, 'attempt-course', 'selected_sound'],
          ),
        );

        final invalidCourseEvidence = sentenceEvidenceRow(
          scopeId: 1,
          attemptId: 'attempt-course',
        );
        await expectSqlRejected(
          insertRow(
            database,
            'learning_attempt_evidence',
            invalidCourseEvidence,
          ),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_attempt_evidence',
            <String, Object?>{'evidence_kind': 'comparisonPlayback'},
            where: 'scope_id = ? AND attempt_id = ? AND evidence_index = 0',
            whereArgs: <Object?>[3, 'attempt-sentence'],
          ),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_attempt_evidence',
            <String, Object?>{'source': 'newPlaybackAssertion'},
            where: 'scope_id = ? AND attempt_id = ? AND evidence_index = 0',
            whereArgs: <Object?>[2, 'attempt-comparison'],
          ),
        );

        final orderedSlots = await database
            .customSelect(
              'SELECT evidence_index, slot FROM learning_attempt_evidence '
              'WHERE scope_id = 2 ORDER BY evidence_index',
            )
            .get();
        expect(
          orderedSlots.map((row) => row.read<String>('slot')).toList(),
          <String>['a', 'b'],
        );
      },
    );

    test(
      'attempt value and evidence foreign keys retain the exact scope',
      () async {
        final database = await _openDatabase();
        addTearDown(database.close);
        await createCoreLearningRows(database);

        final sentenceValue = <String, Object?>{
          'scope_id': 4,
          'attempt_id': 'attempt-sentence',
          'field': 'selected_token_id',
          'ordinal': 1,
          'value_type': 'text',
          'text_value': 'other-scope-token',
          'int_value': null,
          'bool_value': null,
        };
        await expectSqlRejected(
          insertRow(database, 'learning_attempt_values', sentenceValue),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_attempt_values',
            <String, Object?>{'scope_id': 4},
            where: 'scope_id = ? AND attempt_id = ? AND field = ?',
            whereArgs: <Object?>[3, 'attempt-sentence', 'selected_token_id'],
          ),
        );

        final sentenceEvidence = sentenceEvidenceRow(
          scopeId: 4,
          evidenceIndex: 1,
        );
        await expectSqlRejected(
          insertRow(database, 'learning_attempt_evidence', sentenceEvidence),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_attempt_evidence',
            <String, Object?>{'scope_id': 4},
            where: 'scope_id = ? AND attempt_id = ? AND evidence_index = 0',
            whereArgs: <Object?>[3, 'attempt-sentence'],
          ),
        );

        await expectSqlRejected(
          database.customStatement('DELETE FROM learning_scopes WHERE id = 3'),
        );
      },
    );

    test(
      'rejects NULL results from discriminated value and JSON checks',
      () async {
        final database = await _openDatabase();
        addTearDown(database.close);
        await createCoreLearningRows(database);

        for (final (String field, String valueType) in <(String, String)>[
          ('tile_index', 'int'),
          ('expected_membership', 'bool'),
        ]) {
          await expectSqlRejected(
            insertRow(database, 'learning_attempt_values', <String, Object?>{
              'scope_id': 1,
              'attempt_id': 'attempt-course',
              'field': field,
              'ordinal': 10,
              'value_type': valueType,
              'text_value': null,
              'int_value': null,
              'bool_value': null,
            }),
          );
        }

        await insertRow(database, 'learning_attempt_values', <String, Object?>{
          'scope_id': 1,
          'attempt_id': 'attempt-course',
          'field': 'tile_index',
          'ordinal': 10,
          'value_type': 'int',
          'text_value': null,
          'int_value': 1,
          'bool_value': null,
        });
        await expectSqlRejected(
          updateRows(
            database,
            'learning_attempt_values',
            <String, Object?>{
              'text_value': null,
              'int_value': null,
              'bool_value': null,
            },
            where: 'scope_id = ? AND attempt_id = ? AND field = ?',
            whereArgs: <Object?>[1, 'attempt-course', 'tile_index'],
          ),
        );

        await insertRow(database, 'learning_attempt_values', <String, Object?>{
          'scope_id': 1,
          'attempt_id': 'attempt-course',
          'field': 'expected_membership',
          'ordinal': 10,
          'value_type': 'bool',
          'text_value': null,
          'int_value': null,
          'bool_value': 1,
        });
        await expectSqlRejected(
          updateRows(
            database,
            'learning_attempt_values',
            <String, Object?>{
              'text_value': null,
              'int_value': null,
              'bool_value': null,
            },
            where: 'scope_id = ? AND attempt_id = ? AND field = ?',
            whereArgs: <Object?>[1, 'attempt-course', 'expected_membership'],
          ),
        );

        await expectSqlRejected(
          insertRow(
            database,
            'learning_runs',
            runRow(
              scopeId: 1,
              activityId: 'course-b',
              activityKind: 'drill',
              contentBindingId: 108,
              token: 'FFFFFFFFFFFFFFFFFFFFFF',
              receiptPayload: '{}',
            ),
          ),
        );
        await expectSqlRejected(
          insertRow(
            database,
            'learning_runs',
            runRow(
              scopeId: 1,
              activityId: 'course-b',
              activityKind: 'drill',
              contentBindingId: 108,
              token: 'LLLLLLLLLLLLLLLLLLLLLL',
              receiptPayload:
                  '{"activityId":"course-b","expectedScopeRevision":-1}',
            ),
          ),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_runs',
            <String, Object?>{'latest_receipt_payload': '{}'},
            where: 'scope_id = ? AND activity_id = ?',
            whereArgs: <Object?>[1, 'course-a'],
          ),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_runs',
            <String, Object?>{
              'latest_receipt_payload':
                  '{"activityId":"course-a","expectedScopeRevision":"0"}',
            },
            where: 'scope_id = ? AND activity_id = ?',
            whereArgs: <Object?>[1, 'course-a'],
          ),
        );

        Map<String, Object?> receiptRow({
          required String token,
          required String canonicalPayload,
        }) => <String, Object?>{
          'scope_id': 1,
          'activity_id': 'course-a',
          'token': token,
          'canonical_payload': canonicalPayload,
          'before_generation': 0,
          'before_sequence': 0,
          'before_cursor_revision': 0,
          'after_generation': 1,
          'after_sequence': 2,
          'after_cursor_revision': 1,
          'commit_ordinal': 2,
          'result_activity_id': 'course-a',
          'result_generation': 1,
          'result_sequence': 2,
          'result_cursor_revision': 1,
        };

        await expectSqlRejected(
          insertRow(
            database,
            'learning_command_receipts',
            receiptRow(token: 'GGGGGGGGGGGGGGGGGGGGGG', canonicalPayload: '{}'),
          ),
        );
        await expectSqlRejected(
          insertRow(
            database,
            'learning_command_receipts',
            receiptRow(
              token: 'HHHHHHHHHHHHHHHHHHHHHH',
              canonicalPayload: '{"expectedScopeRevision":0}',
            ),
          ),
        );
        await expectSqlRejected(
          insertRow(
            database,
            'learning_command_receipts',
            receiptRow(
              token: 'IIIIIIIIIIIIIIIIIIIIII',
              canonicalPayload: '{"activityId":"course-a"}',
            ),
          ),
        );
        await expectSqlRejected(
          insertRow(
            database,
            'learning_command_receipts',
            receiptRow(
              token: 'JJJJJJJJJJJJJJJJJJJJJJ',
              canonicalPayload:
                  '{"activityId":"course-a","expectedScopeRevision":-1}',
            ),
          ),
        );

        await insertRow(
          database,
          'learning_command_receipts',
          receiptRow(
            token: 'KKKKKKKKKKKKKKKKKKKKKK',
            canonicalPayload:
                '{"activityId":"course-a","expectedScopeRevision":0}',
          ),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_command_receipts',
            <String, Object?>{'canonical_payload': '{}'},
            where: 'scope_id = ? AND token = ?',
            whereArgs: <Object?>[1, 'KKKKKKKKKKKKKKKKKKKKKK'],
          ),
        );

        await expectSqlRejected(
          insertRow(
            database,
            'learning_exposure',
            _courseExposure(
              activityId: 'missing-presentations',
              presentations: null,
            ),
          ),
        );
        await expectSqlRejected(
          insertRow(
            database,
            'learning_exposure',
            _courseExposure(
              activityId: 'missing-assistance-mask',
              assistanceMask: null,
            ),
          ),
        );

        await insertRow(
          database,
          'learning_exposure',
          _courseExposure(activityId: 'update-presentations'),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_exposure',
            <String, Object?>{'presentations': null},
            where: 'scope_id = ? AND activity_id = ?',
            whereArgs: <Object?>[1, 'update-presentations'],
          ),
        );
        await insertRow(
          database,
          'learning_exposure',
          _courseExposure(activityId: 'update-assistance-mask'),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_exposure',
            <String, Object?>{'assistance_mask': null},
            where: 'scope_id = ? AND activity_id = ?',
            whereArgs: <Object?>[1, 'update-assistance-mask'],
          ),
        );
      },
    );

    test(
      'enforces declared SQLite storage classes on inserts and updates',
      () async {
        final database = await _openDatabase();
        addTearDown(database.close);
        await createCoreLearningRows(database);

        await expectSqlRejected(
          insertRow(database, 'learning_scopes', <String, Object?>{
            'id': 20,
            'owner_kind': 'guest',
            'owner_id': '',
            'course_id': 'fractional-revision',
            'family': 'course',
            'schema_version': 1,
            'revision': 0.5,
            'commit_ordinal': 0,
            'availability_state': 'available',
          }),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_scopes',
            <String, Object?>{'revision': 0.5},
            where: 'id = ?',
            whereArgs: <Object?>[1],
          ),
        );

        await expectSqlRejected(
          database.customStatement(
            'INSERT INTO learning_scopes (id, owner_kind, owner_id, course_id, '
            'family, schema_version, revision, commit_ordinal, availability_state) '
            "VALUES (20, 'guest', '', x'656e2d6672', 'course', 1, 0, 0, 'available')",
          ),
        );
        await expectSqlRejected(
          database.customStatement(
            "UPDATE learning_content_bindings SET activity_id = x'6375727365' "
            'WHERE id = 101',
          ),
        );

        await insertBinding(
          database,
          id: 109,
          scopeId: 1,
          activityId: 'nullable-text-columns',
          catalogueFingerprint: 'catalogue-nullables',
        );
      },
    );

    test(
      'normalizes aggregate identities without mutable counts or evidence',
      () async {
        final database = await _openDatabase();
        addTearDown(database.close);
        await createCoreLearningRows(database);
        await _insertValidCourseMistake(database);

        await expectSqlRejected(
          insertRow(
            database,
            'learning_mistakes',
            _courseMistake(
              firstWrongAttemptId: 'different-first',
              latestWrongAttemptId: 'different-latest',
              failureCount: 9,
            ),
          ),
        );
        await expectSqlRejected(
          insertRow(
            database,
            'learning_mistakes',
            _courseMistake(
              family: 'comparison',
              activityId: 'comparison-activity',
              itemId: null,
              targetSound: null,
              skill: null,
              pairId: 'pair-1',
            ),
          ),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_mistakes',
            <String, Object?>{
              'family': 'comparison',
              'item_id': null,
              'target_sound': null,
              'skill': null,
              'pair_id': 'pair-1',
            },
            where: 'scope_id = ? AND family = ?',
            whereArgs: <Object?>[1, 'course'],
          ),
        );

        await insertRow(database, 'learning_summaries', _courseSummary());
        await expectSqlRejected(
          insertRow(
            database,
            'learning_summaries',
            _courseSummary(correct: 0, total: 1),
          ),
        );
        await expectSqlRejected(
          insertRow(
            database,
            'learning_summaries',
            _courseSummary(
              family: 'comparison',
              activityId: 'comparison-activity',
              sound: null,
              skill: null,
              origin: null,
              presentation: null,
              assistanceMask: null,
              pairId: 'pair-1',
              contentRevision: 1,
              bucket: 'firstInRun',
            ),
          ),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_summaries',
            <String, Object?>{
              'family': 'comparison',
              'activity_id': 'comparison-activity',
              'sound': null,
              'skill': null,
              'origin': null,
              'presentation': null,
              'assistance_mask': null,
              'pair_id': 'pair-1',
              'content_revision': 1,
              'bucket': 'firstInRun',
            },
            where: 'scope_id = ? AND family = ?',
            whereArgs: <Object?>[1, 'course'],
          ),
        );

        await insertRow(database, 'learning_exposure', _courseExposure());
        await expectSqlRejected(
          insertRow(
            database,
            'learning_exposure',
            _courseExposure(presentations: 4, assistanceMask: 3),
          ),
        );
        await expectSqlRejected(
          insertRow(database, 'learning_exposure', _courseExposure(scopeId: 2)),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_exposure',
            <String, Object?>{'scope_id': 2},
            where: 'scope_id = ? AND family = ?',
            whereArgs: <Object?>[1, 'course'],
          ),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'learning_exposure',
            <String, Object?>{'presentations': -1},
            where: 'scope_id = ? AND family = ?',
            whereArgs: <Object?>[1, 'course'],
          ),
        );
      },
    );

    test('checks completion policy identity and best-score ranges', () async {
      final database = await _openDatabase();
      addTearDown(database.close);
      await createCoreLearningRows(database);
      await insertRow(database, 'learning_completions', <String, Object?>{
        'scope_id': 1,
        'activity_id': 'course-a',
        'content_revision': 1,
        'policy_kind': 'legacyOnePass',
        'policy_revision': 1,
        'threshold_percent': -1,
        'committed_at_us': 101,
      });
      await insertRow(database, 'learning_completions', <String, Object?>{
        'scope_id': 2,
        'activity_id': 'en-fr-phoneme-comparison',
        'content_revision': 1,
        'policy_kind': 'discoveryThreshold',
        'policy_revision': 1,
        'threshold_percent': 80,
        'committed_at_us': 101,
      });
      await expectSqlRejected(
        insertRow(database, 'learning_completions', <String, Object?>{
          'scope_id': 2,
          'activity_id': 'bad-comparison-policy',
          'content_revision': 1,
          'policy_kind': 'legacyOnePass',
          'policy_revision': 1,
          'threshold_percent': -1,
          'committed_at_us': 101,
        }),
      );
      await expectSqlRejected(
        updateRows(
          database,
          'learning_completions',
          <String, Object?>{
            'policy_kind': 'legacyOnePass',
            'threshold_percent': -1,
          },
          where: 'scope_id = ? AND activity_id = ?',
          whereArgs: <Object?>[2, 'en-fr-phoneme-comparison'],
        ),
      );
      await expectSqlRejected(
        insertRow(database, 'learning_completions', <String, Object?>{
          'scope_id': 1,
          'activity_id': 'bad-threshold',
          'content_revision': 1,
          'policy_kind': 'discoveryThreshold',
          'policy_revision': 1,
          'threshold_percent': 0,
          'committed_at_us': 101,
        }),
      );

      await insertRow(database, 'learning_best_scores', <String, Object?>{
        'scope_id': 1,
        'activity_id': 'sound-game',
        'score': 0,
      });
      await expectSqlRejected(
        updateRows(
          database,
          'learning_best_scores',
          <String, Object?>{'score': -1},
          where: 'scope_id = ? AND activity_id = ?',
          whereArgs: <Object?>[1, 'sound-game'],
        ),
      );
    });

    test(
      'enforces account-course outbox payload and FIFO coordinates',
      () async {
        final database = await _openDatabase();
        addTearDown(database.close);
        await createCoreLearningRows(database);

        await insertRow(
          database,
          'supported_sync_outbox',
          _courseOutbox(
            eventId: 'event-later',
            enqueueCommitOrdinal: 9,
            enqueueEventIndex: 0,
          ),
        );
        await insertRow(
          database,
          'supported_sync_outbox',
          _courseOutbox(
            eventId: 'event-first',
            enqueueCommitOrdinal: 8,
            enqueueEventIndex: 1,
          ),
        );
        final fifo = await database
            .customSelect(
              'SELECT event_id FROM supported_sync_outbox '
              'ORDER BY enqueue_commit_ordinal ASC, enqueue_event_index ASC',
            )
            .get();
        expect(
          fifo.map((row) => row.read<String>('event_id')).toList(),
          <String>['event-first', 'event-later'],
        );
        await expectSqlRejected(
          insertRow(
            database,
            'supported_sync_outbox',
            _courseOutbox(
              eventId: 'duplicate-order',
              enqueueCommitOrdinal: 8,
              enqueueEventIndex: 1,
            ),
          ),
        );
        await insertRow(
          database,
          'supported_sync_outbox',
          _courseOutbox(
            eventId: 'event-third',
            enqueueCommitOrdinal: 10,
            enqueueEventIndex: 0,
            kind: 'lesson',
            sound: null,
            skill: null,
            correct: null,
            activity: null,
            lessonId: 'lesson-1',
          ),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'supported_sync_outbox',
            <String, Object?>{
              'enqueue_commit_ordinal': 8,
              'enqueue_event_index': 1,
            },
            where: 'scope_id = ? AND event_id = ?',
            whereArgs: <Object?>[1, 'event-third'],
          ),
        );

        await expectSqlRejected(
          insertRow(
            database,
            'supported_sync_outbox',
            _courseOutbox(eventId: 'guest-outbox', scopeId: 5, userId: ''),
          ),
        );
        await expectSqlRejected(
          insertRow(
            database,
            'supported_sync_outbox',
            _courseOutbox(eventId: 'wrong-user', userId: 'account-42'),
          ),
        );
        await expectSqlRejected(
          insertRow(
            database,
            'supported_sync_outbox',
            _courseOutbox(eventId: 'wrong-course', courseId: 'other-course'),
          ),
        );
        await expectSqlRejected(
          insertRow(
            database,
            'supported_sync_outbox',
            _courseOutbox(
              eventId: 'comparison-outbox',
              scopeId: 6,
              userId: 'account-compare',
            ),
          ),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'supported_sync_outbox',
            <String, Object?>{'user_id': 'account-42'},
            where: 'scope_id = ? AND event_id = ?',
            whereArgs: <Object?>[1, 'event-first'],
          ),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'supported_sync_outbox',
            <String, Object?>{'course_id': 'other-course'},
            where: 'scope_id = ? AND event_id = ?',
            whereArgs: <Object?>[1, 'event-first'],
          ),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'supported_sync_outbox',
            <String, Object?>{'enqueue_commit_ordinal': 0},
            where: 'scope_id = ? AND event_id = ?',
            whereArgs: <Object?>[1, 'event-first'],
          ),
        );
        await expectSqlRejected(
          updateRows(
            database,
            'supported_sync_outbox',
            <String, Object?>{'enqueue_event_index': -1},
            where: 'scope_id = ? AND event_id = ?',
            whereArgs: <Object?>[1, 'event-first'],
          ),
        );
        await expectSqlRejected(
          insertRow(
            database,
            'supported_sync_outbox',
            _courseOutbox(
              eventId: 'bad-payload',
              kind: 'answer',
              lessonId: 'unexpected-payload',
            ),
          ),
        );
      },
    );

    test(
      'refuses unknown user_version without changing the database file',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'learning-v99-',
        );
        addTearDown(() async => directory.delete(recursive: true));
        final file = File('${directory.path}/future.sqlite');
        final raw = sqlite.sqlite3.open(file.path);
        raw.execute(
          'CREATE TABLE preservation_marker (id INTEGER PRIMARY KEY, value TEXT)',
        );
        raw.execute(
          "INSERT INTO preservation_marker (id, value) VALUES (1, 'kept')",
        );
        raw.execute('PRAGMA user_version = 99');
        raw.close();
        final List<int> before = await file.readAsBytes();

        final database = await openFileLearningTestDatabase(file);
        await expectLater(
          database.customSelect('SELECT 1').getSingle(),
          throwsA(isA<LearningUnsupportedVersionException>()),
        );
        await database.close();
        expect(await file.readAsBytes(), orderedEquals(before));

        final verify = sqlite.sqlite3.open(file.path);
        expect(verify.select('PRAGMA user_version').single['user_version'], 99);
        expect(
          verify
              .select('SELECT value FROM preservation_marker')
              .single['value'],
          'kept',
        );
        expect(
          verify.select(
            "SELECT name FROM sqlite_schema WHERE type = 'table' "
            "AND name = 'learning_scopes'",
          ),
          isEmpty,
        );
        verify.close();
      },
    );

    test(
      'rejects a version-1 file whose schema no longer matches v1',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'learning-drift-',
        );
        addTearDown(() async => directory.delete(recursive: true));
        final file = File('${directory.path}/drift.sqlite');
        final created = await openFileLearningTestDatabase(file);
        await created.customSelect('SELECT 1').getSingle();
        await created.close();
        final raw = sqlite.sqlite3.open(file.path);
        raw.execute('DROP TABLE learning_exposure');
        raw.execute('CREATE TABLE preserved_marker (value TEXT)');
        raw.close();

        final database = await openFileLearningTestDatabase(file);
        await expectLater(
          database.customSelect('SELECT 1').getSingle(),
          throwsA(isA<LearningCorruptException>()),
        );
        await database.close();

        final verify = sqlite.sqlite3.open(file.path);
        expect(verify.select('PRAGMA user_version').single['user_version'], 1);
        expect(
          verify.select(
            "SELECT name FROM sqlite_schema WHERE type = 'table' "
            "AND name = 'learning_exposure'",
          ),
          isEmpty,
        );
        expect(
          verify.select(
            "SELECT name FROM sqlite_schema WHERE type = 'table' "
            "AND name = 'preserved_marker'",
          ),
          hasLength(1),
        );
        verify.close();
      },
    );

    test(
      'rejects same-name altered indexes and triggers and missing constraints',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'learning-definition-drift-',
        );
        addTearDown(() async => directory.delete(recursive: true));
        final mutations = <(String, void Function(sqlite.Database raw))>[
          (
            'nonunique reversed-order index',
            (sqlite.Database raw) {
              raw.execute('DROP INDEX ux_learning_runs_scope_activity');
              raw.execute(
                'CREATE INDEX ux_learning_runs_scope_activity '
                'ON learning_runs(activity_id, scope_id)',
              );
            },
          ),
          (
            'unique index without expected expressions',
            (sqlite.Database raw) {
              raw.execute('DROP INDEX ux_learning_content_bindings_identity');
              raw.execute(
                'CREATE UNIQUE INDEX ux_learning_content_bindings_identity '
                'ON learning_content_bindings(scope_id, activity_id, '
                'content_revision, policy_kind, policy_revision, '
                'catalogue_fingerprint, section_fingerprint, annotation_hash, '
                'annotation_revision)',
              );
            },
          ),
          (
            'no-op same-name trigger',
            (sqlite.Database raw) {
              raw.execute(
                'DROP TRIGGER trg_learning_attempts_scope_family_insert',
              );
              raw.execute(
                'CREATE TRIGGER trg_learning_attempts_scope_family_insert '
                'BEFORE INSERT ON learning_attempts BEGIN SELECT 1; END',
              );
            },
          ),
          (
            'missing CHECK declaration',
            (sqlite.Database raw) => _rewriteSchemaSql(
              raw,
              objectType: 'table',
              objectName: 'learning_attempts',
              remove: ', CHECK(correct IN (0, 1))',
            ),
          ),
          (
            'missing composite foreign key declaration',
            (sqlite.Database raw) => _rewriteSchemaSql(
              raw,
              objectType: 'table',
              objectName: 'learning_attempt_values',
              remove:
                  ', FOREIGN KEY (scope_id, attempt_id) REFERENCES '
                  'learning_attempts(scope_id, attempt_id) ON DELETE RESTRICT',
            ),
          ),
        ];

        for (final (
              String description,
              void Function(sqlite.Database raw) mutate,
            )
            in mutations) {
          final file = await _createVersionOneFile(
            directory,
            description.replaceAll(' ', '-'),
          );
          final raw = sqlite.sqlite3.open(file.path);
          mutate(raw);
          raw.close();
          await _expectVersionOneFileRejectedUnchanged(file);
        }
      },
    );

    test('rolls back a failing synthetic upgrade and keeps v1 rows', () async {
      final directory = await Directory.systemTemp.createTemp(
        'learning-v2-fail-',
      );
      addTearDown(() async => directory.delete(recursive: true));
      final file = File('${directory.path}/rollback.sqlite');
      final database = await openFileLearningTestDatabase(file);
      await insertScope(
        database,
        id: 1,
        ownerKind: 'guest',
        ownerId: '',
        courseId: 'en-fr',
        family: 'course',
        revision: 1,
        commitOrdinal: 1,
      );
      await database.close();

      await expectLater(
        runLearningMigrationFailureProbe(file),
        throwsA(isA<StateError>()),
      );

      final reopened = await openFileLearningTestDatabase(file);
      expect(await pragmaUserVersion(reopened), 1);
      final preserved = await reopened
          .customSelect(
            'SELECT owner_id, revision FROM learning_scopes WHERE id = 1',
          )
          .getSingle();
      expect(preserved.read<String>('owner_id'), '');
      expect(preserved.read<int>('revision'), 1);
      final marker = await reopened
          .customSelect(
            "SELECT name FROM sqlite_schema WHERE type = 'table' "
            "AND name = 'migration_failure_probe'",
          )
          .get();
      expect(marker, isEmpty);
      await reopened.close();
    });

    test('shares concurrent opens and closes/reopens the same file', () async {
      final directory = await Directory.systemTemp.createTemp(
        'learning-handle-',
      );
      addTearDown(() async => directory.delete(recursive: true));
      final file = File('${directory.path}/handle.sqlite');
      final openingGate = Completer<void>();
      final openingStarted = Completer<void>();
      var openCount = 0;
      final handle = LearningDatabaseHandle(
        open: () async {
          openCount++;
          if (!openingStarted.isCompleted) openingStarted.complete();
          await openingGate.future;
          return openFileLearningTestDatabase(file);
        },
      );

      final Future<LearningDatabase> first = handle.open();
      final Future<LearningDatabase> second = handle.open();
      expect(identical(first, second), isTrue);
      await openingStarted.future;
      openingGate.complete();
      final List<LearningDatabase> opened = await Future.wait(
        <Future<LearningDatabase>>[first, second],
      );
      expect(openCount, 1);
      expect(identical(opened[0], opened[1]), isTrue);
      await insertScope(
        opened.first,
        id: 1,
        ownerKind: 'guest',
        ownerId: '',
        courseId: 'en-fr',
        family: 'course',
      );

      await handle.close();
      final LearningDatabase reopened = await handle.reopen();
      expect(identical(opened.first, reopened), isFalse);
      expect(await pragmaUserVersion(reopened), 1);
      expect(
        (await reopened
                .customSelect(
                  'SELECT COUNT(*) AS row_count FROM learning_scopes',
                )
                .getSingle())
            .read<int>('row_count'),
        1,
      );
      await handle.close();

      var attempt = 0;
      final retryingHandle = LearningDatabaseHandle(
        open: () async {
          attempt++;
          if (attempt == 1) throw StateError('synthetic open failure');
          return openFileLearningTestDatabase(
            File('${directory.path}/retry.sqlite'),
          );
        },
      );
      await expectLater(retryingHandle.open(), throwsA(isA<StateError>()));
      expect(await pragmaUserVersion(await retryingHandle.open()), 1);
      await retryingHandle.close();
    });

    test(
      'open during a pending close waits and returns a fresh usable database',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'learning-handle-overlap-',
        );
        addTearDown(() async => directory.delete(recursive: true));
        final firstFile = File('${directory.path}/first.sqlite');
        final secondFile = File('${directory.path}/second.sqlite');
        final openingGate = Completer<void>();
        final openingStarted = Completer<void>();
        var openCount = 0;
        final handle = LearningDatabaseHandle(
          open: () async {
            openCount++;
            if (openCount == 1) {
              openingStarted.complete();
              await openingGate.future;
              return openFileLearningTestDatabase(firstFile);
            }
            return openFileLearningTestDatabase(secondFile);
          },
        );
        addTearDown(handle.close);

        final Future<LearningDatabase> first = handle.open();
        await openingStarted.future;
        final Future<void> closing = handle.close();
        final Future<LearningDatabase> openingAfterClose = handle.open();
        final bool reusedOpening = identical(openingAfterClose, first);
        expect(openCount, 1);

        openingGate.complete();
        final LearningDatabase firstDatabase = await first;
        await closing;
        final LearningDatabase secondDatabase = await openingAfterClose;
        expect(reusedOpening, isFalse);
        expect(identical(firstDatabase, secondDatabase), isFalse);
        expect(openCount, 2);
        expect(await pragmaUserVersion(secondDatabase), 1);
        expect(
          (await secondDatabase.customSelect('SELECT 1 AS usable').getSingle())
              .read<int>('usable'),
          1,
        );
      },
    );
  });
}
