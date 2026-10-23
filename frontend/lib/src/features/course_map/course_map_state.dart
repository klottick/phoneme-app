import 'course_map_catalogue.dart';

enum MapReadiness { alpha, planned, qualificationBlocked, loading, unavailable }

enum MapProgress { unknown, notStarted, resumable, completed }

enum MapLaunch { start, resume, review, open }

final class MapBodyState {
  MapBodyState({
    required this.definition,
    required this.readiness,
    required this.progress,
    required this.recommended,
    required this.explanation,
    required this.launch,
    List<String> evidenceLabels = const [],
  }) : evidenceLabels = List.unmodifiable(evidenceLabels);

  final MapBodyDefinition definition;
  final MapReadiness readiness;
  final MapProgress progress;
  final bool recommended;
  final String explanation;
  final MapLaunch? launch;
  final List<String> evidenceLabels;
}

final class CourseMapState {
  CourseMapState({
    required this.systemId,
    required List<MapBodyState> bodies,
    required this.currentBodyId,
    required this.allAvailableMainComplete,
    required Set<String>? completedLegacyLessonIds,
  }) : bodies = List.unmodifiable(bodies),
       completedLegacyLessonIds = completedLegacyLessonIds == null
           ? null
           : Set.unmodifiable(completedLegacyLessonIds);

  final String systemId;
  final List<MapBodyState> bodies;
  final String? currentBodyId;
  final bool allAvailableMainComplete;
  final Set<String>? completedLegacyLessonIds;
}
