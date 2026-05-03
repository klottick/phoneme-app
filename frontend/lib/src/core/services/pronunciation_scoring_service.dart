import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PronunciationScore {
  final double overall;
  final double clarity;
  final double rhythm;
  final double intonation;
  final List<String> feedback;
  final List<PhonemeFeedback> phonemeDetails;
  final ScoreGrade grade;

  const PronunciationScore({
    required this.overall,
    required this.clarity,
    required this.rhythm,
    required this.intonation,
    required this.feedback,
    required this.phonemeDetails,
    required this.grade,
  });

  factory PronunciationScore.empty() => const PronunciationScore(
        overall: 0,
        clarity: 0,
        rhythm: 0,
        intonation: 0,
        feedback: [],
        phonemeDetails: [],
        grade: ScoreGrade.needsWork,
      );
}

class PhonemeFeedback {
  final String phoneme;
  final double score;
  final bool isCorrect;
  final String? suggestion;

  const PhonemeFeedback({
    required this.phoneme,
    required this.score,
    required this.isCorrect,
    this.suggestion,
  });
}

enum ScoreGrade { excellent, good, fair, needsWork }

extension ScoreGradeX on ScoreGrade {
  String get displayName {
    switch (this) {
      case ScoreGrade.excellent:
        return 'Excellent';
      case ScoreGrade.good:
        return 'Good';
      case ScoreGrade.fair:
        return 'Fair';
      case ScoreGrade.needsWork:
        return 'Needs Work';
    }
  }

  Color get color {
    switch (this) {
      case ScoreGrade.excellent:
        return Colors.green;
      case ScoreGrade.good:
        return Colors.lightGreen;
      case ScoreGrade.fair:
        return Colors.orange;
      case ScoreGrade.needsWork:
        return Colors.red;
    }
  }

  String get emoji {
    switch (this) {
      case ScoreGrade.excellent:
        return '🌟';
      case ScoreGrade.good:
        return '😊';
      case ScoreGrade.fair:
        return '🤔';
      case ScoreGrade.needsWork:
        return '💪';
    }
  }
}

class PronunciationAnalyzer {
  static PronunciationScore analyze({
    required List<String> expected,
    required List<String> spoken,
  }) {
    if (expected.isEmpty || spoken.isEmpty) {
      return PronunciationScore.empty();
    }

    final phonemeDetails = <PhonemeFeedback>[];
    final allFeedback = <String>[];

    int matched = 0;
    double totalClarity = 0;
    double totalRhythm = 0;

    for (var i = 0; i < expected.length; i++) {
      final exp = expected[i];
      final spok = i < spoken.length ? spoken[i] : '';
      final isMatch = exp.toLowerCase() == spok.toLowerCase();

      if (isMatch) matched++;

      final phonemeScore = isMatch ? 0.8 + Random().nextDouble() * 0.2 : 0.3 + Random().nextDouble() * 0.3;
      totalClarity += phonemeScore;
      totalRhythm += isMatch ? 0.9 : 0.4;

      String? suggestion;
      if (!isMatch && spok.isNotEmpty) {
        suggestion = _getSuggestion(exp, spok);
        allFeedback.add(suggestion);
      }

      phonemeDetails.add(PhonemeFeedback(
        phoneme: exp,
        score: phonemeScore,
        isCorrect: isMatch,
        suggestion: suggestion,
      ));
    }

    final clarity = expected.isNotEmpty ? totalClarity / expected.length : 0;
    final rhythm = expected.isNotEmpty ? totalRhythm / expected.length : 0;
    final intonation = 0.5 + Random().nextDouble() * 0.3;

    final overall = (clarity * 0.5 + rhythm * 0.3 + intonation * 0.2);
    final grade = _getGrade(overall);

    if (matched == expected.length && expected.length >= 5) {
      allFeedback.insert(0, 'Perfect pronunciation! Keep it up! 🎯');
    } else if (matched > expected.length * 0.7) {
      allFeedback.add('Great progress! You\'re getting the hang of it!');
    } else if (matched > expected.length * 0.4) {
      allFeedback.add('Keep practicing! Focus on the problem sounds.');
    } else {
      allFeedback.add('Try listening to the reference more carefully.');
    }

    if (rhythm < 0.5) {
      allFeedback.add('Work on your speaking rhythm and pacing.');
    }

    if (clarity < 0.5) {
      allFeedback.add('Try to pronounce each sound more clearly.');
    }

    return PronunciationScore(
      overall: overall.toDouble(),
      clarity: clarity.toDouble(),
      rhythm: rhythm.toDouble(),
      intonation: intonation.toDouble(),
      feedback: allFeedback,
      phonemeDetails: phonemeDetails,
      grade: grade,
    );
  }

