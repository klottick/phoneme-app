import 'dart:math';
import '../../core/course/course_learning_checkpoint.dart';

class SoundMove {
  const SoundMove(this.accepted, this.points, this.families, this.cascades);
  final bool accepted;
  final int points, cascades;
  final Set<String> families;
}

class SoundMatchEngine {
  SoundMatchEngine({Random? random}) : random = random ?? Random() {
    shuffle();
  }

  SoundMatchEngine.fromState(SoundBoardState state, {required this.random}) {
    if (state.board.any((family) => !families.contains(family))) {
      throw const FormatException('Invalid sound board state');
    }
    board.addAll(state.board);
    stars.addAll(state.stars);
    if (matches().isNotEmpty || legalMoves().isEmpty) {
      throw const FormatException('Sound board is unsettled or unplayable');
    }
  }

  final Random random;
  static const families = ['u', 'y', 'i', 'o'];
  final List<String> board = [];
  final Set<int> stars = {};

  SoundBoardState snapshot() => SoundBoardState(board: board, stars: stars);
  bool adjacent(int a, int b) =>
      a >= 0 &&
      b >= 0 &&
      a < 36 &&
      b < 36 &&
      ((a ~/ 6 - b ~/ 6).abs() + (a % 6 - b % 6).abs() == 1);
  void _exchange(int a, int b) {
    final value = board[a];
    board[a] = board[b];
    board[b] = value;
  }

  Set<int> matches() {
    final result = <int>{};
    for (var i = 0; i < 36; i++) {
      if (i % 6 <= 3 && board[i] == board[i + 1] && board[i] == board[i + 2]) {
        result.addAll([i, i + 1, i + 2]);
      }
      if (i ~/ 6 <= 3 &&
          board[i] == board[i + 6] &&
          board[i] == board[i + 12]) {
        result.addAll([i, i + 6, i + 12]);
      }
    }
    return result;
  }

  List<(int, int)> legalMoves() {
    final result = <(int, int)>[];
    for (var a = 0; a < 36; a++) {
      for (final b in [a + 1, a + 6]) {
        if (!adjacent(a, b)) continue;
        _exchange(a, b);
        if (matches().isNotEmpty) result.add((a, b));
        _exchange(a, b);
      }
    }
    return result;
  }

  Set<String> availableFamilies() {
    final result = <String>{};
    for (final move in legalMoves()) {
      _exchange(move.$1, move.$2);
      result.addAll(matches().map((i) => board[i]));
      _exchange(move.$1, move.$2);
    }
    return result;
  }

  void shuffle() {
    stars.clear();
    do {
      board.clear();
      for (var i = 0; i < 36; i++) {
        final choices = families
            .where((s) =>
                !(i % 6 >= 2 && board[i - 1] == s && board[i - 2] == s) &&
                !(i >= 12 && board[i - 6] == s && board[i - 12] == s))
            .toList();
        board.add(choices[random.nextInt(choices.length)]);
      }
    } while (legalMoves().isEmpty);
  }

  SoundMove swap(int a, int b) {
    if (!adjacent(a, b)) return const SoundMove(false, 0, {}, 0);
    _exchange(a, b);
    var clear = matches();
    if (clear.isEmpty) {
      _exchange(a, b);
      return const SoundMove(false, 0, {}, 0);
    }
    final selectedFamilies = clear.map((i) => board[i]).toSet();
    final aStar = stars.remove(a), bStar = stars.remove(b);
    if (aStar) stars.add(b);
    if (bStar) stars.add(a);
    var points = 0, cascades = 0;
    final earnStar = clear.length >= 4;
    while (clear.isNotEmpty && cascades < 50) {
      cascades++;
      for (final star in stars.intersection(clear).toList()) {
        clear.addAll(List.generate(6, (col) => (star ~/ 6) * 6 + col));
      }
      points += clear.length * 10 * cascades;
      final newStars = <int>{};
      for (var col = 0; col < 6; col++) {
        var dest = 30 + col;
        for (var row = 5; row >= 0; row--) {
          final src = row * 6 + col;
          if (clear.contains(src)) continue;
          board[dest] = board[src];
          if (stars.contains(src)) newStars.add(dest);
          dest -= 6;
        }
        while (dest >= 0) {
          board[dest] = families[random.nextInt(4)];
          dest -= 6;
        }
      }
      stars
        ..clear()
        ..addAll(newStars);
      clear = matches();
    }
    if (clear.isNotEmpty || legalMoves().isEmpty) shuffle();
    if (earnStar) stars.add(b);
    return SoundMove(true, points, selectedFamilies, cascades);
  }

  Map<String, dynamic> toJson() => {'board': board, 'stars': stars.toList()};
  void restore(Map<String, dynamic> json) {
    final saved = List<String>.from(json['board'] as List);
    if (saved.length != 36 || saved.any((s) => !families.contains(s))) {
      throw const FormatException('Invalid sound board');
    }
    board
      ..clear()
      ..addAll(saved);
    stars
      ..clear()
      ..addAll(
          List<int>.from(json['stars'] as List).where((i) => i >= 0 && i < 36));
    if (matches().isNotEmpty || legalMoves().isEmpty) shuffle();
  }
}
