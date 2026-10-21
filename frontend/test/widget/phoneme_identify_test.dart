import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:linguist/src/features/phoneme_id/phoneme_identify_screen.dart';
import 'package:linguist/src/core/models/phoneme.dart';
import 'package:linguist/src/core/providers/app_providers.dart';

List<String> visibleOptions(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(of: find.byType(GridView), matching: find.byType(Text)),
    )
    .map((text) => text.data!)
    .toList();

List<Phoneme> catalogue(List<String> symbols) => [
  for (var index = 0; index < symbols.length; index++)
    Phoneme(
      id: '$index',
      languageCode: 'fr',
      ipaSymbol: symbols[index],
      descriptor: 'word$index',
      difficultyLevel: 1,
    ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PhonemeIdentifyScreen', () {
    testWidgets(
      'offers the correct phoneme exactly once and keeps choices stable',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1;
        final items = catalogue(List.generate(8, (i) => '/p$i/'));
        late StateSetter rebuildParent;
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              rebuildParent = setState;
              return ProviderScope(
                overrides: [
                  phonemesProvider.overrideWith((ref) async => items),
                ],
                child: const MaterialApp(home: PhonemeIdentifyScreen()),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        final initial = visibleOptions(tester);
        expect(initial, hasLength(4));
        expect(initial.toSet(), hasLength(4));
        expect(initial.where((option) => option == '/p0/'), hasLength(1));

        await tester.tap(find.byIcon(Icons.volume_up));
        await tester.pump();
        expect(visibleOptions(tester), initial);
        await tester.tap(find.text(initial.first));
        await tester.pump();
        expect(visibleOptions(tester), initial);
        rebuildParent(() {});
        await tester.pump();
        expect(visibleOptions(tester), initial);
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        final next = visibleOptions(tester);
        expect(next, hasLength(4));
        expect(next.toSet(), hasLength(4));
        expect(next.where((option) => option == '/p1/'), hasLength(1));
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'uses all distinct options when source catalogue is small or duplicated',
      (tester) async {
        for (final symbols in [
          ['/small/'],
          ['/first/', '/first/', '/second/'],
        ]) {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                phonemesProvider.overrideWith(
                  (ref) async => catalogue(symbols),
                ),
              ],
              child: const MaterialApp(home: PhonemeIdentifyScreen()),
            ),
          );
          await tester.pumpAndSettle();
          final options = visibleOptions(tester);
          expect(options, hasLength(symbols.toSet().length));
          expect(options.toSet(), hasLength(options.length));
          expect(
            options.where((option) => option == symbols.first),
            hasLength(1),
          );
        }
      },
    );

    testWidgets('refreshing the catalogue invalidates old choices', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          phonemesProvider.overrideWith(
            (ref) async => catalogue(['/old/', '/old2/', '/old3/', '/old4/']),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PhonemeIdentifyScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(visibleOptions(tester), contains('/old/'));

      container.invalidate(phonemesProvider);
      await tester.pumpAndSettle();
      container.updateOverrides([
        phonemesProvider.overrideWith(
          (ref) async => catalogue(['/new/', '/new2/', '/new3/', '/new4/']),
        ),
      ]);
      container.invalidate(phonemesProvider);
      await tester.pumpAndSettle();
      expect(visibleOptions(tester), contains('/new/'));
      expect(
        visibleOptions(tester).where((option) => option.startsWith('/old')),
        isEmpty,
      );
      container.dispose();
    });

    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: PhonemeIdentifyScreen())),
      );

      await tester.pump();
      expect(find.byType(PhonemeIdentifyScreen), findsOneWidget);
    });

    testWidgets('displays the screen title', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: PhonemeIdentifyScreen())),
      );

      await tester.pump();
      expect(find.text('Phoneme Identification'), findsOneWidget);
    });
  });
}
