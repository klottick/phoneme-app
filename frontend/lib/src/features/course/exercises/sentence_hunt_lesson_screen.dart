import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:linguist/src/core/course/backend.dart';
import 'package:linguist/src/core/course/course_attempt.dart';
import 'package:linguist/src/core/course/course_audio.dart';
import 'package:linguist/src/core/course/course_learning_providers.dart';
import 'package:linguist/src/core/course/french_sentence_package.dart';
import 'package:linguist/src/core/course/lesson_policy.dart';
import 'package:linguist/src/core/course/lesson_section_session.dart';
import 'package:linguist/src/core/course/sentence_hunt_content.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_providers.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_state.dart';
import 'package:linguist/src/core/course/sentence_hunt_learning_store.dart';
import 'package:linguist/src/core/widgets/purposeful_motion.dart';
import 'package:linguist/src/features/course/exercises/listening_exercise_contract.dart';
import 'package:linguist/src/features/course/exercises/sentence_hunt.dart';
import 'package:linguist/src/features/course/exercises/sentence_hunt_controller.dart';
import 'package:linguist/src/features/course/exercises/sentence_hunt_section_debrief.dart';
import 'package:linguist/src/features/course/lesson_progress_indicator.dart';

/// Provider- and lifecycle-owning shell around the controlled hunt.
class SentenceHuntLessonScreen extends ConsumerStatefulWidget {
  const SentenceHuntLessonScreen({
    super.key,
    required this.sectionId,
    this.review = false,
    this.itemId,
    this.policy,
  });

  final String sectionId;
  final bool review;
  final String? itemId;
  final LessonPolicy? policy;

  @override
  ConsumerState<SentenceHuntLessonScreen> createState() =>
      _SentenceHuntLessonScreenState();
}

enum _AcquisitionFailure { none, content, provider }

