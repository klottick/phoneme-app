import 'package:flutter/material.dart';
import '../../core/course/lesson_section_session.dart';

/// Count submissions in the active round, including wrong answers.
///
/// This presentation projection is intended for a session that the caller has
/// already established as acknowledged; the session model keeps its mutable
/// submitted-ID set private.
int completedItemsThisRound(LessonSectionSession session) =>
    session.phase == LessonSectionPhase.debrief
    ? session.queue.length
    : session.position + (session.answered ? 1 : 0);

/// Compact, accessible progress for a finite lesson queue.
///
/// The caller supplies the acknowledged count and current queue length. A
/// missing or non-positive total is intentionally rendered as no progress,
/// rather than a misleading `0/0`.
class LessonProgressIndicator extends StatelessWidget {
  const LessonProgressIndicator({
    super.key,
    required this.completed,
    required this.total,
    this.roundLabel,
  });

  final int completed;
  final int total;
  final String? roundLabel;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();

    final int safeCompleted = completed.clamp(0, total);
    final int remaining = total - safeCompleted;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (roundLabel != null) ...<Widget>[
              Text(roundLabel!, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
            ],
            Text(
              '$safeCompleted/$total completed · $remaining remaining',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: safeCompleted / total,
              minHeight: 6,
              color: colors.primary,
              backgroundColor: colors.surfaceContainerHighest,
              semanticsLabel: roundLabel == null
                  ? 'Lesson progress'
                  : '$roundLabel progress',
            ),
          ],
        ),
      ),
    );
  }
}

/// A centered, width-constrained lesson activity that uses the available
/// viewport and still scrolls when content or accessibility text needs more
/// room.
class LessonContentViewport extends StatelessWidget {
  const LessonContentViewport({
    super.key,
    required this.child,
    this.maxWidth = 640,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 20),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final EdgeInsets resolvedPadding = padding.resolve(
        Directionality.of(context),
      );
      final double minimumHeight =
          (constraints.maxHeight - resolvedPadding.vertical).clamp(
            0,
            double.infinity,
          );
      return SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minimumHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}
