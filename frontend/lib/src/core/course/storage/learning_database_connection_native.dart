import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:path_provider/path_provider.dart';

class LearningDatabaseConnection {
  final DatabaseConnection connection;
  final String? webImplementation;

  const LearningDatabaseConnection({
    required this.connection,
    this.webImplementation,
  });
}

const Set<String> _persistentWebImplementations = <String>{
  'opfsShared',
  'opfsLocks',
  'sharedIndexedDb',
};

bool acceptsLearningWebImplementation(String implementationName) =>
    _persistentWebImplementations.contains(implementationName);

Future<LearningDatabaseConnection> openLearningDatabaseConnection() async {
  final Directory supportDirectory = await getApplicationSupportDirectory();
  final File databaseFile =
      File('${supportDirectory.path}/phoneme_learning.sqlite');

  return LearningDatabaseConnection(
    connection: NativeDatabase.createBackgroundConnection(
      databaseFile,
      readPool: 0,
    ),
  );
}