class _SentenceHuntLessonScreenState
    extends ConsumerState<SentenceHuntLessonScreen>
    with WidgetsBindingObserver {
  static const String _providerError =
      'Saved sentence-hunt progress could not be loaded.';

  SentenceHuntCatalogue? _catalogue;
  SentenceHuntSection? _section;
  SentenceHuntLearningStore? _store;
  CourseReferenceAudio? _audio;
  SentenceHuntController? _controller;
  LearningAuthScope? _auth;
  String? _acquisitionError;
  String? _itemNotice;
  _AcquisitionFailure _acquisitionFailure = _AcquisitionFailure.none;

  ProviderSubscription<LearningAuthScope>? _authSubscription;
  ProviderSubscription<AsyncValue<SentenceHuntCatalogue>>?
  _catalogueSubscription;
  ProviderSubscription<AsyncValue<SentenceHuntLearningStore>>?
  _storeSubscription;
  ProviderSubscription<CourseReferenceAudio>? _audioSubscription;
  GoRouter? _goRouter;
  ModalRoute<dynamic>? _route;
  Animation<double>? _coverage;
  bool? _routeWasCurrent;
  bool _routeCovered = false;
  bool _appSuspended = false;
  bool _blocked = false;
  bool _acquiring = false;
  bool _recoveryRequired = false;
  bool _disposed = false;
  int _acquisitionOperation = 0;

  bool get _isBlocked =>
      _appSuspended || _routeCovered || !(_auth?.ready ?? false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appSuspended = switch (WidgetsBinding.instance.lifecycleState) {
      AppLifecycleState.paused ||
      AppLifecycleState.hidden ||
      AppLifecycleState.detached => true,
      _ => false,
    };
    try {
      _auth = ref.read(learningAuthScopeProvider);
      _authSubscription = ref.listenManual<LearningAuthScope>(
        learningAuthScopeProvider,
        _authChanged,
      );
      _catalogueSubscription = ref
          .listenManual<AsyncValue<SentenceHuntCatalogue>>(
            sentenceHuntCatalogueProvider,
            _catalogueChanged,
          );
      _storeSubscription = ref
          .listenManual<AsyncValue<SentenceHuntLearningStore>>(
            sentenceHuntLearningStoreProvider,
            _storeChanged,
          );
      _audioSubscription = ref.listenManual<CourseReferenceAudio>(
        courseReferenceAudioProvider,
        _audioChanged,
      );
    } on Object {
      _auth = LearningAuthScope(
        owner: LearningOwner.guest(),
        generation: 0,
        ready: false,
      );
      _acquisitionError = _providerError;
      _acquisitionFailure = _AcquisitionFailure.provider;
      _recoveryRequired = true;
    }
    _blocked = _isBlocked;
    if (!_blocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_blocked) unawaited(_acquire());
      });
    } else {
      _recoveryRequired = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _goRouter ??= GoRouter.of(context)
        ..routerDelegate.addListener(_routeChanged);
    } on Object {
      // A route-less MaterialApp still receives app lifecycle fencing.
    }
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (!identical(route, _route)) {
      _coverage?.removeListener(_routeChanged);
      _route = route;
      _routeWasCurrent = route?.isCurrent ?? true;
      _coverage = route?.secondaryAnimation?..addListener(_routeChanged);
      _routeCovered = !(route?.isCurrent ?? true);
      _synchronizeLifecycle();
    } else {
      _routeChanged();
    }
  }

  @override
  void didUpdateWidget(covariant SentenceHuntLessonScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sectionId == widget.sectionId &&
        oldWidget.review == widget.review &&
        oldWidget.itemId == widget.itemId &&
        oldWidget.policy?.completionThresholdPercent ==
            widget.policy?.completionThresholdPercent) {
      return;
    }
    _invalidateAcquisition();
    _retireController();
    _catalogue = null;
    _section = null;
    _store = null;
    _audio = null;
    _acquisitionError = null;
    _itemNotice = null;
    _acquisitionFailure = _AcquisitionFailure.none;
    _recoveryRequired = _isBlocked;
    if (!_isBlocked) unawaited(_acquire());
    setState(() {});
  }

  Future<void> _acquire({
    bool refreshCatalogue = false,
    bool refreshStore = false,
  }) async {
    if (!mounted || _disposed || _isBlocked) {
      _recoveryRequired = true;
      return;
    }
    final int operation = ++_acquisitionOperation;
    late final LearningAuthScope capturedAuth;
    try {
      capturedAuth = ref.read(learningAuthScopeProvider);
    } on Object {
      _showProviderFailure(operation);
      return;
    }
    if (!capturedAuth.ready || _backendOwner() != capturedAuth.owner) {
      _acquisitionOperation++;
      _acquisitionError = _providerError;
      _acquisitionFailure = _AcquisitionFailure.provider;
      _recoveryRequired = true;
      _emit();
      return;
    }
    _acquiring = true;
    _acquisitionError = null;
    _itemNotice = null;
    _acquisitionFailure = _AcquisitionFailure.none;
    _recoveryRequired = false;
    _emit();

    late final SentenceHuntCatalogue catalogue;
    try {
      catalogue = refreshCatalogue
          ? await ref.refresh(sentenceHuntCatalogueProvider.future)
          : await ref.read(sentenceHuntCatalogueProvider.future);
    } on Object {
      if (!_ownsAcquisition(operation, capturedAuth)) return;
      _acquiring = false;
      _acquisitionError =
          'Sentence-hunt content could not be checked. Tap "Retry validation" to try again.';
      _acquisitionFailure = _AcquisitionFailure.content;
      _emit();
      return;
    }
    if (!_ownsAcquisition(operation, capturedAuth)) return;

    SentenceHuntSection section;
    try {
      section = catalogue.section(widget.sectionId);
    } on Object {
      _catalogue = catalogue;
      _acquiring = false;
      _acquisitionError = 'This sentence-hunt section is not registered.';
      _acquisitionFailure = _AcquisitionFailure.content;
      _emit();
      return;
    }
    if (widget.itemId != null &&
        !section.items.any(
          (SentenceHuntItem item) => item.identity.itemId == widget.itemId,
        )) {
      _catalogue = catalogue;
      _section = section;
      _acquiring = false;
      _acquisitionError = 'This sentence is not registered in this section.';
      _acquisitionFailure = _AcquisitionFailure.content;
      _emit();
      return;
    }
    if (!catalogue.isAvailable(widget.sectionId)) {
      _catalogue = catalogue;
      _section = section;
      _acquiring = false;
      _acquisitionError = SentenceHuntController.unavailableMessage;
      _acquisitionFailure = _AcquisitionFailure.content;
      _emit();
      return;
    }

    late final SentenceHuntLearningStore store;
    try {
      store = refreshStore
          ? await ref.refresh(sentenceHuntLearningStoreProvider.future)
          : await ref.read(sentenceHuntLearningStoreProvider.future);
    } on Object {
      if (!_ownsAcquisition(operation, capturedAuth)) return;
      _acquiring = false;
      _acquisitionError = _providerError;
      _acquisitionFailure = _AcquisitionFailure.provider;
      _emit();
      return;
    }
    if (!_ownsAcquisition(operation, capturedAuth) ||
        store.scope.courseId != 'en-fr' ||
        store.scope.owner != capturedAuth.owner ||
        _backendOwner() != capturedAuth.owner) {
      return;
    }

    late final CourseReferenceAudio audio;
    try {
      audio = ref.read(courseReferenceAudioProvider);
    } on Object {
      if (!_ownsAcquisition(operation, capturedAuth)) return;
      _acquiring = false;
      _acquisitionError = _providerError;
      _acquisitionFailure = _AcquisitionFailure.provider;
      _emit();
      return;
    }
    if (!_ownsAcquisition(operation, capturedAuth)) return;

    _catalogue = catalogue;
    _section = section;
    _store = store;
    _audio = audio;
    _acquiring = false;
    _acquisitionError = null;
    _acquisitionFailure = _AcquisitionFailure.none;
    if (widget.itemId != null) {
      _itemNotice =
          'Requested sentence is shown only at its saved section position.';
    }
    late final SentenceHuntController controller;
    controller = SentenceHuntController(
      sectionId: widget.sectionId,
      catalogue: catalogue,
      store: store,
      audio: audio,
      entryMode: widget.review
          ? SentenceHuntEntryMode.reviewOnly
          : SentenceHuntEntryMode.practice,
      policy: widget.policy,
      isCurrent: () => _controllerOwns(controller, store, capturedAuth),
      onStateChanged: () {
        if (mounted && identical(_controller, controller)) setState(() {});
      },
    );
    _controller = controller;
    _emit();
    unawaited(controller.load());
  }

  bool _ownsAcquisition(int operation, LearningAuthScope capturedAuth) {
    if (!mounted ||
        _disposed ||
        operation != _acquisitionOperation ||
        _isBlocked) {
      return false;
    }
    try {
      final LearningAuthScope current = ref.read(learningAuthScopeProvider);
      return current.ready &&
          current.owner == capturedAuth.owner &&
          current.generation == capturedAuth.generation &&
          _backendOwner() == capturedAuth.owner &&
          _isRouteCurrent();
    } on Object {
      return false;
    }
  }

  bool _controllerOwns(
    SentenceHuntController controller,
    SentenceHuntLearningStore store,
    LearningAuthScope capturedAuth,
  ) {
    if (!mounted ||
        _disposed ||
        !identical(_controller, controller) ||
        !identical(_store, store) ||
        _isBlocked ||
        !_isRouteCurrent()) {
      return false;
    }
    try {
      final LearningAuthScope current = ref.read(learningAuthScopeProvider);
      return current.ready &&
          current.owner == capturedAuth.owner &&
          current.generation == capturedAuth.generation &&
          store.scope.owner == capturedAuth.owner &&
          _backendOwner() == capturedAuth.owner;
    } on Object {
      return false;
    }
  }

  LearningOwner _backendOwner() {
    final String? userId = courseBackend?.auth.currentUser?.id;
    return userId == null
        ? LearningOwner.guest()
        : LearningOwner.account(userId);
  }

  void _showProviderFailure(int operation) {
    if (!mounted || operation != _acquisitionOperation) return;
    _acquiring = false;
    _acquisitionError = _providerError;
    _acquisitionFailure = _AcquisitionFailure.provider;
    _recoveryRequired = false;
    _emit();
  }

  void _authChanged(LearningAuthScope? previous, LearningAuthScope next) {
    final LearningAuthScope? old = _auth;
    if (old != null &&
        old.owner == next.owner &&
        old.generation == next.generation &&
        old.ready == next.ready) {
      return;
    }
    _auth = next;
    final bool ownerChanged =
        old != null &&
        (old.owner != next.owner || old.generation != next.generation);
    if (ownerChanged) {
      _invalidateAcquisition();
      _retireController();
      _catalogue = null;
      _section = null;
      _store = null;
      _audio = null;
      _acquisitionError = null;
      _acquisitionFailure = _AcquisitionFailure.none;
      _recoveryRequired = true;
    } else if (!next.ready) {
      _invalidateAcquisition();
      _controller?.suspend();
      _recoveryRequired = true;
    }
    _synchronizeLifecycle();
    _emit();
  }

  void _catalogueChanged(
    AsyncValue<SentenceHuntCatalogue>? previous,
    AsyncValue<SentenceHuntCatalogue> next,
  ) {
    final SentenceHuntCatalogue? value = next.asData?.value;
    final SentenceHuntCatalogue? current = _catalogue;
    if (value == null || current == null || identical(value, current)) return;
    final SentenceHuntSection? priorSection = _safeSection(current);
    final SentenceHuntSection? nextSection = _safeSection(value);
    if (priorSection?.sectionFingerprint == nextSection?.sectionFingerprint &&
        value.isAvailable(widget.sectionId) ==
            current.isAvailable(widget.sectionId)) {
      return;
    }
    _requireDependencyRecovery();
  }

  void _storeChanged(
    AsyncValue<SentenceHuntLearningStore>? previous,
    AsyncValue<SentenceHuntLearningStore> next,
  ) {
    final SentenceHuntLearningStore? value = next.asData?.value;
    if (value == null || _store == null || identical(value, _store)) return;
    _requireDependencyRecovery();
  }

  void _audioChanged(
    CourseReferenceAudio? previous,
    CourseReferenceAudio next,
  ) {
    if (_audio == null || identical(_audio, next)) return;
    _requireDependencyRecovery();
  }

  SentenceHuntSection? _safeSection(SentenceHuntCatalogue catalogue) {
    try {
      return catalogue.section(widget.sectionId);
    } on Object {
      return null;
    }
  }

  void _requireDependencyRecovery() {
    _invalidateAcquisition();
    _retireController();
    _catalogue = null;
    _section = null;
    _store = null;
    _audio = null;
    _acquisitionError =
        'Sentence-hunt dependencies changed. Tap "Resume exercise" to reload safely.';
    _acquisitionFailure = _AcquisitionFailure.provider;
    _recoveryRequired = true;
    _emit();
  }

  void _routeChanged() {
    if (!mounted || !_isRouteCurrent(allowCovered: true)) return;
    final bool current = _isRouteCurrent();
    if (_routeWasCurrent == current) return;
    _routeWasCurrent = current;
    _routeCovered = !current;
    _synchronizeLifecycle();
  }

  bool _isRouteCurrent({bool allowCovered = false}) {
    final ModalRoute<dynamic>? route = _route;
    if (route == null) return true;
    try {
      if (!identical(ModalRoute.of(context), route)) return false;
      return allowCovered || route.isCurrent;
    } on Object {
      return false;
    }
  }

  void _synchronizeLifecycle() {
    final bool blocked = _isBlocked;
    if (blocked == _blocked) return;
    _blocked = blocked;
    if (blocked) {
      _invalidateAcquisition();
      _controller?.suspend();
      _recoveryRequired = true;
    } else {
      // Clearing one lifecycle blocker is not itself an explicit recovery
      // action. Keep the controller fenced until the learner resumes safely.
      _recoveryRequired = true;
    }
    _emit();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _appSuspended = true;
    } else if (state == AppLifecycleState.resumed) {
      _appSuspended = false;
    }
    _synchronizeLifecycle();
  }

  void _retireController() {
    final SentenceHuntController? controller = _controller;
    _controller = null;
    controller?.dispose();
  }

  void _invalidateAcquisition() {
    _acquisitionOperation++;
    _acquiring = false;
  }

  Future<void> _resumeExplicitly() async {
    if (_isBlocked) return;
    final SentenceHuntController? controller = _controller;
    if (controller == null) {
      await _acquire(
        refreshCatalogue: _acquisitionFailure == _AcquisitionFailure.content,
        refreshStore: _acquisitionFailure == _AcquisitionFailure.provider,
      );
      return;
    }
    controller.resume();
    final SentenceHuntViewState state = controller.state;
    if (state.savePending) {
      _recoveryRequired = false;
      setState(() {});
      return;
    }
    if (state.session == null || state.loadFailed) {
      _recoveryRequired = false;
      setState(() {});
      await controller.load(retry: state.loadFailed);
      return;
    }
    setState(() => _recoveryRequired = false);
  }

  Future<void> _retryValidation() async {
    if (_acquiring || _isBlocked) return;
    _retireController();
    _catalogue = null;
    _section = null;
    _store = null;
    _audio = null;
    await _acquire(refreshCatalogue: true);
  }

  Future<void> _retryProviderAcquisition() async {
    if (_acquiring || _isBlocked) return;
    _retireController();
    _store = null;
    _audio = null;
    await _acquire(refreshStore: true);
  }

  void _emit() {
    if (mounted && !_disposed) setState(() {});
  }

  @override
  void dispose() {
    _disposed = true;
    _invalidateAcquisition();
    _retireController();
    _authSubscription?.close();
    _catalogueSubscription?.close();
    _storeSubscription?.close();
    _audioSubscription?.close();
    _goRouter?.routerDelegate.removeListener(_routeChanged);
    _coverage?.removeListener(_routeChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SentenceHuntController? controller = _controller;
    final SentenceHuntViewState? state = controller?.state;
    final bool controlsBlocked = _blocked || _recoveryRequired;
    final bool showDebrief =
        state?.session?.phase == LessonSectionPhase.debrief;
    final bool showExercise =
        state?.phase == SentenceHuntPhase.exercise && state?.prompt != null;
    final bool showUnavailable =
        _acquisitionError != null ||
        state?.phase == SentenceHuntPhase.unavailable;
    final LessonSectionSession? session = state?.session;

    return Scaffold(
      appBar: AppBar(title: const Text('Sentence hunt')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (session != null)
              LessonProgressIndicator(
                completed: completedItemsThisRound(session),
                total: session.queue.length,
                roundLabel: state!.reviewOnly || session.round > 1
                    ? 'Review round ${session.round}'
                    : null,
              ),
            Expanded(
              child: LessonContentViewport(
                maxWidth: 640,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (_blocked)
                      const Text(
                        'Sentence hunt is paused while this screen is covered or unavailable.',
                      ),
                    if (_acquiring ||
                        (controller == null &&
                            !showUnavailable &&
                            !_recoveryRequired))
                      const Center(child: CircularProgressIndicator()),
                    if (_acquisitionError != null) ...<Widget>[
                      Text(_acquisitionError!),
                      if (!controlsBlocked && !_acquiring)
                        TextButton(
                          onPressed:
                              _acquisitionFailure == _AcquisitionFailure.content
                              ? _retryValidation
                              : _retryProviderAcquisition,
                          child: Text(
                            _acquisitionFailure == _AcquisitionFailure.content
                                ? 'Retry validation'
                                : 'Retry loading',
                          ),
                        ),
                    ],
                    if (state?.error != null &&
                        !showDebrief &&
                        !state!.savePending)
                      Text(state.error!),
                    if (state?.savePending == true &&
                        state?.error != null &&
                        !showExercise &&
                        !showDebrief) ...<Widget>[
                      Text(state!.error!),
                      if (!controlsBlocked)
                        TextButton(
                          onPressed: controller!.retrySave,
                          child: const Text('Retry saving'),
                        ),
                    ],
                    if (state?.conflict != null && !showDebrief) ...<Widget>[
                      Text(state!.conflict!),
                      if (!controlsBlocked)
                        TextButton(
                          onPressed: () => controller!.load(retry: true),
                          child: const Text('Reload saved progress'),
                        ),
                    ],
                    if (state?.loadFailed == true &&
                        !showDebrief &&
                        !state!.savePending &&
                        !controlsBlocked)
                      TextButton(
                        onPressed: () => controller!.load(retry: true),
                        child: const Text('Retry loading'),
                      ),
                    if (state?.modeMismatch == true)
                      const Text(
                        'The saved run is being resumed in its original mode; this link cannot change it.',
                      ),
                    if (_itemNotice != null) Text(_itemNotice!),
                    if (_recoveryRequired && !_blocked && !_acquiring)
                      TextButton(
                        onPressed: _resumeExplicitly,
                        child: const Text('Resume exercise'),
                      ),
                    if (showExercise) ...<Widget>[
                      PurposefulSwitcher(
                        child: KeyedSubtree(
                          key: ValueKey(
                            'sentence-hunt-problem-${state!.prompt!.itemId}',
                          ),
                          child: SentenceHunt(
                            prompt: state.prompt!,
                            state: ListeningExerciseState(
                              busy: state.busy,
                              playing: state.playing,
                              blocked: controlsBlocked,
                              answered: state.feedback != null,
                              feedback: state.feedback,
                            ),
                            selectedTokenIds: state.selectedTokenIds,
                            canSubmit: state.canSubmit && !controlsBlocked,
                            onPlay: controller!.play,
                            onToggleToken: controller.toggleToken,
                            onSubmit: controller.submit,
                          ),
                        ),
                      ),
                      if (state.audioError != null) ...<Widget>[
                        Text(state.audioError!),
                        if (!controlsBlocked &&
                            !state.busy &&
                            state.feedback == null)
                          TextButton(
                            onPressed: controller.play,
                            child: const Text('Retry audio'),
                          ),
                      ],
                      if (state.savePending &&
                          state.error != null &&
                          !controlsBlocked)
                        TextButton(
                          onPressed: controller.retrySave,
                          child: const Text('Retry saving'),
                        ),
                    ],
                    if (showDebrief && _section != null)
                      SentenceHuntSectionDebrief(
                        section: _section!,
                        session: state!.session!,
                        latestAttempts:
                            state.debriefAttempts ??
                            const <SentenceHuntAttempt>[],
                        busy: state.busy || controlsBlocked,
                        canReview: state.canReview && !controlsBlocked,
                        canFinish: state.canFinish && !controlsBlocked,
                        completionEligible: state.completionEligible,
                        reviewOnly: state.reviewOnly,
                        finished: state.finished,
                        error: state.savePending ? state.error : null,
                        conflict: state.conflict,
                        onReviewMistakes: controller!.reviewMistakes,
                        onFinish: controller.finish,
                        onRetrySave: controller.retrySave,
                        onReload: () => controller.load(retry: true),
                      ),
                    if (state?.busy == true) const LinearProgressIndicator(),
                  ],
                ),
              ),
            ),
            if (showExercise && session?.answered == true && !controlsBlocked)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: state!.canAdvance && !controlsBlocked
                            ? controller!.advance
                            : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: const Text('Continue'),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
