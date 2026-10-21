import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:linguist/src/app.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/models/review_item.dart';
import 'package:linguist/src/core/providers/app_providers.dart';
import 'package:linguist/src/core/repositories/progress_repository.dart';
import 'package:linguist/src/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/course_learning_widget_store.dart';

class _FakeSupabaseClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Override _comparisonStateOverride() =>
    comparisonLearningStateProvider.overrideWith(
      (ref) async => ComparisonLearningState.empty(
        ComparisonProfileScope(courseId: 'en-fr', owner: LearningOwner.guest()),
      ),
    );

void main() {
  setUp(
    () =>
        SharedPreferences.setMockInitialValues({'selected_course_id': 'en-fr'}),
  );

  Future<(ProviderContainer, WidgetTester)> mountApp(
    WidgetTester tester, {
    List<Override> additionalOverrides = const [],
  }) async {
    final container = ProviderContainer(
      overrides: [
        courseLearningStoreProvider.overrideWithValue(
          CourseLearningWidgetStore(),
        ),
        _comparisonStateOverride(),
        ...additionalOverrides,
      ],
    );
    addTearDown(container.dispose);
    container.read(appRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LinguistApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Linguist'), findsOneWidget);
    return (container, tester);
  }

  testWidgets('injected backend keeps legacy analytics data path available', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(2400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (container, _) = await mountApp(
      tester,
      additionalOverrides: [
        legacyBackendAvailableProvider.overrideWithValue(true),
        progressRepositoryProvider.overrideWithValue(
          ProgressRepository(_FakeSupabaseClient()),
        ),
      ],
    );
    container.read(appRouterProvider).push('/analytics');
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Recent Performance'), findsOneWidget);
    expect(
      find.text('Performance totals are not measured in this view.'),
      findsOneWidget,
    );
    expect(find.text('Attempts'), findsNothing);
    expect(find.text('Accuracy'), findsNothing);
    expect(find.textContaining('unavailable'), findsNothing);
  });

  testWidgets('actual app router insights route shows unavailable metrics', (
    tester,
  ) async {
    final (container, _) = await mountApp(tester);
    container.read(appRouterProvider).push('/insights');
    await tester.pumpAndSettle();
    expect(find.text('Learning Insights'), findsOneWidget);
    expect(find.text('Not measured'), findsWidgets);
    expect(find.text('70%'), findsNothing);
    expect(find.text('60%'), findsNothing);
    expect(find.textContaining('errors'), findsNothing);
  });

  testWidgets('injected backend keeps legacy review data path available', (
    tester,
  ) async {
    final (container, _) = await mountApp(
      tester,
      additionalOverrides: [
        legacyBackendAvailableProvider.overrideWithValue(true),
        dueReviewItemsProvider.overrideWith((ref) async => const []),
      ],
    );
    container.read(appRouterProvider).push('/review');
    await tester.pumpAndSettle();
    expect(find.text('No due items. Great consistency.'), findsOneWidget);
    expect(find.textContaining('unavailable'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('configured review transitions from loading to due items', (
    tester,
  ) async {
    final dueItems = Completer<List<ReviewItem>>();
    final (container, _) = await mountApp(
      tester,
      additionalOverrides: [
        legacyBackendAvailableProvider.overrideWithValue(true),
        dueReviewItemsProvider.overrideWith((ref) => dueItems.future),
      ],
    );
    container.read(appRouterProvider).push('/review');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    dueItems.complete([
      ReviewItem(
        queueId: 'queue-1',
        phonemeId: 'phoneme-1',
        ipaSymbol: '/y/',
        descriptor: 'lune',
        languageCode: 'fr',
        dueAt: DateTime.utc(2026, 10, 21),
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('/y/ (fr)'), findsOneWidget);
    expect(find.text('lune'), findsOneWidget);
    expect(find.text('No due items. Great consistency.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('configured review renders a managed provider error', (
    tester,
  ) async {
    final dueItems = Completer<List<ReviewItem>>();
    final (container, _) = await mountApp(
      tester,
      additionalOverrides: [
        legacyBackendAvailableProvider.overrideWithValue(true),
        dueReviewItemsProvider.overrideWith((ref) => dueItems.future),
      ],
    );
    container.read(appRouterProvider).push('/review');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    dueItems.completeError(StateError('controlled review failure'));
    await tester.pumpAndSettle();
    expect(
      find.text('Failed to load reviews: Bad state: controlled review failure'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('actual app router keeps unfinished modes unavailable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final (container, _) = await mountApp(tester);
    final router = container.read(appRouterProvider);
    router.push('/modes');
    await tester.pumpAndSettle();
    expect(find.text('Learning Modes'), findsOneWidget);

    for (final mode in ['Challenge', 'Marathon', 'Zen']) {
      await tester.scrollUntilVisible(find.text(mode), 200);
      expect(
        find.textContaining('Unavailable — $mode practice'),
        findsOneWidget,
      );
      await tester.tap(find.text(mode));
      await tester.pumpAndSettle();
      expect(find.text('Learning Modes'), findsOneWidget);
      expect(find.text('Learning Modes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Linguist'), findsOneWidget);
  });

  for (final route in ['/analytics', '/review']) {
    testWidgets('actual app router shows offline availability at $route', (
      tester,
    ) async {
      final (container, _) = await mountApp(tester);
      final router = container.read(appRouterProvider);
      router.push(route);
      await tester.pumpAndSettle();

      expect(
        find.text(route == '/analytics' ? 'Progress Analytics' : 'Due Review'),
        findsOneWidget,
      );
      expect(find.textContaining('unavailable'), findsOneWidget);
      expect(find.textContaining('backend'), findsOneWidget);
      expect(find.text('Back to home'), findsOneWidget);
      expect(find.textContaining('LateInitializationError'), findsNothing);
      expect(find.textContaining('Failed to load reviews'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Back to home'));
      await tester.pumpAndSettle();
      expect(find.text('Linguist'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final lesson in ['French Basics', 'French Nasals']) {
    testWidgets(
      'actual app router: $lesson opens generic practice and Back returns',
      (tester) async {
        final (container, _) = await mountApp(tester);
        final router = container.read(appRouterProvider);
        router.push('/lessons');
        await tester.pumpAndSettle();
        expect(find.text('Lesson Plans'), findsOneWidget);
        expect(find.text('Generic practice'), findsNWidgets(2));

        await tester.tap(find.text(lesson));
        await tester.pumpAndSettle();
        expect(find.text('Phoneme Identification'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Lesson Plans'), findsOneWidget);
        expect(find.text(lesson), findsOneWidget);
      },
    );
  }
}
