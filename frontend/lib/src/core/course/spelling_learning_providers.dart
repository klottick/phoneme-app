import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backend.dart';
import 'course_attempt.dart';
import 'course_learning_error.dart';
import 'course_learning_providers.dart'
    show learningAuthScopeProvider, learningDatabaseHandleProvider;
import 'french_uy_demo_spelling_content.dart';
import 'spelling_learning_state.dart';
import 'spelling_learning_store.dart';
import 'spelling_learning_transition.dart';
import 'storage/learning_database.dart' show LearningDatabaseHandle;
import 'storage/spelling_learning_sql_repository.dart';

final _spellingLearningStateRevisionProvider = StateProvider<int>((ref) => 0);

final spellingCatalogueProvider = Provider<FrenchUyDemoSpellingCatalogue>(
  (ref) => loadFrenchUyDemoSpellingCatalogue(),
);

final spellingLearningStoreProvider = Provider<SpellingLearningStore>((ref) {
  var isAlive = true;
  ref.onDispose(() => isAlive = false);

  final identity = ref.watch(
    learningAuthScopeProvider.select(
      (auth) =>
          (owner: auth.owner, generation: auth.generation, ready: auth.ready),
    ),
  );
  if (!identity.ready) throw const LearningOwnerChangedException();

  final tracker = ref.read(learningAuthScopeProvider.notifier);
  final stateRevision = ref.read(
    _spellingLearningStateRevisionProvider.notifier,
  );
  final LearningDatabaseHandle database = ref.watch(
    learningDatabaseHandleProvider,
  );
  final catalogue = ref.watch(spellingCatalogueProvider);

  LearningOwner backendOwner() {
    final String? userId = courseBackend?.auth.currentUser?.id;
    return userId == null
        ? LearningOwner.guest()
        : LearningOwner.account(userId);
  }

  final current = tracker.current;
  if (!isAlive ||
      !current.ready ||
      current.owner != identity.owner ||
      current.generation != identity.generation ||
      backendOwner() != identity.owner) {
    throw const LearningOwnerChangedException();
  }

  return SqliteSpellingLearningRepository(
    database: database,
    scope: SpellingProfileScope(courseId: 'en-fr', owner: identity.owner),
    authGeneration: identity.generation,
    currentAuth: () => tracker.current,
    backendOwner: backendOwner,
    transitions: SpellingLearningTransitionEngine(catalogue: catalogue),
    clock: () => DateTime.now().toUtc(),
    newToken: _newSpellingToken,
    onCommitted: () {
      if (!isAlive) return;
      final current = tracker.current;
      if (!current.ready ||
          current.owner != identity.owner ||
          current.generation != identity.generation ||
          backendOwner() != identity.owner) {
        return;
      }
      try {
        stateRevision.state++;
      } on Object {
        // Durable acknowledgment is independent of best-effort notification.
      }
    },
  );
});

final FutureProvider<SpellingLearningState> spellingLearningStateProvider =
    FutureProvider<SpellingLearningState>((ref) async {
      var isAlive = true;
      ref.onDispose(() => isAlive = false);

      ref.watch(_spellingLearningStateRevisionProvider);
      final identity = ref.watch(
        learningAuthScopeProvider.select(
          (auth) => (
            owner: auth.owner,
            generation: auth.generation,
            ready: auth.ready,
          ),
        ),
      );
      if (!identity.ready) throw const LearningOwnerChangedException();

      final tracker = ref.read(learningAuthScopeProvider.notifier);
      final store = ref.watch(spellingLearningStoreProvider);
      final afterAcquisition = tracker.current;
      final acquiredBackendOwner = _currentBackendOwner();
      if (!isAlive ||
          !afterAcquisition.ready ||
          afterAcquisition.owner != identity.owner ||
          afterAcquisition.generation != identity.generation ||
          acquiredBackendOwner != identity.owner ||
          store.scope.owner != identity.owner) {
        throw const LearningOwnerChangedException();
      }

      final state = await store.load();
      final afterLoad = tracker.current;
      if (!isAlive ||
          !afterLoad.ready ||
          afterLoad.owner != identity.owner ||
          afterLoad.generation != identity.generation ||
          _currentBackendOwner() != identity.owner ||
          store.scope.owner != identity.owner ||
          state.scope.owner != identity.owner) {
        throw const LearningOwnerChangedException();
      }
      return state;
    });

String _newSpellingToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

LearningOwner _currentBackendOwner() {
  final String? userId = courseBackend?.auth.currentUser?.id;
  return userId == null ? LearningOwner.guest() : LearningOwner.account(userId);
}
