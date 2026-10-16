import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/course/backend.dart';
import '../../core/course/course_attempt.dart';
import '../../core/course/course_learning_providers.dart';
import '../../core/course/course_learning_registry.dart';
import '../../core/course/course_learning_state.dart';
import '../../core/course/course_learning_sync.dart';
import '../../core/course/course_skill_summary.dart';
import '../../core/course/french_course.dart';

class CourseProgressScreen extends ConsumerStatefulWidget {
  const CourseProgressScreen({super.key, this.review = false});
  final bool review;

  @override
  ConsumerState<CourseProgressScreen> createState() =>
      _CourseProgressScreenState();
}

class _CourseProgressScreenState extends ConsumerState<CourseProgressScreen> {
  bool _retryingLoad = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(courseLearningStoreProvider, (previous, next) {
      if (!identical(previous, next) && mounted && _retryingLoad) {
        setState(() => _retryingLoad = false);
      }
    });
  }

  Future<void> _retryLoad() async {
    if (_retryingLoad) return;
    final store = ref.read(courseLearningStoreProvider);
    setState(() => _retryingLoad = true);
    try {
      await store.retryLoad();
      if (!mounted ||
          !identical(store, ref.read(courseLearningStoreProvider))) {
        return;
      }
      ref.invalidate(courseLearningStateProvider);
    } catch (_) {
      // Keep the unavailable state and leave an explicit retry available.
    } finally {
      if (mounted) setState(() => _retryingLoad = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(courseLearningStateProvider);
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.review ? 'Review sounds' : 'Course progress')),
      body: progress.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: TextButton(
            onPressed: _retryingLoad ? null : _retryLoad,
            child: Text(_retryingLoad ? 'Retrying…' : 'Retry loading progress'),
          ),
        ),
        data: (state) => _ProgressContent(
          state: state,
          review: widget.review,
          registry: ref.watch(learningRegistryProvider),
          sync: () => ref.read(courseLearningStoreProvider).sync(),
        ),
      ),
    );
  }
}

class _ProgressContent extends StatelessWidget {
  const _ProgressContent({
    required this.state,
    required this.review,
    required this.registry,
    required this.sync,
  });

  final CourseLearningState state;
  final bool review;
  final LearningRegistry registry;
  final Future<SupportedSyncResult> Function() sync;

