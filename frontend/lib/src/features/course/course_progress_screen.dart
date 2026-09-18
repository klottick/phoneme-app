import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/course/course_progress.dart';
import '../../core/course/french_course.dart';
import '../../core/course/backend.dart';

class CourseProgressScreen extends ConsumerWidget {
  const CourseProgressScreen({super.key, this.review = false});
  final bool review;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar:
            AppBar(title: Text(review ? 'Review sounds' : 'Course progress')),
        body: ref.watch(courseProgressProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                  child: TextButton(
                      onPressed: () => ref.invalidate(courseProgressProvider),
                      child: const Text('Retry loading progress'))),
              data: (data) {
                final evidence = (data['evidence'] as Map).values.cast<Map>();
                final due = evidence
                    .where((e) => !DateTime.parse(e['due'] as String)
                        .isAfter(DateTime.now()))
                    .toList();
                final entries = review ? due : evidence.toList();
                return ListView(padding: const EdgeInsets.all(20), children: [
                  Text(frenchCourse.title,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Text(
                      '${(data['lessons'] as List).length}/${frenchLessons.length} lessons complete'),
                  const Text(
                      'Progress on this device. Listening and sound–spelling are separate skills.'),
                  if (courseBackend?.auth.currentUser != null)
                    TextButton.icon(
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Sync saved progress'),
                      onPressed: () async {
                        final synced =
                            await CourseProgressStore(frenchCourse.id).sync();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(synced
                                  ? 'Progress backed up.'
                                  : 'Offline: progress stays saved here. Retry when connected.')));
                        }
                      },
                    ),
                  const SizedBox(height: 12),
                  if (entries.isEmpty)
                    Text(review
                        ? 'No sounds due right now. Practice a lesson or play a round.'
                        : 'Your first answers will appear here.'),
                  for (final e in entries)
                    Card(
                        child: ListTile(
                      title: Text(
                          '/${e['sound']}/ · ${e['skill'] == 'listening' ? 'Listening' : 'Sound–spelling'}'),
                      subtitle: Text(
                          '${e['correct']} correct / ${e['attempts']} answers'),
                      trailing: const Icon(Icons.play_arrow),
                      onTap: () {
                        if (e['skill'] == 'spelling') {
                          context.push('/arcade/word');
                          return;
                        }
                        final lesson = frenchLessons
                            .firstWhere((l) => l.sounds.contains(e['sound']));
                        context.push('/course-lesson/${lesson.id}?review=true');
                      },
                    )),
                  if (!review) ...[
                    const SizedBox(height: 20),
                    const Text(
                        'Arcade best scores — separate from sound accuracy'),
                    Text('Sound Match: ${data['scores']['sound'] ?? 0}'),
                    Text('Word Match: ${data['scores']['word'] ?? 0}'),
                  ],
                ]);
              },
            ),
      );
}
