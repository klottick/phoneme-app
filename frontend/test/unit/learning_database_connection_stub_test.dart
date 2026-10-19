import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/storage/learning_database_connection_stub.dart';

import '../support/learning_database_smoke.dart';

void main() {
  test('unsupported platforms fail with the named exception', () async {
    await expectLater(
      openLearningDatabaseConnection(),
      throwsA(isA<LearningStorageUnsupportedPlatformException>()),
    );
  });

  test('generated smoke table writes and reads its typed probe', () async {
    final LearningDatabaseSmoke database = LearningDatabaseSmoke(
      DatabaseConnection(NativeDatabase.memory()),
    );
    try {
      expect(
        database.allTables.map((table) => table.actualTableName),
        <String>['learning_database_smoke_rows'],
      );
      await database.writeProbe('task1-smoke-test', 'sqlite-probe-value');
      expect(
        await database.readProbe('task1-smoke-test'),
        'sqlite-probe-value',
      );
      expect(await database.readProbe('missing-probe'), isNull);
    } finally {
      await database.close();
    }
  });
}
