class LanguageCourse {
  const LanguageCourse(
      this.id, this.sourceLanguage, this.targetLanguage, this.title);
  final String id, sourceLanguage, targetLanguage, title;
}

const frenchCourse =
    LanguageCourse('en-fr', 'en', 'fr', 'French for English speakers');

class CourseWord {
  const CourseWord(this.text, this.meaning, this.ipa, this.sounds, this.hint);
  final String text, meaning, ipa, hint;
  final List<String> sounds;
  bool contains(String sound) => sounds.contains(sound.replaceAll('/', ''));
}

// Citation pronunciations in contemporary metropolitan French. Membership is
// curated: spelling alone cannot determine whether a word contains a phoneme.
const frenchWords = [
  CourseWord('tout', 'all', 'tu', ['t', 'u'], 'ou'),
  CourseWord('rouge', 'red', 'ʁuʒ', ['ʁ', 'u', 'ʒ'], 'ou'),
  CourseWord('vous', 'you', 'vu', ['v', 'u'], 'ou'),
  CourseWord('doux', 'soft', 'du', ['d', 'u'], 'ou'),
  CourseWord('loup', 'wolf', 'lu', ['l', 'u'], 'ou'),
  CourseWord('soupe', 'soup', 'sup', ['s', 'u', 'p'], 'ou'),
  CourseWord('tu', 'you', 'ty', ['t', 'y'], 'u'),
  CourseWord('rue', 'street', 'ʁy', ['ʁ', 'y'], 'u'),
  CourseWord('lune', 'moon', 'lyn', ['l', 'y', 'n'], 'u'),
  CourseWord('jus', 'juice', 'ʒy', ['ʒ', 'y'], 'u'),
  CourseWord('mur', 'wall', 'myʁ', ['m', 'y', 'ʁ'], 'u'),
  CourseWord('plume', 'feather', 'plym', ['p', 'l', 'y', 'm'], 'u'),
  CourseWord('lit', 'bed', 'li', ['l', 'i'], 'i'),
  CourseWord('si', 'if', 'si', ['s', 'i'], 'i'),
  CourseWord('vite', 'quickly', 'vit', ['v', 'i', 't'], 'i'),
  CourseWord('île', 'island', 'il', ['i', 'l'], 'î'),
  CourseWord('beau', 'beautiful', 'bo', ['b', 'o'], 'eau'),
  CourseWord('mot', 'word', 'mo', ['m', 'o'], 'o'),
  CourseWord('eau', 'water', 'o', ['o'], 'eau'),
  CourseWord('dos', 'back', 'do', ['d', 'o'], 'o'),
  CourseWord('bon', 'good', 'bɔ̃', ['b', 'ɔ̃'], 'on'),
  CourseWord('nom', 'name', 'nɔ̃', ['n', 'ɔ̃'], 'om'),
  CourseWord('banc', 'bench', 'bɑ̃', ['b', 'ɑ̃'], 'an'),
  CourseWord('sans', 'without', 'sɑ̃', ['s', 'ɑ̃'], 'an'),
];

CourseWord wordByText(String text) =>
    frenchWords.firstWhere((w) => w.text == text);

class CourseLesson {
  const CourseLesson(
      this.id, this.title, this.explanation, this.sounds, this.words);
  final String id, title, explanation;
  final List<String> sounds, words;
}

const frenchLessons = [
  CourseLesson(
      'en-fr-vowels',
      'Keep French vowels steady',
      'English vowels often glide. In French, hold one steady mouth position. '
          'Compare lit /i/ and beau /o/: avoid adding an English-style “y” or “w” at the end. '
          'English comparisons are starting points, not exact equivalents.',
      ['i', 'o'],
      ['lit', 'beau', 'vite', 'mot']),
  CourseLesson(
      'en-fr-u-y',
      'Tu or tout?',
      'French /u/ in tout is close to the vowel in English “food”, but keep it steady. '
          'For /y/ in tu, hold your tongue as for /i/ and round your lips. '
          'English has no direct equivalent of /y/. French “ou” and “u” represent different sounds.',
      ['u', 'y'],
      ['tout', 'tu', 'rouge', 'rue', 'vous', 'lune']),
  CourseLesson(
      'en-fr-nasal',
      'Let vowels resonate',
      'Compare beau /bo/, bon /bɔ̃/ and banc /bɑ̃/. For nasal vowels, air passes '
          'through the nose as well as the mouth. Do not add an English /n/ at the end. '
          'The tilde marks a nasal vowel; these are different vowel sounds, not just different spellings.',
      ['o', 'ɔ̃', 'ɑ̃'],
      ['beau', 'bon', 'banc', 'nom', 'sans']),
  CourseLesson(
      'en-fr-r',
      'Meet the French R',
      'French /ʁ/ is made near the back of the mouth, unlike most English R sounds. '
          'Listen to rue and rouge; keep your tongue tip relaxed. French R varies by speaker—'
          'aim for comfortable, clear speech rather than forcing a harsh sound.',
      ['ʁ', 'u', 'y'],
      ['rue', 'rouge', 'mur']),
  CourseLesson(
      'en-fr-mix',
      'Mix your new sounds',
      'Listen first, then identify the vowel. Keep /u/ and /y/ distinct, hold vowels steady, '
          'and let nasal vowels resonate. Say the words and compare your recording with the reference.',
      ['u', 'y', 'i', 'o', 'ɔ̃', 'ɑ̃'],
      ['tout', 'tu', 'lit', 'beau', 'bon', 'banc']),
];
