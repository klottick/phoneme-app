import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart';
import '../../integration_test/support/learning_database_workload.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all_families_reopen_at_limits_without_summary_drift', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'sqlite-learning-retention-',
    );
    final File file = File('${directory.path}/learning.sqlite');
    LearningDatabaseHandle handle = _fileHandle(file);
    try {
      await seedLearningAtRetentionLimits(handle, runId: 'retention-test');
      final LearningWorkloadReport beforeClose =
          await verifyLearningAtRetentionLimits(
            handle,
            runId: 'retention-test',
          );
      await handle.close();

      handle = _fileHandle(file);
      final LearningWorkloadReport afterReopen =
          await verifyLearningAtRetentionLimits(
            handle,
            runId: 'retention-test',
          );

      for (final String family in <String>[
        'course',
        'comparison',
        'sentence-hunt',
      ]) {
        expect(beforeClose.rowCountsByFamily[family]?['attempts'], 2000);
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
        expect(
          afterReopen.rowCountsByFamily[family]?['summaries'],
          greaterThan(0),
        );
        expect(
          afterReopen.rowCountsByFamily[family]?['completions'],
          greaterThan(0),
        );
        expect(
          afterReopen.summaryValuesByFamily[family]?['summaryTotal'],
          greaterThanOrEqualTo(2000),
        );
        expect(
          afterReopen.pruneResultByFamily[family],
          contains('retained attempts=2000'),
        );
      }
      expect(
        afterReopen.rowCountsByFamily['course']?['mistakes'],
        greaterThan(0),
      );
      expect(
        afterReopen.rowCountsByFamily['course']?['exposure'],
        greaterThan(0),
      );
      expect(
        afterReopen.rowCountsByFamily['comparison']?['mistakes'],
        greaterThan(0),
      );
      expect(
        afterReopen.rowCountsByFamily['sentence-hunt']?['mistakes'],
        greaterThan(0),
      );
      expect(afterReopen.rowCountsByFamily['sentence-hunt']?['exposure'], 3);
      expect(afterReopen.logicalPageBytesByFamily.values.toSet(), hasLength(1));
      // ignore: avoid_print
      print('TASK9 RETENTION ${afterReopen.toJson()}');
    } finally {
      await handle.close();
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 90)));
}

LearningDatabaseHandle _fileHandle(File file) => LearningDatabaseHandle(
  open: () async => LearningDatabase(DatabaseConnection(NativeDatabase(file))),
);
