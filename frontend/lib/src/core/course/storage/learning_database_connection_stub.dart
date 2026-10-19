import 'package:drift/drift.dart' show DatabaseConnection;

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
  throw const LearningStorageUnsupportedPlatformException(
    'SQLite learning storage is not implemented on this platform.',
  );
}
