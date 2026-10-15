import 'dart:math';
import '../../core/course/french_course.dart';
import '../../core/course/course_learning_checkpoint.dart';

class WordMove {
  const WordMove(this.accepted, this.points, this.evidence, this.message);
  final bool accepted;
  final int points;
  final List<(String, bool)> evidence;
  final String message;
}

class WordMatchEngine {
  WordMatchEngine({Random? random}) : random = random ?? Random() {
    refill();
  }

  WordMatchEngine.fromState(WordBoardState state, {required this.random})
      : target = state.target,
        moves = state.moves,
        combo = state.combo {
    if (!targets.contains(state.target) ||
        state.moves % 4 == 0 &&
            state.target != targets[(state.moves ~/ 4) % 2] ||
        state.moves % 4 != 0 &&
            state.target !=
                targets[((state.moves - state.moves % 4) ~/ 4) % 2] ||
        state.combo > state.moves ||
        state.obstacles.isEmpty ||
        state.obstacles.length > 2 ||
        state.board
            .any((word) => !pool.any((candidate) => candidate.text == word)) ||
        state.stars.intersection(state.obstacles).isNotEmpty) {
      throw const FormatException('Invalid word board state');
    }
    board.addAll(state.board);
    stars.addAll(state.stars);
    obstacles
      ..clear()
      ..addAll(state.obstacles);
    if (findChain().isEmpty) {
      throw const FormatException('Word board has no valid chain');
    }
  }
  final Random random;
  final List<String> board = [];
  String target = 'u';
  int moves = 0;
  int combo = 0;
  final Set<int> stars = {};
  final Set<int> obstacles = {5, 10};
  static const targets = ['u', 'y'];
  List<CourseWord> get pool =>
      frenchWords.where((w) => targets.any(w.contains)).toList();

  WordBoardState snapshot() => WordBoardState(
        board: board,
        target: target,
        moves: moves,
        combo: combo,
        stars: stars,
        obstacles: obstacles,
      );

  bool adjacent(int a, int b) =>
      a != b &&
      ((a ~/ 4) - (b ~/ 4)).abs() <= 1 &&
      ((a % 4) - (b % 4)).abs() <= 1;

  List<int> findChain() {
    List<int> visit(List<int> path) {
      if (path.length >= 3) return path;
      for (var next = 0; next < 16; next++) {
        if (!path.contains(next) &&
            adjacent(path.last, next) &&
            wordByText(board[next]).contains(target)) {
          final found = visit([...path, next]);
          if (found.isNotEmpty) return found;
        }
      }
      return [];
    }

    for (var i = 0; i < board.length; i++) {
      if (wordByText(board[i]).contains(target)) {
        final found = visit([i]);
        if (found.isNotEmpty) return found;
      }
    }
    return [];
  }

  void refill() {
    final words = pool;
    while (board.length < 16) {
      board.add(words[random.nextInt(words.length)].text);
    }
    if (findChain().isEmpty) {
      final matches = words.where((w) => w.contains(target)).toList()
        ..shuffle(random);
      for (var i = 0; i < 3; i++) {
        board[i] = matches[i].text;
      }
    }
  }

  WordMove submit(List<int> chain) {
    if (chain.length < 3 ||
        chain.toSet().length != chain.length ||
        chain.any((i) => i < 0 || i >= 16)) {
      return const WordMove(
          false, 0, [], 'Connect at least three different tiles.');
    }
    for (var i = 1; i < chain.length; i++) {
      if (!adjacent(chain[i - 1], chain[i])) {
        return const WordMove(false, 0, [], 'Connect neighboring tiles.');
      }
    }
    final evidence = chain
        .map((i) => (target, wordByText(board[i]).contains(target)))
        .toList();
    if (evidence.any((e) => !e.$2)) {
      combo = 0;
      final wrong = wordByText(board[
          chain.firstWhere((i) => !wordByText(board[i]).contains(target))]);
      return WordMove(false, 0, evidence,
          '${wrong.text} is /${wrong.ipa}/, without /$target/. Try another chain.');
    }
    combo++;
    final clear = chain.toSet();
    // Star tiles clear a row. Automatic clears never create learning evidence.
    for (final i in chain.where(stars.contains)) {
      clear.addAll(List.generate(4, (column) => (i ~/ 4) * 4 + column));
    }
    final broken = obstacles.intersection(clear).length;
    obstacles.removeAll(clear);
    stars.removeAll(clear);
    final points = clear.length * 10 * combo.clamp(1, 5) + broken * 50;
    // Collapse each column while retaining the positions of surviving specials.
    final newStars = <int>{};
    final newObstacles = <int>{};
    final words = pool;
    for (var col = 0; col < 4; col++) {
      var dest = 12 + col;
      for (var row = 3; row >= 0; row--) {
        final src = row * 4 + col;
        if (clear.contains(src)) continue;
        board[dest] = board[src];
        if (stars.contains(src)) newStars.add(dest);
        if (obstacles.contains(src)) newObstacles.add(dest);
        dest -= 4;
      }
      while (dest >= 0) {
        board[dest] = words[random.nextInt(words.length)].text;
        dest -= 4;
      }
    }
    stars
      ..clear()
      ..addAll(newStars);
    obstacles
      ..clear()
      ..addAll(newObstacles);
    if (chain.length >= 5) stars.add(chain.first);
    moves++;
    if (moves % 4 == 0) target = targets[(moves ~/ 4) % targets.length];
    if (obstacles.isEmpty) {
      obstacles.addAll({random.nextInt(16), random.nextInt(16)});
    }
    refill();
    return WordMove(
        true,
        points,
        evidence,
        chain.length >= 5
            ? 'Star earned! Include it to clear a row.'
            : 'Chain ×$combo! +$points');
  }

  Map<String, dynamic> toJson() => {
        'board': board,
        'target': target,
        'moves': moves,
        'combo': combo,
        'stars': stars.toList(),
        'obstacles': obstacles.toList()
      };
  void restore(Map<String, dynamic> json) {
    final saved = List<String>.from(json['board'] as List);
    if (saved.length != 16 ||
        saved.any((w) => !pool.any((p) => p.text == w)) ||
        !targets.contains(json['target'])) {
      throw const FormatException('Invalid word board');
    }
    board
      ..clear()
      ..addAll(saved);
    target = json['target'] as String;
    moves = json['moves'] as int;
    combo = json['combo'] as int;
    stars
      ..clear()
      ..addAll(
          List<int>.from(json['stars'] as List).where((i) => i >= 0 && i < 16));
    obstacles
      ..clear()
      ..addAll(List<int>.from(json['obstacles'] as List)
          .where((i) => i >= 0 && i < 16));
    refill();
  }
}
