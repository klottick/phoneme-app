import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LearningMode {
  challenge,
  marathon,
  zen,
}

class LearningModeConfig {
  final LearningMode mode;
  final int targetCount;
  final int timeLimit;
  final bool showTimer;
  final bool shuffleQuestions;
  final bool trackStreak;

  const LearningModeConfig({
    required this.mode,
    this.targetCount = 10,
    this.timeLimit = 0,
    this.showTimer = false,
    this.shuffleQuestions = true,
    this.trackStreak = true,
  });

  String get displayName {
    switch (mode) {
      case LearningMode.challenge:
        return 'Challenge';
      case LearningMode.marathon:
        return 'Marathon';
      case LearningMode.zen:
        return 'Zen';
    }
  }

  String get description {
    switch (mode) {
      case LearningMode.challenge:
        return 'Timed challenge - beat your best score!';
      case LearningMode.marathon:
        return 'Answer $targetCount questions without breaks';
      case LearningMode.zen:
        return 'Relaxed practice at your own pace';
    }
  }

  static const challenge = LearningModeConfig(
    mode: LearningMode.challenge,
    showTimer: true,
    trackStreak: true,
  );

  static const marathon = LearningModeConfig(
    mode: LearningMode.marathon,
    targetCount: 20,
    shuffleQuestions: true,
    trackStreak: true,
  );

  static const zen = LearningModeConfig(
    mode: LearningMode.zen,
    showTimer: false,
    trackStreak: false,
    shuffleQuestions: false,
  );
}

class ChallengeState {
  final LearningMode mode;
  final int totalQuestions;
  final int correctAnswers;
  final int currentIndex;
  final int streakCount;
  final int timeRemaining;
  final bool isComplete;
  final int highScore;

  const ChallengeState({
    required this.mode,
    this.totalQuestions = 0,
    this.correctAnswers = 0,
    this.currentIndex = 0,
    this.streakCount = 0,
    this.timeRemaining = 60,
    this.isComplete = false,
    this.highScore = 0,
  });

  double get accuracy => totalQuestions > 0 ? correctAnswers / totalQuestions : 0;
  int get score => (correctAnswers * 100 + streakCount * 10).round();

  ChallengeState copyWith({
    LearningMode? mode,
    int? totalQuestions,
    int? correctAnswers,
    int? currentIndex,
    int? streakCount,
    int? timeRemaining,
    bool? isComplete,
    int? highScore,
  }) {
    return ChallengeState(
      mode: mode ?? this.mode,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      currentIndex: currentIndex ?? this.currentIndex,
      streakCount: streakCount ?? this.streakCount,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      isComplete: isComplete ?? this.isComplete,
      highScore: highScore ?? this.highScore,
    );
  }
}

class ChallengeNotifier extends StateNotifier<ChallengeState> {
  Timer? _timer;
  Timer? _countdown;

  ChallengeNotifier() : super(const ChallengeState(mode: LearningMode.challenge));

  void startChallenge(LearningMode mode, int questionCount, int timeLimit) {
    _timer?.cancel();
    _countdown?.cancel();

    state = ChallengeState(
      mode: mode,
      totalQuestions: mode == LearningMode.zen ? 999999 : questionCount,
      timeRemaining: timeLimit,
    );

    if (mode != LearningMode.zen && timeLimit > 0) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.timeRemaining <= 0) {
        _endChallenge();
      } else {
        state = state.copyWith(timeRemaining: state.timeRemaining - 1);
      }
    });
  }

  void updateQuestion(bool wasCorrect) {
    if (state.isComplete) return;

    final newStreak = wasCorrect ? state.streakCount + 1 : 0;
    final newCorrect = wasCorrect ? state.correctAnswers + 1 : state.correctAnswers;
    final newIndex = state.currentIndex + 1;

    final isComplete = state.mode != LearningMode.zen && 
        (newIndex >= state.totalQuestions || state.timeRemaining <= 0);

    if (isComplete) {
      _endChallenge();
    } else {
      state = state.copyWith(
        correctAnswers: newCorrect,
        currentIndex: newIndex,
        streakCount: newStreak,
      );
    }
  }

  void _endChallenge() {
    _timer?.cancel();
    _countdown?.cancel();
    
    final newHighScore = state.score > state.highScore ? state.score : state.highScore;
    state = state.copyWith(
      isComplete: true,
      highScore: newHighScore,
    );
  }

  void reset() {
    _timer?.cancel();
    _countdown?.cancel();
    state = const ChallengeState(mode: LearningMode.challenge);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdown?.cancel();
    super.dispose();
  }
}

class MarathonConfig {
  final int targetQuestions;
  final int breakEvery;
  final Duration? breakDuration;

  const MarathonConfig({
    this.targetQuestions = 20,
    this.breakEvery = 10,
    this.breakDuration = const Duration(minutes: 1),
  });
}

class ZenModeSession {
  final int questionsAnswered;
  final int correct;
  final Duration totalTime;
  final DateTime startTime;

  const ZenModeSession({
    this.questionsAnswered = 0,
    this.correct = 0,
    this.totalTime = Duration.zero,
    required this.startTime,
  });

  double get accuracy => questionsAnswered > 0 ? correct / questionsAnswered : 0;
  Duration get avgTime => questionsAnswered > 0 
      ? Duration(milliseconds: totalTime.inMilliseconds ~/ questionsAnswered) 
      : Duration.zero;
}

final challengeProvider = StateNotifierProvider<ChallengeNotifier, ChallengeState>((ref) {
  return ChallengeNotifier();
});

final currentModeProvider = StateProvider<LearningMode>((ref) => LearningMode.challenge);

final marathonConfigProvider = Provider<MarathonConfig>((ref) => const MarathonConfig());

final zenSessionProvider = StateProvider<ZenModeSession?>((ref) => null);