  static ScoreGrade _getGrade(double score) {
    if (score >= 0.85) return ScoreGrade.excellent;
    if (score >= 0.7) return ScoreGrade.good;
    if (score >= 0.5) return ScoreGrade.fair;
    return ScoreGrade.needsWork;
  }

  static String _getSuggestion(String expected, String spoken) {
    final similarity = _levenshtein(expected.toLowerCase(), spoken.toLowerCase());
    
    if (similarity < 0.3) {
      return 'Heard "$spoken" but expected "$expected"';
    }
    if (expected.contains(spoken) && spoken.isNotEmpty) {
      return 'Missing sound in "$expected"';
    }
    if (spoken.contains(expected) && expected.isNotEmpty) {
      return 'Extra sound in "$spoken"';
    }
    return 'Try to say "$expected" more clearly';
  }

  static double _levenshtein(String a, String b) {
    if (a.isEmpty) return b.isEmpty ? 1 : 0;
    if (b.isEmpty) return 0;

    final matrix = List.generate(a.length + 1, (i) => List.filled(b.length + 1, 0));

    for (var i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = min(
          matrix[i - 1][j] + 1,
          min(matrix[i][j - 1] + 1, matrix[i - 1][j - 1] + cost),
        );
      }
    }

    final maxLen = max(a.length, b.length);
    return maxLen > 0 ? 1 - (matrix[a.length][b.length] / maxLen) : 1.0;
  }
}

class ScoreDisplay extends StatelessWidget {
  final PronunciationScore score;
  final bool showDetails;

  const ScoreDisplay({
    super.key,
    required this.score,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ScoreRing(score: score),
        if (showDetails) ...[
          const SizedBox(height: 24),
          _ScoreBreakdown(score: score),
          if (score.feedback.isNotEmpty) ...[
            const SizedBox(height: 16),
            _FeedbackList(feedback: score.feedback),
          ],
        ],
      ],
    );
  }
}

class _ScoreRing extends StatelessWidget {
  final PronunciationScore score;

  const _ScoreRing({required this.score});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: CircularProgressIndicator(
            value: score.overall,
            strokeWidth: 12,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation(score.grade.color),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${(score.overall * 100).round()}%',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              score.grade.displayName,
              style: TextStyle(
                color: score.grade.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScoreBreakdown extends StatelessWidget {
  final PronunciationScore score;

  const _ScoreBreakdown({required this.score});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ScoreBar(label: 'Clarity', value: score.clarity, color: Colors.blue),
        const SizedBox(height: 8),
        _ScoreBar(label: 'Rhythm', value: score.rhythm, color: Colors.purple),
        const SizedBox(height: 8),
        _ScoreBar(label: 'Intonation', value: score.intonation, color: Colors.teal),
      ],
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _ScoreBar({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(value * 100).round()}%',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _FeedbackList extends StatelessWidget {
  final List<String> feedback;

  const _FeedbackList({required this.feedback});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: feedback.map((f) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb, size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(child: Text(f, style: const TextStyle(fontSize: 13))),
              ],
            ),
          )).toList(),
        ),
      ),
    );
  }
}

final pronunciationAnalyzerProvider = Provider<PronunciationAnalyzer>((ref) {
  return PronunciationAnalyzer();
});