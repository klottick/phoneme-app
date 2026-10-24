import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/french_uy_demo_spelling_content.dart';

import 'course_map_catalogue.dart';

/// The presentation identity the map uses for the live /u/–/y/ system. This
/// is a map id, not a replacement for the curriculum's `en-fr-u-y` lesson id.
const String frenchUySystemId = 'en-fr-u-y-system';

/// The stable activity id of the /u/–/y/ discovery lesson in the shared
/// learning registry.
const String frenchDiscoveryActivityId = 'lesson:en-fr-u-y';

/// The live initial system: the authored discovery, comparison, and spelling
/// destinations, optional practice and review destinations, and honestly
/// labeled planned lessons.
final MapSystemDefinition _frenchUySystem = MapSystemDefinition(
  id: frenchUySystemId,
  title: 'Tu or tout? /u/–/y/',
  description:
      'The /u/–/y/ contrast: hear the difference in the live discovery '
      'lesson, use optional practice and review, and see where the system is '
      'heading without pretending planned lessons exist.',
  planned: false,
  bodies: [
    MapBodyDefinition(
      id: 'discovery',
      title: 'Hear the difference',
      description:
          'Live discovery planet: hear and tell /u/ and /y/ apart in real '
          'words, using the existing discovery lesson and its completion '
          'policy.',
      role: MapBodyRole.planet,
      optional: false,
      planned: false,
      target: MapTarget.discovery,
      activityId: frenchDiscoveryActivityId,
      // Authored normalized layout against the approved map image: the
      // system's first planet, closest to the star.
      x: 0.5,
      y: 0.24,
      orbitRadius: 0.1,
    ),
    MapBodyDefinition(
      id: 'comparison',
      title: 'Compare /u/ and /y/',
      description:
          'Demo practice: this authored comparison content has not had qualified French review. It is practice, not an assessment.',
      role: MapBodyRole.planet,
      optional: false,
      planned: false,
      target: MapTarget.dedicatedComparison,
      activityId: uyDemoComparisonActivityId,
      x: 0.27,
      y: 0.37,
      orbitRadius: 0.18,
    ),
    MapBodyDefinition(
      id: 'context',
      title: 'Find sounds in context',
      description:
          'Planned listening lesson: find /u/ and /y/ in context. '
          '"Coming soon"; the existing mixed sentence-hunt group is not '
          'remapped into this planet.',
      role: MapBodyRole.planet,
      optional: false,
      planned: true,
      x: 0.73,
      y: 0.4,
      orbitRadius: 0.26,
    ),
    MapBodyDefinition(
      id: 'spelling',
      title: 'Sound → spelling',
      description:
          'Demo practice: this authored spelling content has not had qualified French review. It is practice, not an assessment.',
      role: MapBodyRole.planet,
      optional: false,
      planned: false,
      target: MapTarget.dedicatedSpelling,
      activityId: uyDemoSpellingActivityId,
      x: 0.31,
      y: 0.56,
      orbitRadius: 0.34,
    ),
    MapBodyDefinition(
      id: 'checkpoint',
      title: 'Checkpoint',
      description:
          'Planned assessment. "Coming soon"; no unassessed zero score is '
          'offered.',
      role: MapBodyRole.planet,
      optional: false,
      planned: true,
      x: 0.69,
      y: 0.6,
      orbitRadius: 0.42,
    ),
    MapBodyDefinition(
      id: 'coaching',
      title: 'Coaching moon',
      description:
          'Planned optional coaching moon: articulation coaching for /u/ '
          'and /y/. It is a detour, never a requirement before the lesson.',
      role: MapBodyRole.moon,
      optional: true,
      planned: true,
      parentId: 'discovery',
      x: 0.57,
      y: 0.16,
      orbitRadius: 0.13,
    ),
    MapBodyDefinition(
      id: 'review',
      title: 'Review station',
      description:
          'The existing review destination with item-linked practice over '
          'real saved work.',
      role: MapBodyRole.station,
      optional: true,
      planned: false,
      target: MapTarget.review,
      x: 0.18,
      y: 0.73,
      orbitRadius: 0.5,
    ),
    MapBodyDefinition(
      id: 'mixed-comparison',
      title: 'Mixed comparison practice',
      description:
          'Optional cross-system station: mixed-phoneme comparison practice '
          'that covers sounds beyond /u/ and /y/, with its own evidence and '
          'completion. It is alpha practice, not the system comparison '
          'lesson.',
      role: MapBodyRole.station,
      optional: true,
      planned: false,
      target: MapTarget.mixedComparison,
      activityId: comparisonActivityId,
      x: 0.5,
      y: 0.79,
      orbitRadius: 0.55,
    ),
    MapBodyDefinition(
      id: 'sentence-practice',
      title: 'Sentence practice',
      description:
          'Optional station to the existing sentence hunt, which keeps its '
          'real qualification checks and unavailable sections.',
      role: MapBodyRole.station,
      optional: true,
      planned: false,
      target: MapTarget.sentenceSections,
      x: 0.82,
      y: 0.72,
      orbitRadius: 0.52,
    ),
    MapBodyDefinition(
      id: 'arcade',
      title: 'Asteroid arcade',
      description:
          'Optional arcade detour: the existing arcade games with their '
          'routes, timers, and rules unchanged.',
      role: MapBodyRole.asteroidField,
      optional: true,
      planned: false,
      target: MapTarget.arcade,
      x: 0.63,
      y: 0.9,
      orbitRadius: 0.62,
    ),
  ],
  // Authored recommendation order; orbital distance and drawing position
  // never contribute.
  mainOrder: ['discovery', 'comparison', 'spelling'],
);

/// Planned chart systems: they explain a future sound focus, they do not
/// claim content, bindings, or launch actions.
final MapSystemDefinition _frenchNasalsSystem = MapSystemDefinition(
  id: 'en-fr-nasals-system',
  title: 'Nasal vowels',
  description:
      'Planned sound system: French nasal vowels. "Coming soon"; no lesson '
      'content is available yet.',
  planned: true,
);

final MapSystemDefinition _frenchRSystem = MapSystemDefinition(
  id: 'en-fr-r-system',
  title: 'French R',
  description:
      'Planned sound system: the French R. "Coming soon"; no lesson content '
      'is available yet.',
  planned: true,
);

/// The English → French course as authored on the space map: the live
/// /u/–/y/ system first, then the two planned chart systems.
final List<MapSystemDefinition> frenchSpaceSystems = List.unmodifiable([
  _frenchUySystem,
  _frenchNasalsSystem,
  _frenchRSystem,
]);

/// Finds the authored system with the given presentation id, or null when
/// the id is unknown. Unknown ids are not replaced by a fabricated empty
/// system.
MapSystemDefinition? findSpaceSystem(String id) =>
    frenchSpaceSystems.where((system) => system.id == id).firstOrNull;
