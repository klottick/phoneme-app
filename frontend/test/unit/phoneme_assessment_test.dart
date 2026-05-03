import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/services/phoneme_assessment_service.dart';

void main() {
  group('PhonemeAssessment', () {
    test('correct returns perfect score', () {
      final assessment = PhonemeAssessment.correct();
      
      expect(assessment.score, 100);
      expect(assessment.isCorrect, true);
      expect(assessment.confidence, 1.0);
    });

    test('incorrect returns zero score', () {
      final assessment = PhonemeAssessment.incorrect();
      
      expect(assessment.score, 0);
      expect(assessment.isCorrect, false);
      expect(assessment.confidence, 0.0);
    });

    test('close with high score returns correct', () {
      final assessment = PhonemeAssessment.close(score: 75);
      
      expect(assessment.score, 75);
      expect(assessment.isCorrect, true);
      expect(assessment.confidence, 0.75);
    });

    test('close with low score returns incorrect', () {
      final assessment = PhonemeAssessment.close(score: 50);
      
      expect(assessment.score, 50);
      expect(assessment.isCorrect, false);
    });

    test('factory constructors provide feedback', () {
      final correct = PhonemeAssessment.correct();
      expect(correct.feedback, isNotEmpty);
      
      final incorrect = PhonemeAssessment.incorrect();
      expect(incorrect.feedback, isNotEmpty);
    });
  });

  group('PhonemeAssessmentService', () {
    test('creates service with local models', () {
      final service = PhonemeAssessmentService(useLocalModels: true);
      
      expect(service.useLocalModels, true);
    });

    test('analyze with missing file returns incorrect', () async {
      final service = PhonemeAssessmentService(useLocalModels: true);
      
      final result = await service.analyze(
        recordingPath: '/nonexistent/path.m4a',
        expectedPhoneme: 'æ',
        languageCode: 'en',
      );
      
      expect(result.isCorrect, false);
      expect(result.score, 0);
    });
  });
}