import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_persistence.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_sync.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _AuthNotifier extends AuthController {
  _AuthNotifier() : super(null) {
    emit(const AppAuthState(isLoading: true));
  }
  void emit(AppAuthState value) => state = value;
}

class _MemoryPersistence implements LearningPersistence {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> restore(String key, String? lastCommitted) async {
    if (lastCommitted == null) {
      values.remove(key);
    } else {
      values[key] = lastCommitted;
    }
  }

  @override
  Future<void> reload() async {}
}

User _user(String id) => User.fromJson({
      'id': id,
      'aud': 'authenticated',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': '2026-01-01T00:00:00Z',
    })!;

void main() {
  test('provider rebuild tracks owner epoch, not only equal final id',
      () async {
    final persistence = _MemoryPersistence();
    final auth = _AuthNotifier();
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith((ref) => auth),
      learningPersistenceProvider.overrideWithValue(persistence),
      learningCloudTransportProvider.overrideWithValue(null),
    ]);
    addTearDown(container.dispose);
    final tracker = container.read(learningAuthScopeProvider.notifier);
    final initial = tracker.current;
    expect(initial.ready, isFalse);
    auth.emit(AppAuthState(user: _user('A')));
    await Future<void>.delayed(Duration.zero);
    final originalStore = container.read(courseLearningStoreProvider);
    final firstEpoch = tracker.current.generation;
    auth.emit(AppAuthState(user: _user('B')));
    await Future<void>.delayed(Duration.zero);
    auth.emit(AppAuthState(user: _user('A')));
    await Future<void>.delayed(Duration.zero);
    final returnedStore = container.read(courseLearningStoreProvider);
    expect(tracker.current.owner.userId, 'A');
    expect(tracker.current.generation, firstEpoch + 2);
    expect(identical(returnedStore, originalStore), isFalse);
    final returnedEpoch = tracker.current.generation;
    auth.emit(AppAuthState(user: _user('A'), isLoading: true));
    await Future<void>.delayed(Duration.zero);
    auth.emit(AppAuthState(user: _user('A'), error: 'temporary auth error'));
    await Future<void>.delayed(Duration.zero);
    expect(tracker.current.generation, returnedEpoch);
    expect(tracker.current.ready, isFalse);
  });

  test('initial loading cannot save into guest scope', () async {
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith((ref) => _AuthNotifier()),
      learningPersistenceProvider.overrideWithValue(_MemoryPersistence()),
      learningCloudTransportProvider.overrideWithValue(null),
    ]);
    addTearDown(container.dispose);
    final store = container.read(courseLearningStoreProvider);
    expect(store.scope.owner.isGuest, isTrue);
    final state = await store.load();
    expect(
        () => store.prepare(
            state: state,
            activityId: 'lesson:en-fr-u-y',
            action: StartLearningRun(options: RunOptions())),
        throwsA(isA<LearningOwnerChangedException>()));
  });

  test('same-owner auth readiness updates do not change generation', () {
    final tracker =
        LearningAuthTracker(owner: LearningOwner.account('A'), ready: true);
    final generation = tracker.current.generation;
    tracker.observe(owner: LearningOwner.account('A'), ready: false);
    tracker.observe(owner: LearningOwner.account('A'), ready: true);
    expect(tracker.current.generation, generation);
    expect(tracker.current.ready, isTrue);
    tracker.dispose();
  });

  test('supported synced status does not claim detailed history backup', () {
    const result = SupportedSyncResult(
        status: SupportedSyncStatus.synced, remainingEvents: 0);
    expect(result.status, SupportedSyncStatus.synced);
    expect(result.remainingEvents, 0);
  });
}
