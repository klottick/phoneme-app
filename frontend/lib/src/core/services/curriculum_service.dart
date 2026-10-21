import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


class LessonPlan {
  final String id;
  final String title;
  final String description;
  final String languageCode;
  final int estimatedMinutes;
  final List<String> phonemeIds;
  final LessonDifficulty difficulty;
  final LessonCategory category;

  const LessonPlan({
    required this.id,
    required this.title,
    required this.description,
    required this.languageCode,
    required this.estimatedMinutes,
    required this.phonemeIds,
    required this.difficulty,
    required this.category,
  });

  int get phonemeCount => phonemeIds.length;

  LessonPlan copyWith({
    String? id,
    String? title,
    String? description,
    String? languageCode,
    int? estimatedMinutes,
    List<String>? phonemeIds,
    LessonDifficulty? difficulty,
    LessonCategory? category,
  }) {
    return LessonPlan(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      languageCode: languageCode ?? this.languageCode,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      phonemeIds: phonemeIds ?? this.phonemeIds,
      difficulty: difficulty ?? this.difficulty,
      category: category ?? this.category,
    );
  }
}

enum LessonDifficulty { beginner, intermediate, advanced }

enum LessonCategory {
  basics,
  vowels,
  consonants,
  diphthongs,
  sounds,
  minimalPairs,
  listening,
  speaking,
  review,
}

extension LessonDifficultyX on LessonDifficulty {
  String get displayName {
    switch (this) {
      case LessonDifficulty.beginner:
        return 'Beginner';
      case LessonDifficulty.intermediate:
        return 'Intermediate';
      case LessonDifficulty.advanced:
        return 'Advanced';
    }
  }

  Color get color {
    switch (this) {
      case LessonDifficulty.beginner:
        return Colors.green;
      case LessonDifficulty.intermediate:
        return Colors.orange;
      case LessonDifficulty.advanced:
        return Colors.red;
    }
  }
}

extension LessonCategoryX on LessonCategory {
  String get displayName {
    switch (this) {
      case LessonCategory.basics:
        return 'Basics';
      case LessonCategory.vowels:
        return 'Vowels';
      case LessonCategory.consonants:
        return 'Consonants';
      case LessonCategory.diphthongs:
        return 'Diphthongs';
      case LessonCategory.sounds:
        return 'Sounds';
      case LessonCategory.minimalPairs:
        return 'Minimal Pairs';
      case LessonCategory.listening:
        return 'Listening';
      case LessonCategory.speaking:
        return 'Speaking';
      case LessonCategory.review:
        return 'Review';
    }
  }

  IconData get icon {
    switch (this) {
      case LessonCategory.basics:
        return Icons.school;
      case LessonCategory.vowels:
        return Icons.record_voice_over;
      case LessonCategory.consonants:
        return Icons.speaker;
      case LessonCategory.diphthongs:
        return Icons.swap_horiz;
      case LessonCategory.sounds:
        return Icons.music_note;
      case LessonCategory.minimalPairs:
        return Icons.compare_arrows;
      case LessonCategory.listening:
        return Icons.hearing;
      case LessonCategory.speaking:
        return Icons.mic;
      case LessonCategory.review:
        return Icons.replay;
    }
  }
}

class CurriculumService {
  static List<LessonPlan> getDefaultCurriculum(String languageCode) {
    switch (languageCode) {
      case 'en':
        return _englishCurriculum;
      case 'fr':
        return _frenchCurriculum;
      case 'ja':
        return _japaneseCurriculum;
      default:
        return _englishCurriculum;
    }
  }

  static final _englishCurriculum = [
    const LessonPlan(
      id: 'en_basics_1',
      title: 'English Basics 1',
      description: 'Learn the fundamental sounds of English',
      languageCode: 'en',
      estimatedMinutes: 15,
      phonemeIds: ['æ', 'ʌ', 'ə', 'iː', 'uː'],
      difficulty: LessonDifficulty.beginner,
      category: LessonCategory.basics,
    ),
    const LessonPlan(
      id: 'en_vowels_1',
      title: 'English Vowels',
      description: 'Master English vowel sounds',
      languageCode: 'en',
      estimatedMinutes: 20,
      phonemeIds: ['iː', 'ɪ', 'eɪ', 'æ', 'ɒ', 'ɔː', 'ʊ', 'uː', 'ʌ', 'ə'],
      difficulty: LessonDifficulty.beginner,
      category: LessonCategory.vowels,
    ),
    const LessonPlan(
      id: 'en_consonants_1',
      title: 'English Consonants',
      description: 'Master English consonant sounds',
      languageCode: 'en',
      estimatedMinutes: 25,
      phonemeIds: ['p', 'b', 't', 'd', 'k', 'g', 'f', 'v', 'θ', 'ð', 's', 'z', 'ʃ', 'ʒ', 'h', 'm', 'n', 'ŋ', 'l', 'r', 'j', 'w'],
      difficulty: LessonDifficulty.intermediate,
      category: LessonCategory.consonants,
    ),
    const LessonPlan(
      id: 'en_minimal_1',
      title: 'Common Minimal Pairs',
      description: 'Differentiate similar-sounding words',
      languageCode: 'en',
      estimatedMinutes: 30,
      phonemeIds: ['s', 'ʃ', 'f', 'θ', 'l', 'r'],
      difficulty: LessonDifficulty.intermediate,
      category: LessonCategory.minimalPairs,
    ),
    const LessonPlan(
      id: 'en_sounds_1',
      title: 'Problem Sounds',
      description: 'Tackle challenging English sounds',
      languageCode: 'en',
      estimatedMinutes: 20,
      phonemeIds: ['θ', 'ð', 'ŋ', 'r', 'l'],
      difficulty: LessonDifficulty.advanced,
      category: LessonCategory.sounds,
    ),
    const LessonPlan(
      id: 'en_review_1',
      title: 'Review Session',
      description: 'Review all learned phonemes',
      languageCode: 'en',
      estimatedMinutes: 15,
      phonemeIds: ['æ', 'ʌ', 'ə', 'iː', 'uː', 'p', 'b', 't', 'd', 'k'],
      difficulty: LessonDifficulty.beginner,
      category: LessonCategory.review,
    ),
  ];

