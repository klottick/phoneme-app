import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:linguist/src/features/arcade/arcade_screen.dart';
import 'package:linguist/src/features/arcade/sound_match_engine.dart';

class FailablePreferences extends InMemorySharedPreferencesStore {
  FailablePreferences(super.data) : super.withData();
  bool failWrites = false;
  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (failWrites) return Future.value(false);
    return super.setValue(valueType, key, value);
  }
}

void main() {
  for (final failSave in [false, true]) {
    testWidgets('switch games preserves progress with save failure = $failSave',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final board = SoundMatchEngine(random: Random(9));
      const checkpointPreference = 'arcade.v1.en-fr.sound';
      final store = FailablePreferences({
        'flutter.$checkpointPreference': jsonEncode({
          'session': {'remaining': 60, 'round': 2, 'score': 50},
          'board': board.toJson(),
        })
      });
      SharedPreferencesStorePlatform.instance = store;
      addTearDown(() => SharedPreferences.setMockInitialValues({}));
      final router = GoRouter(initialLocation: '/arcade/sound', routes: [
        GoRoute(
            path: '/arcade/sound',
            builder: (_, __) => const ArcadeScreen(silent: false)),
        GoRoute(
            path: '/arcade/word',
            builder: (_, __) => const ArcadeScreen(silent: true)),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume saved board'));
      await tester.pump(const Duration(seconds: 7));
      final move = board.legalMoves().first;
      await tester.tap(find.byKey(ValueKey('sound-tile-${move.$1}')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('sound-tile-${move.$2}')));
      await tester.pump();
      final visibleBoard = List.generate(36, (i) {
        final tile =
            tester.widget<Semantics>(find.byKey(ValueKey('sound-tile-$i')));
        return RegExp(r'Sound /(.*)/ tile')
            .firstMatch(tile.properties.label!)!
            .group(1)!;
      });
      final scoreLabel = tester.widget<Text>(find.textContaining(' pts')).data!;
      final score = int.parse(scoreLabel.split(' ').first);
      expect(score, greaterThan(50));
      store.failWrites = failSave;
      await tester.tap(find.text('Play without audio: Word Match'));
      await tester.pumpAndSettle();
      if (failSave) {
        expect(router.routeInformationProvider.value.uri.path, '/arcade/sound');
        expect(
            find.textContaining('Could not save this round.'), findsOneWidget);
        expect(find.text('Paused'), findsOneWidget);
        store.failWrites = false;
        await tester.tap(find.text('Retry save'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Resume'));
        await tester.pump();
        await tester.tap(find.text('Play without audio: Word Match'));
        await tester.pumpAndSettle();
      }
      expect(router.routeInformationProvider.value.uri.path, '/arcade/word');
      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(prefs.getString(checkpointPreference)!) as Map;
      expect(saved['session'], {'remaining': 53, 'round': 2, 'score': score});
      expect(saved['board']['board'], visibleBoard);
      router.go('/arcade/sound');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume saved board'));
      await tester.pump();
      expect(find.text('Round 2 · 53s'), findsOneWidget);
      expect(find.text('$score pts'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
