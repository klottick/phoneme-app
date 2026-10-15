import 'package:shared_preferences/shared_preferences.dart';

export 'course_learning_codec.dart' show LearningDocumentCodec;

abstract class LearningPersistence {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> restore(String key, String? lastCommitted);
  Future<void> reload();
}

/// SharedPreferences has an optimistic in-process cache. Repository access is
/// serialized separately; restore verifies the durable image before returning.
class PreferencesLearningPersistence implements LearningPersistence {
  PreferencesLearningPersistence({
    Future<SharedPreferences> Function()? preferences,
  }) : _preferences = preferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _preferences;

  @override
  Future<String?> read(String key) async =>
      (await _preferences()).getString(key);

  @override
  Future<void> write(String key, String value) async {
    if (!await (await _preferences()).setString(key, value)) {
      throw StateError('Preferences rejected the learning document.');
    }
  }

  @override
  Future<void> restore(String key, String? lastCommitted) async {
    final preferences = await _preferences();
    final succeeded = lastCommitted == null
        ? await preferences.remove(key)
        : await preferences.setString(key, lastCommitted);
    if (!succeeded) {
      throw StateError('Preferences could not restore learning data.');
    }
    await preferences.reload();
    if (preferences.getString(key) != lastCommitted) {
      throw StateError('Preferences restore could not be verified.');
    }
  }

  @override
  Future<void> reload() async => (await _preferences()).reload();
}
