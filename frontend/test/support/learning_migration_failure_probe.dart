import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart';

Future<void> runLearningMigrationFailureProbe(File file) async {
  final database = LearningDatabase.forTesting(
    DatabaseConnection(NativeDatabase(file)),
    targetSchemaVersion: 2,
    migrationRunner: (Migrator migrator, int from, int to) async {
      if (from != 1 || to != 2) {
        throw StateError('Expected a synthetic v1-to-v2 migration.');
      }
      await migrator.database.customStatement(
        'CREATE TABLE migration_failure_probe (id INTEGER)',
      );
      throw StateError('Synthetic migration failure.');
    },
  );
  try {
    await database.customSelect('SELECT 1').getSingle();
  } finally {
    await database.close();
  }
}
