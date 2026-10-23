import '../../core/course/comparison_content.dart';
import '../../core/course/course_attempt.dart';
import '../../core/course/course_learning_registry.dart';

/// Presentation roles for the bodies a space map draws.
///
/// These are drawing and labeling roles only: they never decide lesson order
/// or readiness, and they carry no score.
enum MapBodyRole { planet, moon, station, asteroidField }

/// Typed destinations a map body can launch into.
///
/// A target references an existing validated destination; it never invents
/// routes, content, or completion state.
enum MapTarget { discovery, mixedComparison, sentenceSections, review, arcade }

/// Immutable authored metadata for one body on a space map.
///
/// This is presentation and binding metadata only: it does not load learner
/// state, run audio, grade anything, or authorize navigation. The [x], [y],
/// and [orbitRadius] values are the authored normalized layout; orbital
/// distance never establishes lesson order.
class MapBodyDefinition {
  MapBodyDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.role,
    required this.optional,
    required this.planned,
    this.target,
    this.activityId,
    this.parentId,
    List<String> prerequisites = const [],
    required this.x,
    required this.y,
    required this.orbitRadius,
  }) : prerequisites = List.unmodifiable(prerequisites);

  /// Stable presentation identity, unique within its system.
  final String id;
  final String title;
  final String description;
  final MapBodyRole role;
  /// Optional detours can never be a prerequisite of required content.
  final bool optional;
  /// Planned bodies say “Coming soon” and carry no launch target or
  /// activity binding.
  final bool planned;

  /// The validated destination this body can launch, or null while the body
  /// is still planned.
  final MapTarget? target;

  /// The learning activity this body binds, or null: discovery binds its
  /// registry lesson id, mixed comparison binds its own activity id, and
  /// route destinations (review, sentences, arcade) bind nothing.
  final String? activityId;

  /// The body this one is a satellite of (for example, a coaching moon of a
  /// planet), or null.
  final String? parentId;

  /// Authored prerequisite body ids within the same system. Orbital
  /// position is never a prerequisite.
  final List<String> prerequisites;

  /// Authored normalized scene position, inside the unit square.
  final double x;
  final double y;

  /// Authored normalized orbital radius from the system star. Illustration
  /// only; it is not a graph edge and does not order learning.
  final double orbitRadius;
}

/// Immutable authored metadata for one sound system on the course star chart.
class MapSystemDefinition {
  MapSystemDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.planned,
    List<MapBodyDefinition> bodies = const [],
    List<String> mainOrder = const [],
  })  : bodies = List.unmodifiable(bodies),
        mainOrder = List.unmodifiable(mainOrder);

  /// Stable presentation identity (for example `en-fr-u-y-system`); it is a
  /// map identity, not a change to curriculum ids.
  final String id;
  final String title;
  final String description;

  /// Planned chart systems explain a future focus and carry no bodies,
  /// bindings, or main order: they have no launch.
  final bool planned;
  final List<MapBodyDefinition> bodies;

  /// The authored recommendation order over the system's main destinations.
  /// It never derives from orbital position or drawing order.
  final List<String> mainOrder;
}

String _detail(String systemId, String message) =>
    'System "$systemId": $message';

void _requireText(String value, String systemId, String field) {
  if (value.trim().isEmpty) {
    throw FormatException(_detail(systemId, 'field "$field" must not be blank.'));
  }
}

