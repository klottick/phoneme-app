import 'dart:math';

String createComparisonSessionId() =>
    'comparison-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}';
