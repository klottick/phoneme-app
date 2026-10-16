import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/course/course_learning_providers.dart';
import '../../core/course/french_course.dart';

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
    final currentRevisions = {
      for (final lesson in frenchLessons)
        lesson.id: registry.require('lesson:${lesson.id}').contentRevision,
    };
    final completed = progress.valueOrNull?.completions
            .where((completion) =>
                currentRevisions[completion.lessonId] ==
                completion.contentRevision)
            .map((completion) => completion.lessonId)
            .toSet() ??
        <String>{};
    final next = frenchLessons.firstWhere(
        (lesson) => !completed.contains(lesson.id),
        orElse: () => frenchLessons.last);
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
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => TextButton(
                    onPressed: _retryingLoad ? null : _retryLoad,
                    child: Text(
                        _retryingLoad ? 'Retrying…' : 'Retry loading progress'),
                  ),
                  data: (_) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(next.title,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                          '${completed.length} of ${frenchLessons.length} lessons complete · about 3 minutes'),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                          value: completed.length / frenchLessons.length),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () =>
                            context.push('/course-lesson/${next.id}'),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Continue lesson'),
                      ),
                    ],
                  ),
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
            Text('Your sound path',
                style: Theme.of(context).textTheme.titleLarge),
            for (var i = 0; i < frenchLessons.length; i++)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                      child: completed.contains(frenchLessons[i].id)
                          ? const Icon(Icons.check)
                          : Text('${i + 1}')),
                  title: Text(frenchLessons[i].title),
                  subtitle: Text(
                      frenchLessons[i].sounds.map((s) => '/$s/').join('  ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      context.push('/course-lesson/${frenchLessons[i].id}'),
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
