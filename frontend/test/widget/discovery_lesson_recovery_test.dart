import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/backend.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_progress.dart';
import 'package:linguist/src/core/course/french_course.dart';
import 'package:linguist/src/core/course/lesson_section.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/features/course/discovery_lesson_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'dart:convert';

import 'discovery_lesson_test.dart' as support;

/// Real screen + real store regressions for the F1 interleaving:
/// reopening a lesson while a failing answer write is still in flight must
/// not restore the unrecorded answer or strand the next-word flow.

const String lessonId = 'en-fr-u-y';

/// In-memory preferences platform that holds its first platform write
/// mid-flight and releases it as success/failure. The real
/// SharedPreferences singleton applies its optimistic in-process cache
/// update before the platform write resolves, so this models the
/// production interleaving exactly.
class _HeldWritePrefs extends InMemorySharedPreferencesStore {
  _HeldWritePrefs() : super.withData({});

  Completer<void>? _entered;
  Completer<bool>? _gate;
  bool holding = false;
  int heldWrites = 0;

  void beginHold() {
    holding = true;
    _entered = Completer<void>();
    _gate = Completer<bool>();
  }

  void release({bool persist = true}) {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) {
      gate.complete(persist);
    }
    holding = false;
    _entered = null;
    _gate = null;
  }

  Future<void> get entered {
    final gate = _entered;
    if (gate != null) {
      return gate.future;
    }
    return Future<void>.value();
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (holding) {
      heldWrites += 1;
      final entered = _entered;
      if (entered != null && !entered.isCompleted) {
        entered.complete();
      }
      final bool persist = await _gate!.future;
      if (!persist) {
        return false;
      }
      return super.setValue(valueType, key, value);
    }
    return super.setValue(valueType, key, value);
  }
}

Widget _pumpLessonRealStore(WidgetTester tester, support.FakeAudio audio) {
  return ProviderScope(
    overrides: [courseAudioProvider.overrideWithValue(audio)],
    child: const MaterialApp(
      home: DiscoveryLessonScreen(lessonId: lessonId),
    ),
  );
}

Future<void> _answerItem(WidgetTester tester, String sound) async {
  await tester.tap(find.text('Listen to the word'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('/$sound/'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    courseBackend = null;
  });

  testWidgets(
      'reopening while an answer write fails starts fresh and the '
      'next-word flow recovers', (tester) async {
    final prefs = _HeldWritePrefs();
    SharedPreferencesStorePlatform.instance = prefs;
    SharedPreferences.resetStatic();
    addTearDown(() async {
      SharedPreferences.setMockInitialValues({});
    });

    final audio = support.FakeAudio();
    await tester.pumpWidget(_pumpLessonRealStore(tester, audio));
    await tester.pumpAndSettle();
    expect(find.text('Item 1 of 10'), findsOneWidget);

    // First screen's answer: the platform write enters the hold.
    prefs.beginHold();
    await _answerItem(tester, 'u');
    expect(find.text('Correct'), findsOneWidget,
        reason: 'immediate local feedback before persistence');
    await prefs.entered;
    expect(prefs.heldWrites, greaterThan(0),
        reason: 'the held answer write is verified in flight, not timed');
    addTearDown(() {
      if (prefs.holding) {
        prefs.release(persist: false);
      }
    });

    // Reopen the lesson (new screen, same real store and same prefs). The
    // reopened screen's load waits out the in-flight write by design, so let
    // it start without settling.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_pumpLessonRealStore(tester, audio));
    await tester.pump();
    expect(find.text('Correct'), findsNothing,
        reason: 'reopened during an in-flight write: the optimistic '
            'answer must not be visible yet');

    // Reject the pending write, then let the reopened screen settle on the
    // committed (repaired) state.
    prefs.release(persist: false);
    await tester.pumpAndSettle();

    expect(find.text('Correct'), findsNothing,
        reason: 'reopening must not restore an unrecorded answer');
    expect(
        find.textContaining('could not be saved'), findsNothing,
        reason: 'the failed write belongs to the disposed screen');
    expect(find.text('Retry saving'), findsNothing);
    expect(find.text('Item 1 of 10'), findsOneWidget,
        reason: 'the reopened screen starts fresh');

    // The next-word flow must work end to end: no permanent failure loop.
    // Item 1 ("tout") expects /u/.
    await _answerItem(tester, 'u');
    expect(find.text('Correct'), findsOneWidget);
    await tester.tap(find.text('Next word'));
    await tester.pumpAndSettle();
    expect(find.textContaining('could not be saved'), findsNothing,
        reason: 'Next must not strand in a failing retry loop');
    expect(find.text('Retry saving'), findsNothing);
    expect(find.text('Item 2 of 10'), findsOneWidget);

    // Exactly one committed local attempt.
    final data = await CourseProgressStore(frenchCourse.id).load();
    expect((data['evidence'] as Map).length, 1);
    expect((data['evidence']['listening:u'] as Map)['attempts'], 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a corrupt stored entry loads through the corrupt recovery '
      'contract and the new session records cleanly', (tester) async {
    final session = LessonSectionSession(
        itemIds: frenchUySection.items.map((item) => item.id).toList(),
        sessionId: 'corrupt-entry');
    // Seeded platform: a valid zero-attempt checkpoint with corrupted
    // processed metadata.
    SharedPreferences.setMockInitialValues({
      'flutter.course.v1.${frenchCourse.id}': jsonEncode({
        'lessons': <String>[],
        'evidence': <String, dynamic>{},
        'scores': <String, dynamic>{},
        'sections': {
          lessonId: {
            'checkpoint': session.toJson(),
            'processedSessionId': 'corrupt-entry',
            'processedAttemptCount': 100,
          }
        }
      })
    });
    addTearDown(() async {
      SharedPreferences.setMockInitialValues({});
    });

    await tester.pumpWidget(
        _pumpLessonRealStore(tester, support.FakeAudio()));
    await tester.pumpAndSettle();

    expect(find.textContaining('could not be restored'),
        findsOneWidget,
        reason: 'an unusable entry must follow the corrupt snapshot '
            'contract (notice + fresh attempt)');
    expect(find.text('Item 1 of 10'), findsOneWidget);

    // The fresh attempt records and advances without a save failure.
    await _answerItem(tester, 'u');
    expect(find.text('Correct'), findsOneWidget);
    await tester.tap(find.text('Next word'));
    await tester.pumpAndSettle();
    expect(find.textContaining('could not be saved'), findsNothing,
        reason: 'the recovered entry must accept the fresh session');
    expect(find.text('Retry saving'), findsNothing);
    expect(find.text('Item 2 of 10'), findsOneWidget);

    final data = await CourseProgressStore(frenchCourse.id).load();
    expect((data['evidence']['listening:u'] as Map)['attempts'], 1,
        reason: 'the new answer is recorded exactly once');
    await tester.pumpWidget(const SizedBox());
  });
}
