import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:linguist/src/features/onboarding/onboarding_controller.dart';

void main() {
  group('OnboardingController', () {
    late OnboardingController controller;

    setUp(() {
      controller = OnboardingController();
    });
    tearDown(() => controller.dispose());

    test('initial state has no selected language', () {
      expect(controller.state.selectedLanguageCode, isNull);
    });

    test('selectLanguage updates state', () async {
      await controller.selectCourse('en-fr');

      expect(controller.state.selectedLanguageCode, 'fr');
      expect(controller.state.courseId, 'en-fr');
      expect(controller.state.isReady, isTrue);
    });

    test('selectLanguage persists to storage', () async {
      await controller.selectLanguage('fr');

      final newController = OnboardingController();
      await newController.load();

      expect(newController.state.selectedLanguageCode, 'fr');
      newController.dispose();
    });
    test('legacy target alone does not silently invent a source language',
        () async {
      SharedPreferences.setMockInitialValues({'selected_language_code': 'fr'});
      await controller.load();
      expect(controller.state.courseId, isNull);
      expect(controller.state.isReady, isTrue);
    });
  });
}
