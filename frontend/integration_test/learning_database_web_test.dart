import 'package:drift/drift.dart'
    show DatabaseSchemaEntity, GeneratedDatabase, QueryRow, TableInfo, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:linguist/src/core/course/storage/learning_database_connection.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('web database probe survives close and reopen', (
    WidgetTester tester,
  ) async {
    const String probeKey = 'task1-integration-probe';
    const String probeValue = 'sqlite-persisted';

    final LearningDatabaseConnection firstConnection =
        await openLearningDatabaseConnection();
    final _IntegrationSmokeDatabase firstDatabase = _IntegrationSmokeDatabase(
      firstConnection.connection,
    );
    try {
      await firstDatabase.ensureProbeTable();
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
    final _IntegrationSmokeDatabase reopenedDatabase =
        _IntegrationSmokeDatabase(reopenedConnection.connection);
    try {
      await reopenedDatabase.ensureProbeTable();
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
}

class _IntegrationSmokeDatabase extends GeneratedDatabase {
  _IntegrationSmokeDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo> get allTables => const <TableInfo>[];

  @override
  Iterable<DatabaseSchemaEntity> get allSchemaEntities =>
      const <DatabaseSchemaEntity>[];

  Future<void> ensureProbeTable() => customStatement(
    'CREATE TABLE IF NOT EXISTS learning_database_smoke_rows '
    '(probe_key TEXT NOT NULL PRIMARY KEY, probe_value TEXT NOT NULL)',
  );

  Future<void> writeProbe(String key, String value) => customStatement(
    'INSERT INTO learning_database_smoke_rows '
    '(probe_key, probe_value) VALUES (?, ?) '
    'ON CONFLICT(probe_key) DO UPDATE SET probe_value = excluded.probe_value',
    <Object?>[key, value],
  );

  Future<String?> readProbe(String key) => customSelect(
    'SELECT probe_value FROM learning_database_smoke_rows WHERE probe_key = ?',
    variables: <Variable<Object>>[Variable<String>(key)],
  ).map((QueryRow row) => row.read<String>('probe_value')).getSingleOrNull();
}
