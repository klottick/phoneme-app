import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_store.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/features/arcade/arcade_screen.dart';
import '../support/course_learning_widget_store.dart';

final _activeStoreProvider = StateProvider<CourseLearningStore>(
    (ref) => throw StateError('test store must be overridden'));

final _soundPreview = {
  ItemContextKey(itemId: 'tout', targetSound: 'u'),
  ItemContextKey(itemId: 'rouge', targetSound: 'u'),
  ItemContextKey(itemId: 'vous', targetSound: 'u'),
  ItemContextKey(itemId: 'tu', targetSound: 'y'),
  ItemContextKey(itemId: 'rue', targetSound: 'y'),
  ItemContextKey(itemId: 'lune', targetSound: 'y'),
  ItemContextKey(itemId: 'lit', targetSound: 'i'),
  ItemContextKey(itemId: 'beau', targetSound: 'o'),
};
final _wordPreview = {
  ItemContextKey(itemId: 'tout', targetSound: 'u'),
  ItemContextKey(itemId: 'rouge', targetSound: 'u'),
  ItemContextKey(itemId: 'vous', targetSound: 'u'),
  ItemContextKey(itemId: 'tu', targetSound: 'y'),
  ItemContextKey(itemId: 'rue', targetSound: 'y'),
  ItemContextKey(itemId: 'lune', targetSound: 'y'),
};

void main() {
  for (final silent in [false, true]) {
    testWidgets(
        'fresh ${silent ? 'Word' : 'Sound'} Match records only displayed preview before play',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = CourseLearningWidgetStore();
      final gate = Completer<void>();
      store.actionGates[ObserveAssistance] = gate;
      await tester.pumpWidget(ProviderScope(
        overrides: [courseLearningStoreProvider.overrideWithValue(store)],
        child: MaterialApp(home: ArcadeScreen(silent: silent)),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start 60-second round'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(
          store.submitted.any((command) => command.action is ObserveAssistance),
          isTrue,
          reason: 'the displayed preview must be queued after initial save');
      expect(find.byTooltip('Pause'), findsNothing,
          reason: 'gameplay waits until the preview observation is durable');
      expect(store.committedState.history, isEmpty);
      await tester.pump(const Duration(seconds: 3));
      gate.complete();
      await tester.pumpAndSettle();
      final slot = store
          .committedState.activities[silent ? 'arcade:word' : 'arcade:sound']!;
      final expected = silent ? _wordPreview : _soundPreview;
      final explained = slot.exposures.entries
          .where((entry) => entry.value.assistance
              .contains(AssistanceFlag.explanationVisible))
          .map((entry) => entry.key)
          .toSet();
      expect(explained, expected,
          reason: 'only the actually displayed preview earns explanation help');
      for (final context in expected) {
        final exposure = slot.exposures[context]!;
        expect(exposure.presentations, 0);
        expect(
            exposure.assistance, contains(AssistanceFlag.explanationVisible));
        if (silent) {
          expect(
              exposure.assistance,
              everyElement(anyOf(AssistanceFlag.explanationVisible,
                  AssistanceFlag.graphemeHint)));
        } else {
          expect(exposure.assistance, {AssistanceFlag.explanationVisible});
        }
      }
      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(find.text('Round 1 · 60s'), findsOneWidget,
          reason: 'the timer starts only after the preview acknowledgement');
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'failed fresh preview observation retries identical command before play',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = CourseLearningWidgetStore();
    final gate = Completer<void>();
    store.actionGates[ObserveAssistance] = gate;
    await tester.pumpWidget(ProviderScope(
      overrides: [courseLearningStoreProvider.overrideWithValue(store)],
      child: const MaterialApp(home: ArcadeScreen(silent: false)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start 60-second round'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    final observations = store.submitted
        .where((command) => command.action is ObserveAssistance)
        .toList();
    expect(observations, isNotEmpty,
        reason: 'the displayed preview must be observed on a fresh run');
    if (observations.isEmpty) return;
    final held = observations.single;
    expect(find.byTooltip('Pause'), findsNothing);
    store.actionFailures[ObserveAssistance] = const LearningSaveException();
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Retry save'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsNothing);

    store.actionFailures.remove(ObserveAssistance);
    await tester.tap(find.text('Retry save'));
    await tester.pumpAndSettle();
    expect(store.submitted.where((command) => command.token == held.token),
        hasLength(2));
    expect(identical(store.submitted.last, held), isTrue);
    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(store.committedState.history, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('held old-owner preview cannot activate after A to B to A',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storeA = CourseLearningWidgetStore();
    final storeB = CourseLearningWidgetStore();
    final gate = Completer<void>();
    storeA.actionGates[ObserveAssistance] = gate;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        _activeStoreProvider.overrideWith((ref) => storeA),
        courseLearningStoreProvider
            .overrideWith((ref) => ref.watch(_activeStoreProvider)),
      ],
      child: const MaterialApp(home: ArcadeScreen(silent: false)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start 60-second round'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    final observations = storeA.submitted
        .where((command) => command.action is ObserveAssistance)
        .toList();
    expect(observations, isNotEmpty,
        reason:
            'fresh-start preview observation must be held by the test gate');
    if (observations.isEmpty) return;
    final container =
        ProviderScope.containerOf(tester.element(find.byType(ArcadeScreen)));
    container.read(_activeStoreProvider.notifier).state = storeB;
    await tester.pumpAndSettle();
    container.read(_activeStoreProvider.notifier).state = storeA;
    await tester.pumpAndSettle();
    gate.complete();
    await tester.pumpAndSettle();

    expect(storeB.committedState.activities, isEmpty);
    expect(find.byTooltip('Pause'), findsNothing,
        reason: 'a stale observation completion cannot activate the new owner');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
