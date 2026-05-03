import 'dart:math';

import 'package:flutter/material.dart';

class SoundWaveVisualizer extends StatefulWidget {
  final bool isActive;
  final int barCount;
  final double height;

  const SoundWaveVisualizer({
    super.key,
    this.isActive = false,
    this.barCount = 20,
    this.height = 100,
  });

  @override
  State<SoundWaveVisualizer> createState() => _SoundWaveVisualizerState();
}

class _SoundWaveVisualizerState extends State<SoundWaveVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SoundWaveVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          height: widget.height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.barCount, (index) {
              final random = Random(index);
              final baseHeight = widget.height * 0.3;
              final variation = widget.height * 0.7;
              
              double barHeight;
              if (widget.isActive) {
                final phase = (index / widget.barCount) * pi;
                final wave = sin(_controller.value * 2 * pi + phase);
                barHeight = baseHeight + (variation * (0.3 + 0.7 * wave.abs()) * random.nextDouble());
              } else {
                barHeight = baseHeight * 0.5;
              }

              return AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 4,
                height: barHeight,
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.3 + (barHeight / widget.height) * 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class AudioVisualizerScreen extends StatefulWidget {
  const AudioVisualizerScreen({super.key});

  @override
  State<AudioVisualizerScreen> createState() => _AudioVisualizerScreenState();
}

class _AudioVisualizerScreenState extends State<AudioVisualizerScreen> {
  bool _isRecording = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Visualizer')),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SoundWaveVisualizer(
              isActive: _isRecording,
              barCount: 30,
              height: 150,
            ),
            const SizedBox(height: 48),
            FloatingActionButton.large(
              onPressed: () => setState(() => _isRecording = !_isRecording),
              backgroundColor: _isRecording ? Colors.red : Colors.teal,
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isRecording ? 'Recording...' : 'Tap to test visualizer',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class PulsingCircle extends StatefulWidget {
  final bool isActive;
  final Color color;
  final double size;

  const PulsingCircle({
    super.key,
    this.isActive = false,
    this.color = Colors.teal,
    this.size = 100,
  });

  @override
  State<PulsingCircle> createState() => _PulsingCircleState();
}

class _PulsingCircleState extends State<PulsingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulsingCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.3 + _controller.value * 0.3),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.5 + _controller.value * 0.5),
              width: 3,
            ),
          ),
        );
      },
    );
  }
}