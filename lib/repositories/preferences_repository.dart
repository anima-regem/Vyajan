import '../models/user_preferences.dart';

abstract class PreferencesRepository {
  Stream<UserPreferences> watchPreferences(String userId);

  Future<UserPreferences> getPreferences(String userId);

  Future<void> setPreferences(String userId, UserPreferences preferences);

  Future<void> patchPreferences(String userId, Map<String, dynamic> patch);
}
