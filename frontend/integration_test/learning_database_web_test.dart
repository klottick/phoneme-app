import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabase, LearningDatabaseHandle;
import 'package:linguist/src/core/course/storage/learning_database_connection.dart';

import 'support/learning_database_workload.dart';
import '../test/support/learning_database_smoke.dart';

const String _runId = String.fromEnvironment(
  'learningRunId',
  defaultValue: 'sqlite-task9-web-retention',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('web database probe survives close and reopen', (
    WidgetTester tester,
  ) async {
    const String probeKey = 'task1-integration-probe';
    const String probeValue = 'sqlite-persisted';

    final LearningDatabaseConnection firstConnection =
        await openLearningDatabaseConnection();
    final LearningDatabaseSmoke firstDatabase = LearningDatabaseSmoke(
      firstConnection.connection,
    );
    try {
      expect(firstConnection.webImplementation, isNotNull);
      expect(
        acceptsLearningWebImplementation(firstConnection.webImplementation!),
        isTrue,
      );
      await firstDatabase.writeProbe(probeKey, probeValue);
      expect(await firstDatabase.readProbe(probeKey), probeValue);
    } finally {
      await firstDatabase.close();
    }

    final LearningDatabaseConnection reopenedConnection =
        await openLearningDatabaseConnection();
    final LearningDatabaseSmoke reopenedDatabase = LearningDatabaseSmoke(
      reopenedConnection.connection,
    );
    try {
      expect(reopenedConnection.webImplementation, isNotNull);
      expect(
        acceptsLearningWebImplementation(reopenedConnection.webImplementation!),
        isTrue,
      );
      expect(await reopenedDatabase.readProbe(probeKey), probeValue);
    } finally {
      await reopenedDatabase.close();
    }
  });

  testWidgets(
    'web sqlite retains all learning families across connection reopen',
    (WidgetTester tester) async {
      LearningDatabaseHandle handle = await _openWebHandle();
      try {
        await seedLearningAtRetentionLimits(handle, runId: _runId);
        final LearningWorkloadReport beforeClose =
            await verifyLearningAtRetentionLimits(handle, runId: _runId);
        await handle.close();

        handle = await _openWebHandle();
        final LearningWorkloadReport afterReopen =
            await verifyLearningAtRetentionLimits(handle, runId: _runId);
        for (final String family in <String>[
          'course',
          'comparison',
          'sentence-hunt',
        ]) {
          final Map<String, Object?> pruneEvidence =
              beforeClose.postCapPruneEvidenceByFamily[family]!;
          expect(pruneEvidence['observed'], isTrue);
          expect(pruneEvidence['attemptCountBefore'], 2000);
          expect(pruneEvidence['receiptCountBefore'], 2000);
          expect(
            pruneEvidence['attemptCountAfter'],
            beforeClose.rowCountsByFamily[family]?['attempts'],
          );
          expect(pruneEvidence['receiptCountAfter'], 2000);
          expect(pruneEvidence['newAttemptIds'], isNotEmpty);
          expect(pruneEvidence['evictedAttemptIds'], isNotEmpty);
          expect(pruneEvidence['sqlRowsMatchReloadedState'], isTrue);
          expect(
            (pruneEvidence['newAttemptIds']! as List).length,
            pruneEvidence['expectedNewAttemptCount'],
          );
          expect(
            pruneEvidence['attemptIdsAfter'],
            pruneEvidence['sqlAttemptIdsAfter'],
          );
          expect(pruneEvidence['sqlRowsMatchExpectedRetainedIds'], isTrue);
          expect(beforeClose.rowCountsByFamily[family]?['receipts'], 2000);
          expect(
            afterReopen.rowCountsByFamily[family],
            beforeClose.rowCountsByFamily[family],
          );
          expect(
            afterReopen.summaryValuesByFamily[family],
            beforeClose.summaryValuesByFamily[family],
          );
          expect(
            afterReopen.latestReceiptByFamily[family],
            beforeClose.latestReceiptByFamily[family],
          );
        }
        expect(
          beforeClose
              .postCapPruneEvidenceByFamily['course']!['completeCourseBatches'],
          isTrue,
        );
        // ignore: avoid_print
        print('TASK9 WEB runId=$_runId report=${afterReopen.toJson()}');
      } finally {
        await handle.close();
      }
    },
    timeout: const Timeout(Duration(hours: 2)),
  );
}

Future<LearningDatabaseHandle> _openWebHandle() async {
  final LearningDatabaseConnection connection =
      await openLearningDatabaseConnection();
  if (connection.webImplementation == null ||
      !acceptsLearningWebImplementation(connection.webImplementation!)) {
    throw StateError(
      'Web qualification selected unsupported storage: '
      '${connection.webImplementation}',
    );
  }
  return LearningDatabaseHandle(
    open: () async => LearningDatabase(connection.connection),
  );
}
