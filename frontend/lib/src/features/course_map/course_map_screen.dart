import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/course/course_learning_providers.dart';
import '../../core/course/course_attempt.dart';
import '../../core/course/french_sentence_package.dart';
import '../../core/course/spelling_learning_providers.dart';
import '../../routing/course_map_navigation.dart';
import '../../routing/course_root_navigation.dart';
import 'course_legacy_entries.dart';
import 'course_map_catalogue.dart';
import 'course_map_providers.dart';
import 'course_map_state.dart';
import 'course_system_view.dart';
import 'french_space_map.dart';

class CourseMapScreen extends ConsumerStatefulWidget {
  const CourseMapScreen({super.key, required this.systemId});
  final String systemId;

  @override
  ConsumerState<CourseMapScreen> createState() => _CourseMapScreenState();
}

class _CourseMapScreenState extends ConsumerState<CourseMapScreen> {
  String? selected;
  bool retrying = false;
  Object? ownerKey;
  int retryOperation = 0;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(learningAuthScopeProvider);
    final location = GoRouter.maybeOf(context)?.state.uri.path ?? '/home';
    final freshKey = (auth.owner, auth.generation, widget.systemId);
    if (ownerKey != freshKey) {
      ownerKey = freshKey;
      selected = null;
      retrying = false;
    }
    final system = findSpaceSystem(widget.systemId);
    final state = ref.watch(courseMapStateProvider(widget.systemId));
    final availableDiscovery = state.bodies.where(
      (body) =>
          body.definition.target == MapTarget.discovery &&
          body.readiness == MapReadiness.alpha &&
          body.progress != MapProgress.unknown,
    );
    final completedDiscovery = availableDiscovery
        .where((body) => body.progress == MapProgress.completed)
        .length;
    final availableMain = state.bodies
        .where(
          (body) =>
              system?.mainOrder.contains(body.definition.id) == true &&
              body.readiness == MapReadiness.alpha &&
              body.progress != MapProgress.unknown,
        )
        .toList(growable: false);
    final completedMain = availableMain
        .where((body) => body.progress == MapProgress.completed)
        .length;
    final recommendedMain = state.bodies
        .where(
          (body) =>
              body.recommended &&
              system?.mainOrder.contains(body.definition.id) == true &&
              body.readiness == MapReadiness.alpha &&
              body.progress != MapProgress.completed &&
              body.progress != MapProgress.unknown,
        )
        .firstOrNull;
    final selectedBodyId =
        selected ?? recommendedMain?.definition.id ?? state.currentBodyId;
    final summaryLabels = <String>[
      if (availableDiscovery.isNotEmpty)
        'Discovery lessons: $completedDiscovery of ${availableDiscovery.length} complete, ${availableDiscovery.length - completedDiscovery} remaining',
      if (availableMain.isNotEmpty)
        'Available main lessons: $completedMain of ${availableMain.length} complete, ${availableMain.length - completedMain} remaining',
      if (recommendedMain != null &&
          selectedBodyId != recommendedMain.definition.id)
        'Recommended next: ${recommendedMain.definition.title}',
    ];
    final progressSummary = summaryLabels.isEmpty
        ? null
        : Semantics(
            container: true,
            label: summaryLabels.join('. '),
            child: ExcludeSemantics(
              child: Wrap(
                spacing: 12,
                runSpacing: 2,
                children: [
                  if (availableDiscovery.isNotEmpty)
                    Text(
                      'Discovery $completedDiscovery/${availableDiscovery.length} complete · ${availableDiscovery.length - completedDiscovery} remaining',
                    ),
                  if (availableMain.isNotEmpty)
                    Text(
                      'Lessons $completedMain/${availableMain.length} complete · ${availableMain.length - completedMain} remaining',
                    ),
                  if (recommendedMain != null &&
                      selectedBodyId != recommendedMain.definition.id)
                    Text('Next · ${recommendedMain.definition.title}'),
                ],
              ),
            ),
          );

