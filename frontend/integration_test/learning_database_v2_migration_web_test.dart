import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart'
    show DatabaseConnection, OpeningDetails, QueryExecutor, QueryExecutorUser;
import 'package:drift/wasm.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_transition.dart';
import 'package:linguist/src/core/course/storage/course_learning_sql_repository.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show
        LearningDatabase,
        LearningDatabaseHandle,
        LearningMigrationFailurePoint;
import 'package:linguist/src/core/course/storage/learning_database_connection.dart';

import 'support/learning_v1_fixture.dart';

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

Future<Map<String, List<String>>> _rows(DatabaseConnection connection) async {
  final result = <String, List<String>>{};
  for (final table in _tables) {
    final rows = await connection.runSelect('SELECT * FROM "$table"', const []);
    // Compare complete cell values, including opaque checkpoint/canonical text.
    result[table] = rows.map(jsonEncode).toList()..sort();
  }
  return result;
}

class _InspectVersion implements QueryExecutorUser {
  _InspectVersion(this.schemaVersion);

  @override
  final int schemaVersion;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {
    // Assert before Drift can set a version: inspection must not repair a file.
    expect(details.versionBefore, schemaVersion);
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final evidence = <String, Object?>{};
  binding.reportData = evidence;
  final runId = DateTime.now().microsecondsSinceEpoch;
  var counter = 0;

  Future<DatabaseConnection> connect(String name) async {
    final opened = await WasmDatabase.open(
      databaseName: name,
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.dart.js'),
    );
    expect(
      acceptsLearningWebImplementation(opened.chosenImplementation.name),
      isTrue,
    );
    evidence['backend'] = opened.chosenImplementation.name;
    return opened.resolvedExecutor;
  }

  Future<Map<String, List<String>>> seed(String name) async {
    final connection = await connect(name);
    try {
      await openPublishedLearningV1Fixture(connection);
      return await _rows(connection);
    } finally {
      await connection.close();
    }
  }

  testWidgets('worker and SQLite assets load with the required media type', (
    tester,
  ) async {
    final worker = await http.get(Uri.base.resolve('drift_worker.dart.js'));
    final wasm = await http.get(Uri.base.resolve('sqlite3.wasm'));
    expect(worker.statusCode, 200);
    expect(wasm.statusCode, 200);
    expect(wasm.headers['content-type']?.split(';').first, 'application/wasm');
    evidence['assets'] = {
      'workerStatus': worker.statusCode,
      'wasmStatus': wasm.statusCode,
      'wasmContentType': wasm.headers['content-type'],
    };
  });

  testWidgets('published_v1_fixture_migrates_to_v2_and_preserves_old_rows', (
    WidgetTester tester,
  ) async {
    final fixtureConnection = await openLearningDatabaseConnection();
    late Map<String, List<String>> before;
    try {
      expect(fixtureConnection.webImplementation, isNotNull);
      expect(
        acceptsLearningWebImplementation(fixtureConnection.webImplementation!),
        isTrue,
      );
      await openPublishedLearningV1Fixture(fixtureConnection.connection);
      before = await _rows(fixtureConnection.connection);
      expect(
        (await fixtureConnection.connection.runSelect(
          'PRAGMA user_version',
          const <Object?>[],
        )).single['user_version'],
        1,
      );
    } finally {
      await fixtureConnection.connection.close();
    }

    final upgradeConnection = await openLearningDatabaseConnection();
    final database = await LearningDatabase.openValidated(
      upgradeConnection.connection,
    );
    try {
      expect(upgradeConnection.webImplementation, isNotNull);
      expect(
        acceptsLearningWebImplementation(upgradeConnection.webImplementation!),
        isTrue,
      );
      await database.customSelect('SELECT 1').getSingle();
      expect(
        (await database.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        2,
      );
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      expect(await _rows(upgradeConnection.connection), before);
      evidence['productionMigration'] = {
        'backend': upgradeConnection.webImplementation,
        'versionBefore': 1,
        'versionAfter': 2,
        'preservedRows': before.map(
          (key, value) => MapEntry(key, value.length),
        ),
      };
    } finally {
      await database.close();
    }
  });

  for (final point in LearningMigrationFailurePoint.values) {
    testWidgets('real web migration failure boundary ${point.name}', (
      tester,
    ) async {
      final name = 'uy_migration_${runId}_${counter++}';
      final before = await seed(name);
      final failedConnection = await connect(name);
      var reachedHook = false;
      await expectLater(
        LearningDatabase.openValidatedForMigrationTesting(
          failedConnection,
          onPoint: (current) {
            if (current == point) {
              reachedHook = true;
              throw StateError('injected ${point.name}');
            }
          },
        ),
        throwsA(
          predicate<Object>(
            (error) => error.toString().contains('injected ${point.name}'),
          ),
        ),
      );
      expect(reachedHook, isTrue);
      await expectLater(
        () => failedConnection.runSelect('SELECT 1', const []),
        throwsA(anything),
      );
      final expectedVersion =
          point == LearningMigrationFailurePoint.beforeVersion2Commit ? 1 : 2;
      final inspection = await connect(name);
      try {
        await inspection.ensureOpen(_InspectVersion(expectedVersion));
        expect(await _rows(inspection), before);
        expect(
          await inspection.runSelect('PRAGMA foreign_key_check', const []),
          isEmpty,
        );
      } finally {
        await inspection.close();
      }
      final retryConnection = await connect(name);
      final retry = await LearningDatabase.openValidated(retryConnection);
      try {
        expect(
          (await retry.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          2,
        );
        expect(
          (await retry.customSelect('PRAGMA foreign_keys').getSingle())
              .read<int>('foreign_keys'),
          1,
        );
        expect(await _rows(retryConnection), before);
      } finally {
        await retry.close();
      }
      evidence[point.name] = {
        'versionAfterFailure': expectedVersion,
        'rowsPreserved': true,
        'failedConnectionClosed': true,
        'freshRetryVersion': 2,
      };
    }, timeout: const Timeout(Duration(seconds: 45)));
  }

  testWidgets('real web concurrent upgrade and coordinator write are fenced', (
    tester,
  ) async {
    final name = 'uy_migration_${runId}_${counter++}';
    final before = await seed(name);
    final firstConnection = await connect(name);
    final secondConnection = await connect(name);
    final entered = Completer<void>();
    final release = Completer<void>();
    final first = LearningDatabase.openValidatedForMigrationTesting(
      firstConnection,
      onPoint: (point) async {
        if (point == LearningMigrationFailurePoint.beforeVersion2Commit) {
          entered.complete();
          await release.future;
        }
      },
    );
    await entered.future;

    final owner = LearningOwner.account('web-migration-writer');
    final scope = LearningScope(courseId: 'en-fr', owner: owner);
    final auth = LearningAuthScope(owner: owner, generation: 1, ready: true);
    // A separate connection bypasses any isolate-local validated-open queue.
    // Shared-worker/SQLite fencing, not a Dart queue, must protect this open.
    final second = LearningDatabase(secondConnection);
    final secondOpening = second.customSelect('SELECT 1').getSingle();
    release.complete();
    final migrated = await first;
    await secondOpening;
    final handle = LearningDatabaseHandle(open: () async => second);
    final repository = SqliteCourseLearningRepository(
      database: handle,
      scope: scope,
      authGeneration: auth.generation,
      currentAuth: () => auth,
      backendOwner: () => owner,
      transitions: LearningTransitionEngine(LearningRegistry.french()),
      clock: () => DateTime.utc(2026, 10, 23),
      newToken: () => 'WWWWWWWWWWWWWWWWWWWWWW',
      random: math.Random(0),
    );
    try {
      final command = repository.prepare(
        state: CourseLearningState.empty(scope),
        activityId: 'lesson:en-fr-u-y',
        action: StartLearningRun(options: RunOptions()),
      );
      await repository.submit(command);
      await repository.submit(command); // lost-ACK retry must be exactly once
      final after = await _rows(secondConnection);
      for (final table in _tables) {
        expect(after[table], containsAll(before[table]!));
      }
      final receipt = await second
          .customSelect(
            'SELECT COUNT(*) AS n FROM learning_command_receipts r '
            'JOIN learning_scopes s ON s.id = r.scope_id '
            "WHERE s.owner_id = 'web-migration-writer'",
          )
          .getSingle();
      expect(receipt.read<int>('n'), 1);
      expect(
        (await migrated.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        2,
      );
      expect(
        (await second.customSelect('PRAGMA foreign_keys').getSingle())
            .read<int>('foreign_keys'),
        1,
      );
      evidence['concurrentOpenWrite'] = {
        'version': 2,
        'oldRowsPreserved': true,
        'receiptsForRetriedCommand': 1,
      };
    } finally {
      await handle.close();
      await migrated.close();
    }
  }, timeout: const Timeout(Duration(seconds: 45)));
}
