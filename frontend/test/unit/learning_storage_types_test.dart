import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_learning_transaction.dart'
    as compatibility;
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
      expect(
        const compatibility.LearningCursorPosition(
          generation: 2,
          sequence: 3,
          revision: 4,
        ),
        before,
      );

      const receipt = storage.LearningReceiptIdentity(
        activityId: 'activity',
        token: 'abcdefghijklmnopqrstuv',
        canonicalCommand: '{}',
        before: before,
        after: after,
        commitOrdinal: 9,
      );
      const compatibleReceipt = compatibility.LearningReceiptIdentity(
        activityId: 'activity',
        token: 'abcdefghijklmnopqrstuv',
        canonicalCommand: '{}',
        before: before,
        after: after,
        commitOrdinal: 9,
      );
      expect(compatibleReceipt, isA<storage.LearningReceiptIdentity>());
      expect(receipt.activityId, compatibleReceipt.activityId);
      expect(receipt.token, compatibleReceipt.token);
      expect(receipt.canonicalCommand, compatibleReceipt.canonicalCommand);
      expect(receipt.before, compatibleReceipt.before);
      expect(receipt.after, compatibleReceipt.after);
      expect(receipt.commitOrdinal, compatibleReceipt.commitOrdinal);

      const retained = storage.LearningRetainedReceiptIdentity(
        activityId: 'activity',
        token: 'abcdefghijklmnopqrstuv',
        canonicalCommand: '{}',
        generation: 2,
        sequence: 4,
      );
      const compatibleRetained = compatibility.LearningRetainedReceiptIdentity(
        activityId: 'activity',
        token: 'abcdefghijklmnopqrstuv',
        canonicalCommand: '{}',
        generation: 2,
        sequence: 4,
      );
      expect(
        compatibleRetained,
        isA<storage.LearningRetainedReceiptIdentity>(),
      );
      expect(retained.activityId, compatibleRetained.activityId);
      expect(retained.token, compatibleRetained.token);
      expect(retained.canonicalCommand, compatibleRetained.canonicalCommand);
      expect(retained.generation, compatibleRetained.generation);
      expect(retained.sequence, compatibleRetained.sequence);
    },
  );
}
