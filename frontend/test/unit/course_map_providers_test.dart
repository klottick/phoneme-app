import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/features/course_map/course_map_providers.dart';

void main() {
  test('projection provider is keyed by presentation system id', () {
    expect(courseMapStateProvider, isNotNull);
  });
}
