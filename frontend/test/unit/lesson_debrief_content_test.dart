import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/lesson_debrief_content.dart';
import 'package:linguist/src/core/course/french_lesson_teaching.dart';
import 'package:linguist/src/core/course/french_course.dart';

void main() {
  test('teaching_validates_complete_pilot_and_detaches', () {
    final notes = frenchPilotTeachingNotes.toList();
    final content = loadFrenchPilotDebriefContent();
    expect(content.contentRevision, 1);
    expect(content.entries.map((entry) => entry.itemId), [
      'tout',
      'tu',
      'rouge',
      'rue',
      'vous',
      'lune',
      'doux',
      'jus',
      'loup',
      'mur'
    ]);
    expect(content.entries.map((entry) => entry.text), [
      'French /u/ in tout is close to the vowel in English “food”, but keep it steady.',
      'For /y/ in tu, hold your tongue as for /i/ and round your lips.',
      'French /u/ in tout is close to the vowel in English “food”, but keep it steady.',
      'For /y/ in tu, hold your tongue as for /i/ and round your lips.',
      'French /u/ in tout is close to the vowel in English “food”, but keep it steady.',
      'For /y/ in tu, hold your tongue as for /i/ and round your lips.',
      'French /u/ in tout is close to the vowel in English “food”, but keep it steady.',
      'For /y/ in tu, hold your tongue as for /i/ and round your lips.',
      'French /u/ in tout is close to the vowel in English “food”, but keep it steady.',
      'For /y/ in tu, hold your tongue as for /i/ and round your lips.',
    ]);
    expect(content.forUnresolved(['mur', 'tout']).map((e) => e.itemId),
        ['tout', 'mur']);
    expect(content.forUnresolved([]), isEmpty);
    expect(() => content.entries.add(content.entries.first),
        throwsUnsupportedError);
    expect(
        () => content.forUnresolved(['tout']).clear(), throwsUnsupportedError);
    notes.clear();
    expect(loadFrenchPilotDebriefContent().entries, hasLength(10));
  });

  test('teaching_rejects_ambiguous_bindings_and_unknown_aliases', () {
    final valid = frenchPilotTeachingNotes;
    final missing = valid.sublist(1);
    expect(
        () => LessonDebriefContent.fromCurriculum(
              frenchCurriculum,
              lessonId: 'en-fr-u-y',
              notes: missing,
            ),
        throwsA(isA<LessonTeachingValidationException>()));
    expect(() => loadFrenchPilotDebriefContent().forUnresolved(['missing']),
        throwsArgumentError);
    expect(
        () => loadFrenchPilotDebriefContent().forUnresolved(['tout', 'tout']),
        throwsArgumentError);
    final diagnostics = validateLessonDebriefContent(
      frenchCurriculum,
      lessonId: 'en-fr-u-y',
      notes: [valid.first, valid.first],
    );
    expect(diagnostics.map((d) => [d.code, d.recordId]), [
      ['note.duplicate', 'en-fr-u-y-listening-tout'],
      ['note.missing', 'en-fr-u-y-listening-tu'],
      ['note.missing', 'en-fr-u-y-listening-rouge'],
      ['note.missing', 'en-fr-u-y-listening-rue'],
      ['note.missing', 'en-fr-u-y-listening-vous'],
      ['note.missing', 'en-fr-u-y-listening-lune'],
      ['note.missing', 'en-fr-u-y-listening-doux'],
      ['note.missing', 'en-fr-u-y-listening-jus'],
      ['note.missing', 'en-fr-u-y-listening-loup'],
      ['note.missing', 'en-fr-u-y-listening-mur'],
    ]);
    expect(() => diagnostics.clear(), throwsUnsupportedError);
  });
}
