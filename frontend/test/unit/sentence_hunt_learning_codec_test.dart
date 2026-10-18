import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio_contract.dart';
import 'package:linguist/src/core/course/course_learning_transaction.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_codec.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_command.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_transition.dart';

import '../support/sentence_hunt_fixtures.dart';

void main() {
  test('sentence_codec_byte_bound_geometry_probe', () {
    const String packagePath = 'assets/audio/fr-sentences';
    final SentenceHuntCatalogue pending = decodeFrenchSentencePackage(
      manifestJson: File('$packagePath/manifest.json').readAsStringSync(),
      provenanceJson: File('$packagePath/provenance.json').readAsStringSync(),
      annotationsJson: File('$packagePath/annotations.json').readAsStringSync(),
      sourceEvidenceJson:
          File('$packagePath/source-evidence.json').readAsStringSync(),
    );
    final SentenceHuntCatalogue synthetic = syntheticSentenceCatalogue();
    const int largeGeometryWords = 13;
    final SentenceHuntCatalogue largeSynthetic = syntheticSentenceCatalogue(
      wordsPerSentence: largeGeometryWords,
    );
    expect(pending.hasValidRoot, isTrue);
    expect(
        pending.sections.every(
            (SentenceHuntSection section) => !pending.isAvailable(section.id)),
        isTrue);
    final int largestPendingFingerprintBytes = pending.sections
        .map((SentenceHuntSection section) =>
            utf8.encode(section.sectionFingerprint).length)
        .reduce((int a, int b) => a > b ? a : b);
    final List<SentenceHuntItem> pendingItems = pending.sections
        .expand((SentenceHuntSection section) => section.items)
        .toList(growable: false);
    final int largestPendingTextBytes = pendingItems
        .map((SentenceHuntItem item) => utf8.encode(item.sentence.text).length)
        .reduce((int a, int b) => a > b ? a : b);
    final int largestPendingTokenCount = pendingItems
        .map((SentenceHuntItem item) => item.sentence.tokens.length)
        .reduce((int a, int b) => a > b ? a : b);
    final SentenceHuntProfileScope scope = SentenceHuntProfileScope(
      courseId: 'en-fr',
      owner: LearningOwner.guest(),
    );
    String canonicalAdvance(String sectionId, String fingerprint) =>
        sentenceHuntCanonicalCommand(SentenceHuntLearningCommand(
          scope: scope,
          authGeneration: 0,
          sectionId: sectionId,
          sectionFingerprint: fingerprint,
          expected: const LearningCursorPosition(
            generation: 0,
            sequence: 0,
            revision: 0,
          ),
          token: '0000000000000000000000',
          submittedAt: DateTime.utc(2026),
          action: const AdvanceSentenceHuntItem(),
        ));
    final List<SentenceHuntItem> largeSyntheticItems = largeSynthetic.sections
        .expand((SentenceHuntSection section) => section.items)
        .toList(growable: false);
    expect(largeSynthetic.hasValidRoot, isTrue);
    expect(
      largeSynthetic.sections.every((SentenceHuntSection section) =>
          largeSynthetic.isAvailable(section.id)),
      isTrue,
      reason: largeSynthetic.diagnostics
          .map((SentenceHuntDiagnostic diagnostic) =>
              '${diagnostic.code}/${diagnostic.recordId}: '
              '${diagnostic.message}')
          .join('\n'),
    );
    expect(
      largeSynthetic.sections.every((SentenceHuntSection section) =>
          utf8.encode(section.sectionFingerprint).length >=
          largestPendingFingerprintBytes),
      isTrue,
    );
    expect(
      largeSyntheticItems.every((SentenceHuntItem item) =>
          item.sentence.tokens.length >= largestPendingTokenCount &&
          utf8.encode(item.sentence.text).length >= largestPendingTextBytes),
      isTrue,
    );
    for (final (String label, SentenceHuntCatalogue catalogue)
        in <(String, SentenceHuntCatalogue)>[
      ('synthetic', synthetic),
      ('synthetic-large-geometry', largeSynthetic),
      ('production-pending-read-only', pending),
    ]) {
      for (final SentenceHuntSection section in catalogue.sections) {
        final List<int> textBytes = section.items
            .map((SentenceHuntItem item) =>
                utf8.encode(item.sentence.text).length)
            .toList(growable: false);
        final List<int> tokenCounts = section.items
            .map((SentenceHuntItem item) => item.sentence.tokens.length)
            .toList(growable: false);
        final String fingerprint = section.sectionFingerprint;
        final int fingerprintBytes = utf8.encode(fingerprint).length;
        final int commandFieldBytes =
            utf8.encode(jsonEncode(fingerprint)).length;
        final String command = canonicalAdvance(section.id, fingerprint);
        final String baselineCommand = canonicalAdvance(section.id, '{}');
        final int commandFingerprintBytes =
            utf8.encode(command).length - utf8.encode(baselineCommand).length;
        final int receiptFingerprintBytes =
            utf8.encode(jsonEncode(command)).length -
                utf8.encode(jsonEncode(baselineCommand)).length;
        final int commandBytes = utf8.encode(command).length;
        final int receiptCommandBytes = utf8.encode(jsonEncode(command)).length;
        // ignore: avoid_print
        print(
          'BYTEBOUND $label ${section.id}: '
          'fingerprintUtf8=$fingerprintBytes '
          'fingerprintJsonStringUtf8=$commandFieldBytes '
          'canonicalCommandUtf8=$commandBytes '
          'receiptCanonicalCommandUtf8=$receiptCommandBytes '
          'canonicalCommandFingerprintDeltaUtf8=$commandFingerprintBytes '
          'receiptCommandFingerprintDeltaUtf8=$receiptFingerprintBytes '
          'textUtf8ByItem=$textBytes tokenCountsByItem=$tokenCounts',
        );
      }
    }
  });

  test('sentence_codec_empty_document_has_exact_isolated_family', () {
    final SentenceHuntProfileScope scope = SentenceHuntProfileScope(
      courseId: 'en-fr',
      owner: LearningOwner.guest(),
    );
    const SentenceHuntLearningCodec codec = SentenceHuntLearningCodec();
    final String raw = codec.encode(SentenceHuntLearningState.empty(scope));
    final Map<String, Object?> document =
        jsonDecode(raw) as Map<String, Object?>;

    expect(document.keys.toList(), <String>[
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
    ]);
    expect(document['schemaVersion'], 1);
    expect(document['family'], 'sentence-hunt');
    expect(codec.keyFor(scope), 'course.learning.sentence-hunt.v1.ZW4tZnI.g');
    final SentenceHuntLearningState decoded =
        codec.decode(raw, scope, syntheticSentenceCatalogue());
    expect(decoded, isA<SentenceHuntLearningState>());
    expect(codec.encode(decoded), raw);
  });

  test('sentence_codec_encode_rejects_incomplete_committed_receipt_history',
      () {
    final SentenceHuntProfileScope scope = SentenceHuntProfileScope(
      courseId: 'en-fr',
      owner: LearningOwner.guest(),
    );
    final SentenceHuntLearningState structurallyIncomplete =
        SentenceHuntLearningState(
      scope: scope,
      revision: 1,
      commitOrdinal: 1,
      slots: const <String, SentenceHuntSlot>{},
      attempts: const <SentenceHuntAttempt>[],
      receipts: const <SentenceHuntReceipt>[],
      mistakes: const <SentenceHuntMistakeKey, SentenceHuntMistake>{},
      summaries: const <SentenceHuntSummaryKey, SentenceHuntSummary>{},
      completions: const <SentenceHuntCompletion>[],
      teachingExposure: const <SentenceHuntExposureKey>{},
    );

    expect(
      () => const SentenceHuntLearningCodec().encode(structurallyIncomplete),
      throwsA(isA<SentenceHuntUnavailableException>()),
    );
    expect(structurallyIncomplete.commitOrdinal, 1);
    expect(structurallyIncomplete.receipts, isEmpty);
  });

  test('sentence_codec_encode_rejects_receipt_tail_gaps', () {
    final _CodecDriver driver = _CodecDriver();
    for (var index = 0; index < fixtureSectionIds.length; index++) {
      driver.start(index);
    }
    const SentenceHuntLearningLimits limits =
        SentenceHuntLearningLimits(maxReceipts: 2);
    final SentenceHuntLearningState state = SentenceHuntLearningState(
      scope: driver.state.scope,
      revision: driver.state.revision,
      commitOrdinal: driver.state.commitOrdinal,
      slots: driver.state.slots,
      attempts: driver.state.attempts,
      receipts: <SentenceHuntReceipt>[
        driver.state.receipts.first,
        driver.state.receipts.last,
      ],
      mistakes: driver.state.mistakes,
      summaries: driver.state.summaries,
      completions: driver.state.completions,
      teachingExposure: driver.state.teachingExposure,
    );

    expect(
      () => const SentenceHuntLearningCodec(limits: limits).encode(state),
      throwsA(isA<SentenceHuntUnavailableException>()),
    );
  });

  test('sentence_codec_encode_rejects_unreadable_trimmed_slot_receipt', () {
    final _CodecDriver driver = _CodecDriver();
    for (var index = 0; index < fixtureSectionIds.length; index++) {
      driver.start(index);
    }
    final SentenceHuntSlot prior = driver.state.slots[fixtureSectionIds.first]!;
    final SentenceHuntReceipt unreadableLatest = SentenceHuntReceipt(
      scope: prior.latestReceipt.scope,
      sectionId: prior.latestReceipt.sectionId,
      token: prior.latestReceipt.token,
      canonicalCommand: '{not-json',
      before: prior.latestReceipt.before,
      after: prior.latestReceipt.after,
      commitOrdinal: prior.latestReceipt.commitOrdinal,
    );
    final Map<String, SentenceHuntSlot> slots =
        Map<String, SentenceHuntSlot>.of(driver.state.slots)
          ..[fixtureSectionIds.first] = SentenceHuntSlot(
            sectionId: prior.sectionId,
            checkpoint: prior.checkpoint,
            cursor: prior.cursor,
            latestReceipt: unreadableLatest,
          );
    final SentenceHuntLearningState state = SentenceHuntLearningState(
      scope: driver.state.scope,
      revision: driver.state.revision,
      commitOrdinal: driver.state.commitOrdinal,
      slots: slots,
      attempts: driver.state.attempts,
      receipts: driver.state.receipts.skip(1).toList(),
      mistakes: driver.state.mistakes,
      summaries: driver.state.summaries,
      completions: driver.state.completions,
      teachingExposure: driver.state.teachingExposure,
    );
    const SentenceHuntLearningLimits limits =
        SentenceHuntLearningLimits(maxReceipts: 2);

    expect(
      () => const SentenceHuntLearningCodec(limits: limits).encode(state),
      throwsA(isA<SentenceHuntUnavailableException>()),
    );
  });

  test('sentence_codec_encode_does_not_require_implicit_catalogue_membership',
      () {
    final SentenceHuntCatalogue futureCatalogue =
        _catalogueAtContentRevision(fixtureSectionIds.first, 2);
    final _CodecDriver driver = _CodecDriver(catalogue: futureCatalogue);
    driver.start(0);
    const SentenceHuntLearningCodec codec = SentenceHuntLearningCodec();
    final String raw = codec.encode(driver.state);

    expect(raw, isNotEmpty);
    expect(
      () => codec.decode(raw, driver.scope, syntheticSentenceCatalogue()),
      throwsA(isA<SentenceHuntUnavailableException>()),
      reason: 'decode still requires the caller\'s matching catalogue',
    );
    final SentenceHuntLearningState restored =
        codec.decode(raw, driver.scope, futureCatalogue);
    expect(restored.slots.values.single.checkpoint.contentRevision, 2);
    expect(codec.encode(restored), raw);
  });

  test('sentence_codec_rejects_saved_and_receipt_policy_outside_descriptor',
      () {
    final _CodecDriver driver = _CodecDriver();
    driver.start(0);
    const SentenceHuntLearningCodec codec = SentenceHuntLearningCodec();
    for (final String forgedField in <String>[
      'checkpoint',
      'session',
      'start-receipt',
    ]) {
      final Map<String, Object?> forged =
          jsonDecode(codec.encode(driver.state)) as Map<String, Object?>;
      final Map<String, Object?> slot =
          (forged['slots'] as Map<String, Object?>)[fixtureSectionIds.first]
              as Map<String, Object?>;
      final Map<String, Object?> checkpoint =
          slot['checkpoint'] as Map<String, Object?>;

      if (forgedField == 'checkpoint') {
        (checkpoint['policy']
            as Map<String, Object?>)['completionThresholdPercent'] = 1;
      } else if (forgedField == 'session') {
        final Map<String, Object?> session =
            checkpoint['session'] as Map<String, Object?>;
        (session['policy']
            as Map<String, Object?>)['completionThresholdPercent'] = 1;
      } else {
        void forgeStartPolicy(Map<String, Object?> receipt) {
          final Map<String, Object?> command =
              jsonDecode(receipt['canonicalCommand'] as String)
                  as Map<String, Object?>;
          (((command['action'] as Map<String, Object?>)['policy']
              as Map<String, Object?>))['completionThresholdPercent'] = 1;
          receipt['canonicalCommand'] = jsonEncode(command);
        }

        forgeStartPolicy(slot['latestReceipt'] as Map<String, Object?>);
        forgeStartPolicy((forged['receipts'] as List<Object?>).single
            as Map<String, Object?>);
      }

      final String raw = jsonEncode(forged);
      expect(
        () => codec.decode(raw, driver.scope, driver.catalogue),
        throwsA(isA<SentenceHuntUnavailableException>()),
        reason: 'forged saved $forgedField policy',
      );
      expect(jsonEncode(forged), raw, reason: '$forgedField input unchanged');
      expect(codec.encode(driver.state), isNot(raw),
          reason: '$forgedField did not mutate prior state');
    }
  });

  test('sentence_codec_round_trips_registered_versioned_start_policy', () {
    final SentenceHuntCatalogue catalogue = _catalogueWithVersionedPolicy();
    final _CodecDriver driver = _CodecDriver(catalogue: catalogue);
    final String sectionId = fixtureSectionIds.first;
    driver.start(0);
    for (var index = 0; index < 5; index++) {
      driver.answerCurrent(sectionId, correct: index < 4);
      driver.advance(sectionId);
    }
    driver.act(sectionId, const FinishSentenceHuntRun());
    const SentenceHuntLearningCodec codec = SentenceHuntLearningCodec();
    final String raw = codec.encode(driver.state);
    final SentenceHuntLearningState restored =
        codec.decode(raw, driver.scope, catalogue);

    expect(restored.completions, hasLength(1));
    expect(restored.completions.single.policyRevision, 2);
    expect(restored.completions.single.thresholdPercent, 70);
    expect(
        restored.slots[sectionId]!.checkpoint.policy.completionThresholdPercent,
        70);
    expect(codec.encode(restored), raw);
  });

  test('sentence_codec_round_trips_three_independent_slots_and_receipts', () {
    final _CodecDriver driver = _CodecDriver();
    for (var index = 0; index < fixtureSectionIds.length; index++) {
      driver.start(index);
    }
    for (final String sectionId in fixtureSectionIds) {
      driver.answerCurrent(sectionId);
      driver.advance(sectionId);
    }
    const SentenceHuntLearningCodec codec = SentenceHuntLearningCodec();
    final String raw = codec.encode(driver.state);

    final SentenceHuntLearningState restored = codec.decode(
      raw,
      driver.scope,
      driver.catalogue,
    );
    expect(restored.slots.keys.toSet(), fixtureSectionIds.toSet());
    expect(restored.commitOrdinal, 9);
    expect(restored.attempts, hasLength(3));
    expect(restored.receipts, hasLength(9));
    for (final String sectionId in fixtureSectionIds) {
      final SentenceHuntSlot oldSlot = driver.state.slots[sectionId]!;
      final SentenceHuntSlot newSlot = restored.slots[sectionId]!;
      expect(newSlot.cursor, oldSlot.cursor);
      expect(newSlot.latestReceipt.commitOrdinal,
          oldSlot.latestReceipt.commitOrdinal);
      expect(newSlot.latestReceipt.commitOrdinal, lessThanOrEqualTo(9));
      expect(jsonEncode(newSlot.checkpoint.sessionJson),
          jsonEncode(oldSlot.checkpoint.sessionJson));
    }
    expect(codec.encode(restored), raw);
  });

  test('sentence_codec_round_trips_review_only_mode_and_its_finite_queue', () {
    final _CodecDriver driver = _CodecDriver();
    final String sectionId = fixtureSectionIds.first;
    driver.start(0);
    for (var index = 0; index < fixtureItemIds.first.length; index++) {
      driver.answerCurrent(sectionId, correct: index != 0);
      driver.advance(sectionId);
    }
    driver.act(sectionId, const FinishSentenceHuntRun());
    final SentenceHuntSlot finished = driver.state.slots[sectionId]!;
    driver.act(
      sectionId,
      StartSentenceHuntRun(
        sessionId: 'review-only-codec-run',
        policy: finished.checkpoint.policy,
        mode: SentenceHuntRunMode.reviewOnly,
      ),
    );
    const SentenceHuntLearningCodec codec = SentenceHuntLearningCodec();
    final String raw = codec.encode(driver.state);
    final SentenceHuntLearningState restored =
        codec.decode(raw, driver.scope, driver.catalogue);
    final SentenceHuntSlot slot = restored.slots[sectionId]!;
    final LessonSectionSession session = LessonSectionSession.fromJson(
      _mutable(slot.checkpoint.sessionJson) as Map<String, dynamic>,
      itemIds: fixtureItemIds.first,
      contentRevision: slot.checkpoint.contentRevision,
    );

    expect(slot.checkpoint.mode, SentenceHuntRunMode.reviewOnly);
    expect(slot.checkpoint.finished, isFalse);
    expect(session.phase, LessonSectionPhase.exercise);
    expect(session.queue, <String>[fixtureItemIds.first.first]);
    expect(restored.attempts, hasLength(5));
    expect(codec.encode(restored), raw);
  });

  test('sentence_codec_retains_exposure_and_first_run_summary_dimensions', () {
    final _CodecDriver driver = _CodecDriver();
    final String sectionId = fixtureSectionIds.first;
    driver.start(0);
    for (var index = 0; index < fixtureItemIds.first.length; index++) {
      driver.answerCurrent(sectionId);
      driver.advance(sectionId);
    }
    driver.act(sectionId, const FinishSentenceHuntRun());
    driver.act(
      sectionId,
      StartSentenceHuntRun(
        sessionId: 'exposed-follow-up',
        policy: driver.catalogue.section(sectionId).policy,
        mode: SentenceHuntRunMode.practice,
      ),
    );
    final SentenceHuntTransition exposed = driver.answerCurrent(sectionId);
    final SentenceHuntAttempt exposedFirstAttempt = exposed.attempts.single;
    final SentenceHuntLearningState nextState = exposed.nextState;
    const SentenceHuntLearningCodec codec = SentenceHuntLearningCodec();
    final String raw = codec.encode(nextState);
    final SentenceHuntLearningState restored =
        codec.decode(raw, driver.scope, driver.catalogue);
    final SentenceHuntSummary summary = restored.summaries.values.firstWhere(
      (SentenceHuntSummary value) =>
          value.content.itemId == fixtureItemIds.first.first,
    );

    expect(exposedFirstAttempt.presentation, AttemptPresentation.firstInRun);
    expect(exposedFirstAttempt.teachingExposed, isTrue);
    expect(restored.teachingExposure, hasLength(1));
    expect(summary.firstInRun.correct, 2);
    expect(summary.firstInRun.total, 2);
    expect(summary.firstTeachingExposed.correct, 1);
    expect(summary.firstTeachingExposed.total, 1);
    expect(codec.encode(restored), raw);
  });

  test('sentence_codec_trims_history_but_retains_independent_slot_receipts',
      () {
    const SentenceHuntLearningLimits limits = SentenceHuntLearningLimits(
      maxAttempts: 1,
      maxReceipts: 2,
    );
    final _CodecDriver driver = _CodecDriver(limits: limits);
    for (var index = 0; index < fixtureSectionIds.length; index++) {
      driver.start(index);
    }
    driver.answerCurrent(fixtureSectionIds.first);
    driver.advance(fixtureSectionIds.first);
    const SentenceHuntLearningCodec codec =
        SentenceHuntLearningCodec(limits: limits);
    final String raw = codec.encode(driver.state);

    expect(driver.state.attempts, hasLength(1));
    expect(
        driver.state.receipts.map((SentenceHuntReceipt r) => r.commitOrdinal),
        <int>[4, 5]);
    final SentenceHuntLearningState restored = codec.decode(
      raw,
      driver.scope,
      driver.catalogue,
    );
    expect(restored.receipts.map((SentenceHuntReceipt r) => r.commitOrdinal),
        <int>[4, 5]);
    expect(restored.slots.keys.toSet(), fixtureSectionIds.toSet());
    for (final String sectionId in fixtureSectionIds) {
      expect(restored.slots[sectionId]!.latestReceipt.commitOrdinal,
          driver.state.slots[sectionId]!.latestReceipt.commitOrdinal);
    }
    expect(codec.encode(restored), raw);
  });

  test('sentence_codec_round_trips_full_retained_attempt_and_receipt_limits',
      () {
    var maximumBytes = 0;
    for (var section = 0; section < fixtureSectionIds.length; section++) {
      final _CodecDriver driver = _CodecDriver(fastCommands: true);
      for (var run = 0; run < sentenceHuntMaxAttempts ~/ 5; run++) {
        driver.start(section, replaceExisting: run > 0);
        for (var item = 0; item < fixtureItemIds[section].length; item++) {
          driver.answerCurrent(fixtureSectionIds[section]);
          driver.advance(fixtureSectionIds[section]);
        }
      }
      driver.start((section + 1) % fixtureSectionIds.length);
      driver.start((section + 2) % fixtureSectionIds.length);

      expect(driver.state.attempts, hasLength(sentenceHuntMaxAttempts));
      expect(driver.state.receipts, hasLength(sentenceHuntMaxReceipts));
      expect(driver.state.slots, hasLength(sentenceHuntMaxSlots));
      const SentenceHuntLearningCodec codec = SentenceHuntLearningCodec();
      final String raw = codec.encode(driver.state);
      final int encodedBytes = utf8.encode(raw).length;
      final SentenceHuntLearningState restored =
          codec.decode(raw, driver.scope, driver.catalogue);

      if (encodedBytes > maximumBytes) maximumBytes = encodedBytes;
      expect(restored.attempts, hasLength(sentenceHuntMaxAttempts));
      expect(restored.receipts, hasLength(sentenceHuntMaxReceipts));
      expect(restored.slots, hasLength(sentenceHuntMaxSlots));
      expect(codec.encode(restored), raw);
      // ignore: avoid_print
      print(
        'Full-retention fixture for ${fixtureSectionIds[section]}: '
        '${driver.state.attempts.length} attempts, '
        '${driver.state.receipts.length} receipts, '
        '${driver.state.slots.length} slots, $encodedBytes UTF-8 bytes; '
        'strict decode and canonical round-trip passed.',
      );
    }
    expect(maximumBytes, lessThanOrEqualTo(sentenceHuntMaxDocumentBytes));
  });

  test('sentence_codec_round_trips_full_retention_large_synthetic_geometry',
      () {
    final SentenceHuntCatalogue catalogue = syntheticSentenceCatalogue(
      wordsPerSentence: 13,
    );
    var maximumBytes = 0;
    for (var section = 0; section < fixtureSectionIds.length; section++) {
      final _CodecDriver driver = _CodecDriver(
        fastCommands: true,
        catalogue: catalogue,
      );
      for (var run = 0; run < sentenceHuntMaxAttempts ~/ 5; run++) {
        driver.start(section, replaceExisting: run > 0);
        for (var item = 0; item < fixtureItemIds[section].length; item++) {
          driver.answerCurrent(fixtureSectionIds[section]);
          driver.advance(fixtureSectionIds[section]);
        }
      }
      driver.start((section + 1) % fixtureSectionIds.length);
      driver.start((section + 2) % fixtureSectionIds.length);

      expect(driver.state.attempts, hasLength(sentenceHuntMaxAttempts));
      expect(driver.state.receipts, hasLength(sentenceHuntMaxReceipts));
      expect(driver.state.slots, hasLength(sentenceHuntMaxSlots));
      const SentenceHuntLearningCodec codec = SentenceHuntLearningCodec();
      final String raw = codec.encode(driver.state);
      final int encodedBytes = utf8.encode(raw).length;
      final SentenceHuntLearningState restored =
          codec.decode(raw, driver.scope, catalogue);

      if (encodedBytes > maximumBytes) maximumBytes = encodedBytes;
      expect(restored.attempts, hasLength(sentenceHuntMaxAttempts));
      expect(restored.receipts, hasLength(sentenceHuntMaxReceipts));
      expect(restored.slots, hasLength(sentenceHuntMaxSlots));
      expect(codec.encode(restored), raw);
      // ignore: avoid_print
      print(
        'Large-geometry full-retention synthetic fixture for '
        '${fixtureSectionIds[section]}: '
        '${driver.state.attempts.length} attempts, '
        '${driver.state.receipts.length} receipts, '
        '${driver.state.slots.length} slots, $encodedBytes UTF-8 bytes; '
        'strict decode and canonical round-trip passed.',
      );
    }
    expect(maximumBytes, lessThanOrEqualTo(sentenceHuntMaxDocumentBytes));
  });

  test('sentence_transition_refuses_aggregate_capacity_without_mutating_state',
      () {
    const SentenceHuntLearningLimits limits =
        SentenceHuntLearningLimits(maxAggregateEntries: 1);
    final _CodecDriver driver = _CodecDriver(limits: limits);
    driver.start(0);
    driver.answerCurrent(fixtureSectionIds.first);
    driver.advance(fixtureSectionIds.first);
    const SentenceHuntLearningCodec codec =
        SentenceHuntLearningCodec(limits: limits);
    final String before = codec.encode(driver.state);

    expect(
      () => driver.answerCurrent(fixtureSectionIds.first),
      throwsA(isA<SentenceHuntCapacityException>()),
    );
    expect(codec.encode(driver.state), before);
  });

  test('sentence_codec_preserves_history_when_current_section_is_pending', () {
    final _CodecDriver driver = _CodecDriver();
    driver.start(0);
    driver.answerCurrent(fixtureSectionIds.first);
    const SentenceHuntLearningCodec codec = SentenceHuntLearningCodec();
    final String raw = codec.encode(driver.state);
    final SentenceHuntCatalogue pending =
        syntheticSentenceCatalogue(reviewed: false);

    expect(pending.isAvailable(fixtureSectionIds.first), isFalse);
    final SentenceHuntLearningState restored =
        codec.decode(raw, driver.scope, pending);
    expect(restored.attempts, hasLength(1));
    expect(restored.slots.keys, contains(fixtureSectionIds.first));
    expect(
      () => SentenceHuntTransitionEngine(catalogue: pending).prepare(
        state: restored,
        sectionId: fixtureSectionIds.first,
        action: StartSentenceHuntRun(
          sessionId: 'pending-restart',
          policy: pending.section(fixtureSectionIds.first).policy,
          mode: SentenceHuntRunMode.practice,
          replaceExisting: true,
        ),
        authGeneration: 0,
        token: 'pending0000000000000000',
        submittedAt: DateTime.utc(2026),
      ),
      throwsStateError,
    );
  });

  test('sentence_codec_retains_known_revision_completion_without_resuming_it',
      () {
    final _CodecDriver driver = _CodecDriver();
    final String sectionId = fixtureSectionIds.first;
    driver.start(0);
    for (var index = 0; index < fixtureItemIds.first.length; index++) {
      driver.answerCurrent(sectionId);
      driver.advance(sectionId);
    }
    driver.act(sectionId, const FinishSentenceHuntRun());
    final SentenceHuntSection historicalSection =
        driver.catalogue.section(sectionId);
    final String raw = const SentenceHuntLearningCodec().encode(driver.state);
    final SentenceHuntCatalogue withHistory =
        _catalogueWithHistoricalRevision(historicalSection);
    final SentenceHuntCatalogue withoutHistory =
        _catalogueAtContentRevision(sectionId, 2);
    const SentenceHuntLearningCodec codec = SentenceHuntLearningCodec();

    expect(
      () => codec.decode(raw, driver.scope, withoutHistory),
      throwsA(isA<SentenceHuntUnavailableException>()),
    );
    final SentenceHuntLearningState restored =
        codec.decode(raw, driver.scope, withHistory);
    expect(restored.completions, hasLength(1));
    expect(restored.completions.single.contentRevision, 1);
    expect(restored.slots[sectionId]!.checkpoint.contentRevision, 1);
    final SentenceHuntTransitionEngine currentEngine =
        SentenceHuntTransitionEngine(catalogue: withHistory);
    expect(
      () => currentEngine.prepare(
        state: restored,
        sectionId: sectionId,
        action: const AdvanceSentenceHuntItem(),
        authGeneration: 0,
        token: 'stalecursor00000000000',
        submittedAt: DateTime.utc(2026),
      ),
      throwsStateError,
    );

    final StartSentenceHuntRun replacement = StartSentenceHuntRun(
      sessionId: 'revision-two-run',
      policy: withHistory.section(sectionId).policy,
      mode: SentenceHuntRunMode.practice,
      replaceExisting: true,
    );
    expect(
      () => currentEngine.prepare(
        state: restored,
        sectionId: sectionId,
        action: replacement,
        authGeneration: 0,
        token: 'currentrun000000000000',
        submittedAt: DateTime.utc(2026),
      ),
      throwsStateError,
    );
    expect(
      () => currentEngine.evaluate(
        state: restored,
        command: SentenceHuntLearningCommand(
          scope: restored.scope,
          authGeneration: 0,
          sectionId: sectionId,
          sectionFingerprint: withHistory.section(sectionId).sectionFingerprint,
          expected: restored.slots[sectionId]!.cursor,
          token: 'currentrun000000000001',
          submittedAt: DateTime.utc(2026),
          action: replacement,
        ),
        committedAt: DateTime.utc(2026),
      ),
      throwsStateError,
    );
    expect(codec.encode(restored), raw);
    expect(restored.completions.single.contentRevision, 1);
    expect(restored.slots[sectionId]!.checkpoint.contentRevision, 1);
  });

  test('sentence_codec_refuses_unknown_and_future_bytes_without_repair', () {
    final SentenceHuntProfileScope scope = SentenceHuntProfileScope(
      courseId: 'en-fr',
      owner: LearningOwner.guest(),
    );
    const SentenceHuntLearningCodec codec = SentenceHuntLearningCodec();
    final SentenceHuntCatalogue catalogue = syntheticSentenceCatalogue();
    final Map<String, Object?> base =
        jsonDecode(codec.encode(SentenceHuntLearningState.empty(scope)))
            as Map<String, Object?>;
    final List<Map<String, Object?>> invalid = <Map<String, Object?>>[
      <String, Object?>{...base, 'schemaVersion': 2},
      <String, Object?>{...base, 'family': 'comparison'},
      <String, Object?>{...base, 'revision': true},
      <String, Object?>{...base, 'revision': 1.0},
      <String, Object?>{...base, 'unknownFutureField': true},
      <String, Object?>{
        ...base,
        'owner': <String, Object?>{'kind': 'account', 'userId': 'other'},
      },
    ];
    for (final Map<String, Object?> row in invalid) {
      final String raw = jsonEncode(row);
      expect(
        () => codec.decode(raw, scope, catalogue),
        throwsA(isA<SentenceHuntUnavailableException>()),
        reason: raw,
      );
      expect(jsonEncode(row), raw);
    }
  });

  test('sentence_codec_rejects_nested_unknown_fields_types_and_variants', () {
    final _CodecDriver driver = _CodecDriver();
    driver.start(0);
    const SentenceHuntLearningCodec codec = SentenceHuntLearningCodec();
    final String base = codec.encode(driver.state);
    final List<void Function(Map<String, Object?>)> corruptions =
        <void Function(Map<String, Object?>)>[
      (Map<String, Object?> document) {
        final Map<String, Object?> slot =
            (document['slots'] as Map<String, Object?>)[fixtureSectionIds.first]
                as Map<String, Object?>;
        (slot['checkpoint'] as Map<String, Object?>)['futureField'] = true;
      },
      (Map<String, Object?> document) {
        final Map<String, Object?> slot =
            (document['slots'] as Map<String, Object?>)[fixtureSectionIds.first]
                as Map<String, Object?>;
        (slot['checkpoint'] as Map<String, Object?>)['finished'] = 1;
      },
      (Map<String, Object?> document) {
        final Map<String, Object?> slot =
            (document['slots'] as Map<String, Object?>)[fixtureSectionIds.first]
                as Map<String, Object?>;
        final Map<String, Object?> checkpoint =
            slot['checkpoint'] as Map<String, Object?>;
        (checkpoint['session'] as Map<String, Object?>)['position'] = 5;
      },
      (Map<String, Object?> document) {
        final List<Object?> receipts = document['receipts'] as List<Object?>;
        final Map<String, Object?> receipt =
            receipts.first as Map<String, Object?>;
        final Map<String, Object?> command =
            jsonDecode(receipt['canonicalCommand'] as String)
                as Map<String, Object?>;
        (command['action'] as Map<String, Object?>)['kind'] = 'future-action';
        receipt['canonicalCommand'] = jsonEncode(command);
      },
      (Map<String, Object?> document) {
        final Map<String, Object?> slot =
            (document['slots'] as Map<String, Object?>)[fixtureSectionIds.first]
                as Map<String, Object?>;
        (slot['latestReceipt'] as Map<String, Object?>)['sectionId'] =
            fixtureSectionIds[1];
      },
    ];

    for (final void Function(Map<String, Object?>) corrupt in corruptions) {
      final Map<String, Object?> document =
          jsonDecode(base) as Map<String, Object?>;
      corrupt(document);
      final String raw = jsonEncode(document);
      expect(
        () => codec.decode(raw, driver.scope, driver.catalogue),
        throwsA(isA<SentenceHuntUnavailableException>()),
        reason: raw,
      );
    }

    final int validBytes = utf8.encode(base).length;
    final SentenceHuntLearningCodec byteLimited = SentenceHuntLearningCodec(
      limits: SentenceHuntLearningLimits(maxDocumentBytes: validBytes),
    );
    final String oversized = '$base ';
    expect(
      () => byteLimited.decode(oversized, driver.scope, driver.catalogue),
      throwsA(isA<SentenceHuntUnavailableException>()),
    );
    expect(oversized, '$base ');
  });

  test('sentence_codec_byte_limit_error_reports_encoded_size', () {
    final _CodecDriver driver = _CodecDriver();
    driver.start(0);
    final String valid = const SentenceHuntLearningCodec().encode(driver.state);
    final int byteCount = utf8.encode(valid).length;
    final SentenceHuntLearningCodec limited = SentenceHuntLearningCodec(
      limits: SentenceHuntLearningLimits(maxDocumentBytes: byteCount - 1),
    );

    expect(
      () => limited.encode(driver.state),
      throwsA(
        isA<SentenceHuntUnavailableException>().having(
          (SentenceHuntUnavailableException error) => error.cause,
          'cause',
          'Encoded sentence-hunt document is $byteCount bytes; limit is '
              '${byteCount - 1}.',
        ),
      ),
    );
  });

  test('sentence_codec_enforces_exact_utf8_byte_limit_without_mutation', () {
    final SentenceHuntProfileScope scope = SentenceHuntProfileScope(
      courseId: 'en-fr',
      owner: LearningOwner.account('élève'),
    );
    final SentenceHuntLearningState state =
        SentenceHuntLearningState.empty(scope);
    const SentenceHuntLearningCodec unlimited = SentenceHuntLearningCodec();
    final String raw = unlimited.encode(state);
    final int byteCount = utf8.encode(raw).length;
    expect(byteCount, greaterThan(raw.length));

    final SentenceHuntLearningCodec exact = SentenceHuntLearningCodec(
      limits: SentenceHuntLearningLimits(maxDocumentBytes: byteCount),
    );
    expect(utf8.encode(exact.encode(state)).length, byteCount);
    final SentenceHuntLearningState restored =
        exact.decode(raw, scope, syntheticSentenceCatalogue());
    expect(exact.encode(restored), raw);

    final SentenceHuntLearningCodec oneByteTooSmall = SentenceHuntLearningCodec(
      limits: SentenceHuntLearningLimits(maxDocumentBytes: byteCount - 1),
    );
    expect(
      () => oneByteTooSmall.encode(state),
      throwsA(
        isA<SentenceHuntUnavailableException>().having(
          (SentenceHuntUnavailableException error) => error.cause,
          'cause',
          'Encoded sentence-hunt document is $byteCount bytes; limit is '
              '${byteCount - 1}.',
        ),
      ),
    );
    expect(unlimited.encode(state), raw);

    final String oversizedInput = '$raw ';
    expect(
      () => exact.decode(
        oversizedInput,
        scope,
        syntheticSentenceCatalogue(),
      ),
      throwsA(isA<SentenceHuntUnavailableException>()),
    );
    expect(oversizedInput, '$raw ');
    expect(unlimited.encode(state), raw);
  });

  test('sentence_codec_rejects_revision_without_matching_commit_ordinal', () {
    final SentenceHuntProfileScope scope = SentenceHuntProfileScope(
      courseId: 'en-fr',
      owner: LearningOwner.guest(),
    );
    const SentenceHuntLearningCodec codec = SentenceHuntLearningCodec();
    final Map<String, Object?> document =
        jsonDecode(codec.encode(SentenceHuntLearningState.empty(scope)))
            as Map<String, Object?>;
    document['revision'] = 1;
    final String forged = jsonEncode(document);

    expect(
      () => codec.decode(forged, scope, syntheticSentenceCatalogue()),
      throwsA(isA<SentenceHuntUnavailableException>()),
    );
  });

  test('sentence_codec_rejects_missing_untrimmed_receipt_history', () {
    final _CodecDriver driver = _CodecDriver();
    driver.start(0);
    const SentenceHuntLearningCodec codec = SentenceHuntLearningCodec();
    final Map<String, Object?> document =
        jsonDecode(codec.encode(driver.state)) as Map<String, Object?>;
    (document['receipts'] as List<Object?>).clear();
    final String forged = jsonEncode(document);

    expect(
      () => codec.decode(forged, driver.scope, driver.catalogue),
      throwsA(isA<SentenceHuntUnavailableException>()),
    );
  });

  test('sentence_codec_rejects_discontinuous_receipt_cursor_history', () {
    final _CodecDriver driver = _CodecDriver();
    driver.start(0);
    driver.answerCurrent(fixtureSectionIds.first);
    driver.advance(fixtureSectionIds.first);
    const SentenceHuntLearningCodec codec = SentenceHuntLearningCodec();
    final Map<String, Object?> document =
        jsonDecode(codec.encode(driver.state)) as Map<String, Object?>;
    final List<Object?> receipts = document['receipts'] as List<Object?>;
    final Map<String, Object?> forged =
        Map<String, Object?>.from(receipts[1] as Map<String, Object?>);
    final Map<String, Object?> before =
        Map<String, Object?>.from(forged['before'] as Map<String, Object?>);
    final Map<String, Object?> after =
        Map<String, Object?>.from(forged['after'] as Map<String, Object?>);
    before['revision'] = 1;
    after['revision'] = 2;
    final Map<String, Object?> command =
        jsonDecode(forged['canonicalCommand'] as String)
            as Map<String, Object?>;
    command['revision'] = 1;
    forged['canonicalCommand'] = jsonEncode(command);
    forged['before'] = before;
    forged['after'] = after;
    receipts[1] = forged;
    final String raw = jsonEncode(document);

    expect(
      () => codec.decode(raw, driver.scope, driver.catalogue),
      throwsA(isA<SentenceHuntUnavailableException>()),
    );
  });

  test('sentence_codec_rejects_advance_without_a_submitted_queue_prefix', () {
    final _CodecDriver driver = _CodecDriver();
    driver.start(0);
    const SentenceHuntLearningCodec codec = SentenceHuntLearningCodec();
    final Map<String, Object?> document =
        jsonDecode(codec.encode(driver.state)) as Map<String, Object?>;
    final Map<String, Object?> slot =
        (document['slots'] as Map<String, Object?>)[fixtureSectionIds.first]
            as Map<String, Object?>;
    final Map<String, Object?> before =
        Map<String, Object?>.from(slot['cursor'] as Map<String, Object?>);
    final Map<String, Object?> after = <String, Object?>{
      'generation': 1,
      'sequence': 2,
      'revision': 1,
    };
    const String token = 'badadv0000000000000000';
    final SentenceHuntLearningCommand command = SentenceHuntLearningCommand(
      scope: driver.scope,
      authGeneration: 0,
      sectionId: fixtureSectionIds.first,
      sectionFingerprint: (slot['checkpoint']
          as Map<String, Object?>)['sectionFingerprint'] as String,
      expected: const LearningCursorPosition(
        generation: 1,
        sequence: 1,
        revision: 0,
      ),
      token: token,
      submittedAt: DateTime.utc(2026),
      action: const AdvanceSentenceHuntItem(),
    );
    final Map<String, Object?> receipt = <String, Object?>{
      'sectionId': fixtureSectionIds.first,
      'token': token,
      'canonicalCommand': sentenceHuntCanonicalCommand(command),
      'before': before,
      'after': after,
      'commitOrdinal': 2,
    };
    slot['cursor'] = after;
    slot['latestReceipt'] = receipt;
    (document['receipts'] as List<Object?>).add(receipt);
    document['revision'] = 2;
    document['commitOrdinal'] = 2;
    final String forged = jsonEncode(document);

    expect(
      () => codec.decode(forged, driver.scope, driver.catalogue),
      throwsA(isA<SentenceHuntUnavailableException>()),
    );
    expect(jsonEncode(document), forged);
  });
}

