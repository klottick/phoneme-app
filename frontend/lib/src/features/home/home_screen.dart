import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/course/course_learning_providers.dart';
import '../../core/course/french_course.dart';
import '../course/course_completion_summary.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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
      // The provider remains in its unavailable state; Retry can be tried again.
    } finally {
      if (mounted) setState(() => _retryingLoad = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(courseLearningStateProvider);
    final registry = ref.watch(learningRegistryProvider);
    final completedExistingLessonIds = progress.when(
      skipLoadingOnRefresh: false,
      data: (state) =>
          CourseCompletionSummary.fromState(state: state, registry: registry)
              .completedExistingLessonIds,
      loading: () => const <String>{},
      error: (_, __) => const <String>{},
    );
    final legacyLessons = frenchLessons
        .where((lesson) => lesson.id != 'en-fr-u-y')
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Linguist'), actions: [
        IconButton(
            tooltip: 'Progress',
            icon: const Icon(Icons.insights),
            onPressed: () => context.push('/course-progress')),
        IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings')),
      ]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Text(frenchCourse.title,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('ENGLISH → FRENCH  •  Hear it. Feel it. Say it.'),
            const SizedBox(height: 20),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: progress.when(
                  skipLoadingOnRefresh: false,
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => TextButton(
                    onPressed: _retryingLoad ? null : _retryLoad,
                    child: Text(
                        _retryingLoad ? 'Retrying…' : 'Retry loading progress'),
                  ),
                  data: (state) {
                    final completion = CourseCompletionSummary.fromState(
                        state: state, registry: registry);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tu or tout?',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text('Discovery lessons: '
                            '${completion.discoveryCompleteCount}/${completion.discoveryTotal} complete'),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                            value: completion.discoveryCompleteCount /
                                completion.discoveryTotal),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => context.push(
                              '/course-lesson/en-fr-u-y'
                              '${completion.discoveryComplete ? '?review=true' : ''}'),
                          icon: const Icon(Icons.play_arrow),
                          label: Text(completion.discoveryComplete
                              ? 'Review discovery'
                              : 'Continue discovery'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 8, children: [
              OutlinedButton.icon(
                  onPressed: () => context.push('/course-review'),
                  icon: const Icon(Icons.replay),
                  label: const Text('Review sounds')),
              FilledButton.tonalIcon(
                  onPressed: () => context.push('/arcade'),
                  icon: const Icon(Icons.sports_esports_outlined),
                  label: const Text('Play for a minute')),
            ]),
            const SizedBox(height: 24),
            Text('Legacy practice',
                style: Theme.of(context).textTheme.titleLarge),
            for (var i = 0; i < legacyLessons.length; i++)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                      child: completedExistingLessonIds
                              .contains(legacyLessons[i].id)
                          ? const Icon(Icons.check)
                          : Text('${i + 1}')),
                  title: Text(legacyLessons[i].title),
                  subtitle: Text(
                      legacyLessons[i].sounds.map((s) => '/$s/').join('  ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      context.push('/course-lesson/${legacyLessons[i].id}'),
                ),
              ),
            const SizedBox(height: 12),
            ExpansionTile(title: const Text('Practice tools'), children: [
              for (final tool in const {
                'IPA Explorer': '/ipa',
                'Listening Drill': '/drill',
                'Phoneme ID': '/phoneme-id',
                'Phoneme Test': '/phoneme-test',
                'Audio Compare': '/compare',
                'Profile': '/profile'
              }.entries)
                ListTile(
                    title: Text(tool.key),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(tool.value)),
            ]),
          ]),
        ),
      ),
    );
  }
}
