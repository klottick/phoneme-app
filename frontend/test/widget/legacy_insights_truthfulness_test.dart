import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:linguist/src/core/services/insights_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'empty and stale insight preferences do not become learner metrics',
    () async {
      SharedPreferences.setMockInitialValues({});
      final empty = await InsightsService().getInsights();
      expect(empty.totalSessions, isNull);
      expect(empty.totalMinutes, isNull);
      expect(empty.averageAccuracy, isNull);
      expect(empty.weeklyStats, isEmpty);
      expect(empty.weakAreas, isEmpty);

      SharedPreferences.setMockInitialValues({
        'learning_insights.sessions': 4,
        'learning_insights.minutes': 20,
        'learning_insights.accuracy': .7,
        'learning_insights.longest_session': 10,
      });
      final stale = await InsightsService().getInsights();
      expect(stale.totalSessions, isNull);
      expect(stale.totalMinutes, isNull);
      expect(stale.averageAccuracy, isNull);
      expect(stale.longestSession, isNull);
      expect(stale.mostPracticedPhoneme, isNull);
      expect(stale.hardestPhoneme, isNull);
      expect(stale.weakAreas, isEmpty);
      expect(stale.weeklyStats, isEmpty);
    },
  );

  testWidgets(
    'insights route presents unavailable labels, not sample metrics',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: InsightsScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Not measured'), findsWidgets);
      expect(find.text('70%'), findsNothing);
      expect(find.text('60%'), findsNothing);
      expect(find.textContaining('errors'), findsNothing);
    },
  );
}
