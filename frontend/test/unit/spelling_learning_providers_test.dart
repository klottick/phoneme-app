import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_learning_error.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart'
    show learningAuthScopeProvider, learningDatabaseHandleProvider;
import 'package:linguist/src/core/course/french_uy_demo_spelling_content.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/spelling_learning_command.dart';
import 'package:linguist/src/core/course/spelling_learning_providers.dart';
import 'package:linguist/src/core/course/spelling_learning_state.dart';
import 'package:linguist/src/core/course/storage/learning_database.dart'
    show LearningDatabase, LearningDatabaseHandle;
import 'package:linguist/src/core/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'spelling store is lazy and state provider uses the shared handle',
    () async {
      final harness = await _Harness.create();
      addTearDown(harness.close);

      final store = harness.container.read(spellingLearningStoreProvider);
      expect(store.scope.owner, LearningOwner.guest());
      expect(harness.openCalls, 0);

      final state = await harness.container.read(
        spellingLearningStateProvider.future,
      );
      expect(state, isA<SpellingLearningState>());
      expect(state.revision, 0);
      expect(harness.openCalls, 1);
      expect(
        identical(store, harness.container.read(spellingLearningStoreProvider)),
        isTrue,
      );
    },
  );

  test('only a current-owner durable ACK refreshes spelling state', () async {
    final harness = await _Harness.create();
    addTearDown(harness.close);
    final notifications = <AsyncValue<SpellingLearningState>>[];
    final subscription = harness.container.listen(
      spellingLearningStateProvider,
      (_, next) => notifications.add(next),
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await harness.container.read(spellingLearningStateProvider.future);
    final store = harness.container.read(spellingLearningStoreProvider);
    final initial = await store.load();
    final command = store.prepare(
      state: initial,
      action: StartSpellingPractice(
        sessionId: 'provider-state-refresh',
        policy: LessonPolicy(),
      ),
    );
    final saved = await store.submit(command);
    expect(saved.duplicate, isFalse);
    final refreshed = await harness.container.read(
      spellingLearningStateProvider.future,
    );
    expect(refreshed.revision, 1);
    final notificationCountAfterAck = notifications.length;

    expect((await store.submit(command)).duplicate, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(notifications.length, notificationCountAfterAck);
    expect((await store.load()).revision, 1);
  });

  test(
    'state provider rejects publication when auth changes during shared open',
    () async {
      final openGate = Completer<void>();
      final enteredOpen = Completer<void>();
      final harness = await _Harness.create(
        beforeOpen: () async {
          if (!enteredOpen.isCompleted) enteredOpen.complete();
          await openGate.future;
        },
      );
      addTearDown(harness.close);

      final loading = harness.container.read(
        spellingLearningStateProvider.future,
      );
      await enteredOpen.future;
      harness.auth.emit(const AppAuthState(isLoading: true));
      await Future<void>.delayed(Duration.zero);
      unawaited(
        loading.then<void>((_) {}, onError: (Object _, StackTrace __) {}),
      );
      await expectLater(
        harness.container.read(spellingLearningStateProvider.future),
        throwsA(isA<LearningOwnerChangedException>()),
      );
      openGate.complete();
      await Future<void>.delayed(Duration.zero);
    },
  );

  test(
    'an invalid spelling catalogue fails locally before opening SQLite',
    () async {
      final valid = loadFrenchUyDemoSpellingCatalogue();
      final invalid = FrenchUyDemoSpellingCatalogue(
        activityId: valid.activityId,
        sectionId: valid.sectionId,
        contentRevision: 2,
        rows: valid.rows,
      );
      final harness = await _Harness.create(catalogue: invalid);
      addTearDown(harness.close);

      expect(
        () => harness.container.read(spellingLearningStoreProvider),
        throwsA(isA<FrenchUyDemoSpellingCatalogueValidationException>()),
      );
      expect(harness.openCalls, 0);
    },
  );
}

final class _ProviderAuth extends AuthController {
  _ProviderAuth() : super(null) {
    emit(const AppAuthState(isLoading: true));
  }

  void emit(AppAuthState value) => state = value;
}

final class _Harness {
  final Directory directory;
  final _ProviderAuth auth;
  final LearningDatabaseHandle handle;
  final ProviderContainer container;
  int openCalls = 0;
  bool _containerDisposed = false;

  static Future<_Harness> create({
    Future<void> Function()? beforeOpen,
    FrenchUyDemoSpellingCatalogue? catalogue,
  }) async {
    final directory = await Directory.systemTemp.createTemp(
      'spelling-provider-',
    );
    final auth = _ProviderAuth();
    late final _Harness harness;
    final handle = LearningDatabaseHandle(
      open: () async {
        harness.openCalls++;
        await beforeOpen?.call();
        return LearningDatabase.openValidated(
          DatabaseConnection(
            NativeDatabase(File('${directory.path}/learning.sqlite')),
          ),
        );
      },
    );
    final container = ProviderContainer(
      overrides: <Override>[
        authControllerProvider.overrideWith((ref) => auth),
        learningDatabaseHandleProvider.overrideWithValue(handle),
        if (catalogue != null)
          spellingCatalogueProvider.overrideWithValue(catalogue),
      ],
    );
    harness = _Harness(directory, auth, handle, container);
    container.read(learningAuthScopeProvider);
    auth.emit(const AppAuthState());
    await Future<void>.delayed(Duration.zero);
    return harness;
  }

  _Harness(this.directory, this.auth, this.handle, this.container);

  Future<void> close() async {
    if (!_containerDisposed) {
      _containerDisposed = true;
      container.dispose();
    }
    await handle.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
