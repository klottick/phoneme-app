
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/learning_modes_service.dart';

class ChallengeModeScreen extends ConsumerWidget {
  const ChallengeModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modes = [
      LearningModeConfig.challenge,
      LearningModeConfig.marathon,
      LearningModeConfig.zen,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Learning Modes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Choose Your Practice Mode',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          for (final mode in modes) _ModeCard(config: mode),
        ],
      ),
    );
  }
}

class _ModeCard extends ConsumerWidget {
  final LearningModeConfig config;

  const _ModeCard({required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _getModeColor(config.mode).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _getModeIcon(config.mode),
                  color: _getModeColor(config.mode),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Unavailable — ${config.displayName} practice is not implemented yet.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
              const Text('Unavailable'),
            ],
          ),
        ),
      ),
    );
  }
  IconData _getModeIcon(LearningMode mode) {
    switch (mode) {
      case LearningMode.challenge:
        return Icons.timer;
      case LearningMode.marathon:
        return Icons.directions_run;
      case LearningMode.zen:
        return Icons.self_improvement;
    }
  }

  Color _getModeColor(LearningMode mode) {
    switch (mode) {
      case LearningMode.challenge:
        return Colors.orange;
      case LearningMode.marathon:
        return Colors.blue;
      case LearningMode.zen:
        return Colors.green;
    }
  }
}

class MarathonScreen extends ConsumerStatefulWidget {
  const MarathonScreen({super.key});

  @override
  ConsumerState<MarathonScreen> createState() => _MarathonScreenState();
}

class _MarathonScreenState extends ConsumerState<MarathonScreen> {
  int _currentQuestion = 0;
  final int _correct = 0;
  final int _total = 20;
  bool _onBreak = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marathon Mode'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: _onBreak ? _buildBreakScreen(context) : _buildQuestionScreen(context),
    );
  }

  Widget _buildQuestionScreen(BuildContext context) {
    final progress = _currentQuestion / _total;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 8),
          Text('Question ${_currentQuestion + 1} of $_total'),
          const Spacer(),
          Center(
            child: Text(
              'Keep going!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const Spacer(),
          if (_currentQuestion >= _total)
            FilledButton(
              onPressed: _finishMarathon,
              child: const Text('Finish'),
            )
          else
            FilledButton(
              onPressed: _nextQuestion,
              child: const Text('Next Question'),
            ),
        ],
      ),
    );
  }

  Widget _buildBreakScreen(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.pause_circle, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          Text(
            'Break Time!',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text('You answered $_correct correctly so far'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => setState(() => _onBreak = false),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _nextQuestion() {
    setState(() {
      _currentQuestion++;
      if (_currentQuestion > 0 && _currentQuestion % 10 == 0) {
        _onBreak = true;
      }
    });
  }

  void _finishMarathon() {
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Marathon complete! $_correct / $_total correct')),
    );
  }
}
