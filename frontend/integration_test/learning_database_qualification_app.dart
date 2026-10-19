import 'package:flutter/material.dart';
import 'package:linguist/src/core/course/storage/learning_database_connection.dart';

import '../test/support/learning_database_smoke.dart';

const String _probeValue = 'learning-storage-task1-persisted';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final String? probeKey = Uri.base.queryParameters['probe'];
  if (probeKey == null || probeKey.isEmpty) {
    throw const FormatException('A non-empty ?probe= key is required.');
  }

  final LearningDatabaseConnection databaseConnection =
      await openLearningDatabaseConnection();
  final LearningDatabaseSmoke database = LearningDatabaseSmoke(
    databaseConnection.connection,
  );

  runApp(
    _LearningDatabaseQualificationApp(
      databaseConnection: databaseConnection,
      database: database,
      probeKey: probeKey,
    ),
  );
}

class _LearningDatabaseQualificationApp extends StatefulWidget {
  final LearningDatabaseConnection databaseConnection;
  final LearningDatabaseSmoke database;
  final String probeKey;

  const _LearningDatabaseQualificationApp({
    required this.databaseConnection,
    required this.database,
    required this.probeKey,
  });

  @override
  State<_LearningDatabaseQualificationApp> createState() =>
      _LearningDatabaseQualificationAppState();
}

class _LearningDatabaseQualificationAppState
    extends State<_LearningDatabaseQualificationApp> {
  bool _working = false;
  String _result = '';

  Future<void> _writeAndReadProbe() async {
    await _runProbe(write: true);
  }

  Future<void> _readProbe() async {
    await _runProbe(write: false);
  }

  Future<void> _runProbe({required bool write}) async {
    setState(() {
      _working = true;
      _result = '';
    });

    try {
      if (write) {
        await widget.database.writeProbe(widget.probeKey, _probeValue);
      }
      final String? value = await widget.database.readProbe(widget.probeKey);
      if (value == null) {
        throw StateError('No committed probe row exists for this key.');
      }
      if (mounted) {
        setState(() => _result = value);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _result = 'ERROR: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('SQLite platform qualification')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                widget.databaseConnection.webImplementation ?? 'unavailable',
                key: const ValueKey<String>('learning-storage-backend'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                key: const ValueKey<String>('learning-storage-write-probe'),
                onPressed: _working ? null : _writeAndReadProbe,
                child: const Text('Write probe'),
              ),
              ElevatedButton(
                key: const ValueKey<String>('learning-storage-read-probe'),
                onPressed: _working ? null : _readProbe,
                child: const Text('Read probe'),
              ),
              const SizedBox(height: 16),
              Text(
                _result,
                key: const ValueKey<String>('learning-storage-probe-result'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