final class _CodecDriver {
  _CodecDriver({
    this.limits = const SentenceHuntLearningLimits(),
    this.fastCommands = false,
    SentenceHuntCatalogue? catalogue,
  })  : catalogue = catalogue ?? syntheticSentenceCatalogue(),
        scope = SentenceHuntProfileScope(
          courseId: 'en-fr',
          owner: LearningOwner.guest(),
        ) {
    engine = SentenceHuntTransitionEngine(
      catalogue: this.catalogue,
      limits: limits,
    );
    state = SentenceHuntLearningState.empty(scope);
  }

  final SentenceHuntLearningLimits limits;
  final bool fastCommands;
  final SentenceHuntCatalogue catalogue;
  final SentenceHuntProfileScope scope;
  late final SentenceHuntTransitionEngine engine;
  late SentenceHuntLearningState state;
  int _nonce = 0;

  DateTime now() => DateTime.utc(2026).add(Duration(seconds: _nonce));

  String token() => 'codec${(++_nonce).toString().padLeft(17, '0')}';

  SentenceHuntTransition act(String sectionId, SentenceHuntAction action) {
    final SentenceHuntLearningCommand command;
    if (fastCommands) {
      final SentenceHuntSlot? slot = state.slots[sectionId];
      command = SentenceHuntLearningCommand(
        scope: scope,
        authGeneration: 0,
        sectionId: sectionId,
        sectionFingerprint: catalogue.section(sectionId).sectionFingerprint,
        expected: slot?.cursor ??
            const LearningCursorPosition(
                generation: 0, sequence: 0, revision: 0),
        token: token(),
        submittedAt: now(),
        action: action,
      );
    } else {
      command = engine.prepare(
        state: state,
        sectionId: sectionId,
        action: action,
        authGeneration: 0,
        token: token(),
        submittedAt: now(),
      );
    }
    final SentenceHuntTransition transition = engine.evaluate(
      state: state,
      command: command,
      committedAt: now(),
    );
    state = transition.nextState;
    return transition;
  }

