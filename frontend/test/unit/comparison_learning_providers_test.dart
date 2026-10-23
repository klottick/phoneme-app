import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/comparison_learning_command.dart';
import 'package:linguist/src/core/course/comparison_learning_state.dart';
import 'package:linguist/src/core/course/comparison_learning_transition.dart';
import 'package:linguist/src/core/course/storage/comparison_learning_sql_repository.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabase, LearningDatabaseHandle;
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_command.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/course_learning_state.dart';
import 'package:linguist/src/core/course/backend.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_providers.dart'
    show sentenceHuntLearningStateProvider;
import 'package:linguist/src/core/services/auth_service.dart';
import 'package:linguist/src/core/course/french_comparison_content.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class _ProviderAuth extends AuthController {
  _ProviderAuth() : super(null) {
    emit(const AppAuthState(isLoading: true));
  }
  void emit(AppAuthState value) => state = value;
}

final class _OverridableCurrentTracker extends LearningAuthTracker {
  _OverridableCurrentTracker()
    : super(owner: LearningOwner.guest(), ready: true);
  LearningAuthScope? currentOverride;
  @override
  LearningAuthScope get current => currentOverride ?? super.current;
}

final class _Harness {
  _Harness(this.auth, this.database, this.container);
  final _ProviderAuth auth;
  final _ProviderDatabase database;
  final ProviderContainer container;
  bool _containerDisposed = false;

  void disposeContainer() {
    if (_containerDisposed) return;
    _containerDisposed = true;
    container.dispose();
  }

  Future<void> close() async {
    disposeContainer();
    await database.close();
    courseBackend = null;
  }
}

Future<_Harness> _harness({List<Override> extraOverrides = const []}) async {
  courseBackend = null;
  final auth = _ProviderAuth();
  final database = await _newProviderDatabase();
  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith((ref) => auth),
      learningDatabaseHandleProvider.overrideWithValue(database.handle),
      ...extraOverrides,
    ],
  );
  container.read(learningAuthScopeProvider);
  auth.emit(const AppAuthState());
  await Future<void>.delayed(Duration.zero);
  return _Harness(auth, database, container);
}

