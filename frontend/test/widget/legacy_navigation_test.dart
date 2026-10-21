import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:linguist/src/features/modes/challenge_mode_screen.dart';
import 'package:linguist/src/core/services/curriculum_service.dart';
import 'package:linguist/src/features/phoneme_id/phoneme_identify_screen.dart';

void main() {
  testWidgets('unfinished mode cards are unavailable and Back stays usable', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/modes'),
              child: const Text('Open modes'),
            ),
          ),
        ),
        GoRoute(
          path: '/modes',
          builder: (_, __) => const ChallengeModeScreen(),
        ),
        GoRoute(
          path: '/phoneme-id',
          builder: (_, __) => const Scaffold(body: Text('Practice')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open modes'));
    await tester.pumpAndSettle();
    for (final mode in ['Challenge', 'Marathon', 'Zen']) {
      await tester.scrollUntilVisible(find.text(mode), 200);
      expect(find.text(mode), findsOneWidget);
      expect(
        find.textContaining('Unavailable — $mode practice'),
        findsOneWidget,
      );
      expect(find.text('Unavailable'), findsNWidgets(3));
      await tester.tap(find.text(mode));
      await tester.pumpAndSettle();
      expect(find.text('Learning Modes'), findsOneWidget);
      expect(find.text('Practice'), findsNothing);
    }
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Open modes'), findsOneWidget);
  });

  for (final lesson in ['French Basics', 'French Nasals']) {
    testWidgets(
      '$lesson opens generic practice and Back returns to lesson plans',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => context.push('/lessons'),
                  child: const Text('Open lessons'),
                ),
              ),
            ),
            GoRoute(
              path: '/lessons',
              builder: (_, __) => const LessonPlanScreen(languageCode: 'fr'),
            ),
            GoRoute(
              path: '/phoneme-id',
              builder: (_, __) => const PhonemeIdentifyScreen(),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open lessons'));
        await tester.pumpAndSettle();
        expect(find.text('Generic practice'), findsNWidgets(2));
        await tester.tap(find.text(lesson));
        await tester.pumpAndSettle();
        expect(find.text('Phoneme Identification'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Lesson Plans'), findsOneWidget);
        expect(find.text(lesson), findsOneWidget);
      },
    );
  }
}
