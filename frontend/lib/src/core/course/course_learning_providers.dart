import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import 'comparison_content.dart';
import 'comparison_learning_state.dart';
import 'comparison_learning_store.dart';
import 'comparison_learning_transition.dart';
import 'french_comparison_content.dart';
import 'backend.dart';
import 'course_attempt.dart';
import 'course_learning_registry.dart';
import 'course_learning_state.dart';
import 'course_learning_store.dart';
import 'course_learning_sync.dart';
import 'course_learning_transition.dart';
import 'storage/comparison_learning_sql_repository.dart';
import 'storage/course_learning_sql_repository.dart';
import 'storage/learning_database.dart'
    show LearningDatabase, LearningDatabaseHandle;
import 'storage/learning_database_connection.dart';

class LearningAuthTracker extends StateNotifier<LearningAuthScope> {
  LearningAuthTracker({required LearningOwner owner, required bool ready})
      : super(LearningAuthScope(owner: owner, generation: 0, ready: ready)) {
    _current = state;
  }

  late LearningAuthScope _current;

  LearningAuthScope get current => _current;

  void observe({required LearningOwner owner, required bool ready}) {
    final generation = _current.generation + (_current.owner == owner ? 0 : 1);
    _current = LearningAuthScope(
      owner: owner,
      generation: generation,
      ready: ready,
    );
    state = _current;
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

final learningDatabaseHandleProvider =
    Provider<LearningDatabaseHandle>((ref) {
  final handle = LearningDatabaseHandle(
      open: () async {
        final connection = await openLearningDatabaseConnection();
        return LearningDatabase.openValidated(connection.connection);
      });
  ref.onDispose(() => unawaited(handle.close()));
  return handle;
});

final learningCloudTransportProvider = Provider<LearningCloudTransport?>((ref) {
  final client = courseBackend;
  return client == null ? null : SupabaseLearningCloudTransport(client);
});

final _courseLearningStateRevisionProvider = StateProvider<int>((ref) => 0);

final courseLearningStoreProvider = Provider<CourseLearningStore>((ref) {
  var isAlive = true;
  ref.onDispose(() => isAlive = false);
  final identity = ref.watch(learningAuthScopeProvider
      .select((auth) => (owner: auth.owner, generation: auth.generation)));
  final tracker = ref.read(learningAuthScopeProvider.notifier);
  final stateRevision = ref.read(_courseLearningStateRevisionProvider.notifier);
  final database = ref.watch(learningDatabaseHandleProvider);
  final registry = ref.watch(learningRegistryProvider);
  final cloud = ref.watch(learningCloudTransportProvider);
  final scope = LearningScope(courseId: 'en-fr', owner: identity.owner);
  return SqliteCourseLearningRepository(
      database: database,
      scope: scope,
      authGeneration: identity.generation,
      currentAuth: () => tracker.current,
      backendOwner: _backendOwner,
      transitions: LearningTransitionEngine(registry),
      cloud: cloud,
      clock: () => DateTime.now().toUtc(),
      newToken: _newToken,
      random: Random.secure(),
      onCommitted: () {
        if (!isAlive) return;
        final current = tracker.current;
        if (current.owner != identity.owner ||
            current.generation != identity.generation ||
            _backendOwner() != identity.owner) {
          return;
        }
        try {
          stateRevision.state++;
        } catch (_) {
          // Notification is best-effort and never changes a durable commit.
        }
      });
});

String _newToken() => _base64UrlToken();

String _base64UrlToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

final FutureProvider<CourseLearningState> courseLearningStateProvider =
    FutureProvider<CourseLearningState>((ref) {
  ref.watch(_courseLearningStateRevisionProvider);
  return ref.watch(courseLearningStoreProvider).load();
});

final _comparisonLearningStateRevisionProvider = StateProvider<int>((ref) => 0);

final comparisonCatalogueProvider =
    Provider<ComparisonCatalogue>((ref) => loadFrenchComparisonCatalogue());

final uyDemoComparisonCatalogueProvider = Provider<ComparisonCatalogue>(
  (ref) => loadFrenchUyDemoComparisonCatalogue(),
);

final comparisonCatalogueRegistryProvider =
    Provider<ComparisonCatalogueRegistry>((ref) {
      final mixed = ref.watch(comparisonCatalogueProvider);
      late final ComparisonCatalogueRegistration uyDemoRegistration;
      try {
        final catalogue = ref.watch(uyDemoComparisonCatalogueProvider);
        if (catalogue.activityId != uyDemoComparisonActivityId ||
            catalogue.sectionId != uyDemoComparisonActivityId) {
          throw const FormatException(
            'The dedicated comparison catalogue identity is invalid.',
          );
        }
        uyDemoRegistration = ComparisonCatalogueRegistration.available(
          catalogue,
        );
      } on ComparisonContentValidationException catch (error) {
        uyDemoRegistration = ComparisonCatalogueRegistration.unavailable(
          activityId: uyDemoComparisonActivityId,
          cause: error,
        );
      } on FormatException catch (error) {
        uyDemoRegistration = ComparisonCatalogueRegistration.unavailable(
          activityId: uyDemoComparisonActivityId,
          cause: error,
        );
      }
      return ComparisonCatalogueRegistry([
        ComparisonCatalogueRegistration.available(mixed),
        uyDemoRegistration,
      ]);
    });

final comparisonLearningStoreProvider =
    Provider<ComparisonLearningStore>((ref) {
  var isAlive = true;
  ref.onDispose(() => isAlive = false);
  final identity = ref.watch(learningAuthScopeProvider
      .select((auth) => (owner: auth.owner, generation: auth.generation)));
  final tracker = ref.read(learningAuthScopeProvider.notifier);
  final stateRevision =
      ref.read(_comparisonLearningStateRevisionProvider.notifier);
  final database = ref.watch(learningDatabaseHandleProvider);
  final registry = ref.watch(comparisonCatalogueRegistryProvider);
  return SqliteComparisonLearningRepository(
      database: database,
      scope: ComparisonProfileScope(courseId: 'en-fr', owner: identity.owner),
      authGeneration: identity.generation,
      currentAuth: () => tracker.current,
      backendOwner: _backendOwner,
      transitions: ComparisonLearningTransitionEngine(registry: registry),
      clock: () => DateTime.now().toUtc(),
      newToken: _newToken,
      onCommitted: () {
        if (!isAlive) return;
        final current = tracker.current;
        if (current.owner != identity.owner ||
            current.generation != identity.generation) {
          return;
        }
        if (_backendOwner() != identity.owner) return;
        try {
          stateRevision.state++;
        } catch (_) {
          // Notification is best-effort; the durable commit is already ACKed.
        }
      });
});

final FutureProvider<ComparisonLearningState> comparisonLearningStateProvider =
    FutureProvider<ComparisonLearningState>((ref) {
  ref.watch(_comparisonLearningStateRevisionProvider);
  ref.watch(comparisonCatalogueRegistryProvider);
  return ref.watch(comparisonLearningStoreProvider).load();
});
