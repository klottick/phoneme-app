import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/onboarding/onboarding_controller.dart';
import '../models/minimal_pair.dart';
import '../models/phoneme.dart';
import '../models/review_item.dart';
import '../repositories/curriculum_repository.dart';
import '../repositories/progress_repository.dart';
import '../services/streak_service.dart';
import '../services/phoneme_assessment_service.dart';
import '../services/recording_service.dart' hide recordingServiceProvider;
import '../course/french_course.dart';

final supabaseClientProvider = Provider<SupabaseClient>((_) {
  return Supabase.instance.client;
});

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>((_) {
  return OnboardingController();
});

final selectedLanguageCodeProvider = Provider<String>((ref) {
  return ref.watch(selectedCourseProvider).targetLanguage;
});

final selectedCourseProvider = Provider<LanguageCourse>((ref) {
  ref.watch(onboardingControllerProvider);
  return frenchCourse;
});

final curriculumRepositoryProvider = Provider<CurriculumRepository>((ref) {
  return CurriculumRepository(ref.watch(supabaseClientProvider));
});

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(ref.watch(supabaseClientProvider));
});

final phonemesProvider = FutureProvider<List<Phoneme>>((ref) {
  final course = ref.watch(selectedCourseProvider);
  final sounds = frenchLessons.expand((l) => l.sounds).toSet();
  return Future.value(sounds
      .map((s) => Phoneme(
          id: '${course.id}:$s',
          languageCode: course.targetLanguage,
          ipaSymbol: '/$s/',
          descriptor: frenchWords.firstWhere((w) => w.contains(s)).text,
          difficultyLevel: 1))
      .toList());
});

final minimalPairsProvider = FutureProvider<List<MinimalPair>>((ref) {
  ref.watch(selectedCourseProvider);
  return Future.value([
    const MinimalPair(
        id: 'en-fr-tu-tout',
        wordA: 'tu',
        wordB: 'tout',
        phonemeA: '/y/',
        phonemeB: '/u/'),
    const MinimalPair(
        id: 'en-fr-rue-roue',
        wordA: 'rue',
        wordB: 'roue',
        phonemeA: '/y/',
        phonemeB: '/u/'),
    const MinimalPair(
        id: 'en-fr-beau-bon',
        wordA: 'beau',
        wordB: 'bon',
        phonemeA: '/o/',
        phonemeB: '/ɔ̃/'),
  ]);
});

final dueReviewItemsProvider = FutureProvider<List<ReviewItem>>((ref) {
  return ref.watch(progressRepositoryProvider).getDueReviews();
});

final streakServiceProvider = Provider<StreakService>((ref) => StreakService());

final recordingServiceProvider = Provider<RecordingService>((ref) {
  final service = RecordingService();
  ref.onDispose(() => service.dispose());
  return service;
});

final phonemeAssessmentServiceProvider = Provider<PhonemeAnalyzer>((ref) {
  return PhonemeAssessmentService(useLocalModels: true, apiKey: null);
});

// Auth providers are in auth_service.dart