/// Validates one authored system against the learning registry.
///
/// Throws [FormatException] when the system's identity, body metadata,
/// activity bindings, prerequisite graph, or authored geometry is
/// inconsistent. Validation is synchronous and pure: it inspects only the
/// passed system and the registry, without validating unrelated systems or
/// loading learner state.
void validateMapSystem(
  MapSystemDefinition system, {
  required LearningRegistry registry,
}) {
  final systemId = system.id;
  _requireText(systemId, systemId, 'system.id');
  _requireText(system.title, systemId, 'system.title');
  _requireText(system.description, systemId, 'system.description');

  if (system.planned) {
    // A planned chart entry is an honest "Coming soon": its metadata must be
    // complete, but it must not carry launchable bodies or an authored main
    // order.
    if (system.bodies.isNotEmpty || system.mainOrder.isNotEmpty) {
      throw FormatException(
          _detail(systemId, 'a planned system must have no bodies or main order.'));
    }
    return;
  }

  final bodies = system.bodies;
  final bodyById = <String, MapBodyDefinition>{};
  for (final body in bodies) {
    if (bodyById.containsKey(body.id)) {
      throw FormatException(
          _detail(systemId, 'duplicate body id "${body.id}".'));
    }
    bodyById[body.id] = body;
  }

  for (final body in bodies) {
    _requireText(body.id, systemId, 'body "${body.id}".id');
    _requireText(body.title, systemId, 'body "${body.id}".title');
    _requireText(body.description, systemId, 'body "${body.id}".description');

    // Launch coherence: planned bodies never launch; every non-planned body
    // is a real destination.
    if (body.planned) {
      if (body.target != null || body.activityId != null) {
        throw FormatException(
            _detail(systemId, 'planned body "${body.id}" must have no target or activity binding.'));
      }
    } else if (body.target == null) {
      throw FormatException(
          _detail(systemId, 'body "${body.id}" must target an existing destination or stay planned.'));
    }

    // Target/role consistency.
    switch (body.target) {
      case MapTarget.discovery:
        if (body.role != MapBodyRole.planet) {
          throw FormatException(
              _detail(systemId, 'discovery body "${body.id}" must be a planet.'));
        }
        break;
      case MapTarget.mixedComparison:
      case MapTarget.sentenceSections:
      case MapTarget.review:
        if (body.role != MapBodyRole.station) {
          throw FormatException(
              _detail(systemId, '${body.target} body "${body.id}" must be a station.'));
        }
        break;
      case MapTarget.arcade:
        if (body.role != MapBodyRole.asteroidField) {
          throw FormatException(
              _detail(systemId, 'arcade body "${body.id}" must be an asteroid field.'));
        }
        break;
      case null:
        break;
    }
    // No mandatory moon: coaching is always an optional detour.
    if (body.role == MapBodyRole.moon && !body.optional) {
      throw FormatException(
          _detail(systemId, 'moon "${body.id}" must be optional.'));
    }

    // Authored geometry: finite and normalized to the scene unit square.
    _requireUnitValue(body.x, body, 'x');
    _requireUnitValue(body.y, body, 'y');
    _requireUnitValue(body.orbitRadius, body, 'orbitRadius');

    // Graph references within this system.
    if (body.parentId != null && body.parentId != body.id) {
      if (bodyById[body.parentId] == null) {
        throw FormatException(
            _detail(systemId, 'body "${body.id}" has unknown parent "${body.parentId}".'));
      }
    }
    final prerequisites = <String>{};
    for (final prerequisite in body.prerequisites) {
      if (!prerequisites.add(prerequisite)) {
        throw FormatException(
            _detail(systemId, 'body "${body.id}" lists prerequisite "$prerequisite" twice.'));
      }
      if (prerequisite == body.id) {
        throw FormatException(
            _detail(systemId, 'body "${body.id}" is its own prerequisite.'));
      }
      if (bodyById[prerequisite] == null) {
        throw FormatException(
            _detail(systemId, 'body "${body.id}" has unknown prerequisite "$prerequisite".'));
      }
    }

    _validateBinding(systemId, body, registry);
  }

  // Parent pointers form a forest.
  for (final body in bodies) {
    if (body.parentId == body.id) {
      throw FormatException(_detail(systemId, 'body "${body.id}" is its own parent.'));
    }
    final visited = <String>{};
    MapBodyDefinition? cursor = bodyById[body.parentId ?? ''];
    while (cursor != null) {
      if (!visited.add(cursor.id)) {
        throw FormatException(
            _detail(systemId, 'parent chain cycles at body "${cursor.id}".'));
      }
      cursor = bodyById[cursor.parentId ?? ''];
    }
  }

  // Prerequisite graph is acyclic and never lets required content depend on
  // an optional detour.
  final visitState = <String, int>{};
  void visit(String id) {
    final state = visitState[id];
    if (state == 2) return;
    if (state == 1) {
      throw FormatException(
          _detail(systemId, 'prerequisite cycle at body "$id".'));
    }
    visitState[id] = 1;
    for (final prerequisite in bodyById[id]!.prerequisites) {
      visit(prerequisite);
    }
    visitState[id] = 2;
    final body = bodyById[id]!;
    if (!body.optional) {
      for (final prerequisite in body.prerequisites) {
        if (bodyById[prerequisite]!.optional) {
          throw FormatException(_detail(
              systemId, 'required body "${body.id}" must not require optional body "$prerequisite".'));
        }
      }
    }
  }

  for (final id in bodyById.keys) {
    visit(id);
  }

  // Authored main order: real, required, non-planned, unique destinations.
  final ordered = <String>{};
  for (final id in system.mainOrder) {
    final body = bodyById[id];
    if (body == null) {
      throw FormatException(_detail(systemId, 'main order references unknown body "$id".'));
    }
    if (!ordered.add(id)) {
      throw FormatException(_detail(systemId, 'main order duplicates body "$id".'));
    }
    if (body.optional) {
      throw FormatException(
          _detail(systemId, 'main order includes optional body "$id".'));
    }
    if (body.planned) {
      throw FormatException(
          _detail(systemId, 'main order includes planned body "$id".'));
    }
  }
}

