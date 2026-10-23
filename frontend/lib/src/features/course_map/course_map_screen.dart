import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/course/course_learning_providers.dart';
import '../../core/course/french_sentence_package.dart';
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

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(learningAuthScopeProvider);
    final freshKey = (auth.owner, auth.generation, widget.systemId);
    if (ownerKey != freshKey) {
      ownerKey = freshKey;
      selected = null;
      retrying = false;
    }
    final system = findSpaceSystem(widget.systemId);
    final state = ref.watch(courseMapStateProvider(widget.systemId));
    final profile = ref.watch(courseLearningStateProvider);
    final footer = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.bodies.isEmpty ||
            state.bodies.every((body) => body.launch == null))
          TextButton(
            onPressed: () => context.go('/course-chart'),
            child: const Text('Open course chart'),
          ),
        if (profile.hasError)
          TextButton(
            onPressed: retrying ? null : _retryProgress,
            child: Text(retrying ? 'Retrying…' : 'Retry loading progress'),
          ),
        const Divider(),
        const ListTile(
          title: Text('Recovery and other practice'),
          subtitle: Text(
            'Separate access remains available when a map family is unavailable.',
          ),
        ),
        TextButton(
          onPressed: () => context.push('/course-lesson/en-fr-u-y'),
          child: const Text('Open discovery recovery'),
        ),
        TextButton(
          onPressed: () =>
              context.push('/course-comparison/en-fr-phoneme-comparison'),
          child: const Text('Open mixed comparison recovery'),
        ),
        TextButton(
          onPressed: () => context.push('/course-sentence-hunt'),
          child: const Text('View sentence sections'),
        ),
        TextButton(
          onPressed: () => ref.invalidate(comparisonCatalogueProvider),
          child: const Text('Retry mixed comparison catalogue'),
        ),
        TextButton(
          onPressed: () => ref.invalidate(sentenceHuntCatalogueProvider),
          child: const Text('Retry sentence catalogue'),
        ),
        TextButton(
          onPressed: () {
            ref.invalidate(learningRegistryProvider);
            ref.invalidate(courseMapStateProvider(widget.systemId));
          },
          child: const Text('Retry map content registry'),
        ),
        CourseLegacyEntries(completedLessonIds: state.completedLegacyLessonIds),
      ],
    );

    return CourseRootNavigation(
      location: '/home',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Linguist'),
          actions: [
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
                selectedBodyId: selected ?? state.currentBodyId,
                onInspect: (id) => setState(() => selected = id),
                onLaunch: (body) {
                  final currentAuth = ref.read(learningAuthScopeProvider);
                  if (currentAuth.owner != auth.owner ||
                      currentAuth.generation != auth.generation) {
                    return;
                  }
                  final current = ref.read(
                    courseMapStateProvider(widget.systemId),
                  );
                  final latest = current.bodies
                      .where(
                        (candidate) =>
                            candidate.definition.id == body.definition.id,
                      )
                      .firstOrNull;
                  if (latest == null ||
                      latest.launch == null ||
                      latest.readiness == MapReadiness.planned) {
                    return;
                  }
                  final recovery =
                      latest.readiness == MapReadiness.loading ||
                      latest.readiness == MapReadiness.unavailable ||
                      latest.readiness == MapReadiness.qualificationBlocked;
                  if (recovery &&
                      !(latest.launch == MapLaunch.open &&
                          (latest.definition.target ==
                                  MapTarget.mixedComparison ||
                              latest.definition.target ==
                                  MapTarget.sentenceSections))) {
                    return;
                  }
                  final route = courseMapLocation(
                    latest.definition.target!,
                    latest.launch!,
                  );
                  if (route != null) context.push(route);
                },
                footer: footer,
              ),
      ),
    );
  }

  Future<void> _retryProgress() async {
    final store = ref.read(courseLearningStoreProvider);
    final scope = ref.read(learningAuthScopeProvider);
    setState(() => retrying = true);
    try {
      await store.retryLoad();
      if (!mounted ||
          !identical(store, ref.read(courseLearningStoreProvider))) {
        return;
      }
      final now = ref.read(learningAuthScopeProvider);
      if (now.owner == scope.owner && now.generation == scope.generation) {
        ref.invalidate(courseLearningStateProvider);
      }
    } on Object {
      // Keep the validated unavailable state and its retry action in place.
    } finally {
      if (mounted) setState(() => retrying = false);
    }
  }
}
