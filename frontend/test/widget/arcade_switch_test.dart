import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_progress.dart';
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

/// Held-cue boundary audio: [speak] stays open until [release] settles it,
/// [stop] only records itself (a compatible implementation may settle
/// after Stop); [cues] retain each request so the test can release the
/// held one — really, with success or the exact engine error — AFTER the
/// navigation that retired it.
final class _HeldCueAudio implements CourseAudio {
  final List<String> spoken = <String>[];
  final List<_HeldCue> cues = <_HeldCue>[];
  int stops = 0;

  @override
  Future<void> speak(String word) {
    spoken.add(word);
    final Completer<Object?> settle = Completer<Object?>();
    final _HeldCue cue = _HeldCue(settle);
    cues.add(cue);
    final Future<void> delivery = settle.future.then((Object? value) {});
    unawaited(delivery.then<void>(
        (Object? value) {}, onError: (Object error) {}));
    return delivery;
  }

  @override
  Future<void> stop() {
    stops++;
    return Future<void>.value();
  }
}

final class _HeldCue {
  _HeldCue(this._settle);

  final Completer<Object?> _settle;

  bool get settled => _settle.isCompleted;

  void release([Object? error]) {
    if (_settle.isCompleted) return;
    if (error == null) {
      _settle.complete();
    } else {
      _settle.completeError(error);
    }
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

  testWidgets(
      'switching to Word Match during a held cue retires the round cleanly '
      'and records no listening evidence', (tester) async {
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
    final audio = _HeldCueAudio();
    await tester.pumpWidget(ProviderScope(
        overrides: [courseAudioProvider.overrideWithValue(audio)],
        child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume saved board'));
    await tester.pump(const Duration(seconds: 12));
    await tester.pump();
    expect(audio.spoken, isNotEmpty,
        reason: 'the cue must reach playback before the switch');
    // Switch away while the cue is still held: the save must land on the
    // captured owner and the round must not arm its bonus.
    await tester.tap(find.text('Play without audio: Word Match'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/arcade/word',
        reason: 'the switch must succeed even with a held cue');
    final prefs = await SharedPreferences.getInstance();
    final saved =
        jsonDecode(prefs.getString(checkpointPreference)!) as Map<String, dynamic>;
    expect(
        (saved['session'] as Map<String, dynamic>)['score'],
        greaterThanOrEqualTo(50),
        reason: 'the round checkpoint must be saved');
    // The held cue settles late — DELIVERED, with a real engine failure —
    // after the navigation retired it: quiet, no evidence, no exception.
    audio.cues[0].release(StateError('late engine failure'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Audio unavailable.'),
      findsNothing,
      reason: 'a navigation-retired cue must not publish failure feedback',
    );
    expect(tester.takeException(), isNull);
    final data = await CourseProgressStore('en-fr').load();
    expect(
      data['evidence'],
      isEmpty,
      reason: 'a navigation-retired cue must not record evidence',
    );
    await tester.pumpWidget(const SizedBox());
  });
}
