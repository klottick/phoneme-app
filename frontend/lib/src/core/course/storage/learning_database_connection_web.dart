import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/wasm.dart' show WasmDatabase;

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

class LearningStorageUnsupportedPlatformException implements Exception {
  final String message;

  const LearningStorageUnsupportedPlatformException(this.message);

  @override
  String toString() => 'LearningStorageUnsupportedPlatformException: $message';
}

Future<LearningDatabaseConnection> openLearningDatabaseConnection() async {
  final result = await WasmDatabase.open(
    databaseName: 'phoneme_learning',
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.dart.js'),
  );
  final String implementationName = result.chosenImplementation.name;

  if (!acceptsLearningWebImplementation(implementationName)) {
    await result.resolvedExecutor.close();
    throw LearningStorageUnsupportedPlatformException(
      'Drift selected unsupported web storage: $implementationName',
    );
  }

  return LearningDatabaseConnection(
    connection: result.resolvedExecutor,
    webImplementation: implementationName,
  );
}
