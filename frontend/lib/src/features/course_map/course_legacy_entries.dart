import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/course/french_course.dart';

class CourseLegacyEntries extends StatelessWidget {
  const CourseLegacyEntries({super.key, required this.completedLessonIds});
  final Set<String>? completedLessonIds;
  @override
  Widget build(BuildContext context) {
    final lessons = frenchLessons.where((lesson) => lesson.id != 'en-fr-u-y');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ExpansionTile(title: const Text('Legacy practice'), children: [
        for (final lesson in lessons)
          ListTile(
            leading: CircleAvatar(child: completedLessonIds == null
                ? const Icon(Icons.help_outline)
                : completedLessonIds!.contains(lesson.id) ? const Icon(Icons.check) : null),
            title: Text(lesson.title),
            subtitle: Text(lesson.sounds.map((s) => '/$s/').join('  ')),
            onTap: () => context.push('/course-lesson/${lesson.id}'),
          ),
      ]),
      const _ExtraEntries(),
    ]);
  }
}

class _ExtraEntries extends StatelessWidget {
  const _ExtraEntries();
  @override
  Widget build(BuildContext context) => Column(children: [
    ListTile(title: const Text('Sentence sound hunt'), onTap: () => context.push('/course-sentence-hunt')),
    ExpansionTile(title: const Text('Practice tools'), children: [
      for (final tool in const {'IPA Explorer':'/ipa','Listening Drill':'/drill','Phoneme ID':'/phoneme-id','Phoneme Test':'/phoneme-test','Audio Compare':'/compare','Profile':'/profile'}.entries)
        ListTile(title: Text(tool.key), onTap: () => context.push(tool.value)),
    ]),
    ListTile(title: const Text('Settings'), onTap: () => context.push('/settings')),
  ]);
}
