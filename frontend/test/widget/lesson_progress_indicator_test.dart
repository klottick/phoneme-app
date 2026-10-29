import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsData;
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/features/course/lesson_progress_indicator.dart';

void main() {
  testWidgets('lesson progress exposes a numeric accessible range', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LessonProgressIndicator(completed: 1, total: 10)),
      ),
    );

    expect(find.text('1/10 completed · 9 remaining'), findsOneWidget);
    final SemanticsData data = tester
        .getSemantics(find.byType(LinearProgressIndicator))
        .getSemanticsData();
    expect(data.label, 'Lesson progress');
    expect(data.value, '10');
    expect(data.minValue, '0');
    expect(data.maxValue, '100');
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
