import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/course_learning_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/course_learning_preferences_harness.dart';

class _Transport implements LearningCloudTransport {
  bool offline = true;
  final List<List<SupportedCloudEvent>> sent = [];

  @override
  Future<void> send(List<SupportedCloudEvent> events) async {
    sent.add(List.unmodifiable(events));
    if (offline) throw StateError('offline');
  }
}

void main() {
  test('supported backup retries stable IDs without mixing guest local history',
      () async {
    SharedPreferences.setMockInitialValues({});
    final guest = PreferencesLearningHarness();
    await guest.start('lesson:en-fr-u-y');
    await guest.answerPilot('u');

    final transport = _Transport();
    final account = PreferencesLearningHarness(
      owner: LearningOwner.account('sync-user'),
      cloud: transport,
    );
    await account.start('lesson:en-fr-u-y');
    await account.answerPilot('u');
    final pendingBefore = (await account.store.load()).pending;
    expect(pendingBefore, hasLength(1));

    final failed = await account.store.sync();
    expect(failed.status, SupportedSyncStatus.pending);
    expect((await account.store.load()).pending.map((event) => event.id),
        [pendingBefore.single.id]);
    transport.offline = false;
    final delivered = await account.store.sync();
    expect(delivered.status, SupportedSyncStatus.synced);
    expect(transport.sent.last.single.id, pendingBefore.single.id);
    expect((await account.store.load()).pending, isEmpty);

    final guestState = await guest.store.load();
    expect(guestState.history, hasLength(1));
    expect(guestState.pending, isEmpty);
    expect((await guest.store.sync()).status, SupportedSyncStatus.guest);
  });
}
