import 'dart:convert';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:linguist/src/app.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/spelling_learning_providers.dart';
import 'package:linguist/src/core/course/spelling_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/providers/app_providers.dart'
    show onboardingControllerProvider;
import 'package:linguist/src/features/course_map/course_map_screen.dart';
import 'package:linguist/src/routing/app_router.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabaseHandle;
import 'package:linguist/src/core/course/storage/learning_database_connection.dart';

import 'support/learning_v1_fixture.dart';

const _spellingPath = '/course-spelling/en-fr-u-y-spelling';
const _tables = <String>[
  'learning_scopes',
  'learning_content_bindings',
  'learning_runs',
  'learning_attempts',
  'learning_attempt_values',
  'learning_attempt_evidence',
  'learning_command_receipts',
  'learning_mistakes',
  'learning_summaries',
  'learning_completions',
  'learning_exposure',
  'learning_best_scores',
  'supported_sync_outbox',
];

final class _BrowserReferenceAudio implements CourseReferenceAudio {
  final List<String> requests = <String>[];

  @override
  Future<CourseAudioResult> playReference(
    String referenceId, {
    CourseAudioUse use = CourseAudioUse.alphaPractice,
    CourseAudioVariant variant = CourseAudioVariant.normal,
    bool allowPracticeTts = false,
  }) async {
    requests.add(referenceId);
    return CourseAudioResult.completed(
      referenceId: referenceId,
      source: CourseAudioSource.unverifiedRecording,
    );
  }

  @override
  Future<void> speak(String word) async =>
      throw StateError('This browser workflow must not request TTS.');

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

final class _BrowserApp {
  _BrowserApp(this.container, this.audio);

  final ProviderContainer container;
  final _BrowserReferenceAudio audio;
  bool disposed = false;

  GoRouter get router => container.read(appRouterProvider);
}

Future<_BrowserApp> _createBrowserApp(_BrowserReferenceAudio audio) async {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      courseReferenceAudioProvider.overrideWithValue(audio),
    ],
  );
  await container
      .read(onboardingControllerProvider.notifier)
      .selectCourse('en-fr');
  return _BrowserApp(container, audio);
}

Future<void> _disposeBrowserApp(WidgetTester tester, _BrowserApp app) async {
  if (app.disposed) return;
  app.disposed = true;
  await tester.pumpWidget(const SizedBox.shrink());
  app.router.dispose();
  final LearningDatabaseHandle handle = app.container.read(
    learningDatabaseHandleProvider,
  );
  app.container.dispose();
  await handle.close();
  await app.audio.dispose();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 45),
  );
}

Future<Map<String, List<String>>> _rows(DatabaseConnection connection) async {
  final Map<String, List<String>> result = <String, List<String>>{};
  for (final String table in _tables) {
    final String order = table == 'supported_sync_outbox'
        ? ' ORDER BY enqueue_commit_ordinal, enqueue_event_index, event_id'
        : '';
    final List<Map<String, dynamic>> rows = await connection.runSelect(
      'SELECT * FROM "$table"$order',
      const <Object?>[],
    );
    final List<String> encoded = rows.map(jsonEncode).toList();
    if (table != 'supported_sync_outbox') encoded.sort();
    result[table] = encoded;
  }
  return result;
}

Map<String, int> _frequencies(List<String> rows) {
  final Map<String, int> result = <String, int>{};
  for (final String row in rows) {
    result.update(row, (int count) => count + 1, ifAbsent: () => 1);
  }
  return result;
}

void _expectOldRowsPreserved(
  Map<String, List<String>> before,
  Map<String, List<String>> after,
) {
  for (final String table in _tables) {
    if (table == 'supported_sync_outbox') {
      expect(after[table], before[table], reason: 'outbox order is unchanged');
      continue;
    }
    final Map<String, int> oldRows = _frequencies(before[table]!);
    final Map<String, int> newRows = _frequencies(after[table]!);
    for (final MapEntry<String, int> entry in oldRows.entries) {
      expect(
        newRows[entry.key] ?? 0,
        greaterThanOrEqualTo(entry.value),
        reason: '$table preserves every original cell and canonical byte',
      );
    }
  }
}

