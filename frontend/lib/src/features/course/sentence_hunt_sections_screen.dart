import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/course/french_sentence_exercises.dart';
import '../../core/course/french_sentence_package.dart';
import '../../core/course/sentence_hunt_content.dart';
import '../../core/course/sentence_hunt_learning_providers.dart';
import '../../core/course/sentence_hunt_learning_state.dart';
import 'sentence_hunt_progress_summary.dart';

class SentenceHuntSectionsScreen extends ConsumerWidget {
  const SentenceHuntSectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SentenceHuntCatalogue> catalogue =
        ref.watch(sentenceHuntCatalogueProvider);
    final AsyncValue<SentenceHuntState> progress =
        ref.watch(sentenceHuntLearningStateProvider);
    final SentenceHuntProgressSummary? summary =
        _summaryFor(progress, catalogue);

    return Scaffold(
      appBar: AppBar(title: const Text('Sentence sections')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            Text('Sentence sound hunt',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('Listen to a French sentence and select every word '
                'that contains its target sound. Each section is independent.'),
            const SizedBox(height: 16),
            if (summary != null) ...<Widget>[
              Text(summary.practiceLabel),
              Text(summary.completionLabel),
            ] else if (progress.isLoading || catalogue.isLoading) ...<Widget>[
              const Text('Sentence progress is loading.'),
              const LinearProgressIndicator(),
            ] else ...<Widget>[
              const Text('Sentence progress is unavailable.'),
              TextButton(
                onPressed: () => context.push('/course-progress'),
                child: const Text('Open sentence progress recovery'),
              ),
            ],
            const SizedBox(height: 12),
            catalogue.when(
              skipLoadingOnRefresh: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Sentence content could not be checked.'),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(sentenceHuntCatalogueProvider),
                    child: const Text('Retry sentence content'),
                  ),
                ],
              ),
              data: (SentenceHuntCatalogue value) => Column(
                children: <Widget>[
                  for (final SentenceHuntSectionSpecification specification
                      in sentenceHuntSectionSpecifications)
                    _SectionTile(
                      specification: specification,
                      catalogue: value,
                      progress: summary?.sections
                          .where((section) => section.id == specification.id)
                          .firstOrNull,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  SentenceHuntProgressSummary? _summaryFor(
    AsyncValue<SentenceHuntState> progress,
    AsyncValue<SentenceHuntCatalogue> catalogue,
  ) {
    final SentenceHuntState? state = progress.asData?.value;
    final SentenceHuntCatalogue? content = catalogue.asData?.value;
    if (state == null || content == null) return null;
    try {
      return SentenceHuntProgressSummary.fromState(
          state: state, catalogue: content);
    } on Object {
      return null;
    }
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.specification,
    required this.catalogue,
    required this.progress,
  });

  final SentenceHuntSectionSpecification specification;
  final SentenceHuntCatalogue catalogue;
  final SentenceHuntSectionProgress? progress;

  @override
  Widget build(BuildContext context) {
    final bool available = catalogue.isAvailable(specification.id);
    final String title = _titleFor(specification.kind);
    final SentenceHuntSectionStatus? status = progress?.status;
    final String statusLabel =
        available ? status?.name ?? 'Progress unavailable' : 'unavailable';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('5 items'),
            Text(_readableStatus(statusLabel)),
            if (!available)
              Text('Content not yet available: '
                  '${_availabilityReason(catalogue, specification.id)}'),
            const SizedBox(height: 8),
            if (!available)
              TextButton(
                onPressed: () =>
                    context.push('/course-sentence-hunt/${specification.id}'),
                child: const Text('See why unavailable'),
              )
            else
              FilledButton(
                onPressed: () =>
                    context.push('/course-sentence-hunt/${specification.id}'),
                child: Text(_entryLabel(title, status)),
              ),
          ],
        ),
      ),
    );
  }

  String _entryLabel(String title, SentenceHuntSectionStatus? status) =>
      switch (status) {
        SentenceHuntSectionStatus.resumable => 'Continue $title',
        SentenceHuntSectionStatus.completed => 'Review $title',
        _ => 'Start $title',
      };

  String _readableStatus(String status) => switch (status) {
        'unavailable' => 'Unavailable',
        'notStarted' => 'Not started',
        'resumable' => 'Resumable',
        'completed' => 'Completed',
        _ => status,
      };
}

String _titleFor(String kind) => switch (kind) {
      'vowels' => 'Vowels',
      'consonants' => 'Consonants',
      _ => 'Mixed review',
    };

String _availabilityReason(SentenceHuntCatalogue catalogue, String sectionId) {
  final Set<String> codes = catalogue
      .diagnosticsFor(sectionId)
      .map((SentenceHuntDiagnostic diagnostic) => diagnostic.code)
      .toSet();
  if (codes.any((String code) => code == 'review_pending')) {
    return 'French/audio or rights review is pending.';
  }
  if (codes.any((String code) => code.startsWith('review_rejected'))) {
    return 'French/audio or rights review did not clear.';
  }
  if (codes.any((String code) => code == 'publication_pending')) {
    return 'Publication is waiting for review evidence.';
  }
  return 'Content and audio are not yet available for practice.';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final Iterator<T> iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
