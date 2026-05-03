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

final supabaseClientProvider = Provider<SupabaseClient>((_) {
  return Supabase.instance.client;
});

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>((_) {
      return OnboardingController();
    });

final selectedLanguageCodeProvider = Provider<String>((ref) {
  return ref.watch(onboardingControllerProvider).selectedLanguageCode ?? 'en';
});

final curriculumRepositoryProvider = Provider<CurriculumRepository>((ref) {
  return CurriculumRepository(ref.watch(supabaseClientProvider));
});

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(ref.watch(supabaseClientProvider));
});

final phonemesProvider = FutureProvider<List<Phoneme>>((ref) {
  final languageCode = ref.watch(selectedLanguageCodeProvider);
  return ref.watch(curriculumRepositoryProvider).getPhonemes(languageCode);
});

final minimalPairsProvider = FutureProvider<List<MinimalPair>>((ref) {
  final languageCode = ref.watch(selectedLanguageCodeProvider);
  return ref.watch(curriculumRepositoryProvider).getMinimalPairs(languageCode);
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