Future<Map<String, Object?>> _snapshotDatabase() async {
  final LearningDatabaseConnection opened =
      await openLearningDatabaseConnection();
  try {
    final Map<String, List<String>> rows = await _rows(opened.connection);
    final int version =
        (await opened.connection.runSelect(
              'PRAGMA user_version',
              const <Object?>[],
            )).single['user_version']
            as int;
    return <String, Object?>{
      'backend': opened.webImplementation,
      'version': version,
      'rows': rows,
    };
  } finally {
    await opened.connection.close();
  }
}

Map<String, Object?> _spellingSnapshot(SpellingLearningState state) {
  final SpellingSlot slot = state.slots['en-fr-u-y-spelling']!;
  return <String, Object?>{
    'revision': state.revision,
    'commitOrdinal': state.commitOrdinal,
    'cursor': <int>[
      slot.cursor.generation,
      slot.cursor.sequence,
      slot.cursor.revision,
    ],
    'session': jsonEncode(slot.checkpoint.sessionJson),
    'receipt': slot.latestReceipt.canonicalCommand,
    'receipts': state.receipts
        .map((receipt) => receipt.canonicalCommand)
        .toList(growable: false),
    'attempts': state.attempts
        .map(
          (attempt) => <Object?>[
            attempt.itemId,
            attempt.selectedOptionId,
            attempt.expectedOptionId,
            attempt.correct,
            attempt.playback.source.name,
          ],
        )
        .toList(growable: false),
  };
}

