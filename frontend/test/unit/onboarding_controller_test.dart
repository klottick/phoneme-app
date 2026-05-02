import 'package:flutter_test/flutter_test.dart';

import 'package:linguist/src/features/onboarding/onboarding_controller.dart';

void main() {
  group('OnboardingController', () {
    late OnboardingController controller;

    setUp(() {
      controller = OnboardingController();
    });

    test('initial state has no selected language', () {
      expect(controller.state.selectedLanguageCode, isNull);
    });

    test('selectLanguage updates state', () async {
      await controller.selectLanguage('en');
      
      expect(controller.state.selectedLanguageCode, 'en');
      expect(controller.state.isReady, isTrue);
    });

    test('selectLanguage persists to storage', () async {
      await controller.selectLanguage('fr');
      
      final newController = OnboardingController();
      await newController.load();
      
      expect(newController.state.selectedLanguageCode, 'fr');
    });
  });
}