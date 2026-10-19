import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backend.dart';
import 'course_attempt.dart';
import 'course_learning_error.dart';
import 'course_learning_providers.dart'
    show learningAuthScopeProvider, learningDatabaseHandleProvider;
import 'french_sentence_package.dart' show sentenceHuntCatalogueProvider;
import 'sentence_hunt_content.dart';
import 'sentence_hunt_learning_transition.dart';
import 'sentence_hunt_learning_state.dart';
import 'sentence_hunt_learning_store.dart';
import 'storage/learning_database.dart';
import 'storage/sentence_hunt_learning_sql_repository.dart';

final _sentenceHuntLearningStateRevisionProvider =
    StateProvider<int>((ref) => 0);

final FutureProvider<SentenceHuntLearningStore>
    sentenceHuntLearningStoreProvider =
    FutureProvider<SentenceHuntLearningStore>((ref) async {
  var isAlive = true;
  ref.onDispose(() => isAlive = false);

  final identity = ref.watch(learningAuthScopeProvider.select((auth) => (
        owner: auth.owner,
        generation: auth.generation,
        ready: auth.ready,
      )));
  if (!identity.ready) throw const LearningOwnerChangedException();

  final tracker = ref.read(learningAuthScopeProvider.notifier);
  final stateRevision =
      ref.read(_sentenceHuntLearningStateRevisionProvider.notifier);
  final LearningDatabaseHandle database =
      ref.watch(learningDatabaseHandleProvider);
  final SentenceHuntCatalogue catalogue =
      await ref.watch(sentenceHuntCatalogueProvider.future);

  LearningOwner backendOwner() {
    final String? userId = courseBackend?.auth.currentUser?.id;
    return userId == null
        ? LearningOwner.guest()
        : LearningOwner.account(userId);
  }

  final LearningAuthScope current = tracker.current;
  if (!isAlive ||
      !current.ready ||
      current.owner != identity.owner ||
      current.generation != identity.generation ||
      backendOwner() != identity.owner) {
    throw const LearningOwnerChangedException();
  }

  return SqliteSentenceHuntLearningRepository(
    database: database,
    scope: SentenceHuntProfileScope(courseId: 'en-fr', owner: identity.owner),
    authGeneration: identity.generation,
    currentAuth: () => tracker.current,
    backendOwner: backendOwner,
    transitions: SentenceHuntTransitionEngine(catalogue: catalogue),
    clock: () => DateTime.now().toUtc(),
    newToken: _newSentenceHuntToken,
    onCommitted: () {
      if (!isAlive) return;
      final LearningAuthScope current = tracker.current;
      if (!current.ready ||
          current.owner != identity.owner ||
          current.generation != identity.generation ||
          backendOwner() != identity.owner) {
        return;
      }
      try {
        stateRevision.state++;
      } catch (_) {
        // Durable acknowledgment is independent of observer notification.
      }
    },
  );
});

final FutureProvider<SentenceHuntState> sentenceHuntLearningStateProvider =
    FutureProvider<SentenceHuntState>((ref) async {
  var isAlive = true;
  ref.onDispose(() => isAlive = false);

  ref.watch(_sentenceHuntLearningStateRevisionProvider);
  final identity = ref.watch(learningAuthScopeProvider.select((auth) => (
        owner: auth.owner,
        generation: auth.generation,
        ready: auth.ready,
      )));
  if (!identity.ready) throw const LearningOwnerChangedException();

  final tracker = ref.read(learningAuthScopeProvider.notifier);
  final SentenceHuntLearningStore store =
      await ref.watch(sentenceHuntLearningStoreProvider.future);
  final LearningAuthScope afterAcquisition = tracker.current;
  final String? acquiredBackendUserId = courseBackend?.auth.currentUser?.id;
  final LearningOwner acquiredBackendOwner = acquiredBackendUserId == null
      ? LearningOwner.guest()
      : LearningOwner.account(acquiredBackendUserId);
  if (!isAlive ||
      !afterAcquisition.ready ||
      afterAcquisition.owner != identity.owner ||
      afterAcquisition.generation != identity.generation ||
      acquiredBackendOwner != identity.owner ||
      store.scope.owner != identity.owner) {
    throw const LearningOwnerChangedException();
  }

  final SentenceHuntState state = await store.load();
  final LearningAuthScope afterLoad = tracker.current;
  final String? backendUserId = courseBackend?.auth.currentUser?.id;
  final LearningOwner currentBackendOwner = backendUserId == null
      ? LearningOwner.guest()
      : LearningOwner.account(backendUserId);
  if (!isAlive ||
      !afterLoad.ready ||
      afterLoad.owner != identity.owner ||
      afterLoad.generation != identity.generation ||
      currentBackendOwner != identity.owner ||
      state.scope.owner != identity.owner) {
    throw const LearningOwnerChangedException();
  }
  return state;
});

String _newSentenceHuntToken() {
  final Random random = Random.secure();
  final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}
