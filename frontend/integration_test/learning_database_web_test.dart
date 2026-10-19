import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:linguist/src/core/course/storage/learning_database_connection.dart';

import '../test/support/learning_database_smoke.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('web database probe survives close and reopen', (
    WidgetTester tester,
  ) async {
    const String probeKey = 'task1-integration-probe';
    const String probeValue = 'sqlite-persisted';

    final LearningDatabaseConnection firstConnection =
        await openLearningDatabaseConnection();
    final LearningDatabaseSmoke firstDatabase = LearningDatabaseSmoke(
      firstConnection.connection,
    );
    try {
      expect(firstConnection.webImplementation, isNotNull);
      expect(
        acceptsLearningWebImplementation(firstConnection.webImplementation!),
        isTrue,
      );
      await firstDatabase.writeProbe(probeKey, probeValue);
      expect(await firstDatabase.readProbe(probeKey), probeValue);
    } finally {
      await firstDatabase.close();
    }

    final LearningDatabaseConnection reopenedConnection =
        await openLearningDatabaseConnection();
    final LearningDatabaseSmoke reopenedDatabase = LearningDatabaseSmoke(
      reopenedConnection.connection,
    );
    try {
      expect(reopenedConnection.webImplementation, isNotNull);
      expect(
        acceptsLearningWebImplementation(reopenedConnection.webImplementation!),
        isTrue,
      );
      expect(await reopenedDatabase.readProbe(probeKey), probeValue);
    } finally {
      await reopenedDatabase.close();
    }
  });
}
