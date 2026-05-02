import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingState {
  const OnboardingState({
    required this.selectedLanguageCode,
    required this.isReady,
  });

  final String? selectedLanguageCode;
  final bool isReady;

  OnboardingState copyWith({
    String? selectedLanguageCode,
    bool? isReady,
  }) {
    return OnboardingState(
      selectedLanguageCode: selectedLanguageCode ?? this.selectedLanguageCode,
      isReady: isReady ?? this.isReady,
    );
  }
}

class OnboardingController extends StateNotifier<OnboardingState> {
  OnboardingController()
      : super(const OnboardingState(selectedLanguageCode: null, isReady: false)) {
    load();
  }

  static const _languageKey = 'selected_language_code';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      selectedLanguageCode: prefs.getString(_languageKey),
      isReady: true,
    );
  }

  Future<void> selectLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, code);
    state = state.copyWith(selectedLanguageCode: code, isReady: true);
  }
}
