import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WordOfTheDay {
  final String word;
  final String pronunciation;
  final String meaning;
  final List<String> phonemes;
  final String exampleSentence;
  final DateTime date;

  const WordOfTheDay({
    required this.word,
    required this.pronunciation,
    required this.meaning,
    required this.phonemes,
    required this.exampleSentence,
    required this.date,
  });
}

class WordBank {
  static final List<Map<String, dynamic>> _words = [
    {
      'word': 'serendipity',
      'pronunciation': '/ˌserənˈdɪpɪti/',
      'meaning': 'The occurrence of events by chance in a happy way',
      'phonemes': ['s', 'ɛ', 'r', 'ə', 'n', 'd', 'ɪ', 'p', 'ɪ', 't', 'i'],
      'example': 'Finding that book was pure serendipity.',
    },
    {
      'word': 'ephemeral',
      'pronunciation': '/ɪˈfem(ə)rəl/',
      'meaning': 'Lasting for a very short time',
      'phonemes': ['ɪ', 'f', 'e', 'm', 'ə', 'r', 'ə', 'l'],
      'example': 'The beauty of cherry blossoms is ephemeral.',
    },
    {
      'word': 'eloquent',
      'pronunciation': '/ˈeləkwənt/',
      'meaning': 'Fluent or persuasive in speaking or writing',
      'phonemes': ['e', 'l', 'ə', 'k', 'w', 'ə', 'n', 't'],
      'example': 'She gave an eloquent speech.',
    },
    {
      'word': 'luminous',
      'pronunciation': '/ˈl(j)uːmɪnəs/',
      'meaning': 'Full of or shedding light; bright',
      'phonemes': ['l', 'uː', 'm', 'ɪ', 'n', 'ə', 's'],
      'example': 'The luminous stars filled the night sky.',
    },
    {
      'word': 'petrichor',
      'pronunciation': '/ˈpetrɪkɔː/',
      'meaning': 'The pleasant smell of rain on dry earth',
      'phonemes': ['p', 'e', 't', 'r', 'ɪ', 'k', 'ɔː'],
      'example': 'I love the petrichor after a summer rain.',
    },
    {
      'word': 'sonder',
      'pronunciation': '/ˈsɒndə/',
      'meaning': 'Realization that everyone has a complex life',
      'phonemes': ['s', 'ɒ', 'n', 'd', 'ə'],
      'example': 'Standing in the crowd, I felt a sense of sonder.',
    },
    {
      'word': 'ethereal',
      'pronunciation': '/ɪˈθɪəriəl/',
      'meaning': 'Extremely delicate and light; heavenly',
      'phonemes': ['ɪ', 'θ', 'ɪə', 'r', 'i', 'ə', 'l'],
      'example': 'The ballet dancer moved with ethereal grace.',
    },
    {
      'word': 'quintessential',
      'pronunciation': '/ˌkwɪntɪˈsenʃ(ə)l/',
      'meaning': 'Representing the most perfect example',
      'phonemes': ['k', 'w', 'ɪ', 'n', 't', 'ɪ', 's', 'e', 'n', 'ʃ', 'ə', 'l'],
      'example': 'She is the quintessential professional.',
    },
  ];

  static WordOfTheDay getWordForDate(DateTime date) {
    final random = Random(date.year * 10000 + date.month * 100 + date.day);
    final wordData = _words[random.nextInt(_words.length)];

    return WordOfTheDay(
      word: wordData['word'],
      pronunciation: wordData['pronunciation'],
      meaning: wordData['meaning'],
      phonemes: List<String>.from(wordData['phonemes']),
      exampleSentence: wordData['example'],
      date: date,
    );
  }

  static WordOfTheDay getRandomWord() {
    final random = Random();
    final wordData = _words[random.nextInt(_words.length)];

    return WordOfTheDay(
      word: wordData['word'],
      pronunciation: wordData['pronunciation'],
      meaning: wordData['meaning'],
      phonemes: List<String>.from(wordData['phonemes']),
      exampleSentence: wordData['example'],
      date: DateTime.now(),
    );
  }
}

class WordOfTheDayNotifier extends StateNotifier<WordOfTheDay> {
  WordOfTheDayNotifier() : super(WordBank.getWordForDate(DateTime.now())) {
    _checkAndUpdate();
  }

  Future<void> _checkAndUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDateStr = prefs.getString('word_of_the_day_date');
    final today = DateTime.now();

    if (lastDateStr != null) {
      final lastDate = DateTime.parse(lastDateStr);
      if (lastDate.day != today.day ||
          lastDate.month != today.month ||
          lastDate.year != today.year) {
        state = WordBank.getWordForDate(today);
        await prefs.setString('word_of_the_day_date', today.toIso8601String());
      }
    } else {
      await prefs.setString('word_of_the_day_date', today.toIso8601String());
    }
  }

  void refresh() {
    state = WordBank.getRandomWord();
  }
}

final wordOfTheDayProvider =
    StateNotifierProvider<WordOfTheDayNotifier, WordOfTheDay>((ref) {
  return WordOfTheDayNotifier();
});

class WordOfTheDayCard extends ConsumerWidget {
  const WordOfTheDayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final word = ref.watch(wordOfTheDayProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amber),
                const SizedBox(width: 8),
                const Text(
                  'Word of the Day',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => ref.read(wordOfTheDayProvider.notifier).refresh(),
                  child: const Text('Random'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              word.word,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              word.pronunciation,
              style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            Text(word.meaning),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${word.exampleSentence}"',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: word.phonemes.map((p) => Chip(
                label: Text(p, style: const TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}