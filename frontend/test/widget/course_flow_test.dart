import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:linguist/src/app.dart';
import 'package:linguist/src/features/arcade/arcade_screen.dart';
import 'package:linguist/src/features/arcade/sound_match_engine.dart';
import 'package:linguist/src/features/arcade/word_match_engine.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_progress.dart';
import 'package:linguist/src/features/course/course_lesson_screen.dart';

class TestFrenchAudio implements CourseAudio {
  TestFrenchAudio({this.fail = false});
  final bool fail;
  int calls = 0;
  @override
  Future<void> speak(String word) async {
    calls++;
    if (fail) throw StateError('Audio unavailable');
  }

  @override
  Future<void> stop() async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('onboard into a directional course and open silent arcade',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LinguistApp()));
    await tester.pumpAndSettle();
    expect(find.text('I speak English'), findsOneWidget);
    await tester.tap(find.text('Start English → French'));
    await tester.pumpAndSettle();
    expect(find.text('French for English speakers'), findsOneWidget);
    await tester.tap(find.text('Play for a minute'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Word Match'));
    await tester.pumpAndSettle();
    expect(find.text('No audio needed'), findsOneWidget);
    await tester.tap(find.text('Start 60-second round'));
    await tester.pump();
    expect(find.textContaining('Connect words containing'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('silent game ends at a minute and continues the same score',
      (tester) async {
    final audio = TestFrenchAudio(fail: true);
    await tester.pumpWidget(ProviderScope(
        overrides: [courseAudioProvider.overrideWithValue(audio)],
        child: const MaterialApp(home: ArcadeScreen(silent: true))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start 60-second round'));
    await tester.pump(const Duration(seconds: 60));
    await tester.pumpAndSettle();
    expect(find.text('Round complete'), findsOneWidget);
    await tester.tap(find.text('Continue this board'));
    await tester.pump();
    expect(find.textContaining('Round 2'), findsOneWidget);
    expect(audio.calls, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed sound cue never records an incorrect listening answer',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final board = SoundMatchEngine(random: Random(9));
    SharedPreferences.setMockInitialValues({
      'arcade.v1.en-fr.sound': jsonEncode({
        'session': {'remaining': 60, 'round': 1, 'score': 0},
        'board': board.toJson(),
      })
    });
    await tester.pumpWidget(ProviderScope(overrides: [
      courseAudioProvider.overrideWithValue(TestFrenchAudio(fail: true))
    ], child: const MaterialApp(home: ArcadeScreen(silent: false))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Resume saved board'), 200);
    await tester.tap(find.text('Resume saved board'));
    await tester.pump(const Duration(seconds: 12));
    await tester.pumpAndSettle();
    expect(find.textContaining('Audio unavailable.'), findsOneWidget);
    final move = board.legalMoves().first;
    await tester.tap(find.byKey(ValueKey('sound-tile-${move.$1}')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('sound-tile-${move.$2}')));
    await tester.pump();
    expect(find.text('0 pts'), findsNothing);
    expect((await CourseProgressStore('en-fr').load())['evidence'], isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('lesson completion records real answers and advances the path',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [courseAudioProvider.overrideWithValue(TestFrenchAudio())],
        child: const MaterialApp(
            home: CourseLessonScreen(lessonId: 'en-fr-vowels'))));
    var step = 0;
    for (final sound in ['i', 'o', 'i', 'o']) {
      await tester.scrollUntilVisible(find.text('Listen to French word'), -200);
      await tester.tap(find.text('Listen to French word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/$sound/'));
      await tester.pumpAndSettle();
      step++;
      await tester.scrollUntilVisible(
          find.text(step == 4 ? 'Finish' : 'Next word'), 200);
      if (step == 4) {
        await tester.tap(find.text('Finish'));
      } else {
        await tester.tap(find.text('Next word'));
      }
      await tester.pumpAndSettle();
    }
    final data = await CourseProgressStore('en-fr').load();
    expect(data['lessons'], contains('en-fr-vowels'), reason: data.toString());
    expect(data['evidence']['listening:i']['correct'], 2);
    expect(data['evidence']['listening:o']['correct'], 2);
  });

  testWidgets('backgrounding pauses the game until explicitly resumed',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: ArcadeScreen(silent: true))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start 60-second round'));
    await tester.pump(const Duration(seconds: 10));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 80));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Paused'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pump();
    expect(find.text('Round 1 · 50s'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'dragging a word chain clears tiles and records only selected words',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final board = WordMatchEngine(random: Random(3));
    board.board.setRange(0, 4, ['tout', 'rouge', 'vous', 'tu']);
    board.stars.add(0);
    SharedPreferences.setMockInitialValues({
      'arcade.v1.en-fr.word': jsonEncode({
        'session': {'remaining': 60, 'round': 1, 'score': 0},
        'board': board.toJson(),
      })
    });
    final audio = TestFrenchAudio(fail: true);
    await tester.pumpWidget(ProviderScope(
        overrides: [courseAudioProvider.overrideWithValue(audio)],
        child: const MaterialApp(home: ArcadeScreen(silent: true))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume saved board'));
    await tester.pump();
    final start = tester.getCenter(find.byKey(const ValueKey('word-tile-0')));
    final gesture = await tester.startGesture(start);
    // Cross the touch-slop threshold inside the first tile before linking others.
    await gesture.moveTo(start + const Offset(22, 0));
    await tester.pump();
    for (final i in [1, 2]) {
      await gesture
          .moveTo(tester.getCenter(find.byKey(ValueKey('word-tile-$i'))));
      await tester.pump();
    }
    expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .where((t) => t?.startsWith('Link ') ?? false),
        contains('Link 3 words'));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('0 pts'), findsNothing);
    final data = await CourseProgressStore('en-fr').load();
    expect(data['evidence']['spelling:u']['attempts'], 3);
    expect(data['evidence']['spelling:u']['correct'], 3);
    expect(data['evidence']['listening:u'], isNull);
    expect(audio.calls, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