Future<void> _inspectSpelling(WidgetTester tester) async {
  final Finder tile = find.widgetWithText(ListTile, 'Sound → spelling');
  if (tile.evaluate().isEmpty) {
    final Finder disclosure = find.text('All destinations');
    await tester.ensureVisible(disclosure);
    await tester.tap(disclosure);
    await _settle(tester);
  }
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await _settle(tester);
}

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final Map<String, Object?> evidence = <String, Object?>{};
  binding.reportData = evidence;

  testWidgets('published v1 spelling answer survives same-page SQL reopen', (
    WidgetTester tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    final LearningDatabaseConnection fixtureConnection =
        await openLearningDatabaseConnection();
    late final Map<String, List<String>> oldRows;
    try {
      expect(fixtureConnection.webImplementation, isNotNull);
      expect(
        acceptsLearningWebImplementation(fixtureConnection.webImplementation!),
        isTrue,
      );
      await openPublishedLearningV1Fixture(fixtureConnection.connection);
      oldRows = await _rows(fixtureConnection.connection);
      expect(
        (await fixtureConnection.connection.runSelect(
          'PRAGMA user_version',
          const <Object?>[],
        )).single['user_version'],
        1,
      );
      evidence['fixture'] = <String, Object?>{
        'backend': fixtureConnection.webImplementation,
        'version': 1,
        'rows': oldRows.map(
          (String key, List<String> value) =>
              MapEntry<String, int>(key, value.length),
        ),
      };
    } finally {
      await fixtureConnection.connection.close();
    }

    final http.Response worker = await http.get(
      Uri.base.resolve('drift_worker.dart.js'),
    );
    final http.Response wasm = await http.get(Uri.base.resolve('sqlite3.wasm'));
    expect(worker.statusCode, 200);
    expect(wasm.statusCode, 200);
    expect(wasm.headers['content-type']?.split(';').first, 'application/wasm');
    evidence['assets'] = <String, Object?>{
      'workerStatus': worker.statusCode,
      'wasmStatus': wasm.statusCode,
      'wasmContentType': wasm.headers['content-type'],
    };

    final _BrowserReferenceAudio audio = _BrowserReferenceAudio();
    final _BrowserApp app = await _createBrowserApp(audio);
    addTearDown(() => _disposeBrowserApp(tester, app));
    final GoRouter router = app.router;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: app.container,
        child: const LinguistApp(),
      ),
    );
    await _settle(tester);
    expect(router.state.uri.path, '/home');
    expect(find.byType(CourseMapScreen), findsOneWidget);

    final LearningDatabaseHandle handle = app.container.read(
      learningDatabaseHandleProvider,
    );
    final database = await handle.open();
    expect(
      (await database.customSelect('PRAGMA user_version').getSingle())
          .read<int>('user_version'),
      2,
    );
    final Map<String, Object?> migrated = await _snapshotDatabase();
    expect(migrated['version'], 2);
    expect(migrated['backend'], fixtureConnection.webImplementation);
    _expectOldRowsPreserved(
      oldRows,
      migrated['rows']! as Map<String, List<String>>,
    );

    await _inspectSpelling(tester);
    // This assertion is intentionally before the map implementation: RED must
    // reach this missing public UI action after real v1 setup and migration.
    expect(find.text('Start spelling'), findsOneWidget);

    await tester.ensureVisible(find.text('Start spelling'));
    await tester.tap(find.text('Start spelling'));
    await _settle(tester);
    expect(router.state.uri.path, _spellingPath);
    expect(find.text('Start practice'), findsOneWidget);
    await tester.tap(find.text('Start practice'));
    await _settle(tester);
    await tester.tap(find.text('Listen to the word'));
    await _settle(tester);
    expect(audio.requests, <String>['fr-word-tout']);
    expect(find.text('tout'), findsNothing);

    await tester.tap(find.text('ou'));
    await _settle(tester);
    expect(
      find.byKey(const ValueKey<String>('spelling-feedback-word')),
      findsOneWidget,
    );
    final Text savedWord = tester.widget<Text>(
      find.byKey(const ValueKey<String>('spelling-feedback-word')),
    );
    expect(savedWord.textSpan!.toPlainText(), 'tout');
    final SpellingLearningState answered = await app.container
        .read(spellingLearningStoreProvider)
        .load();
    expect(answered.attempts, hasLength(1));
    expect(answered.receipts, hasLength(2));
    expect(answered.attempts.single.selectedOptionId, 'ou');
    final Map<String, Object?> savedSnapshot = _spellingSnapshot(answered);
    final Map<String, Object?> afterAnswer = await _snapshotDatabase();
    _expectOldRowsPreserved(
      oldRows,
      afterAnswer['rows']! as Map<String, List<String>>,
    );

    await handle.close();
    router.go('/home');
    await _settle(tester);
    router.go(_spellingPath);
    await _settle(tester);
    expect(router.state.uri.path, _spellingPath);
    expect(find.text('Continue'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('spelling-feedback-word')),
      findsOneWidget,
    );
    final SpellingLearningState reopened = await app.container
        .read(spellingLearningStoreProvider)
        .load();
    expect(_spellingSnapshot(reopened), savedSnapshot);
    expect(reopened.attempts, hasLength(1));
    expect(reopened.receipts, hasLength(2));
    expect(audio.requests, <String>['fr-word-tout']);
    final Map<String, Object?> afterReopen = await _snapshotDatabase();
    _expectOldRowsPreserved(
      oldRows,
      afterReopen['rows']! as Map<String, List<String>>,
    );
    expect(afterReopen['version'], 2);

    evidence['workflow'] = <String, Object?>{
      'productionBackend': migrated['backend'],
      'versionBefore': 1,
      'versionAfter': afterReopen['version'],
      'oldRowsPreservedAfterAnswerAndReopen': true,
      'attempts': reopened.attempts.length,
      'receipts': reopened.receipts.length,
      'audioRequests': audio.requests,
      'samePageRoute': router.state.uri.toString(),
      'savedFeedback': savedSnapshot,
    };
  });
}
