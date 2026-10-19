import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/storage/learning_database_connection.dart';

void main() {
  test('accepts only coordinated persistent implementations', () {
    expect(acceptsLearningWebImplementation('opfsShared'), isTrue);
    expect(acceptsLearningWebImplementation('opfsLocks'), isTrue);
    expect(acceptsLearningWebImplementation('sharedIndexedDb'), isTrue);
    expect(acceptsLearningWebImplementation('unsafeIndexedDb'), isFalse);
    expect(acceptsLearningWebImplementation('inMemory'), isFalse);
  });
}