  void start(int index, {bool replaceExisting = false}) {
    final String sectionId = fixtureSectionIds[index];
    act(
      sectionId,
      StartSentenceHuntRun(
        sessionId: 'codec-run-$index',
        policy: catalogue.section(sectionId).policy,
        mode: SentenceHuntRunMode.practice,
        replaceExisting: replaceExisting,
      ),
    );
  }

  SentenceHuntTransition answerCurrent(String sectionId,
      {bool correct = true}) {
    final SentenceHuntSlot slot = state.slots[sectionId]!;
    final LessonSectionSession saved = LessonSectionSession.fromJson(
      _mutable(state.slots[sectionId]!.checkpoint.sessionJson)
          as Map<String, dynamic>,
      itemIds: catalogue
          .section(sectionId)
          .items
          .map((SentenceHuntItem item) => item.identity.itemId)
          .toList(),
      contentRevision: slot.checkpoint.contentRevision,
    );
    final SentenceHuntItem item =
        catalogue.item(sectionId, saved.currentItemId!);
    return act(
      sectionId,
      AnswerSentenceHuntItem(SentenceHuntAnswer(
        content: item.identity,
        selectedTokenIds: correct
            ? item.expectedTokenIds
            : <String>[
                item.selectableTokenIds.firstWhere(
                  (String id) => !item.expectedTokenIds.contains(id),
                ),
              ],
        expectedTokenIdsSnapshot: item.expectedTokenIds,
        playback: SentenceHuntPlaybackObservation(
          scope: scope,
          content: item.identity,
          runGeneration: slot.cursor.generation,
          round: saved.round,
          uiGeneration: _nonce,
          referenceId: item.identity.audioRefId,
          outcome: CourseAudioOutcome.completed,
          source: CourseAudioSource.reviewedRecording,
        ),
      )),
    );
  }

