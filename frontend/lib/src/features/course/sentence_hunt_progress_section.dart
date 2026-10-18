import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/course/course_attempt.dart';
import '../../core/course/course_learning_providers.dart';
import '../../core/course/french_sentence_package.dart';
import '../../core/course/sentence_hunt_content.dart';
import '../../core/course/sentence_hunt_learning_providers.dart';
import '../../core/course/sentence_hunt_learning_state.dart';
import '../../core/course/sentence_hunt_learning_store.dart';
import 'sentence_hunt_progress_summary.dart';

class SentenceHuntProgressSection extends ConsumerStatefulWidget {
  const SentenceHuntProgressSection({super.key});

  @override
  ConsumerState<SentenceHuntProgressSection> createState() =>
      _SentenceHuntProgressSectionState();
}

class _SentenceHuntProgressSectionState
    extends ConsumerState<SentenceHuntProgressSection> {
  ProviderSubscription<LearningAuthScope>? _authSubscription;
  LearningAuthScope? _auth;
  bool _retrying = false;
  bool _disposed = false;
  String? _recoveryMessage;
  int _operation = 0;

  @override
  void initState() {
    super.initState();
    try {
      _auth = ref.read(learningAuthScopeProvider);
      _authSubscription = ref.listenManual<LearningAuthScope>(
          learningAuthScopeProvider, _authChanged);
    } on Object {
      _auth = null;
    }
  }

  void _authChanged(LearningAuthScope? previous, LearningAuthScope next) {
    final LearningAuthScope? prior = _auth;
    if (prior != null &&
        prior.owner == next.owner &&
        prior.generation == next.generation &&
        prior.ready == next.ready) {
      return;
    }
    _auth = next;
    _operation++;
    if (mounted) {
      setState(() {
        _retrying = false;
        _recoveryMessage = null;
      });
    }
  }

  bool _ownsRetry(int operation, LearningAuthScope captured) {
    if (!mounted || _disposed || operation != _operation) return false;
    try {
      final LearningAuthScope current = ref.read(learningAuthScopeProvider);
      return current.ready &&
          current.owner == captured.owner &&
          current.generation == captured.generation;
    } on Object {
      return false;
    }
  }

  Future<void> _retry() async {
    if (_retrying || _disposed) return;
    late final LearningAuthScope captured;
    try {
      captured = ref.read(learningAuthScopeProvider);
    } on Object {
      if (mounted) {
        setState(() => _recoveryMessage =
            'Sentence progress is unavailable. Try again when the profile is ready.');
      }
      return;
    }
    if (!captured.ready) return;

    final int operation = ++_operation;
    setState(() {
      _retrying = true;
      _recoveryMessage = null;
    });

    try {
      try {
        await ref.read(sentenceHuntCatalogueProvider.future);
      } on Object {
        if (!_ownsRetry(operation, captured)) return;
        final SentenceHuntCatalogue _ =
            await ref.refresh(sentenceHuntCatalogueProvider.future);
      }
      if (!_ownsRetry(operation, captured)) return;

      // Store acquisition is intentionally inside this guarded recovery path:
      // it may await both the catalogue and owner-scoped persistence setup.
      final SentenceHuntLearningStore store =
          await ref.read(sentenceHuntLearningStoreProvider.future);
      if (!_ownsRetry(operation, captured) ||
          store.scope.owner != captured.owner) {
        return;
      }

      await store.retryLoad();
      if (!_ownsRetry(operation, captured)) return;
      ref.invalidate(sentenceHuntLearningStateProvider);
      if (!_ownsRetry(operation, captured)) return;
      _recoveryMessage = null;
    } on Object {
      if (!_ownsRetry(operation, captured)) return;
      _recoveryMessage = 'Sentence progress is unavailable. Try again.';
    } finally {
      // A stale A→B→A operation cannot clear another owner's busy/error state.
      if (_ownsRetry(operation, captured)) {
        setState(() => _retrying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SentenceHuntState> progress =
        ref.watch(sentenceHuntLearningStateProvider);
    final AsyncValue<SentenceHuntCatalogue> catalogue =
        ref.watch(sentenceHuntCatalogueProvider);

    return progress.when(
      skipLoadingOnRefresh: false,
      loading: () => _loading(),
      error: (_, __) => _unavailable(),
      data: (SentenceHuntState state) => catalogue.when(
        skipLoadingOnRefresh: false,
        loading: () => _loading(),
        error: (_, __) => _unavailable(),
        data: (SentenceHuntCatalogue value) {
          try {
            return _content(
                context,
                SentenceHuntProgressSummary.fromState(
                    state: state, catalogue: value));
          } on Object {
            return _unavailable();
          }
        },
      ),
    );
  }

  Widget _loading() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Sentence practice, not phoneme mastery'),
            SizedBox(height: 8),
            Text('Sentence progress is loading.'),
          ],
        ),
      );

  Widget _unavailable() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Sentence practice, not phoneme mastery'),
            const Text('Sentence progress is unavailable.'),
            if (_recoveryMessage != null) Text(_recoveryMessage!),
            TextButton(
              onPressed: _retrying ? null : _retry,
              child: Text(_retrying
                  ? 'Retrying sentence progress…'
                  : 'Retry sentence progress'),
            ),
          ],
        ),
      );

  Widget _content(BuildContext context, SentenceHuntProgressSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(summary.practiceLabel),
        Text(summary.completionLabel),
        Text(summary.answersLabel),
        Text(summary.exposedAnswersLabel),
        for (final SentenceHuntSectionProgress section
            in summary.sections) ...<Widget>[
          const SizedBox(height: 8),
          Text('${section.title} · ${section.statusLabel}'),
          Text(section.latestResultLabel),
          if (section.savedThresholdPercent != null)
            Text('Saved completion threshold: '
                '${section.savedThresholdPercent}%'),
          for (final SentenceHuntMistakeProgress mistake in section.mistakes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Sentence item ${mistake.itemId}'),
              subtitle: Text('Unresolved · ${mistake.failureCount} '
                  'incorrect answers'),
              trailing: const Icon(Icons.play_arrow),
              onTap: () => context.push(Uri(
                path: '/course-sentence-hunt/${mistake.sectionId}',
                queryParameters: <String, String>{
                  'review': 'true',
                  'itemId': mistake.itemId,
                },
              ).toString()),
            ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _operation++;
    _authSubscription?.close();
    super.dispose();
  }
}
