import 'package:drift/drift.dart';

part 'learning_database_smoke.g.dart';

class LearningDatabaseSmokeRows extends Table {
  TextColumn get probeKey => text()();
  TextColumn get probeValue => text()();

  @override
  Set<Column> get primaryKey => <Column>{probeKey};
}

@DriftDatabase(tables: <Type>[LearningDatabaseSmokeRows])
class LearningDatabaseSmoke extends _$LearningDatabaseSmoke {
  LearningDatabaseSmoke(super.connection);

  @override
  int get schemaVersion => 1;

  Future<void> writeProbe(String key, String value) async {
    await into(learningDatabaseSmokeRows).insertOnConflictUpdate(
      LearningDatabaseSmokeRowsCompanion.insert(
        probeKey: key,
        probeValue: value,
      ),
    );
  }

  Future<String?> readProbe(String key) async {
    final LearningDatabaseSmokeRow? row =
        await (select(learningDatabaseSmokeRows)..where(
              (LearningDatabaseSmokeRows row) => row.probeKey.equals(key),
            ))
            .getSingleOrNull();
    return row?.probeValue;
  }
}
