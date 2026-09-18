class ArcadeSession {
  int remaining = 60;
  int round = 1;
  int score = 0;
  bool paused = false;
  bool get roundOver => remaining == 0;
  void elapse(int seconds) {
    if (!paused && !roundOver) remaining = (remaining - seconds).clamp(0, 60);
  }

  void continueRound() {
    if (!roundOver) return;
    remaining = 60;
    round++;
  }

  Map<String, dynamic> toJson() =>
      {'remaining': remaining, 'round': round, 'score': score};
  void restore(Map<String, dynamic> json) {
    remaining = (json['remaining'] as int).clamp(0, 60);
    round = (json['round'] as int).clamp(1, 1000000);
    score = (json['score'] as int).clamp(0, 1000000000);
  }
}
