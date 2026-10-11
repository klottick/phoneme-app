import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_progress.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/lesson_section_store.dart';
import 'package:linguist/src/features/course/discovery_lesson_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'discovery_lesson_test.dart' as support;

/// Full-screen accessibility regressions: the recovery/error states must stay
/// usable at 360x800 with 3x text scaling — the notice lives inside the same
/// scrolling content as the controls, and the tests scroll to the controls and
/// interact with them, not just assert that no overflow exception was raised.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget pumpLargeScreen(WidgetTester tester, LessonSectionStore store) {
    return ProviderScope(
      overrides: [
        courseAudioProvider.overrideWithValue(support.FakeAudio()),
        lessonSectionStoreProvider.overrideWithValue(store),
      ],
      child: MaterialApp(
        builder: (_, child) => MediaQuery(
          data: const MediaQueryData(
              size: Size(360, 800), textScaler: TextScaler.linear(3)),
          child: child!,
        ),
        home: const DiscoveryLessonScreen(lessonId: 'en-fr-u-y'),
      ),
    );
  }

  void setSmallPhone3x(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
      'corrupt recovery notice scrolls with the exercise controls '
      'at 360x800 with 3x text', (tester) async {
    setSmallPhone3x(tester);
    final store = support.FakeSectionStore()..stored = {'version': 999};
    await tester.pumpWidget(pumpLargeScreen(tester, store));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull,
        reason: 'the notice lives in the scrolling content; no RenderFlex '
            'overflow may remain');
    expect(find.textContaining('could not be restored'), findsOneWidget);
    // Scroll to the controls and interact: the exercise is usable, not just
    // visible.
    await tester.scrollUntilVisible(find.text('Listen to the word'), 200);
    await tester.tap(find.text('Listen to the word'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('/u/'), 200);
    await tester.tap(find.text('/u/'));
    await tester.pumpAndSettle();
    expect(find.text('Correct'), findsOneWidget,
        reason: 'the recovered exercise must be answerable at 3x text');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'a failed save keeps Retry saving reachable at 360x800 with 3x '
      'text', (tester) async {
    setSmallPhone3x(tester);
    final store = support.FakeSectionStore()..failAnswer = true;
    await tester.pumpWidget(pumpLargeScreen(tester, store));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Listen to the word'), 200);
    await tester.tap(find.text('Listen to the word'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('/u/'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('could not be saved'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Retry saving'), 200);
    store.failAnswer = false;
    await tester.tap(find.text('Retry saving'));
    await tester.pumpAndSettle();
    expect(find.text('Correct'), findsOneWidget,
        reason: 'the retried save must settle with the answer');
    expect(store.processedAttempts, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'a stale-session conflict keeps Reload saved progress reachable '
      'at 360x800 with 3x text', (tester) async {
    setSmallPhone3x(tester);
    // The screen starts with no saved state (its own fresh identity); a
    // competing instance then commits the same step first — the same
    // interleaving the stacked real-store regression exercises.
    final store = support.FakeSectionStore();
    await tester.pumpWidget(pumpLargeScreen(tester, store));
    await tester.pumpAndSettle();
    final foreign = LessonSectionSession(
      itemIds: support.FakeSectionStore.itemIds,
      sessionId: 'other-screen-session',
    )..submit(true);
    store.stored = foreign.toJson();
    await tester.scrollUntilVisible(find.text('Listen to the word'), 200);
    await tester.tap(find.text('Listen to the word'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('/u/'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('matches the saved progress'), findsOneWidget,
        reason: 'the typed conflict must be surfaced');
    expect(find.text('Retry saving'), findsNothing,
        reason: 'a conflict is recovered by reload, not by retry');
    await tester.scrollUntilVisible(find.text('Reload saved progress'), 200);
    await tester.tap(find.text('Reload saved progress'));
    await tester.pumpAndSettle();
    expect(find.text('Reload saved progress'), findsNothing,
        reason: 'the explicit reload must abandon the stale draft');
    expect(find.textContaining('could not be saved'), findsNothing);
    final savedNow = store.parse(store.stored!);
    expect(savedNow.sessionId, 'other-screen-session',
        reason: 'the reload must keep the stored committed state');
    expect(find.text('Correct'), findsOneWidget,
        reason: 'the stored committed state must be restored');
    await tester.pumpWidget(const SizedBox());
  });
}
