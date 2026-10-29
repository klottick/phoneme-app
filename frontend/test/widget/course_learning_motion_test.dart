import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/features/course/discovery_lesson_screen.dart';
import 'package:linguist/src/features/course/discovery_section_view.dart';
import 'package:linguist/src/features/course/exercises/listening_exercise_frame.dart';

import '../support/course_learning_widget_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'discovery_problem_transition_hides_stale_controls_without_replaying_work',
    (tester) async {
      final store = CourseLearningWidgetStore();
      final audio = _CountingAudio();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            courseLearningStoreProvider.overrideWithValue(store),
            courseAudioProvider.overrideWithValue(audio),
          ],
          child: const MaterialApp(
            home: DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstItemId = store.discoverySession!.currentItemId!;
      final initialAttempts = store.discoverySession!.attemptCount;
      await tester.tap(find.text('Listen to the word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/u/'));
      await tester.pumpAndSettle();

      final answerCommand = store.submitted.last;
      expect(answerCommand.action, isA<ChooseSound>());
      expect(store.discoverySession!.attemptCount, initialAttempts + 1);
      expect(store.committedState.history, hasLength(1));

      final advanceGate = Completer<void>();
      store.actionGates[AdvanceLesson] = advanceGate;
      await tester.tap(find.text('Next word'));
      await tester.pump();
      expect(store.submitted.last.action, isA<AdvanceLesson>());
      expect(store.discoverySession!.currentItemId, firstItemId);

      advanceGate.complete();
      store.actionGates.remove(AdvanceLesson);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));

      final nextItemId = store.discoverySession!.currentItemId!;
      expect(nextItemId, isNot(firstItemId));
      final oldProblem = find.byKey(
        ValueKey('listening-problem-$firstItemId'),
        skipOffstage: false,
      );
      final currentProblem = find.byKey(
        ValueKey('listening-problem-$nextItemId'),
        skipOffstage: false,
      );
      expect(oldProblem, findsOneWidget);
      expect(currentProblem, findsOneWidget);
      expect(find.byType(ListeningExerciseFrame), findsNWidgets(2));

      final listeningButton = find.descendant(
        of: oldProblem,
        matching: find.widgetWithText(FilledButton, 'Listen to the word'),
      );
      final staleButtonRect = tester.getRect(listeningButton);
      final currentListenButton = find.descendant(
        of: currentProblem,
        matching: find.widgetWithText(FilledButton, 'Listen to the word'),
      );
      final currentButtonRect = tester.getRect(currentListenButton);
      expect(staleButtonRect.overlaps(currentButtonRect), isTrue);
      final staleOnlyPoints =
          <Offset>[
            Offset(staleButtonRect.center.dx, staleButtonRect.top + 2),
            Offset(staleButtonRect.center.dx, staleButtonRect.bottom - 2),
            Offset(staleButtonRect.left + 2, staleButtonRect.center.dy),
            Offset(staleButtonRect.right - 2, staleButtonRect.center.dy),
          ].where(
            (Offset point) =>
                staleButtonRect.contains(point) &&
                !currentButtonRect.contains(point),
          );
      expect(staleOnlyPoints, isNotEmpty);
      final semantics = tester.ensureSemantics();
      final labels = _semanticsLabels(
        tester.getSemantics(find.byType(DiscoverySectionView)),
      );
      expect(
        labels.where((label) => label == 'Listen to the word'),
        hasLength(1),
      );
      semantics.dispose();

      await tester.tapAt(staleOnlyPoints.first);
      await tester.pump();
      expect(audio.speakCalls, 1);
      expect(
        store.submitted.where((command) => command.action is ChooseSound),
        hasLength(1),
      );
      expect(
        store.submitted.where((command) => command.action is AdvanceLesson),
        hasLength(1),
      );
      expect(store.discoverySession!.attemptCount, initialAttempts + 1);
      expect(store.committedState.history, hasLength(1));

      await tester.pumpAndSettle();
      expect(find.byType(ListeningExerciseFrame), findsOneWidget);
      expect(
        audio.speakCalls,
        1,
        reason: 'a visual transition must not play audio',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

List<String> _semanticsLabels(SemanticsNode node) {
  final labels = <String>[node.label];
  node.visitChildren((child) {
    labels.addAll(_semanticsLabels(child));
    return true;
  });
  return labels;
}

final class _CountingAudio implements CourseAudio {
  int speakCalls = 0;

  @override
  Future<void> speak(String word) async {
    speakCalls++;
  }

  @override
  Future<void> stop() async {}
}
