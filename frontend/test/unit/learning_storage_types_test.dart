import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/learning_storage_types.dart'
    as storage;

void main() {
  test(
    'shared receipt identities preserve fields and compatibility exports',
    () {
      const before = storage.LearningCursorPosition(
        generation: 2,
        sequence: 3,
        revision: 4,
      );
      const after = storage.LearningCursorPosition(
        generation: 2,
        sequence: 4,
        revision: 5,
      );
      expect(before, isA<storage.LearningCursorPosition>());

      const receipt = storage.LearningReceiptIdentity(
        activityId: 'activity',
        token: 'abcdefghijklmnopqrstuv',
        canonicalCommand: '{}',
        before: before,
        after: after,
        commitOrdinal: 9,
      );
      expect(receipt, isA<storage.LearningReceiptIdentity>());
      expect(receipt.activityId, 'activity');
      expect(receipt.token, 'abcdefghijklmnopqrstuv');
      expect(receipt.canonicalCommand, '{}');
      expect(receipt.before, before);
      expect(receipt.after, after);
      expect(receipt.commitOrdinal, 9);

      const retained = storage.LearningRetainedReceiptIdentity(
        activityId: 'activity',
        token: 'abcdefghijklmnopqrstuv',
        canonicalCommand: '{}',
        generation: 2,
        sequence: 4,
      );
      expect(retained, isA<storage.LearningRetainedReceiptIdentity>());
      expect(retained.activityId, 'activity');
      expect(retained.token, 'abcdefghijklmnopqrstuv');
      expect(retained.canonicalCommand, '{}');
      expect(retained.generation, 2);
      expect(retained.sequence, 4);
    },
  );
}