  @override
  Widget build(BuildContext context) {
    final currentRevisions = {
      for (final lesson in frenchLessons)
        lesson.id: registry.require('lesson:${lesson.id}').contentRevision,
    };
    final completed = state.completions
        .where((completion) =>
            currentRevisions[completion.lessonId] == completion.contentRevision)
        .map((completion) => completion.lessonId)
        .toSet();
    final summaries = state.summaries.entries.toList()
      ..sort((a, b) {
        final keyA = a.key;
        final keyB = b.key;
        final bySound = keyA.sound.compareTo(keyB.sound);
        if (bySound != 0) return bySound;
        final bySkill = keyA.skill.index.compareTo(keyB.skill.index);
        if (bySkill != 0) return bySkill;
        final byOrigin = keyA.origin.index.compareTo(keyB.origin.index);
        if (byOrigin != 0) return byOrigin;
        return keyA.presentation.index.compareTo(keyB.presentation.index);
      });
    final mistakes = state.mistakes.values.toList()
      ..sort((a, b) => a.key.targetSound.compareTo(b.key.targetSound));

    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(frenchCourse.title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      Text('${completed.length}/${frenchLessons.length} lessons complete'),
      const Text(
          'On this device, committed practice and game answers are shown separately.'),
      const Text(
          'This alpha uses a new progress format. Earlier development progress has not been imported.'),
      if (courseBackend?.auth.currentUser != null)
        TextButton.icon(
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text('Sync supported progress'),
          onPressed: () async {
            final result = await sync();
            if (!context.mounted) return;
            final message = result.status == SupportedSyncStatus.synced
                ? 'Supported scores and answer totals backed up. Detailed history, mistakes and lesson resume stay on this device.'
                : 'Supported backup pending. Local commits remain saved on this device. Earlier server totals were not reset or imported.';
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(message)));
          },
        ),
      const Text(
          'Supported backup covers scores and answer totals. Detailed history, mistakes and lesson resume stay on this device.'),
      if (state.pending.isNotEmpty)
        const Text(
            'Offline: supported backup is pending; local commits remain saved on this device.'),
      const Text('Earlier server totals were not reset or imported.'),
      const SizedBox(height: 16),
      if (review) ...[
        const Text('Unresolved sounds'),
        if (mistakes.isEmpty)
          const Text(
              'No unresolved sounds right now. Practice a lesson or play a round.'),
        for (final mistake in mistakes) _mistakeTile(context, mistake),
      ] else ...[
        const Text('Practice and game evidence'),
        if (summaries.isEmpty)
          const Text('Your first answers will appear here.'),
        for (final entry in summaries)
          _summaryTile(context, entry.key, entry.value),
        const SizedBox(height: 16),
        const Text('Recent local answers'),
        if (state.history.isEmpty) const Text('No local answer history yet.'),
        for (final batch in state.history.reversed)
          for (final attempt in batch.attempts.reversed)
            Card(
              child: ListTile(
                title: Text(
                    '${attempt.correct ? 'Correct' : 'Incorrect'} · ${attempt.itemId}'),
                subtitle: Text(
                    '${attempt.origin == AttemptOrigin.practice ? 'Practice' : 'Game'} · '
                    '${attempt.presentation == AttemptPresentation.firstInRun ? 'first' : 'repeat'} presentation · '
                    '${attempt.assistance.isEmpty ? 'no tracked assistance' : 'assisted'} · '
                    '${attempt.contentState.name} · audio: ${attempt.audioSource.name}'),
              ),
            ),
        const SizedBox(height: 16),
        const Text('Speaking: not assessed'),
        const Text('Pronunciation assessment: not assessed'),
        const SizedBox(height: 12),
        const Text('Arcade best scores — separate from sound accuracy'),
        Text('Sound Match: ${state.bestScores['sound'] ?? 0}'),
        Text('Word Match: ${state.bestScores['word'] ?? 0}'),
      ],
    ]);
  }

  Widget _summaryTile(BuildContext context, SummaryKey key, SkillCount count) {
    final assistance = key.assistance.isEmpty
        ? 'unassisted in-app'
        : 'assisted: ${key.assistance.map(_assistanceLabel).join(', ')}';
    final origin = key.origin == AttemptOrigin.practice ? 'Practice' : 'Game';
    final presentation = key.presentation == AttemptPresentation.firstInRun
        ? 'first presentation'
        : 'repeat presentation';
    final skill =
        key.skill == LearningSkill.listening ? 'Listening' : 'Sound–spelling';
    final answerLabel = count.total == 1 ? 'answer' : 'answers';
    return Card(
      child: ListTile(
        title: Text('/${key.sound}/ · $skill'),
        subtitle: Text('$origin · $presentation · $assistance\n'
            '${count.correct} correct / ${count.total} $answerLabel · sample size ${count.total}\n'
            '${key.skill == LearningSkill.listening ? 'Audio source: pending recording' : 'Audio source: not applicable'}'),
        isThreeLine: true,
        trailing: const Icon(Icons.play_arrow),
        onTap: () => _openSound(context, key.sound, key.skill),
      ),
    );
  }

  Widget _mistakeTile(BuildContext context, LearningMistake mistake) {
    final key = mistake.key;
    final definition = registry.activities
        .where((activity) => activity.id == key.activityId)
        .firstOrNull;
    final item = definition?.items
        .where((candidate) => candidate.id == key.itemId)
        .firstOrNull;
    final reviewable = definition != null &&
        definition.contentRevision == key.contentRevision &&
        item != null &&
        item.targetSounds.contains(key.targetSound);
    final label =
        '/${key.targetSound}/ · ${key.skill == LearningSkill.listening ? 'Listening' : 'Sound–spelling'}';
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text(reviewable
            ? 'Unresolved · ${mistake.failureCount} incorrect answers'
            : 'Unavailable content · not reviewable'),
        trailing: reviewable ? const Icon(Icons.play_arrow) : null,
        onTap: reviewable
            ? () => _openSound(context, key.targetSound, key.skill)
            : null,
      ),
    );
  }

  void _openSound(BuildContext context, String sound, LearningSkill skill) {
    if (skill == LearningSkill.spelling) {
      context.push('/arcade/word');
      return;
    }
    final lesson = frenchLessons
        .where((candidate) => candidate.sounds.contains(sound))
        .firstOrNull;
    if (lesson != null) {
      context.push('/course-lesson/${lesson.id}?review=true');
    }
  }

  String _assistanceLabel(AssistanceFlag flag) => switch (flag) {
        AssistanceFlag.explanationVisible => 'explanation shown',
        AssistanceFlag.graphemeHint => 'grapheme hint',
        AssistanceFlag.afterDebrief => 'after debrief',
        AssistanceFlag.answerRevealed => 'answer revealed',
      };
}
