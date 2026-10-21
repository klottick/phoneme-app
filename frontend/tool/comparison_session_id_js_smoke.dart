import 'package:linguist/src/features/course/comparison_session_id.dart';

void main() {
  final ids = List.generate(100, (_) => createComparisonSessionId());
  if (ids.toSet().length != ids.length ||
      ids.any((id) => !RegExp(r'^comparison-\d+-\d+$').hasMatch(id))) {
    throw StateError('comparison session IDs are invalid or not unique');
  }
  // ignore: avoid_print
  print('100 valid unique comparison session IDs');
}
