import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingState {
  const OnboardingState({
    required this.selectedLanguageCode,
    required this.isReady,
    this.courseId,
  });

  final String? selectedLanguageCode;
  final bool isReady;
  final String? courseId;

  OnboardingState copyWith({
    String? selectedLanguageCode,
    bool? isReady,
    String? courseId,
  }) {
    return OnboardingState(
      selectedLanguageCode: selectedLanguageCode ?? this.selectedLanguageCode,
      isReady: isReady ?? this.isReady,
      courseId: courseId ?? this.courseId,
    );
  }
}

class OnboardingController extends StateNotifier<OnboardingState> {
  OnboardingController()
      : super(
            const OnboardingState(selectedLanguageCode: null, isReady: false)) {
    load();
  }

  static const _languageKey = 'selected_language_code';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final course = prefs.getString('selected_course_id');
    state = state.copyWith(
      selectedLanguageCode: course == 'en-fr' ? 'fr' : null,
      courseId: course == 'en-fr' ? course : null,
      isReady: true,
    );
  }

  Future<void> selectLanguage(String code) async {
    // Compatibility for older callers. Only a fully authored course is offered.
    if (code != 'fr') return;
    await selectCourse('en-fr');
  }

  Future<void> selectCourse(String courseId) async {
    if (courseId != 'en-fr') throw ArgumentError.value(courseId, 'courseId');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_course_id', courseId);
    await prefs.setString(_languageKey, 'fr');
    if (!mounted) return;
    state = state.copyWith(
        selectedLanguageCode: 'fr', courseId: courseId, isReady: true);
  }
}
