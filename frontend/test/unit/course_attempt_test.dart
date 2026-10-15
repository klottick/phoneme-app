import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import '../support/course_learning_fixtures.dart';

void main() {
  test('composite keys cannot alias owners or targets', () {
    expect(guestScope.storageKey, isNot(accountAScope.storageKey));
    expect(accountAScope.storageKey, isNot(accountBScope.storageKey));
    expect(accountAScope.storageKey, isNot(guestScope.storageKey));
    expect(accountAScope.owner.userId, 'account/a');
    expect(
        LearningScope(courseId: 'a.b', owner: accountAScope.owner).storageKey,
        isNot(LearningScope(courseId: 'a', owner: LearningOwner.account('b/c'))
            .storageKey));
  });
}
