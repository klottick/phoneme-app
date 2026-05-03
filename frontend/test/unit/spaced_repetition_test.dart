import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/services/spaced_repetition_service.dart';

void main() {
  group('SpacedRepetitionService', () {
    test('createItem creates new item with correct defaults', () {
      final service = SpacedRepetitionService();
      final item = service.createItem('æ');

      expect(item.phonemeId, 'æ');
      expect(item.easeFactor, 250);
      expect(item.interval, 1);
      expect(item.repetitions, 0);
    });

    test('processReview updates based on quality', () {
      final service = SpacedRepetitionService();
      final item = service.createItem('æ');

      final updated = service.processReview(item, 5);
      expect(updated.repetitions, 1);
    });

    test('processReview resets on low quality', () {
      final service = SpacedRepetitionService();
      var item = service.createItem('æ');
      item = service.processReview(item, 5);
      item = service.processReview(item, 5);
      expect(item.repetitions, 2);

      final failed = service.processReview(item, 1);
      expect(failed.repetitions, 0);
    });

    test('getDueItems returns due items', () {
      final service = SpacedRepetitionService();
      final items = [
        service.createItem('æ'),
        SpacedRepetitionItem(
          id: 'test2',
          phonemeId: 'ə',
          nextReview: DateTime.now().add(const Duration(days: 1)),
        ),
      ];

      final due = service.getDueItems(items);
      expect(due.length, 1);
      expect(due.first.phonemeId, 'æ');
    });

    test('getDueItems respects limit', () {
      final service = SpacedRepetitionService();
      final items = [
        service.createItem('æ'),
        service.createItem('ə'),
        service.createItem('ɪ'),
      ];

      final due = service.getDueItems(items, limit: 2);
      expect(due.length, 2);
    });
  });

  group('SpacedRepetitionItem', () {
    test('isDue returns true for null nextReview', () {
      const item = SpacedRepetitionItem(id: 'test', phonemeId: 'æ');
      expect(item.isDue, true);
    });

    test('isDue returns true when nextReview is past', () {
      final item = SpacedRepetitionItem(
        id: 'test',
        phonemeId: 'æ',
        nextReview: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(item.isDue, true);
    });

    test('isDue returns false when nextReview is future', () {
      final item = SpacedRepetitionItem(
        id: 'test',
        phonemeId: 'æ',
        nextReview: DateTime.now().add(const Duration(days: 1)),
      );
      expect(item.isDue, false);
    });

    test('successRate calculates correctly', () {
      const item = SpacedRepetitionItem(id: 'test', phonemeId: 'æ', repetitions: 3, interval: 2);
      expect(item.successRate, greaterThan(0));
      expect(item.successRate, lessThanOrEqualTo(1));
    });

    test('copyWith preserves unchanged values', () {
      const item = SpacedRepetitionItem(id: 'test', phonemeId: 'æ', interval: 10);
      final updated = item.copyWith(repetitions: 5);

      expect(updated.interval, 10);
      expect(updated.repetitions, 5);
    });

    test('toJson and fromJson roundtrip', () {
      const item = SpacedRepetitionItem(id: 'test', phonemeId: 'æ', repetitions: 3, interval: 5);

      final json = item.toJson();
      final restored = SpacedRepetitionItem.fromJson(json);

      expect(restored.phonemeId, item.phonemeId);
      expect(restored.repetitions, item.repetitions);
    });
  });
}