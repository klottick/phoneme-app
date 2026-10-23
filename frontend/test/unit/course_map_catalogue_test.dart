import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/course_learning_registry.dart';
import 'package:linguist/src/features/course_map/course_map_catalogue.dart';
import 'package:linguist/src/features/course_map/french_space_map.dart';

/// A valid fixture body: the /u/–/y/ discovery planet bound to the real
/// registry activity.
MapBodyDefinition body({
  String id = 'a',
  MapBodyRole role = MapBodyRole.planet,
  bool optional = false,
  bool planned = false,
  MapTarget? target = MapTarget.discovery,
  String? activityId = 'lesson:en-fr-u-y',
  String? parentId,
  List<String> prerequisites = const [],
  double x = 0.2,
  double y = 0.5,
  double orbitRadius = 0.25,
}) {
  return MapBodyDefinition(
    id: id,
    title: 'Body $id',
    description: 'Fixture body $id',
    role: role,
    optional: optional,
    planned: planned,
    target: target,
    activityId: activityId,
    parentId: parentId,
    prerequisites: prerequisites,
    x: x,
    y: y,
    orbitRadius: orbitRadius,
  );
}

MapSystemDefinition system({
  String id = 'fixture-system',
  List<MapBodyDefinition> bodies = const [],
  List<String> mainOrder = const [],
  bool planned = false,
}) {
  return MapSystemDefinition(
    id: id,
    title: 'Fixture system',
    description: 'Fixture system $id',
    planned: planned,
    bodies: bodies,
    mainOrder: mainOrder,
  );
}

