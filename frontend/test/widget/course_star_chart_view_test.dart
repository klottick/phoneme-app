import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/features/course_map/course_star_chart_view.dart';
import 'package:linguist/src/features/course_map/french_space_map.dart';

void main() {
  testWidgets('chart_planned_system_has_no_launch', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CourseStarChartView(
            systems: frenchSpaceSystems,
            onOpenSystem: opened.add,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Nasal vowels'));
    expect(opened, isEmpty);
    expect(
      find.textContaining('Planned sound system: French nasal vowels'),
      findsWidgets,
    );
    expect(find.textContaining('Coming soon'), findsWidgets);
    expect(find.textContaining('Start'), findsNothing);
  });

  testWidgets('chart_surfaces_and_copy_remain_readable_at_phone_text_scales', (
    tester,
  ) async {
    for (final size in [const Size(390, 844), const Size(360, 640)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      for (final scale in [2.0, 3.0]) {
        for (final theme in [ThemeData.light(), ThemeData.dark()]) {
          final opened = <String>[];
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                backgroundColor: theme.scaffoldBackgroundColor,
                body: CourseStarChartView(
                  key: ValueKey(
                    'chart-${size.width}-$scale-${theme.brightness}',
                  ),
                  systems: frenchSpaceSystems,
                  onOpenSystem: opened.add,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$size at $scale');

          Future<void> reveal(
            Finder target, {
            double direction = -180,
            bool full = true,
          }) async {
            final scrollable = tester.state<ScrollableState>(
              find
                  .descendant(
                    of: find.byType(ListView),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            if (target.evaluate().isEmpty) {
              scrollable.position.jumpTo(
                direction > 0
                    ? scrollable.position.minScrollExtent
                    : scrollable.position.maxScrollExtent,
              );
              await tester.pumpAndSettle();
            }
            expect(target, findsOneWidget);
            for (var attempt = 0; attempt < 4; attempt++) {
              final rect = tester.getRect(target);
              if (full
                  ? rect.top >= 0 && rect.bottom <= size.height
                  : rect.bottom > 0 && rect.top < size.height) {
                return;
              }
              final delta = rect.center.dy - size.height / 2;
              scrollable.position.jumpTo(
                (scrollable.position.pixels + delta).clamp(
                  scrollable.position.minScrollExtent,
                  scrollable.position.maxScrollExtent,
                ),
              );
              await tester.pumpAndSettle();
            }
            final rect = tester.getRect(target);
            if (full) {
              expect(rect.top, greaterThanOrEqualTo(0));
              expect(rect.bottom, lessThanOrEqualTo(size.height));
            } else {
              expect(rect.bottom, greaterThan(0));
              expect(rect.top, lessThan(size.height));
            }
          }

          final chartTitle = find.text('Star chart');
          final titleRect = tester.getRect(chartTitle);
          expect(titleRect.top, greaterThanOrEqualTo(0));
          expect(titleRect.bottom, lessThanOrEqualTo(size.height));
          expect(
            _contrast(
              _textColor(tester, chartTitle, theme),
              theme.scaffoldBackgroundColor,
            ),
            greaterThanOrEqualTo(4.5),
            reason: 'chart title at $size scale $scale ${theme.brightness}',
          );

          for (final system in frenchSpaceSystems) {
            final title = find.text(system.title);
            final cardFinder = find.ancestor(
              of: title,
              matching: find.byType(Card),
            );
            await tester.scrollUntilVisible(
              title,
              120,
              scrollable: find.byType(Scrollable).first,
            );
            await Scrollable.ensureVisible(
              tester.element(title),
              alignment: .2,
            );
            await tester.pumpAndSettle();
            final systemTitleRect = tester.getRect(title);
            expect(systemTitleRect.top, greaterThanOrEqualTo(0));
            expect(systemTitleRect.bottom, lessThanOrEqualTo(size.height));
            final card = tester.widget<Card>(cardFinder);
            final surface = card.color ?? theme.cardColor;
            expect(tester.getRect(cardFinder).height, greaterThanOrEqualTo(48));
            expect(
              _contrast(_textColor(tester, title, theme), surface),
              greaterThanOrEqualTo(4.5),
              reason:
                  '${system.title} at $size scale $scale ${theme.brightness}',
            );
            final description = find.textContaining(system.description).first;
            expect(
              _contrast(_textColor(tester, description, theme), surface),
              greaterThanOrEqualTo(4.5),
              reason:
                  '${system.title} description at $size scale $scale ${theme.brightness}',
            );
          }

          final live = frenchSpaceSystems.first;
          final liveTitle = find.text(live.title);
          await reveal(liveTitle, direction: 300);
          final liveDescription = find.textContaining(live.description).first;
          await reveal(liveDescription, direction: 300, full: false);
          expect(liveDescription, findsOneWidget);
          await tester.tap(liveTitle);
          expect(opened, contains(live.id));

          final planned = frenchSpaceSystems[1];
          final plannedTitle = find.text(planned.title);
          await reveal(plannedTitle);
          await tester.tap(plannedTitle);
          await tester.pumpAndSettle();
          expect(opened, contains(live.id));
          final plannedDescription = find
              .textContaining(planned.description)
              .last;
          await reveal(plannedDescription, full: false);
          expect(plannedDescription, findsOneWidget);
          final detailCard = tester.widget<Card>(
            find.ancestor(of: plannedDescription, matching: find.byType(Card)),
          );
          final detailSurface = detailCard.color ?? theme.cardColor;
          expect(
            _contrast(
              _textColor(tester, plannedDescription, theme),
              detailSurface,
            ),
            greaterThanOrEqualTo(4.5),
          );
          expect(tester.takeException(), isNull, reason: '$size at $scale');
        }
      }
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}

Color _textColor(WidgetTester tester, Finder finder, ThemeData theme) {
  final element = tester.element(finder);
  final text = tester.widget<Text>(finder);
  return DefaultTextStyle.of(element).style.merge(text.style).color ??
      theme.colorScheme.onSurface;
}

double _contrast(Color foreground, Color background) {
  final light = foreground.computeLuminance();
  final dark = background.computeLuminance();
  return (light > dark ? light + .05 : dark + .05) /
      (light > dark ? dark + .05 : light + .05);
}