void main() {
  const activity = comparisonActivityId;

  test('comparison provider declarations are lazy until read', () async {
    var catalogueCalls = 0;
    final h = await _harness(
      extraOverrides: [
        comparisonCatalogueProvider.overrideWith((ref) {
          catalogueCalls++;
          return loadFrenchComparisonCatalogue();
        }),
      ],
    );
    addTearDown(h.close);
    expect(catalogueCalls, 0);
    final store =
        h.container.read(comparisonLearningStoreProvider)
            as SqliteComparisonLearningRepository;
    expect(catalogueCalls, 1);
    expect(store, isA<SqliteComparisonLearningRepository>());
    expect(
      h.database.openCalls,
      0,
      reason: 'constructing the real store must not open SQLite',
    );
  });

  test('catalogue failure precedes persistence access', () async {
    final h = await _harness(
      extraOverrides: [
        comparisonCatalogueProvider.overrideWith(
          (ref) => throw StateError('catalogue invalid'),
        ),
      ],
    );
    addTearDown(h.close);
    expect(
      () => h.container.read(comparisonLearningStoreProvider),
      throwsA(isA<StateError>()),
    );
    expect(
      h.database.openCalls,
      0,
      reason: 'catalogue failure must precede database opening',
    );
  });

  test('invalid dedicated catalogue is local to mixed comparison', () async {
    final h = await _harness(
      extraOverrides: [
        uyDemoComparisonCatalogueProvider.overrideWith(
          (ref) => loadFrenchComparisonCatalogue(),
        ),
      ],
    );
    addTearDown(h.close);

    final mixed = h.container.read(comparisonCatalogueProvider);
    final registry = h.container.read(comparisonCatalogueRegistryProvider);
    expect(mixed.activityId, comparisonActivityId);
    expect(registry.requireAvailable(comparisonActivityId), same(mixed));
    final unavailable = registry.registrationFor(uyDemoComparisonActivityId);
    expect(unavailable, isNotNull);
    expect(unavailable!.catalogue, equals(null));
    expect(unavailable.cause, isA<FormatException>());

    final store =
        h.container.read(comparisonLearningStoreProvider)
            as SqliteComparisonLearningRepository;
    expect(identical(store.transitions.registry, registry), isTrue);
    expect(h.database.openCalls, 0);
    final state = await store.load();
    expect(state.slots, isEmpty);
    expect(
      store.prepare(
        state: state,
        activityId: comparisonActivityId,
        action: StartComparisonRun(
          sessionId: 'mixed-still-available',
          policy: LessonPolicy(),
        ),
      ),
      isA<ComparisonLearningCommand>(),
    );
    expect(
      () => store.prepare(
        state: state,
        activityId: uyDemoComparisonActivityId,
        action: StartComparisonRun(
          sessionId: 'dedicated-unavailable',
          policy: LessonPolicy(),
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('comparison store tracks registry availability changes', () async {
    var dedicatedAvailable = true;
    final h = await _harness(
      extraOverrides: [
        uyDemoComparisonCatalogueProvider.overrideWith((ref) {
          if (!dedicatedAvailable) {
            throw const FormatException('dedicated catalogue unavailable');
          }
          return loadFrenchUyDemoComparisonCatalogue();
        }),
      ],
    );
    addTearDown(h.close);

    final availableStore =
        h.container.read(comparisonLearningStoreProvider)
            as SqliteComparisonLearningRepository;
    final availableRegistry = h.container.read(
      comparisonCatalogueRegistryProvider,
    );
    expect(availableStore.transitions.registry, same(availableRegistry));

    dedicatedAvailable = false;
    h.container.invalidate(uyDemoComparisonCatalogueProvider);
    final unavailableRegistry = h.container.read(
      comparisonCatalogueRegistryProvider,
    );
    final unavailableStore =
        h.container.read(comparisonLearningStoreProvider)
            as SqliteComparisonLearningRepository;

    expect(
      unavailableRegistry
          .registrationFor(uyDemoComparisonActivityId)!
          .catalogue,
      equals(null),
    );
    expect(unavailableStore, isNot(same(availableStore)));
    expect(unavailableStore.transitions.registry, same(unavailableRegistry));
    expect(h.database.openCalls, 0);
  });

  test(
    'mixed catalogue failures are not masked by registry fallback',
    () async {
      final h = await _harness(
        extraOverrides: [
          comparisonCatalogueProvider.overrideWith(
            (ref) => loadFrenchUyDemoComparisonCatalogue(),
          ),
        ],
      );
      addTearDown(h.close);

      expect(
        () => h.container.read(comparisonCatalogueRegistryProvider),
        throwsA(isA<FormatException>()),
      );
      expect(h.database.openCalls, 0);
    },
  );

  test(
    'unknown comparison corruption does not block other family providers',
    () async {
      final h = await _harness();
      addTearDown(h.close);
      final store = h.container.read(comparisonLearningStoreProvider);
      final empty = await store.load();
      await store.submit(
        store.prepare(
          state: empty,
          activityId: comparisonActivityId,
          action: StartComparisonRun(
            sessionId: 'independent-families',
            policy: LessonPolicy(),
          ),
        ),
      );

      final db = await h.database.handle.open();
      final scopeId =
          (await db
                  .customSelect(
                    "SELECT id FROM learning_scopes WHERE family = 'comparison'",
                  )
                  .getSingle())
              .read<int>('id');
      await db.customStatement(
        'INSERT INTO learning_completions '
        '(scope_id, activity_id, content_revision, policy_kind, '
        'policy_revision, threshold_percent, committed_at_us) '
        "VALUES (?, 'unknown-comparison-activity', 1, 'discoveryThreshold', 1, 80, ?)",
        [scopeId, DateTime.utc(2026, 10, 23).microsecondsSinceEpoch],
      );

      await expectLater(store.load(), throwsA(isA<LearningCorruptException>()));
      expect(
        (await h.container.read(courseLearningStateProvider.future)).revision,
        0,
      );
      expect(
        (await h.container.read(
          sentenceHuntLearningStateProvider.future,
        )).revision,
        0,
      );
    },
  );

  test('comparison commits without constructing cloud transport', () async {
    final h = await _harness(
      extraOverrides: [
        learningCloudTransportProvider.overrideWith(
          (ref) => throw StateError('cloud must not be read'),
        ),
      ],
    );
    addTearDown(h.close);
    final store = h.container.read(comparisonLearningStoreProvider);
    final state = await store.load();
    final command = store.prepare(
      state: state,
      activityId: activity,
      action: StartComparisonRun(sessionId: 'no-cloud', policy: LessonPolicy()),
    );
    expect((await store.submit(command)).state.slot, isNotNull);
    final db = await h.database.handle.open();
    expect(
      await _scopeRevision(db, family: 'comparison', owner: store.scope.owner),
      1,
    );
  });

  test(
    'readiness changes preserve provider identity and fence prepare',
    () async {
      final h = await _harness();
      addTearDown(h.close);
      final store = h.container.read(comparisonLearningStoreProvider);
      final generation = h.container.read(learningAuthScopeProvider).generation;
      final state = await store.load();
      h.auth.emit(const AppAuthState(isLoading: true));
      await Future<void>.delayed(Duration.zero);
      expect(
        h.container.read(learningAuthScopeProvider).generation,
        generation,
      );
      expect(
        identical(h.container.read(comparisonLearningStoreProvider), store),
        isTrue,
      );
      await expectLater(
        () => store.prepare(
          state: state,
          activityId: activity,
          action: StartComparisonRun(
            sessionId: 'blocked',
            policy: LessonPolicy(),
          ),
        ),
        throwsA(isA<LearningOwnerChangedException>()),
      );
      await expectLater(
        store.load(),
        throwsA(isA<LearningOwnerChangedException>()),
      );
      h.auth.emit(const AppAuthState());
      await Future<void>.delayed(Duration.zero);
      expect(
        identical(h.container.read(comparisonLearningStoreProvider), store),
        isTrue,
      );
      expect(
        store.prepare(
          state: state,
          activityId: activity,
          action: StartComparisonRun(
            sessionId: 'recovered',
            policy: LessonPolicy(),
          ),
        ),
        isA<ComparisonLearningCommand>(),
      );
    },
  );

  test(
    'comparison and v2 state providers refresh only their own family',
    () async {
      final h = await _harness();
      addTearDown(h.close);
      final comparison = h.container.read(comparisonLearningStoreProvider);
      final v2 = h.container.read(courseLearningStoreProvider);
      final comparisonSubscription = h.container.listen(
        comparisonLearningStateProvider,
        (_, __) {},
        fireImmediately: true,
      );
      final v2Subscription = h.container.listen(
        courseLearningStateProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(comparisonSubscription.close);
      addTearDown(v2Subscription.close);
      await h.container.read(comparisonLearningStateProvider.future);
      await h.container.read(courseLearningStateProvider.future);
      var comparisonNotifications = 0;
      var courseNotifications = 0;
      final comparisonListener = h.container.listen(
        comparisonLearningStateProvider,
        (_, __) => comparisonNotifications++,
      );
      final courseListener = h.container.listen(
        courseLearningStateProvider,
        (_, __) => courseNotifications++,
      );
      addTearDown(comparisonListener.close);
      addTearDown(courseListener.close);
      final comparisonBefore = comparisonNotifications;
      final courseBefore = courseNotifications;
      final cState = await comparison.load();
      await comparison.submit(
        comparison.prepare(
          state: cState,
          activityId: activity,
          action: StartComparisonRun(
            sessionId: 'refresh-c',
            policy: LessonPolicy(),
          ),
        ),
      );
      await h.container.read(comparisonLearningStateProvider.future);
      final cNotificationsAfterCommit = comparisonNotifications;
      expect(cNotificationsAfterCommit, greaterThan(comparisonBefore));
      expect(
        courseNotifications,
        courseBefore,
        reason: 'comparison commits must not refresh course state',
      );
      final vState = await v2.load();
      await v2.submit(
        v2.prepare(
          state: vState,
          activityId: 'lesson:en-fr-u-y',
          action: StartLearningRun(options: RunOptions()),
        ),
      );
      await h.container.read(courseLearningStateProvider.future);
      expect(courseNotifications, greaterThan(courseBefore));
      expect(
        comparisonNotifications,
        cNotificationsAfterCommit,
        reason: 'course commits must not refresh comparison state',
      );
    },
  );

  test(
    'duplicate and rejected comparison writes do not refresh state provider',
    () async {
      final h = await _harness();
      addTearDown(h.close);
      final db = await h.database.handle.open();
      final store = h.container.read(comparisonLearningStoreProvider);
      var notifications = 0;
      final sub = h.container.listen(
        comparisonLearningStateProvider,
        (_, __) => notifications++,
        fireImmediately: true,
      );
      addTearDown(sub.close);
      await h.container.read(comparisonLearningStateProvider.future);
      final beforeFailureNotifications = notifications;
      final empty = await store.load();
      final start = store.prepare(
        state: empty,
        activityId: activity,
        action: StartComparisonRun(
          sessionId: 'no-refresh',
          policy: LessonPolicy(),
        ),
      );
      h.database.barrier.failNextLearningWrite();
      await expectLater(
        store.submit(start),
        throwsA(isA<LearningSaveException>()),
      );
      expect(notifications, beforeFailureNotifications);
      expect(
        await _scopeRevision(
          db,
          family: 'comparison',
          owner: store.scope.owner,
        ),
        0,
        reason: 'a rejected SQL transaction must leave the scope unchanged',
      );
      final retry = await store.submit(start);
      expect(retry.duplicate, isFalse);
      await h.container.read(comparisonLearningStateProvider.future);
      expect(
        await _scopeRevision(
          db,
          family: 'comparison',
          owner: store.scope.owner,
        ),
        1,
      );
      final afterCommitNotifications = notifications;
      expect(afterCommitNotifications, greaterThan(beforeFailureNotifications));
      await store.submit(start);
      await Future<void>.delayed(Duration.zero);
      expect(notifications, afterCommitNotifications);
    },
  );

  test(
    'corrupt comparison state does not block valid v2 state, and reverse',
    () async {
      final h = await _harness();
      addTearDown(h.close);
      final comparison = h.container.read(comparisonLearningStoreProvider);
      final v2 = h.container.read(courseLearningStoreProvider);
      final db = await h.database.handle.open();
      final v2Empty = await v2.load();
      final comparisonEmpty = await comparison.load();
      expect(v2Empty.revision, 0);
      expect(comparisonEmpty.revision, 0);
      await _setSchemaVersion(db, family: 'comparison', version: 99);
      h.container.invalidate(comparisonLearningStateProvider);
      h.container.invalidate(courseLearningStateProvider);
      await expectLater(
        comparison.load(),
        throwsA(isA<LearningUnsupportedVersionException>()),
      );
      expect(
        (await h.container.read(courseLearningStateProvider.future)).revision,
        0,
      );
      await _setSchemaVersion(db, family: 'comparison', version: 1);
      final compEmpty = await comparison.load();
      await comparison.submit(
        comparison.prepare(
          state: compEmpty,
          activityId: activity,
          action: StartComparisonRun(
            sessionId: 'valid-c',
            policy: LessonPolicy(),
          ),
        ),
      );
      await _setSchemaVersion(db, family: 'course', version: 99);
      expect((await comparison.load()).revision, 1);
      await expectLater(
        v2.load(),
        throwsA(isA<LearningUnsupportedVersionException>()),
      );
    },
  );

  test(
    'committed comparison write cannot ACK after an auth epoch change',
    () async {
      final client = _backendClient();
      await _signIn(client, 'B');
      final h = await _harness();
      addTearDown(() async {
        await h.close();
        await client.dispose();
      });
      final db = await h.database.handle.open();
      final store =
          h.container.read(comparisonLearningStoreProvider)
              as SqliteComparisonLearningRepository;
      var notifications = 0;
      final sub = h.container.listen(
        comparisonLearningStateProvider,
        (_, __) => notifications++,
        fireImmediately: true,
      );
      addTearDown(sub.close);
      await h.container.read(comparisonLearningStateProvider.future);
      final state = await store.load();
      final command = store.prepare(
        state: state,
        activityId: activity,
        action: StartComparisonRun(
          sessionId: 'epoch-held',
          policy: LessonPolicy(),
        ),
      );
      h.database.barrier.holdNextCommit();
      final save = store.submit(command);
      await h.database.barrier.commitEntered;
      courseBackend = client;
      h.auth.emit(AppAuthState(user: _userFor('B')));
      await Future<void>.delayed(Duration.zero);
      h.database.barrier.releaseCommit();
      await expectLater(save, throwsA(isA<LearningOwnerChangedException>()));
      final currentState = await h.container.read(
        comparisonLearningStateProvider.future,
      );
      expect(currentState.scope.owner, LearningOwner.account('B'));
      expect(currentState.revision, 0);
      expect(
        await _scopeRevision(
          db,
          family: 'comparison',
          owner: store.scope.owner,
        ),
        1,
        reason: 'the completed SQL commit remains in its captured owner scope',
      );
      final afterReplacementLoad = notifications;
      store.onCommitted!.call();
      await Future<void>.delayed(Duration.zero);
      expect(
        notifications,
        afterReplacementLoad,
        reason: 'the stale captured callback cannot refresh replacement state',
      );
    },
  );

  test('tracker owner epoch guard suppresses callback independently', () async {
    final client = _backendClient();
    await _signIn(client, 'B');
    final h = await _harness();
    addTearDown(() async {
      await h.close();
      await client.dispose();
    });
    final db = await h.database.handle.open();
    final store =
        h.container.read(comparisonLearningStoreProvider)
            as SqliteComparisonLearningRepository;
    var notifications = 0;
    final sub = h.container.listen(
      comparisonLearningStateProvider,
      (_, __) => notifications++,
      fireImmediately: true,
    );
    addTearDown(sub.close);
    await h.container.read(comparisonLearningStateProvider.future);
    final state = await store.load();
    final command = store.prepare(
      state: state,
      activityId: activity,
      action: StartComparisonRun(
        sessionId: 'tracker-guard',
        policy: LessonPolicy(),
      ),
    );
    h.database.barrier.holdNextCommit();
    final save = store.submit(command);
    await h.database.barrier.commitEntered;
    courseBackend = client;
    h.auth.emit(AppAuthState(user: _userFor('B')));
    await Future<void>.delayed(Duration.zero);
    courseBackend = null;
    h.auth.emit(const AppAuthState());
    h.database.barrier.releaseCommit();
    await expectLater(save, throwsA(isA<LearningOwnerChangedException>()));
    expect(h.container.read(learningAuthScopeProvider).owner.isGuest, isTrue);
    expect(h.container.read(learningAuthScopeProvider).generation, 2);
    expect(
      await _scopeRevision(db, family: 'comparison', owner: store.scope.owner),
      1,
    );
    final currentState = await h.container.read(
      comparisonLearningStateProvider.future,
    );
    expect(currentState.scope.owner.isGuest, isTrue);
    expect(
      currentState.revision,
      1,
      reason: 'the replacement guest epoch can reload the durable guest row',
    );
    await Future<void>.delayed(Duration.zero);
    final notificationsAfterCurrentLoad = notifications;
    store.onCommitted!.call();
    await Future<void>.delayed(Duration.zero);
    expect(
      notifications,
      notificationsAfterCurrentLoad,
      reason: 'the old generation callback cannot notify the current provider',
    );
  });

  test('captured provider callback ignores stale tracker identity', () async {
    final client = _backendClient();
    await _signIn(client, 'B');
    final h = await _harness();
    addTearDown(() async {
      await h.close();
      await client.dispose();
    });
    final store =
        h.container.read(comparisonLearningStoreProvider)
            as SqliteComparisonLearningRepository;
    var notifications = 0;
    final subscription = h.container.listen(
      comparisonLearningStateProvider,
      (_, __) => notifications++,
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await h.container.read(comparisonLearningStateProvider.future);
    courseBackend = client;
    h.auth.emit(AppAuthState(user: _userFor('B')));
    await Future<void>.delayed(Duration.zero);
    await h.container.read(comparisonLearningStateProvider.future);
    final beforeStaleCallback = notifications;
    store.onCommitted!.call();
    await Future<void>.delayed(Duration.zero);
    expect(
      notifications,
      beforeStaleCallback,
      reason: 'the old store cannot notify after auth identity replacement',
    );
  });

  test('tracker guard independently fences a stale current snapshot', () async {
    final tracker = _OverridableCurrentTracker();
    final database = await _newProviderDatabase();
    final container = ProviderContainer(
      overrides: [
        learningAuthScopeProvider.overrideWith((ref) => tracker),
        learningDatabaseHandleProvider.overrideWithValue(database.handle),
        learningCloudTransportProvider.overrideWithValue(null),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });
    final store =
        container.read(comparisonLearningStoreProvider)
            as SqliteComparisonLearningRepository;
    var notifications = 0;
    final subscription = container.listen(
      comparisonLearningStateProvider,
      (_, __) => notifications++,
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.read(comparisonLearningStateProvider.future);
    final beforeStaleSnapshot = notifications;
    tracker.currentOverride = LearningAuthScope(
      owner: LearningOwner.account('stale'),
      generation: 1,
      ready: true,
    );
    store.onCommitted!.call();
    await Future<void>.delayed(Duration.zero);
    expect(
      notifications,
      beforeStaleSnapshot,
      reason:
          'only tracker.current differs; provider identity/aliveness do not',
    );
  });

  test('backend-only owner mismatch suppresses comparison callback', () async {
    final client = _backendClient();
    await client.auth.signInWithPassword(
      email: 'backend-owner@example.invalid',
      password: 'test-password',
    );
    final h = await _harness();
    addTearDown(() async {
      await h.close();
      await client.dispose();
    });
    final store =
        h.container.read(comparisonLearningStoreProvider)
            as SqliteComparisonLearningRepository;
    final originalAuth = h.container.read(learningAuthScopeProvider);
    final sub = h.container.listen(
      comparisonLearningStateProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);
    await h.container.read(comparisonLearningStateProvider.future);
    final state = await store.load();
    final command = store.prepare(
      state: state,
      activityId: activity,
      action: StartComparisonRun(
        sessionId: 'backend-guard',
        policy: LessonPolicy(),
      ),
    );
    h.database.barrier.holdNextCommit();
    final save = store.submit(command);
    await h.database.barrier.commitEntered;
    courseBackend = client;
    h.database.barrier.releaseCommit();
    await expectLater(save, throwsA(isA<LearningOwnerChangedException>()));
    expect(h.container.read(learningAuthScopeProvider).owner.isGuest, isTrue);
    expect(
      h.container.read(learningAuthScopeProvider).generation,
      originalAuth.generation,
    );
    final db = await h.database.handle.open();
    expect(
      await _scopeRevision(db, family: 'comparison', owner: store.scope.owner),
      1,
      reason: 'backend owner changes cannot undo an already durable commit',
    );
    store.onCommitted!.call();
  });

  test(
    'disposed comparison provider suppresses callback before notifier access',
    () async {
      final h = await _harness();
      addTearDown(h.close);
      final db = await h.database.handle.open();
      final store = h.container.read(comparisonLearningStoreProvider);
      final state = await store.load();
      final command = store.prepare(
        state: state,
        activityId: activity,
        action: StartComparisonRun(
          sessionId: 'disposed',
          policy: LessonPolicy(),
        ),
      );
      h.database.barrier.holdNextCommit();
      final save = store.submit(command);
      await h.database.barrier.commitEntered;
      h.disposeContainer();
      h.database.barrier.releaseCommit();
      expect((await save).state.revision, 1);
      expect(
        await _scopeRevision(
          db,
          family: 'comparison',
          owner: store.scope.owner,
        ),
        1,
      );
    },
  );

  test(
    'throwing comparison onCommitted cannot undo durable acknowledgment',
    () async {
      final h = await _harness();
      addTearDown(h.close);
      final owner = LearningOwner.guest();
      final store = SqliteComparisonLearningRepository(
        database: h.database.handle,
        scope: ComparisonProfileScope(courseId: 'en-fr', owner: owner),
        authGeneration: 0,
        currentAuth: () =>
            LearningAuthScope(owner: owner, generation: 0, ready: true),
        backendOwner: () => owner,
        transitions: ComparisonLearningTransitionEngine(
          catalogue: loadFrenchComparisonCatalogue(),
        ),
        clock: () => DateTime.utc(2026),
        newToken: () => 'abcdefghijklmnopqrstuv',
        onCommitted: () => throw StateError('observer failed'),
      );
      final empty = await store.load();
      final command = store.prepare(
        state: empty,
        activityId: activity,
        action: StartComparisonRun(
          sessionId: 'throwing',
          policy: LessonPolicy(),
        ),
      );
      expect((await store.submit(command)).state.revision, 1);
      expect((await store.load()).revision, 1);
    },
  );
}

User _userFor(String id) => User.fromJson({
  'id': id,
  'aud': 'authenticated',
  'app_metadata': <String, dynamic>{},
  'user_metadata': <String, dynamic>{},
  'created_at': '2026-01-01T00:00:00Z',
})!;

SupabaseClient _backendClient() => SupabaseClient(
  'https://providers.example.invalid',
  'public-test-key',
  httpClient: MockClient((request) async {
    final email = (jsonDecode(request.body) as Map)['email'] as String;
    final id = email.split('@').first;
    final payload = jsonEncode({
      'sub': id,
      'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
    });
    final token =
        '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.'
        '${base64Url.encode(utf8.encode(payload))}.signature';
    return http.Response(
      jsonEncode({
        'access_token': token,
        'refresh_token': 'test-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': id,
          'aud': 'authenticated',
          'app_metadata': <String, dynamic>{},
          'user_metadata': <String, dynamic>{},
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }),
);

final class _ProviderDatabase {
  _ProviderDatabase(this.directory, this.barrier);

  final Directory directory;
  final _ProviderSqlCommitBarrier barrier;
  int openCalls = 0;

  late final LearningDatabaseHandle handle = LearningDatabaseHandle(
    open: () async {
      openCalls++;
      final file = File('${directory.path}/learning.sqlite');
      return LearningDatabase(
        DatabaseConnection(NativeDatabase(file).interceptWith(barrier)),
      );
    },
  );

  Future<void> close() async {
    await handle.close();
    await directory.delete(recursive: true);
  }
}

final class _ProviderSqlCommitBarrier extends QueryInterceptor {
  bool _holdCommit = false;
  bool _learningWritePendingCommit = false;
  bool _failNextLearningWrite = false;
  Completer<void>? _entered;
  Completer<void>? _release;

  Future<void> get commitEntered => _entered!.future;

  void holdNextCommit() {
    _holdCommit = true;
    _entered = Completer<void>();
    _release = Completer<void>();
  }

  void failNextLearningWrite() {
    _failNextLearningWrite = true;
  }

  void releaseCommit() {
    final release = _release;
    if (release != null && !release.isCompleted) release.complete();
  }

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (_isLearningWrite(statement) && _failNextLearningWrite) {
      _failNextLearningWrite = false;
      return Future<void>.error(StateError('test SQL write rejected'));
    }
    if (statement.contains('UPDATE learning_scopes SET revision = revision')) {
      _learningWritePendingCommit = true;
    }
    return executor.runCustom(statement, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    if (_isLearningWrite(statement) && _failNextLearningWrite) {
      _failNextLearningWrite = false;
      return Future<int>.error(StateError('test SQL write rejected'));
    }
    if (statement.contains('UPDATE learning_scopes SET revision = revision')) {
      _learningWritePendingCommit = true;
    }
    return executor.runUpdate(statement, args);
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    await inner.send();
    final shouldHold = _holdCommit && _learningWritePendingCommit;
    _learningWritePendingCommit = false;
    if (!shouldHold) return;
    _holdCommit = false;
    _entered!.complete();
    await _release!.future;
  }

  bool _isLearningWrite(String statement) =>
      statement.contains('UPDATE learning_scopes SET revision = revision');
}

Future<_ProviderDatabase> _newProviderDatabase() async {
  final directory = await Directory.systemTemp.createTemp(
    'comparison-provider-test-',
  );
  return _ProviderDatabase(directory, _ProviderSqlCommitBarrier());
}

Future<void> _signIn(SupabaseClient client, String id) async {
  await client.auth.signInWithPassword(
    email: '$id@example.invalid',
    password: 'test-password',
  );
}

Future<int?> _scopeRevision(
  LearningDatabase db, {
  required String family,
  required LearningOwner owner,
}) async {
  final rows = await db
      .customSelect(
        'SELECT revision FROM learning_scopes WHERE owner_kind = ? AND '
        'owner_id = ? AND course_id = ? AND family = ?',
        variables: <Variable<Object>>[
          Variable<String>(owner.isGuest ? 'guest' : 'account'),
          Variable<String>(owner.userId ?? ''),
          const Variable<String>('en-fr'),
          Variable<String>(family),
        ],
      )
      .get();
  return rows.isEmpty ? null : rows.single.read<int>('revision');
}

Future<void> _setSchemaVersion(
  LearningDatabase db, {
  required String family,
  required int version,
}) async {
  await db.customStatement(
    'UPDATE learning_scopes SET schema_version = ? WHERE owner_kind = ? AND '
    'owner_id = ? AND course_id = ? AND family = ?',
    <Object?>[version, 'guest', '', 'en-fr', family],
  );
}