  static final _frenchCurriculum = [
    const LessonPlan(
      id: 'fr_basics_1',
      title: 'French Basics',
      description: 'Learn French pronunciation fundamentals',
      languageCode: 'fr',
      estimatedMinutes: 15,
      phonemeIds: ['a', 'e', 'i', 'o', 'u', 'y'],
      difficulty: LessonDifficulty.beginner,
      category: LessonCategory.basics,
    ),
    const LessonPlan(
      id: 'fr_nasals',
      title: 'French Nasals',
      description: 'Master nasal vowel sounds',
      languageCode: 'fr',
      estimatedMinutes: 20,
      phonemeIds: ['ɑ̃', 'ɔ̃', 'ɛ̃', 'œ̃'],
      difficulty: LessonDifficulty.intermediate,
      category: LessonCategory.vowels,
    ),
  ];

  static final _japaneseCurriculum = [
    const LessonPlan(
      id: 'ja_hiragana',
      title: 'Hiragana Sounds',
      description: 'Master hiragana pronunciation',
      languageCode: 'ja',
      estimatedMinutes: 20,
      phonemeIds: ['a', 'i', 'u', 'e', 'o', 'n'],
      difficulty: LessonDifficulty.beginner,
      category: LessonCategory.basics,
    ),
    const LessonPlan(
      id: 'ja_romaji',
      title: 'Romanized Japanese',
      description: 'Practice romaji pronunciation',
      languageCode: 'ja',
      estimatedMinutes: 15,
      phonemeIds: ['ɾ', 'tɕ', 'ts', 'ŋ'],
      difficulty: LessonDifficulty.intermediate,
      category: LessonCategory.sounds,
    ),
  ];
}

class CurriculumNotifier extends StateNotifier<List<LessonPlan>> {
  final String _languageCode;
  CurriculumNotifier(this._languageCode)
      : super(CurriculumService.getDefaultCurriculum(_languageCode));

  void reset() {
    state = CurriculumService.getDefaultCurriculum(_languageCode);
  }

  LessonPlan? getLesson(String id) {
    try {
      return state.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  List<LessonPlan> getLessonsByCategory(LessonCategory category) {
    return state.where((l) => l.category == category).toList();
  }

  List<LessonPlan> getLessonsByDifficulty(LessonDifficulty difficulty) {
    return state.where((l) => l.difficulty == difficulty).toList();
  }
}

final curriculumProvider = StateNotifierProvider.family<CurriculumNotifier, List<LessonPlan>, String>(
  (ref, languageCode) => CurriculumNotifier(languageCode),
);

class LessonPlanScreen extends ConsumerWidget {
  final String? lessonId;
  final String languageCode;

  const LessonPlanScreen({
    super.key,
    this.lessonId,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = ref.watch(curriculumProvider(languageCode));
    final selectedLesson = lessonId != null
        ? lessons.where((l) => l.id == lessonId).firstOrNull
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(selectedLesson?.title ?? 'Lesson Plans')),
      body: lessons.isEmpty
          ? const Center(child: Text('No lessons available'))
          : ListView.builder(
              itemCount: lessons.length,
              itemBuilder: (context, index) {
                final lesson = lessons[index];
                return _LessonCard(
                  lesson: lesson,
                  isSelected: lesson.id == lessonId,
                );
              },
            ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  final LessonPlan lesson;
  final bool isSelected;

  const _LessonCard({required this.lesson, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: () => context.push('/phoneme-id'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: lesson.difficulty.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(lesson.category.icon, color: lesson.difficulty.color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      lesson.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.timer, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('${lesson.estimatedMinutes} min'),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: lesson.difficulty.color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            lesson.difficulty.displayName,
                            style: TextStyle(
                              fontSize: 10,
                              color: lesson.difficulty.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Generic practice'),
                  Icon(Icons.chevron_right),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