void main() {
  test('initial_system_has_one_live_main_lesson', () {
    final initial = findSpaceSystem('en-fr-u-y-system');
    expect(initial, isNotNull);
    final bodies = initial!.bodies;
    expect(bodies, hasLength(10));
    expect(initial.planned, isFalse);
    expect(initial.mainOrder, ['discovery']);
    expect(bodies.where((b) => b.planned).length, 5);
    // The one live main destination is the discovery planet, bound to the
    // real discovery activity.
    final discovery = bodies.firstWhere((b) => b.id == 'discovery');
    expect(discovery.role, MapBodyRole.planet);
    expect(discovery.planned, isFalse);
    expect(discovery.optional, isFalse);
    expect(discovery.target, MapTarget.discovery);
    expect(discovery.activityId, 'lesson:en-fr-u-y');
    expect(discovery.parentId, isNull);
    final liveMains = bodies
        .where((b) => initial.mainOrder.contains(b.id))
        .toList(growable: false);
    expect(liveMains, hasLength(1));
    expect(liveMains.single.planned, isFalse);
    expect(liveMains.single.activityId, isNotNull);
    // The authored initial system validates cleanly against the registry.
    validateMapSystem(initial, registry: LearningRegistry.french());
  });

  test('mixed_practice_is_not_a_system_lesson', () {
    final initial = findSpaceSystem('en-fr-u-y-system');
    expect(initial, isNotNull);
    final mixed =
        initial!.bodies.firstWhere((b) => b.id == 'mixed-comparison');
    expect(mixed.role, MapBodyRole.station);
    expect(mixed.planned, isFalse);
    expect(mixed.optional, isTrue);
    expect(mixed.target, MapTarget.mixedComparison);
    expect(mixed.activityId, 'en-fr-phoneme-comparison');
    // Mixed practice is optional cross-system alpha practice, not a main
    // system lesson: it never enters the authored main order.
    expect(initial.mainOrder, isNot(contains('mixed-comparison')));
    final mains = initial.bodies
        .where((b) => initial.mainOrder.contains(b.id))
        .toList(growable: false);
    expect(
      mains.any((b) => b.activityId == 'en-fr-phoneme-comparison'),
      isFalse,
    );
  });

  test('planned_systems_have_no_launch', () {
    final planned = frenchSpaceSystems
        .where((s) => s.planned)
        .toList(growable: false);
    expect(planned, hasLength(2));
    expect(planned.map((s) => s.id).toList(),
        ['en-fr-nasals-system', 'en-fr-r-system']);
    for (final entry in planned) {
      expect(findSpaceSystem(entry.id), same(entry));
      expect(entry.bodies, isEmpty, reason: '${entry.id} must not launch');
      expect(entry.mainOrder, isEmpty, reason: '${entry.id} has no main order');
    }
    expect(findSpaceSystem('not-a-system'), isNull);
    // Planned bodies inside the live system explain availability; they carry
    // no launch target or activity binding.
    final initial = findSpaceSystem('en-fr-u-y-system');
    final plannedBodies =
        initial!.bodies.where((b) => b.planned).toList(growable: false);
    expect(plannedBodies, hasLength(5));
    for (final body in plannedBodies) {
      expect(body.target, isNull, reason: 'planned ${body.id} must not launch');
      expect(body.activityId, isNull,
          reason: 'planned ${body.id} must not bind');
    }
    // The whole chart validates per system without learning state.
    for (final entry in frenchSpaceSystems) {
      validateMapSystem(entry, registry: LearningRegistry.french());
    }
  });

  test('invalid_graph_fails_per_system', () {
    final registry = LearningRegistry.french();

    void expectInvalid(MapSystemDefinition invalid, String why) {
      expect(
        () => validateMapSystem(invalid, registry: registry),
        throwsFormatException,
        reason: why,
      );
    }

    // Duplicate body ids.
    expectInvalid(
      system(bodies: [body(id: 'a'), body(id: 'a')], mainOrder: ['a']),
      'duplicate body id',
    );
    // Unknown prerequisite, parent, and order ids.
    expectInvalid(
      system(
          bodies: [body(id: 'a', prerequisites: ['missing'])],
          mainOrder: ['a']),
      'unknown prerequisite',
    );
    expectInvalid(
      system(bodies: [body(id: 'a', parentId: 'missing')], mainOrder: ['a']),
      'unknown parent',
    );
    expectInvalid(
      system(bodies: [body(id: 'a')], mainOrder: ['missing']),
      'unknown order id',
    );
    // Cycles in prerequisite and parent graphs.
    expectInvalid(
      system(bodies: [
        body(id: 'a', prerequisites: ['b']),
        body(id: 'b', prerequisites: ['a']),
      ]),
      'prerequisite cycle',
    );
    expectInvalid(
      system(bodies: [
        body(id: 'a', parentId: 'b'),
        body(id: 'b', parentId: 'a'),
      ]),
      'parent cycle',
    );
    expectInvalid(
      system(bodies: [body(id: 'a', parentId: 'a')], mainOrder: ['a']),
      'self parent',
    );
    // Required content must never depend on an optional detour.
    expectInvalid(
      system(bodies: [
        body(id: 'required'),
        body(
          id: 'optional',
          role: MapBodyRole.station,
          optional: true,
          target: MapTarget.review,
          activityId: null,
        ),
        body(id: 'second', prerequisites: ['optional']),
      ], mainOrder: ['required', 'second']),
      'required body depending on an optional detour',
    );
    // Invalid bindings.
    expectInvalid(
      system(bodies: [body(id: 'a', activityId: 'drill:minimal-pairs')]),
      'discovery destination bound to a non-discovery registry kind',
    );
    expectInvalid(
      system(bodies: [body(id: 'a', activityId: 'lesson:missing')]),
      'discovery destination bound to an unknown registry id',
    );
    expectInvalid(
      system(bodies: [
        body(
          id: 'a',
          role: MapBodyRole.station,
          optional: true,
          target: MapTarget.mixedComparison,
          activityId: 'lesson:en-fr-u-y',
        ),
      ]),
      'mixed practice bound to the discovery lesson',
    );
    expectInvalid(
      system(bodies: [
        body(
          id: 'a',
          role: MapBodyRole.station,
          optional: true,
          target: MapTarget.review,
          activityId: comparisonActivityId,
        ),
      ]),
      'mixed-family binding without the mixed target',
    );
    expectInvalid(
      system(bodies: [
        body(
          id: 'a',
          role: MapBodyRole.station,
          optional: true,
          target: MapTarget.review,
          activityId: 'lesson:en-fr-u-y',
        ),
      ]),
      'review station bound to a registry lesson',
    );
    // Nonfinite geometry.
    expectInvalid(system(bodies: [body(id: 'a', x: double.nan)]),
        'non-finite x');
    expectInvalid(
        system(bodies: [body(id: 'a', orbitRadius: double.infinity)]),
        'non-finite orbit radius');
    // Out-of-range geometry.
    expectInvalid(system(bodies: [body(id: 'a', y: 1.5)], mainOrder: ['a']),
        'out-of-range y');
    expectInvalid(system(bodies: [body(id: 'a', x: -0.1)]), 'out-of-range x');
    expectInvalid(
        system(bodies: [body(id: 'a', orbitRadius: -0.01)]),
        'out-of-range orbit radius');
    // Planned bodies never carry launch metadata; every non-planned body is
    // a real destination.
    expectInvalid(
      system(bodies: [body(id: 'a', planned: true)]),
      'planned body carrying a launch binding',
    );
    expectInvalid(
      system(bodies: [body(id: 'a', target: null, activityId: null)]),
      'non-planned body without a destination target',
    );
    expectInvalid(
      system(bodies: [
        body(id: 'parent'),
        body(
          id: 'moon',
          role: MapBodyRole.moon,
          optional: false,
          target: null,
          activityId: null,
          parentId: 'parent',
        ),
      ]),
      'required moon',
    );
    // A planned chart system carries no bodies, bindings, or main order.
    expectInvalid(
      system(
        id: 'planned-system',
        planned: true,
        bodies: [body(id: 'a', planned: true, target: null, activityId: null)],
        mainOrder: ['a'],
      ),
      'planned system with launch metadata',
    );
    // A plain valid system still passes.
    expect(
      () => validateMapSystem(
          system(bodies: [body(id: 'a')], mainOrder: ['a']),
          registry: registry),
      returnsNormally,
    );
  });

  test('orbital_position_does_not_order_learning', () {
    final initial = findSpaceSystem('en-fr-u-y-system');
    expect(initial, isNotNull);
    final authoredSystem = initial!;
    // Re-author every body position and orbital radius while keeping the
    // learning metadata identical; order must come from the author, not from
    // where a body is drawn.
    final authoredOrder = [...authoredSystem.mainOrder];
    final permuted = MapSystemDefinition(
      id: authoredSystem.id,
      title: authoredSystem.title,
      description: authoredSystem.description,
      planned: authoredSystem.planned,
      bodies: [
        for (final body in authoredSystem.bodies)
          MapBodyDefinition(
            id: body.id,
            title: body.title,
            description: body.description,
            role: body.role,
            optional: body.optional,
            planned: body.planned,
            target: body.target,
            activityId: body.activityId,
            parentId: body.parentId,
            prerequisites: body.prerequisites,
            x: (body.x + 0.5) % 1.0,
            y: (body.y + 0.5) % 1.0,
            orbitRadius: body.orbitRadius * 0.5 + 0.2,
          ),
      ],
      mainOrder: authoredOrder,
    );
    authoredOrder.clear();
    expect(permuted.mainOrder, ['discovery']);
    expect(() => permuted.mainOrder.add('another'), throwsUnsupportedError);
    expect(permuted.mainOrder, authoredSystem.mainOrder);
    // Shuffled presentation metadata still validates against the registry.
    expect(
      () => validateMapSystem(permuted, registry: LearningRegistry.french()),
      returnsNormally,
    );
  });

  test('live_system_requires_nonempty_bodies', () {
    final registry = LearningRegistry.french();
    expect(
      () => validateMapSystem(system(), registry: registry),
      throwsFormatException,
      reason: 'a live system must contain at least one body',
    );
  });

  test('every_required_live_body_is_in_main_order', () {
    final registry = LearningRegistry.french();
    expect(
      () => validateMapSystem(
        system(bodies: [body(id: 'required')]),
        registry: registry,
      ),
      throwsFormatException,
      reason: 'every required live body must be in mainOrder',
    );

    final complete = system(
      bodies: [
        body(id: 'first'),
        body(id: 'second'),
        body(id: 'planned', planned: true, target: null, activityId: null),
        body(
          id: 'optional',
          role: MapBodyRole.station,
          optional: true,
          target: MapTarget.review,
          activityId: null,
        ),
      ],
      mainOrder: ['first', 'second'],
    );
    expect(
      () => validateMapSystem(complete, registry: registry),
      returnsNormally,
      reason: 'required bodies are ordered; planned and optional bodies are excluded',
    );
    expect(
      () => validateMapSystem(
        findSpaceSystem('en-fr-u-y-system')!,
        registry: registry,
      ),
      returnsNormally,
      reason: 'the authored initial system has its required live body ordered',
    );
  });
}
