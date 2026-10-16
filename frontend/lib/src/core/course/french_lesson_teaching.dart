import 'french_course.dart';
import 'lesson_debrief_content.dart';

const _u =
    'French /u/ in tout is close to the vowel in English “food”, but keep it steady.';
const _y = 'For /y/ in tu, hold your tongue as for /i/ and round your lips.';

List<LessonTeachingNote> get frenchPilotTeachingNotes => List.unmodifiable([
      for (final item in const [
        ('tout', _u),
        ('tu', _y),
        ('rouge', _u),
        ('rue', _y),
        ('vous', _u),
        ('lune', _y),
        ('doux', _u),
        ('jus', _y),
        ('loup', _u),
        ('mur', _y)
      ])
        LessonTeachingNote(
            sectionId: 'en-fr-u-y-listening',
            exerciseId: 'en-fr-u-y-listening-${item.$1}',
            text: item.$2),
    ]);

LessonDebriefContent loadFrenchPilotDebriefContent() =>
    LessonDebriefContent.fromCurriculum(
      frenchCurriculum,
      lessonId: 'en-fr-u-y',
      notes: frenchPilotTeachingNotes,
    );
