import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/services/data_export_service.dart';
import 'package:linguist/src/features/phoneme_test/phoneme_test_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ControlledExportService extends DataExportService {
  _ControlledExportService({this.failFirst = false});

  final bool failFirst;
  int calls = 0;
  final Completer<void> firstCall = Completer<void>();
  final Completer<void> finishFirst = Completer<void>();

  @override
  Future<void> shareExport() async {
    calls++;
    if (calls == 1 && failFirst) {
      firstCall.complete();
      await finishFirst.future;
      throw StateError('temporary export failure');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'unsupported web export is unavailable without native file calls',
    () async {
      final service = DataExportService(supportsNativeFileActions: false);
      expect(service.supportsFileActions, isFalse);
      await expectLater(
        service.exportToFile(),
        throwsA(isA<UnsupportedError>()),
      );
      await expectLater(
        service.shareExport(),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        DataExportService(supportsNativeFileActions: true).supportsFileActions,
        isTrue,
      );
    },
  );

  test(
    'invalid import is a managed failure and leaves stored data unchanged',
    () async {
      SharedPreferences.setMockInitialValues({'srs_phonemes': 'existing'});
      final service = DataExportService();
      final notifier = DataExportNotifier(service);
      expect(await notifier.import('{invalid'), isFalse);
      expect(notifier.state, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('srs_phonemes'), 'existing');
    },
  );

  testWidgets('failed export clears busy, reports failure, and can retry', (
    tester,
  ) async {
    final service = _ControlledExportService(failFirst: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dataExportServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: DataExportScreen()),
      ),
    );

    await tester.tap(find.text('Export Progress'));
    await service.firstCall.future;
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    service.finishFirst.complete();
    await tester.pumpAndSettle();
    expect(find.text('Export failed. Please try again.'), findsOneWidget);
    expect(find.text('Export shared!'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .clearSnackBars();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export Progress'));
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    expect(find.text('Export shared!'), findsOneWidget);
  });

  testWidgets('concurrent export taps only start one operation', (
    tester,
  ) async {
    final service = _ControlledExportService(failFirst: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dataExportServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(home: DataExportScreen()),
      ),
    );
    await tester.tap(find.text('Export Progress'));
    await service.firstCall.future;
    await tester.tap(find.text('Export Progress'));
    expect(service.calls, 1);
    service.finishFirst.complete();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'unsupported export explains unavailability and never invokes service',
    (tester) async {
      final service = _ControlledExportService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dataExportServiceProvider.overrideWithValue(service),
            nativeFileActionsAvailableProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(home: DataExportScreen()),
        ),
      );
      expect(
        find.textContaining('not available in this browser'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.block), findsOneWidget);
      await tester.tap(find.text('Export Progress'));
      await tester.pumpAndSettle();
      expect(service.calls, 0);
    },
  );

  testWidgets(
    'unsupported recording control explains availability and is disabled',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            phonemeRecordingAvailableProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(home: PhonemeTestScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Recording is not available in this browser'),
        findsOneWidget,
      );
      expect(find.text('Tap to say the phoneme'), findsNothing);
      final recordButton = tester
          .widgetList<FloatingActionButton>(find.byType(FloatingActionButton))
          .firstWhere(
            (button) =>
                button.tooltip == 'Recording is not available in this browser',
          );
      expect(recordButton.onPressed, isNull);
      expect(
        recordButton.tooltip,
        'Recording is not available in this browser',
      );
      await tester.tap(
        find.byTooltip('Recording is not available in this browser').first,
      );
      await tester.pump();
      expect(find.text('Recording...'), findsNothing);
    },
  );

  testWidgets('supported recording retains its recording instruction', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [phonemeRecordingAvailableProvider.overrideWithValue(true)],
        child: const MaterialApp(home: PhonemeTestScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tap to say the phoneme'), findsOneWidget);
  });
}