  SentenceHuntTransition advance(String sectionId) =>
      act(sectionId, const AdvanceSentenceHuntItem());
}

Object? _mutable(Object? value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final MapEntry<Object?, Object?> entry in value.entries)
        entry.key as String: _mutable(entry.value),
    };
  }
  if (value is List) {
    final List<Object?> result =
        value.map<Object?>((Object? child) => _mutable(child)).toList();
    return result.every((Object? child) => child is String)
        ? result.cast<String>()
        : result;
  }
  return value;
}

SentenceHuntCatalogue _catalogueWithHistoricalRevision(
  SentenceHuntSection oldSection,
) {
  final SentenceHuntPackageFixture fixture = syntheticSentencePackage(
    historicalSections: <Map<String, dynamic>>[
      <String, dynamic>{
        'sectionId': oldSection.id,
        'kind': oldSection.kind.name,
        'contentRevision': oldSection.contentRevision,
        'policyRevision': oldSection.policyRevision,
        'completionThresholdPercent':
            oldSection.policy.completionThresholdPercent,
        'sectionFingerprint': oldSection.sectionFingerprint,
      },
    ],
  );
  (fixture.manifest['sections'] as List<Map<String, dynamic>>).firstWhere(
      (Map<String, dynamic> row) =>
          row['id'] == oldSection.id)['contentRevision'] = 2;
  return decodeFrenchSentencePackage(
    manifestJson: fixture.manifestJson,
    provenanceJson: fixture.provenanceJson,
    annotationsJson: fixture.annotationsJson,
    sourceEvidenceJson: fixture.sourceEvidenceJson,
  );
}

SentenceHuntCatalogue _catalogueAtContentRevision(
  String sectionId,
  int revision,
) {
  final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
  (fixture.manifest['sections'] as List<Map<String, dynamic>>).firstWhere(
      (Map<String, dynamic> row) =>
          row['id'] == sectionId)['contentRevision'] = revision;
  return decodeFrenchSentencePackage(
    manifestJson: fixture.manifestJson,
    provenanceJson: fixture.provenanceJson,
    annotationsJson: fixture.annotationsJson,
    sourceEvidenceJson: fixture.sourceEvidenceJson,
  );
}

SentenceHuntCatalogue _catalogueWithVersionedPolicy() {
  final SentenceHuntPackageFixture fixture = syntheticSentencePackage();
  final Map<String, dynamic> section =
      (fixture.manifest['sections'] as List<Map<String, dynamic>>).first;
  section['policyRevision'] = 2;
  section['completionThresholdPercent'] = 70;
  return decodeFrenchSentencePackage(
    manifestJson: fixture.manifestJson,
    provenanceJson: fixture.provenanceJson,
    annotationsJson: fixture.annotationsJson,
    sourceEvidenceJson: fixture.sourceEvidenceJson,
  );
}
