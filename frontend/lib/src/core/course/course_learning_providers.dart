import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'backend.dart';
import 'course_attempt.dart';
import 'course_learning_persistence.dart';
import 'course_learning_registry.dart';
import 'course_learning_state.dart';
import 'course_learning_store.dart';
import 'course_learning_sync.dart';
import 'course_learning_transition.dart';

class LearningAuthTracker extends StateNotifier<LearningAuthScope> {
  LearningAuthTracker({required LearningOwner owner, required bool ready})
      : super(LearningAuthScope(owner: owner, generation: 0, ready: ready));

  LearningAuthScope get current => state;

  void observe({required LearningOwner owner, required bool ready}) {
    final generation = state.generation + (state.owner == owner ? 0 : 1);
    state =
        LearningAuthScope(owner: owner, generation: generation, ready: ready);
  }
}

LearningOwner _backendOwner() {
  final userId = courseBackend?.auth.currentUser?.id;
  return userId == null ? LearningOwner.guest() : LearningOwner.account(userId);
}

final learningAuthScopeProvider =
    StateNotifierProvider<LearningAuthTracker, LearningAuthScope>((ref) {
  final auth = ref.read(authControllerProvider);
  final initialOwner = auth.user == null
      ? _backendOwner()
      : LearningOwner.account(auth.user!.id);
  final tracker = LearningAuthTracker(
      owner: initialOwner, ready: !auth.isLoading && auth.error == null);
  ref.listen<AppAuthState>(authControllerProvider, (_, next) {
    final owner = next.user == null
        ? _backendOwner()
        : LearningOwner.account(next.user!.id);
    tracker.observe(owner: owner, ready: !next.isLoading && next.error == null);
  });
  return tracker;
});

final learningRegistryProvider =
    Provider<LearningRegistry>((ref) => LearningRegistry.french());

final learningPersistenceProvider = Provider<LearningPersistence>((ref) =>
    PreferencesLearningPersistence(preferences: SharedPreferences.getInstance));

final learningCloudTransportProvider = Provider<LearningCloudTransport?>((ref) {
  final client = courseBackend;
  return client == null ? null : SupabaseLearningCloudTransport(client);
});

final courseLearningStoreProvider = Provider<CourseLearningStore>((ref) {
  final identity = ref.watch(learningAuthScopeProvider
      .select((auth) => (owner: auth.owner, generation: auth.generation)));
  final tracker = ref.read(learningAuthScopeProvider.notifier);
  final persistence = ref.watch(learningPersistenceProvider);
  final registry = ref.watch(learningRegistryProvider);
  final cloud = ref.watch(learningCloudTransportProvider);
  final scope = LearningScope(courseId: 'en-fr', owner: identity.owner);
  return CourseLearningRepository(
      scope: scope,
      authGeneration: identity.generation,
      currentAuth: () => tracker.current,
      backendOwner: _backendOwner,
      persistence: persistence,
      transitions: LearningTransitionEngine(registry),
      cloud: cloud,
      clock: () => DateTime.now().toUtc(),
      newToken: _newToken,
      random: Random.secure(),
      onCommitted: () => ref.invalidate(courseLearningStateProvider));
});

String _newToken() => _base64UrlToken();

String _base64UrlToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

final FutureProvider<CourseLearningState> courseLearningStateProvider =
    FutureProvider<CourseLearningState>((ref) {
  return ref.watch(courseLearningStoreProvider).load();
});
