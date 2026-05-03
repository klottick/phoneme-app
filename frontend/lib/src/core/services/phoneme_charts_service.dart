import 'dart:math';

import 'package:flutter/material.dart';

class PhonemeChartData {
  final String phoneme;
  final int correct;
  final int incorrect;
  final double accuracy;
  final int totalAttempts;

  const PhonemeChartData({
    required this.phoneme,
    required this.correct,
    required this.incorrect,
    required this.accuracy,
    required this.totalAttempts,
  });
}

class PhonemeComparisonChart extends StatelessWidget {
  final List<PhonemeChartData> data;
  final bool sortByAccuracy;
  final bool showWorst;

  const PhonemeComparisonChart({
    super.key,
    required this.data,
    this.sortByAccuracy = true,
    this.showWorst = false,
  });

  @override
  Widget build(BuildContext context) {
    var sorted = List<PhonemeChartData>.from(data);
    
    if (sortByAccuracy) {
      sorted.sort((a, b) {
        if (showWorst) {
          return a.accuracy.compareTo(b.accuracy);
        }
        return b.accuracy.compareTo(a.accuracy);
      });
    }

    final displayData = showWorst ? sorted.take(5).toList() : sorted;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              showWorst ? 'Need More Practice' : 'Phoneme Progress',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ...displayData.map((d) => _PhonemeBar(data: d)),
            if (data.length > 5) ...[
              const SizedBox(height: 8),
              Text(
                '${data.length} phonemes total',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhonemeBar extends StatelessWidget {
  final PhonemeChartData data;

  const _PhonemeBar({required this.data});

  @override
  Widget build(BuildContext context) {
    Color barColor;
    if (data.accuracy >= 0.8) {
      barColor = Colors.green;
    } else if (data.accuracy >= 0.6) {
      barColor = Colors.orange;
    } else {
      barColor = Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              data.phoneme,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: data.accuracy,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(barColor),
                minHeight: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              '${(data.accuracy * 100).round()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: barColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PhonemeProgressCard extends StatelessWidget {
  final List<PhonemeChartData> allPhonemes;

  const PhonemeProgressCard({super.key, required this.allPhonemes});

  @override
  Widget build(BuildContext context) {
    final mastered = allPhonemes.where((p) => p.accuracy >= 0.8).length;
    final learning = allPhonemes.where((p) => p.accuracy >= 0.5 && p.accuracy < 0.8).length;
    final needsWork = allPhonemes.where((p) => p.accuracy < 0.5 && p.totalAttempts > 0).length;
    final notStarted = allPhonemes.where((p) => p.totalAttempts == 0).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phoneme Mastery',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MasteryCircle(
                  count: mastered,
                  label: 'Mastered',
                  color: Colors.green,
                ),
                _MasteryCircle(
                  count: learning,
                  label: 'Learning',
                  color: Colors.orange,
                ),
                _MasteryCircle(
                  count: needsWork,
                  label: 'Practice',
                  color: Colors.red,
                ),
                _MasteryCircle(
                  count: notStarted,
                  label: 'Not Tried',
                  color: Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MasteryCircle extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _MasteryCircle({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
          child: Center(
            child: Text(
              '$count',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }
}

class PhonemeHeatmap extends StatelessWidget {
  final Map<String, int> phonemeAttempts;
  
  const PhonemeHeatmap({super.key, required this.phonemeAttempts});

  @override
  Widget build(BuildContext context) {
    final phonemes = phonemeAttempts.keys.toList()..sort();
    final maxAttempts = phonemeAttempts.values.fold(0, max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Practice Heatmap',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: phonemes.map((p) {
                final attempts = phonemeAttempts[p] ?? 0;
                final intensity = maxAttempts > 0 ? attempts / maxAttempts : 0.0;
                return Tooltip(
                  message: '$p: $attempts attempts',
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.2 + intensity * 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        p,
                        style: TextStyle(
                          fontSize: 10,
                          color: intensity > 0.5 ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}