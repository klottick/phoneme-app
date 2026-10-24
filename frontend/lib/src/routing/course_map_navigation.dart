import '../features/course_map/course_map_catalogue.dart';
import '../features/course_map/course_map_state.dart';
import '../features/course_map/french_space_map.dart';
import '../core/course/french_uy_demo_spelling_content.dart';

String? courseMapLocation(MapTarget target, MapLaunch launch) {
  return switch ((target, launch)) {
    (MapTarget.discovery, MapLaunch.start) => '/course-lesson/en-fr-u-y',
    (MapTarget.discovery, MapLaunch.resume) => '/course-lesson/en-fr-u-y',
    (MapTarget.discovery, MapLaunch.review) =>
      '/course-lesson/en-fr-u-y?review=true',
    (MapTarget.dedicatedComparison, MapLaunch.start) =>
      '/course-comparison/en-fr-u-y-comparison',
    (MapTarget.dedicatedComparison, MapLaunch.resume) =>
      '/course-comparison/en-fr-u-y-comparison',
    (MapTarget.dedicatedComparison, MapLaunch.review) =>
      '/course-comparison/en-fr-u-y-comparison?review=true',
    (MapTarget.dedicatedSpelling, MapLaunch.start) =>
      '/course-spelling/$uyDemoSpellingActivityId',
    (MapTarget.dedicatedSpelling, MapLaunch.resume) =>
      '/course-spelling/$uyDemoSpellingActivityId',
    (MapTarget.dedicatedSpelling, MapLaunch.review) =>
      '/course-spelling/$uyDemoSpellingActivityId?review=true',
    (MapTarget.mixedComparison, MapLaunch.open) =>
      '/course-comparison/en-fr-phoneme-comparison',
    (MapTarget.mixedComparison, MapLaunch.review) =>
      '/course-comparison/en-fr-phoneme-comparison?review=true',
    (MapTarget.review, MapLaunch.open) => '/course-review',
    (MapTarget.sentenceSections, MapLaunch.open) => '/course-sentence-hunt',
    (MapTarget.arcade, MapLaunch.open) => '/arcade',
    _ => null,
  };
}

bool isKnownCourseSystem(String id) => findSpaceSystem(id) != null;
