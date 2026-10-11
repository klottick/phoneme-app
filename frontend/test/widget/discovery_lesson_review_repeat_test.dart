import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:linguist/src/core/course/backend.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_progress.dart';
import 'package:linguist/src/core/course/lesson_section.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/features/course/discovery_lesson_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'discovery_lesson_test.dart' as support;

/// Real-store F2 regressions: the review route (`/course-lesson/:id
/// ?review=true`) reached with an already-mastered section — the same route
/// the course-progress due list pushes for a due lesson — must offer
/// `Practise again`, persist the fresh zero-attempt identity BEFORE the
/// exercise is exposed, keep every historical aggregate (legacy completions
/// and evidence) intact, keep the restarted identity after a page reload,
/// and let the repeated practice complete without adding a completion.
///
/// Also the F4 regression through the real store: an equal-count same-session
/// outcome divergence (another instance of the shared session committed a
/// different outcome for the same attempt) is a typed conflict whose explicit
/// `Reload saved progress` clears the local wrong-answer feedback, restores
/// the committed state with the hearing gate closed, and duplicates nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    courseBackend = null;
  });

  const String lesson = 'en-fr-u-y';
  final List<String> ids = frenchUySection.items.map((item) => item.id).toList();

  /// A mastered historical session (10/10, debrief phase); [complete] also
  /// records the legacy completion the restart must preserve.
  Future<LessonSectionSession> seedMastered(
    CourseProgressStore store, {
    required bool complete,
  }) async {
    final session = LessonSectionSession(itemIds: ids, sessionId: 'historical');
    await store.saveLessonSection(lesson, session.toJson());
    for (final item in frenchUySection.items) {
      session.submit(true);
      await store.recordLessonSectionAnswer(
          lesson, session.toJson(),
          sound: item.expectedSound, correct: true);
      session.advance();
      await store.saveLessonSection(lesson, session.toJson());
    }
    if (complete) {
      await store.completeLessonSection(lesson, session.toJson());
    }
    return session;
  }

  /// The review route: the exact lesson URL the course-progress due list
  /// pushes (`/course-lesson/<id>?review=true`), review mode read from the
  /// query parameters.
  GoRouter reviewRouter() => GoRouter(
      initialLocation: '/course-lesson/$lesson?review=true',
      routes: [
        GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('home'))),
        GoRoute(
            path: '/course-lesson/:id',
            builder: (_, state) => DiscoveryLessonScreen(
                  lessonId: state.pathParameters['id']!,
                  review: state.uri.queryParameters['review'] == 'true',
                )),
      ]);

  for (final bool completed in [false, true]) {
    testWidgets('real-store review route restarts a mastered section, keeps '
        'legacy/evidence/completion (completed=$completed), survives '
        'reopening, and finishes without a new completion', (tester) async {
      final store = CourseProgressStore('en-fr');
      // A legacy completion on another lesson: the mastered review restart
      // and its review Finish must never disturb it.
      await store.completeLesson('en-fr-vowels');
      await seedMastered(store, complete: completed);
      final List<dynamic> beforeLessons =
          List.of((await store.load())['lessons'] as List);

      final router = reviewRouter();
      addTearDown(router.dispose);
      Widget app() => ProviderScope(
          overrides: [
            courseAudioProvider.overrideWithValue(support.FakeAudio()),
          ],
          child: MaterialApp.router(routerConfig: router));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Section debrief'), findsOneWidget,
          reason: 'the mastered debrief is restored from the real store');

      // Explicit restart: the fresh zero-attempt identity must be persisted
      // before the exercise is exposed and the history must stay intact.
      await tester.scrollUntilVisible(find.text('Practise again'), 100);
      await tester.tap(find.text('Practise again'));
      await tester.pumpAndSettle();
      final Map<String, dynamic> restartedJson =
          (await store.loadLessonSection(lesson))!;
      final String newId = restartedJson['sessionId'] as String;
      expect(newId, isNot('historical'),
          reason: 'the restart starts a fresh session identity');
      expect(restartedJson['attemptCount'], 0,
          reason: 'the zero-attempt identity persisted before exposure');
      final Map<String, dynamic> before = await store.load();
      expect((before['evidence'] as Map)['listening:u']['attempts'], 5,
          reason: 'the historical evidence is retained by the restart');
      expect((before['evidence'] as Map)['listening:u']['correct'], 5);
      expect((await store.load())['lessons'], beforeLessons,
          reason: 'legacy completions are untouched by the restart');
      expect(find.text('Item 1 of 10'), findsOneWidget,
          reason: 'only after the restart save settles is the exercise '
              'exposed');

      // Reopening the app (a new page) loads the SAME restarted identity.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final Map<String, dynamic> reloadedJson =
          (await store.loadLessonSection(lesson))!;
      expect(reloadedJson['sessionId'], newId,
          reason: 'the persisted restart identity survives reopening');

      // The repeated practice records its own new history over the retained
      // aggregates, and the review Finish exits without a new completion.
      for (var n = 0; n < 10; n++) {
        await tester.scrollUntilVisible(find.text('Listen to the word'), 100);
        await tester.tap(find.text('Listen to the word'));
        await tester.pumpAndSettle();
        await tester.tap(find
            .text('/${frenchUySection.items[n].expectedSound}/'));
        await tester.pumpAndSettle();
        final Finder next =
            find.text(n == 9 ? 'See section explanation' : 'Next word');
        await tester.scrollUntilVisible(next, 100);
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(find.text('Finish section'), 100);
      await tester.tap(find.text('Finish section'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/home',
          reason: 'the settled review Finish exits the lesson');

      final Map<String, dynamic> saved = await store.load();
      expect(saved['lessons'], beforeLessons,
          reason: 'a review Finish cannot add a completion, even when no '
              'completion existed before');
      expect((saved['evidence'] as Map)['listening:u']['attempts'], 10,
          reason: 'the repeated practice recorded exactly five new attempts');
      expect((saved['evidence'] as Map)['listening:u']['correct'], 10);
      expect((saved['evidence'] as Map)['listening:y']['attempts'], 10);
      final Map<String, dynamic> finalJson =
          (await store.loadLessonSection(lesson))!;
      expect(finalJson['sessionId'], newId,
          reason: 'the repeated practice stays on the restarted identity');
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('an equal-count divergent same-session outcome on the real '
      'store reloads the exact committed result', (tester) async {
    final store = CourseProgressStore('en-fr');
    // A shared session captured by both instances before either answered.
    final seed = LessonSectionSession(itemIds: ids, sessionId: 'shared');
    await store.saveLessonSection(lesson, seed.toJson());
    await tester.pumpWidget(support.pumpLesson(tester, support.FakeAudio(), null));
    await tester.pumpAndSettle();
    expect(find.text('Item 1 of 10'), findsOneWidget);

    // The competing instance of the SAME session answers item 1 correctly,
    // records it, and advances: the stored session moves one attempt ahead.
    final competitor = LessonSectionSession.fromJson(
      seed.toJson(),
      itemIds: ids,
      contentRevision: frenchUySection.contentRevision,
    )..submit(true);
    await store.recordLessonSectionAnswer(
        lesson, competitor.toJson(), sound: 'u', correct: true);
    competitor.advance();
    await store.saveLessonSection(lesson, competitor.toJson());

    // The local instance answers the same attempt with a WRONG outcome:
    // feedback is local, the advance is an equal-count divergence the store
    // must reject with the typed conflict, not a plain retryable failure.
    await tester.tap(find.text('Listen to the word'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('/y/'));
    await tester.pumpAndSettle();
    expect(find.text('Not yet'), findsOneWidget,
        reason: 'local wrong-answer feedback stays while the state is stale');
    await tester.tap(find.text('Next word'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('matches the saved progress'), findsOneWidget,
        reason: 'the equal-count outcome divergence is a typed conflict');
    expect(find.text('Retry saving'), findsNothing,
        reason: 'a conflict is recovered by reload, not by retry');

    // The explicit reload abandons the stale draft (including the wrong local
    // feedback), restores the committed progress, and keeps the hearing gate
    // closed; the wrong attempt must not be recorded on top of the correct
    // one.
    await tester.tap(find.text('Reload saved progress'));
    await tester.pumpAndSettle();
    expect(find.text('Item 2 of 10'), findsOneWidget,
        reason: 'the committed advance is restored');
    expect(find.text('Not yet'), findsNothing,
        reason: 'the stale wrong-answer feedback is cleared');
    expect(find.text('Correct'), findsNothing,
        reason: 'the restored item is the unanswered one, not the old item');
    expect(support.choicesEnabled(tester), isFalse,
        reason: 'a fresh completed playback is required before answering '
            'the restored item');
    expect((await store.load())['evidence']['listening:u']['attempts'], 1,
        reason: 'the stale wrong attempt was rejected, not recorded');
    await tester.pumpWidget(const SizedBox());
  });
}