void _requireUnitValue(
    double value, MapBodyDefinition body, String field) {
  if (!value.isFinite) {
    throw FormatException('Body "${body.id}", $field: value must be finite.');
  }
  if (value < 0 || value > 1) {
    throw FormatException(
        'Body "${body.id}", $field: value must be within 0.0 to 1.0.');
  }
}

void _validateBinding(
    String systemId, MapBodyDefinition body, LearningRegistry registry) {
  final activityId = body.activityId;
  switch (body.target) {
    case MapTarget.discovery:
      final bound = activityId ??
          (throw FormatException(
              _detail(systemId, 'discovery body "${body.id}" must bind its lesson activity id.')));
      final definition = registry.activities.firstWhere(
        (activity) => activity.id == bound,
        orElse: () => throw FormatException(_detail(
            systemId, 'discovery binding "$bound" of body "${body.id}" is not in the learning registry.')),
      );
      if (definition.kind != LearningActivityKind.discovery) {
        throw FormatException(_detail(
            systemId, 'discovery binding of body "${body.id}" must reference a discovery activity.'));
      }
      final covered = <String>{
        for (final item in definition.items) ...item.targetSounds
      };
      if (!covered.contains('u') || !covered.contains('y')) {
        throw FormatException(_detail(
            systemId, 'discovery activity of body "${body.id}" must teach /u/ and /y/.'));
      }
      break;
    case MapTarget.mixedComparison:
      // The mixed family is bound exactly: the station uses the
      // comparison activity id and nothing else.
      if (activityId != comparisonActivityId) {
        throw FormatException(_detail(
            systemId, 'mixed practice body "${body.id}" must bind exactly $comparisonActivityId.'));
      }
      break;
    case MapTarget.review:
    case MapTarget.sentenceSections:
    case MapTarget.arcade:
      // Route destinations stay route destinations: they are not proxy
      // bindings for registry activities, so their evidence and completion
      // are never transferred.
      if (activityId != null) {
        throw FormatException(_detail(
            systemId, '${body.target} body "${body.id}" must not carry a registry activity binding.'));
      }
      break;
    case null:
      if (activityId != null) {
        throw FormatException(_detail(
            systemId, 'activity binding of body "${body.id}" requires a destination target.'));
      }
      break;
  }
}
