import 'package:flutter_test/flutter_test.dart';
import 'package:linguist/src/core/course/comparison_content.dart';
import 'package:linguist/src/core/course/french_comparison_content.dart';

void main() {
  test(
    'registry exposes immutable lookup and distinguishes unknown from unavailable',
    () {
      final catalogue = loadFrenchComparisonCatalogue();
      final unavailable = ComparisonCatalogueRegistration.unavailable(
        activityId: uyDemoComparisonActivityId,
        cause: StateError('pending'),
      );
      final registry = ComparisonCatalogueRegistry([
        ComparisonCatalogueRegistration.available(catalogue),
        unavailable,
      ]);

      expect(registry.registrationFor('not-registered'), isNull);
      expect(
        registry.registrationFor(uyDemoComparisonActivityId),
        same(unavailable),
      );
      expect(
        registry.registrationFor(uyDemoComparisonActivityId)!.catalogue,
        isNull,
      );
      expect(() => registry.byActivityId.clear(), throwsUnsupportedError);
      expect(
        () => registry.requireAvailable(uyDemoComparisonActivityId),
        throwsStateError,
      );
      expect(registry.requireAvailable(comparisonActivityId), same(catalogue));
    },
  );

  test('registry rejects duplicate keys and blank unavailable IDs', () {
    final catalogue = loadFrenchComparisonCatalogue();
    final available = ComparisonCatalogueRegistration.available(catalogue);
    expect(
      () => ComparisonCatalogueRegistry([available, available]),
      throwsFormatException,
    );
    expect(
      () => ComparisonCatalogueRegistration.unavailable(
        activityId: ' ',
        cause: StateError('unavailable'),
      ),
      throwsFormatException,
    );
  });
}
