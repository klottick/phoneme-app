import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:linguist/src/core/course/course_learning_command.dart'
    show LearningCommand;
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabase, LearningDatabaseHandle;
import 'package:linguist/src/core/course/storage/learning_database_connection.dart';

import 'support/learning_database_workload.dart';

const String _runId = String.fromEnvironment(
  'learningRunId',
  defaultValue: 'sqlite-task9-shared',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native sqlite retains all families and remains responsive under load',
    (WidgetTester tester) async {
      final List<int> heartbeatSamples = <int>[];
      final Stopwatch heartbeatClock = Stopwatch()..start();
      await tester.pumpWidget(
        _HeartbeatAnimation(samples: heartbeatSamples, clock: heartbeatClock),
      );

      LearningDatabaseHandle handle = await _openNativeHandle();
      try {
        final LearningDatabase firstDatabase = await _pumpFramesWhile(
          tester,
          handle.open(),
        );
        expect(firstDatabase, isNotNull);

        final Future<LearningWorkloadReport> beforeReopenFuture = () async {
          await seedLearningAtRetentionLimits(handle, runId: _runId);
          return verifyLearningAtRetentionLimits(handle, runId: _runId);
        }();
        final LearningWorkloadReport beforeReopen = await _pumpFramesWhile(
          tester,
          beforeReopenFuture,
        );

        await handle.close();
        handle = await _openNativeHandle();
        final LearningWorkloadReport afterReopen = await _pumpFramesWhile(
          tester,
          verifyLearningAtRetentionLimits(handle, runId: _runId),
        );

        for (final String family in <String>[
          'course',
          'comparison',
          'sentence-hunt',
        ]) {
          expect(beforeReopen.rowCountsByFamily[family]?['attempts'], 2000);
          expect(beforeReopen.rowCountsByFamily[family]?['receipts'], 2000);
          expect(
            afterReopen.rowCountsByFamily[family],
            beforeReopen.rowCountsByFamily[family],
          );
          expect(
            afterReopen.summaryValuesByFamily[family],
            beforeReopen.summaryValuesByFamily[family],
          );
          expect(
            afterReopen.latestReceiptByFamily[family],
            beforeReopen.latestReceiptByFamily[family],
          );
        }

        const String concurrencyRunId = '$_runId-native-concurrency';
        final LearningCommand commandA = await prepareCourseCommandProbe(
          handle,
          runId: concurrencyRunId,
          commandNamespace: 'native-tab-a',
          correct: true,
        );
        final LearningCommand commandB = await prepareCourseCommandProbe(
          handle,
          runId: concurrencyRunId,
          commandNamespace: 'native-tab-b',
          correct: false,
        );
        final LearningDatabaseHandle secondConnection =
            await _openNativeHandle();
        var commits = 0;
        var conflicts = 0;
        try {
          final LearningDatabase firstConnectionDatabase = await handle.open();
          final LearningDatabase secondConnectionDatabase =
              await secondConnection.open();
          expect(
            identical(firstConnectionDatabase, secondConnectionDatabase),
            isFalse,
          );
          final List<bool> concurrentResults =
              await Future.wait<bool>(<Future<bool>>[
                _submitOrConflict(
                  handle,
                  frozenCourseCommandPayload(commandA),
                  runId: concurrencyRunId,
                ),
                _submitOrConflict(
                  secondConnection,
                  frozenCourseCommandPayload(commandB),
                  runId: concurrencyRunId,
                ),
              ]);
          commits = concurrentResults.where((bool value) => value).length;
          conflicts = concurrentResults.where((bool value) => !value).length;
        } finally {
          await secondConnection.close();
        }
        expect(commits, 1);
        expect(conflicts, 1);
        expect(await _attemptCount(handle, concurrencyRunId), 1);

        const String replayRunId = '$_runId-native-lost-ack';
        final LearningCommand frozenCommand = await prepareCourseCommandProbe(
          handle,
          runId: replayRunId,
          commandNamespace: 'native-lost-ack',
          correct: true,
        );
        final String frozenPayload = frozenCourseCommandPayload(frozenCommand);
        expect(jsonDecode(frozenPayload), isA<Map<String, dynamic>>());

        // Commit on the first connection and intentionally discard its ACK.
        await submitFrozenCourseCommand(
          handle,
          frozenPayload,
          runId: replayRunId,
        );
        final int attemptsAfterCommit = await _attemptCount(
          handle,
          replayRunId,
        );
        expect(attemptsAfterCommit, 1);

        final LearningDatabaseHandle independentConnection =
            await _openNativeHandle();
        try {
          final bool duplicate = await submitFrozenCourseCommand(
            independentConnection,
            frozenPayload,
            runId: replayRunId,
          );
          expect(duplicate, isTrue);
          expect(
            await _attemptCount(independentConnection, replayRunId),
            attemptsAfterCommit,
          );
        } finally {
          await independentConnection.close();
        }

        final LearningRecoveryControlEvidence controls =
            await qualifyLearningRecoveryControls(
              handle,
              runId: '$_runId-native-controls',
            );
        expect(controls.changedPayloadRejected, isTrue);
        expect(controls.changedPayloadDidNotRewrite, isTrue);
        expect(controls.changedContentRejectedWithoutRewrite, isTrue);
        expect(controls.changedPolicyRejectedWithoutRewrite, isTrue);
        expect(controls.unknownVersionRejectedWithoutRewrite, isTrue);
        expect(controls.unknownAckDidNotWrite, isTrue);

        await tester.pump(const Duration(milliseconds: 300));
        final int maxHeartbeatGap = _maxGap(heartbeatSamples);
        expect(heartbeatSamples.length, greaterThan(1));
        expect(maxHeartbeatGap, lessThanOrEqualTo(250000));
        // ignore: avoid_print
        print(
          'TASK9 NATIVE runId=$_runId report=${jsonEncode(afterReopen.toJson())} '
          'heartbeatFrames=${heartbeatSamples.length} '
          'maxHeartbeatGapMicros=$maxHeartbeatGap '
          'frozenCommand=$frozenPayload',
        );
      } finally {
        await handle.close();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
    timeout: const Timeout(Duration(hours: 2)),
  );
}

Future<LearningDatabaseHandle> _openNativeHandle() async {
  final LearningDatabaseConnection connection =
      await openLearningDatabaseConnection();
  if (connection.webImplementation != null) {
    throw StateError('Native qualification unexpectedly selected web storage.');
  }
  return LearningDatabaseHandle(
    open: () async => LearningDatabase(connection.connection),
  );
}

Future<int> _attemptCount(LearningDatabaseHandle handle, String runId) async {
  final LearningDatabase database = await handle.open();
  final result = await database
      .customSelect(
        'SELECT COUNT(*) AS row_count FROM learning_attempts '
        'WHERE scope_id = (SELECT id FROM learning_scopes WHERE '
        'owner_kind = ? AND owner_id = ? AND course_id = ? AND family = ?)',
        variables: <Variable<Object>>[
          const Variable<String>('account'),
          Variable<String>('sqlite-qualification-$runId'),
          const Variable<String>('en-fr'),
          const Variable<String>('course'),
        ],
      )
      .getSingle();
  return result.read<int>('row_count');
}

Future<bool> _submitOrConflict(
  LearningDatabaseHandle handle,
  String payload, {
  required String runId,
}) async {
  try {
    await submitFrozenCourseCommand(handle, payload, runId: runId);
    return true;
  } on LearningConflictException {
    return false;
  }
}

int _maxGap(List<int> samples) {
  if (samples.length < 2) return 0;
  var maxGap = 0;
  for (var index = 1; index < samples.length; index++) {
    final int gap = samples[index] - samples[index - 1];
    if (gap > maxGap) maxGap = gap;
  }
  return maxGap;
}

Future<T> _pumpFramesWhile<T>(WidgetTester tester, Future<T> operation) async {
  final Completer<T> completed = Completer<T>();
  operation.then(completed.complete, onError: completed.completeError);
  while (!completed.isCompleted) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return completed.future;
}

class _HeartbeatAnimation extends StatefulWidget {
  const _HeartbeatAnimation({required this.samples, required this.clock});

  final List<int> samples;
  final Stopwatch clock;

  @override
  State<_HeartbeatAnimation> createState() => _HeartbeatAnimationState();
}

class _HeartbeatAnimationState extends State<_HeartbeatAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..addListener(_recordHeartbeat);

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  void _recordHeartbeat() {
    widget.samples.add(widget.clock.elapsedMicroseconds);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) => Text(
            _controller.value.toStringAsFixed(3),
            key: const ValueKey<String>('learning-sqlite-heartbeat'),
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
