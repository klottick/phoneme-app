import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:linguist/src/core/course/course_learning_command.dart'
    show LearningCommand;
import 'package:linguist/src/core/course/course_learning_error.dart'
    show LearningConflictException;
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabase, LearningDatabaseHandle;
import 'package:linguist/src/core/course/storage/learning_database_connection.dart';

import 'support/learning_database_workload.dart';
import '../test/support/learning_database_smoke.dart';

const String _probeValue = 'learning-storage-task1-persisted';
const String _configuredRunId = String.fromEnvironment('learningRunId');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final String? probeKey = Uri.base.queryParameters['probe'];
  final String runId = Uri.base.queryParameters['runId'] ?? _configuredRunId;
  if (runId.isNotEmpty) {
    try {
      final LearningDatabaseConnection databaseConnection =
          await openLearningDatabaseConnection();
      final LearningDatabaseHandle database = LearningDatabaseHandle(
        open: () async => LearningDatabase(databaseConnection.connection),
      );
      runApp(
        LearningDatabaseQualificationApp(
          database: database,
          runId: runId,
          backendName:
              databaseConnection.webImplementation ??
              'native SQLite (app-private background connection)',
        ),
      );
    } on Object catch (error) {
      runApp(_QualificationStartupFailure(runId: runId, error: error));
    }
    return;
  }
  if (probeKey == null || probeKey.isEmpty) {
    throw const FormatException(
      'Provide ?probe= for the smoke probe or a non-empty runId for '
      'Task 9 qualification.',
    );
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

/// Test-only controls over the same production SQL repositories used by the
/// retention and recovery workloads.
class LearningDatabaseQualificationApp extends StatefulWidget {
  const LearningDatabaseQualificationApp({
    super.key,
    required this.database,
    required this.runId,
    required this.backendName,
  });

  final LearningDatabaseHandle database;
  final String runId;
  final String backendName;

  @override
  State<LearningDatabaseQualificationApp> createState() =>
      _Task9QualificationAppState();
}

class _Task9QualificationAppState
    extends State<LearningDatabaseQualificationApp> {
  final TextEditingController _replayInput = TextEditingController();
  bool _working = false;
  bool _discardNextAcknowledgment = false;
  LearningCommand? _commandA;
  LearningCommand? _commandB;
  String _frozenCommand = '';
  String _result = 'Ready for SQLite qualification.';

  String get _ownerId => 'sqlite-qualification-${widget.runId}';

  Future<void> _run(String label, Future<void> Function() action) async {
    if (_working) return;
    setState(() {
      _working = true;
      _result = '$label: running';
    });
    try {
      await action();
    } on LearningConflictException {
      if (mounted) {
        setState(
          () => _result =
              'conflict: command cursor is stale; no attempt was written',
        );
      }
    } on Object catch (error) {
      if (mounted) setState(() => _result = 'ERROR: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _prepareCommand({
    required bool commandA,
  }) => _run('prepare command ${commandA ? 'A' : 'B'}', () async {
    final LearningCommand command = await prepareCourseCommandProbe(
      widget.database,
      runId: widget.runId,
      commandNamespace: commandA
          ? 'qualification-tab-a'
          : 'qualification-tab-b',
      correct: commandA,
    );
    final String payload = frozenCourseCommandPayload(command);
    if (!mounted) return;
    setState(() {
      if (commandA) {
        _commandA = command;
      } else {
        _commandB = command;
      }
      _frozenCommand = payload;
      _result =
          'prepared command ${commandA ? 'A' : 'B'} '
          'scopeRevision=${command.expectedScopeRevision} '
          'cursor=${_formatCursor(command.expected.generation, command.expected.sequence, command.expected.revision)}';
    });
  });

  Future<void> _submitCommand({required bool commandA}) async {
    final LearningCommand? command = commandA ? _commandA : _commandB;
    if (command == null) return;
    await _run('submit command ${commandA ? 'A' : 'B'}', () async {
      final String payload = frozenCourseCommandPayload(command);
      final bool discardAcknowledgment = _discardNextAcknowledgment;
      bool? duplicate;
      if (discardAcknowledgment) {
        await submitFrozenCourseCommand(
          widget.database,
          payload,
          runId: widget.runId,
        );
      } else {
        duplicate = await submitFrozenCourseCommand(
          widget.database,
          payload,
          runId: widget.runId,
        );
      }
      final Map<String, Object?> snapshot =
          await inspectCourseQualificationState(
            widget.database,
            runId: widget.runId,
          );
      if (!mounted) return;
      setState(() {
        _discardNextAcknowledgment = false;
        _result = discardAcknowledgment
            ? 'committed; acknowledgment discarded '
                  'attempts=${snapshot['attempts']} '
                  'scopeRevision=${snapshot['scopeRevision']} '
                  'cursor=${jsonEncode(snapshot['cursors'])}'
            : 'committed duplicate=$duplicate '
                  'attempts=${snapshot['attempts']} '
                  'scopeRevision=${snapshot['scopeRevision']} '
                  'cursor=${jsonEncode(snapshot['cursors'])}';
      });
    });
  }

  Future<void> _seedRetention() => _run('seed retention', () async {
    await seedLearningAtRetentionLimits(widget.database, runId: widget.runId);
    if (mounted) {
      setState(
        () => _result =
            'retention seed completed for runId=${widget.runId}; '
            'owner=$_ownerId course=en-fr',
      );
    }
  });

  Future<void> _verifyRetention() => _run('verify retention', () async {
    final LearningWorkloadReport report = await verifyLearningAtRetentionLimits(
      widget.database,
      runId: widget.runId,
    );
    if (mounted) {
      setState(
        () => _result = jsonEncode(<String, Object?>{
          'backend': widget.backendName,
          'runId': widget.runId,
          'owner': _ownerId,
          'course': 'en-fr',
          'auth': <String, Object?>{
            'ready': true,
            'generation': learningQualificationAuthGeneration,
          },
          'backendOwner': _ownerId,
          'cloudTransport': 'disabled',
          'report': report.toJson(),
        }),
      );
    }
  });

  Future<void> _replayFrozenCommand() async {
    final String payload = _replayInput.text.trim();
    if (payload.isEmpty) {
      setState(
        () => _result = 'ERROR: paste a frozen canonical command first.',
      );
      return;
    }
    await _run('replay frozen command', () async {
      final Map<String, Object?> before = await inspectCourseQualificationState(
        widget.database,
        runId: widget.runId,
      );
      final bool duplicate = await submitFrozenCourseCommand(
        widget.database,
        payload,
        runId: widget.runId,
      );
      final Map<String, Object?> after = await inspectCourseQualificationState(
        widget.database,
        runId: widget.runId,
      );
      if (mounted) {
        setState(
          () => _result =
              'duplicate=$duplicate attempts=${after['attempts']} '
              'unchanged=${before['attempts'] == after['attempts']} '
              'scopeRevision=${after['scopeRevision']} '
              'cursor=${jsonEncode(after['cursors'])}',
        );
      }
    });
  }

  String _formatCursor(int generation, int sequence, int revision) =>
      '($generation,$sequence,$revision)';

  @override
  void dispose() {
    _replayInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('SQLite learning qualification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget.backendName,
              key: const ValueKey<String>('learning-storage-backend'),
            ),
            const SizedBox(height: 8),
            Text(
              widget.runId,
              key: const ValueKey<String>('learning-storage-run-id'),
            ),
            const SizedBox(height: 8),
            Text(
              'owner=$_ownerId course=en-fr authReady=true '
              'authGeneration=$learningQualificationAuthGeneration '
              'backendOwner=$_ownerId cloudTransport=disabled',
              key: const ValueKey<String>('learning-storage-scope'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const ValueKey<String>('learning-storage-seed-retention'),
              onPressed: _working ? null : _seedRetention,
              child: const Text('Seed retention'),
            ),
            ElevatedButton(
              key: const ValueKey<String>('learning-storage-verify-retention'),
              onPressed: _working ? null : _verifyRetention,
              child: const Text('Verify retention'),
            ),
            const Divider(),
            ElevatedButton(
              key: const ValueKey<String>('learning-storage-prepare-command-a'),
              onPressed: _working
                  ? null
                  : () => _prepareCommand(commandA: true),
              child: const Text('Prepare command A'),
            ),
            ElevatedButton(
              key: const ValueKey<String>('learning-storage-prepare-command-b'),
              onPressed: _working
                  ? null
                  : () => _prepareCommand(commandA: false),
              child: const Text('Prepare command B'),
            ),
            ElevatedButton(
              key: const ValueKey<String>('learning-storage-submit-command-a'),
              onPressed: _working || _commandA == null
                  ? null
                  : () => _submitCommand(commandA: true),
              child: const Text('Submit command A'),
            ),
            ElevatedButton(
              key: const ValueKey<String>('learning-storage-submit-command-b'),
              onPressed: _working || _commandB == null
                  ? null
                  : () => _submitCommand(commandA: false),
              child: const Text('Submit command B'),
            ),
            CheckboxListTile(
              key: const ValueKey<String>('learning-storage-discard-ack'),
              value: _discardNextAcknowledgment,
              onChanged: _working
                  ? null
                  : (bool? value) => setState(
                      () => _discardNextAcknowledgment = value ?? false,
                    ),
              title: const Text('Discard next submit acknowledgment'),
            ),
            const Text('Frozen canonical command (copy exactly between tabs):'),
            Semantics(
              label: _frozenCommand,
              excludeSemantics: true,
              child: SelectableText(
                _frozenCommand,
                key: const ValueKey<String>('learning-storage-frozen-command'),
              ),
            ),
            TextField(
              key: const ValueKey<String>('learning-storage-replay-input'),
              controller: _replayInput,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Paste frozen command JSON from the other tab',
                border: OutlineInputBorder(),
              ),
            ),
            ElevatedButton(
              key: const ValueKey<String>(
                'learning-storage-replay-frozen-command',
              ),
              onPressed: _working ? null : _replayFrozenCommand,
              child: const Text('Replay frozen command'),
            ),
            if (_working) ...<Widget>[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
            ],
            const Text('Result, row counts and SQL cursors:'),
            Semantics(
              label: _result,
              excludeSemantics: true,
              child: SelectableText(
                _result,
                key: const ValueKey<String>('learning-storage-result'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _QualificationStartupFailure extends StatelessWidget {
  const _QualificationStartupFailure({
    required this.runId,
    required this.error,
  });

  final String runId;
  final Object error;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('SQLite learning qualification')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'unavailable',
              key: ValueKey<String>('learning-storage-backend'),
            ),
            Text(runId, key: const ValueKey<String>('learning-storage-run-id')),
            Text(
              'ERROR: $error',
              key: const ValueKey<String>('learning-storage-result'),
            ),
          ],
        ),
      ),
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