    Widget secondaryTools(
      StateSetter setSheetState,
      BuildContext sheetContext,
    ) => Consumer(
      builder: (context, sheetRef, _) {
        final toolsState = sheetRef.watch(
          courseMapStateProvider(widget.systemId),
        );
        final toolsProfile = sheetRef.watch(courseLearningStateProvider);
        final toolsAuth = sheetRef.watch(learningAuthScopeProvider);
        final toolsSystem = findSpaceSystem(widget.systemId);
        final toolsRecommendation = toolsState.bodies
            .where(
              (body) =>
                  body.recommended &&
                  toolsSystem?.mainOrder.contains(body.definition.id) == true &&
                  body.readiness == MapReadiness.alpha &&
                  body.progress != MapProgress.completed &&
                  body.progress != MapProgress.unknown,
            )
            .firstOrNull;
        final toolsSelectedId =
            selected ??
            toolsRecommendation?.definition.id ??
            toolsState.currentBodyId;
        final toolsSelectedComparison = toolsState.bodies
            .where(
              (body) =>
                  body.definition.id == toolsSelectedId &&
                  body.definition.target == MapTarget.mixedComparison &&
                  body.readiness == MapReadiness.alpha &&
                  body.progress == MapProgress.completed,
            )
            .firstOrNull;
        final toolsDedicatedUnavailable = toolsState.bodies.any(
          (body) =>
              body.definition.target == MapTarget.dedicatedComparison &&
              body.readiness == MapReadiness.unavailable,
        );
        final toolsSpellingUnavailable = toolsState.bodies.any(
          (body) =>
              body.definition.target == MapTarget.dedicatedSpelling &&
              body.readiness == MapReadiness.unavailable,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (toolsSelectedComparison != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: OutlinedButton.icon(
                  onPressed: () => _launch(
                    toolsSelectedComparison,
                    toolsAuth,
                    openSavedCheckpoint: true,
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open comparison practice'),
                ),
              ),
            if (toolsState.bodies.isEmpty ||
                toolsState.bodies.every((body) => body.launch == null))
              TextButton(
                onPressed: () => context.go('/course-chart'),
                child: const Text('Open course chart'),
              ),
            if (toolsProfile.hasError)
              TextButton.icon(
                onPressed: retrying
                    ? null
                    : () async {
                        final retry = _retryProgress();
                        if (sheetContext.mounted) setSheetState(() {});
                        await retry;
                        if (sheetContext.mounted) {
                          setSheetState(() {});
                        }
                      },
                icon: const Icon(Icons.refresh),
                label: Text(retrying ? 'Retrying…' : 'Retry loading progress'),
              ),
            const Divider(),
            const ListTile(
              title: Text('Recovery and other practice'),
              subtitle: Text(
                'Separate access remains available when a map family is unavailable.',
              ),
            ),
            TextButton.icon(
              onPressed: () => context.push('/course-lesson/en-fr-u-y'),
              icon: const Icon(Icons.hearing),
              label: const Text('Open discovery recovery'),
            ),
            TextButton.icon(
              onPressed: () =>
                  context.push('/course-comparison/en-fr-phoneme-comparison'),
              icon: const Icon(Icons.compare_arrows),
              label: const Text('Open mixed comparison recovery'),
            ),
            TextButton.icon(
              onPressed: () => context.push('/course-sentence-hunt'),
              icon: const Icon(Icons.segment),
              label: const Text('View sentence sections'),
            ),
            TextButton.icon(
              onPressed: () => sheetRef.invalidate(comparisonCatalogueProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry mixed comparison catalogue'),
            ),
            if (toolsDedicatedUnavailable)
              TextButton.icon(
                onPressed: () {
                  sheetRef.invalidate(uyDemoComparisonCatalogueProvider);
                  sheetRef.invalidate(comparisonCatalogueRegistryProvider);
                  sheetRef.invalidate(comparisonLearningStateProvider);
                  sheetRef.invalidate(courseMapStateProvider(widget.systemId));
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry dedicated comparison'),
              ),
            if (toolsSpellingUnavailable)
              TextButton.icon(
                onPressed: () {
                  sheetRef.invalidate(spellingCatalogueProvider);
                  sheetRef.invalidate(spellingLearningStoreProvider);
                  sheetRef.invalidate(spellingLearningStateProvider);
                  sheetRef.invalidate(courseMapStateProvider(widget.systemId));
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry spelling progress'),
              ),
            TextButton.icon(
              onPressed: () =>
                  sheetRef.invalidate(sentenceHuntCatalogueProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry sentence catalogue'),
            ),
            TextButton.icon(
              onPressed: () {
                sheetRef.invalidate(learningRegistryProvider);
                sheetRef.invalidate(courseMapStateProvider(widget.systemId));
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry map content registry'),
            ),
            CourseLegacyEntries(
              completedLessonIds: toolsState.completedLegacyLessonIds,
            ),
          ],
        );
      },
    );

    return CourseRootNavigation(
      location: location,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Linguist'),
          actions: [
            IconButton(
              tooltip: 'More learning tools',
              icon: const Icon(Icons.more_horiz),
              onPressed: () => _showMapTools(
                context,
                (setSheetState, sheetContext) =>
                    secondaryTools(setSheetState, sheetContext),
              ),
            ),
            IconButton(
              tooltip: 'Star chart',
              icon: const Icon(Icons.auto_awesome),
              onPressed: () => context.go('/course-chart'),
            ),
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
        body: system == null || system.planned
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      system?.description ??
                          'This sound system is not available.',
                    ),
                    FilledButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('Return to map'),
                    ),
                  ],
                ),
              )
            : CourseSystemView(
                key: ValueKey(freshKey),
                state: state,
                selectedBodyId: selectedBodyId,
                onInspect: (id) => setState(() => selected = id),
                onLaunch: (body) => _launch(body, auth),
                progressSummary: progressSummary,
                pickerRevision: (auth.owner, auth.generation, auth.ready),
              ),
      ),
    );
  }

  void _launch(
    MapBodyState body,
    LearningAuthScope expectedAuth, {
    bool openSavedCheckpoint = false,
  }) {
    final currentAuth = ref.read(learningAuthScopeProvider);
    if (currentAuth.owner != expectedAuth.owner ||
        currentAuth.generation != expectedAuth.generation) {
      return;
    }
    final current = ref.read(courseMapStateProvider(widget.systemId));
    final latest = current.bodies
        .where((candidate) => candidate.definition.id == body.definition.id)
        .firstOrNull;
    if (latest == null) return;

    final MapLaunch? launch;
    if (openSavedCheckpoint) {
      if (latest.readiness != MapReadiness.alpha ||
          latest.definition.target != MapTarget.mixedComparison ||
          latest.progress != MapProgress.completed ||
          latest.launch != MapLaunch.review) {
        return;
      }
      launch = MapLaunch.open;
    } else {
      launch = latest.launch;
      if (launch == null || latest.readiness == MapReadiness.planned) {
        return;
      }
      final recovery =
          latest.readiness == MapReadiness.loading ||
          latest.readiness == MapReadiness.unavailable ||
          latest.readiness == MapReadiness.qualificationBlocked;
      final dedicatedRecovery =
          latest.definition.target == MapTarget.dedicatedComparison &&
          launch == MapLaunch.start;
      final spellingRecovery =
          latest.definition.target == MapTarget.dedicatedSpelling &&
          launch == MapLaunch.start;
      if (recovery &&
          !dedicatedRecovery &&
          !spellingRecovery &&
          !(launch == MapLaunch.open &&
              (latest.definition.target == MapTarget.mixedComparison ||
                  latest.definition.target == MapTarget.sentenceSections))) {
        return;
      }
    }
    final route = courseMapLocation(latest.definition.target!, launch);
    if (route != null) context.push(route);
  }

  Future<void> _retryProgress() async {
    final store = ref.read(courseLearningStoreProvider);
    final scope = ref.read(learningAuthScopeProvider);
    final operation = ++retryOperation;
    bool isCurrentOperation() {
      if (!mounted ||
          operation != retryOperation ||
          !identical(store, ref.read(courseLearningStoreProvider))) {
        return false;
      }
      final now = ref.read(learningAuthScopeProvider);
      return now.owner == scope.owner && now.generation == scope.generation;
    }

    setState(() => retrying = true);
    try {
      await store.retryLoad();
      if (isCurrentOperation()) ref.invalidate(courseLearningStateProvider);
    } on Object {
      // Keep the validated unavailable state and its retry action in place.
    } finally {
      if (isCurrentOperation()) setState(() => retrying = false);
    }
  }
}

void _showMapTools(
  BuildContext context,
  Widget Function(StateSetter setSheetState, BuildContext sheetContext)
  buildTools,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final height = (MediaQuery.sizeOf(sheetContext).height * .84)
            .clamp(300.0, 720.0)
            .toDouble();
        return SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        key: const ValueKey('map-tools-heading'),
                        header: true,
                        label: 'More learning tools',
                        child: ExcludeSemantics(
                          child: Text(
                            'Learning tools',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(sheetContext).textTheme.titleMedium,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close tools',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: buildTools(setSheetState, sheetContext),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
