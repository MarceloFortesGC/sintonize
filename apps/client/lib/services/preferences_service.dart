import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/room_user.dart';

/// Cache local (shared_preferences) — database_and_state.md §1.
class PreferencesService {
  static const _kUserId = 'user_id';
  static const _kUserName = 'user_name';
  static const _kUserProfile = 'user_profile';
  static const _kOnboardingCompleted = 'onboarding_completed';
  static const _kLastRoomUrl = 'last_room_url';

  final SharedPreferences _prefs;
  PreferencesService(this._prefs);

  static Future<PreferencesService> create() async {
    return PreferencesService(await SharedPreferences.getInstance());
  }

  bool get isCacheValid {
    final onboarding = _prefs.getBool(_kOnboardingCompleted) == true;
    final id = _prefs.getString(_kUserId);
    final name = _prefs.getString(_kUserName);
    final profile = _prefs.getString(_kUserProfile);
    return onboarding &&
        id != null &&
        id.isNotEmpty &&
        name != null &&
        name.isNotEmpty &&
        (profile == 'host' || profile == 'listener');
  }

  String get userId {
    var id = _prefs.getString(_kUserId);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      _prefs.setString(_kUserId, id);
    }
    return id;
  }

  String? get userName => _prefs.getString(_kUserName);

  UserProfile get userProfile =>
      profileFromString(_prefs.getString(_kUserProfile) ?? 'listener');

  String? get lastRoomUrl => _prefs.getString(_kLastRoomUrl);

  Future<void> completeOnboarding({
    required String name,
    required UserProfile profile,
    String? roomUrl,
  }) async {
    final id = userId; // garante geração do UUID
    await _prefs.setString(_kUserId, id);
    await _prefs.setString(_kUserName, name);
    await _prefs.setString(_kUserProfile, profileToString(profile));
    await _prefs.setBool(_kOnboardingCompleted, true);
    if (roomUrl != null) {
      await _prefs.setString(_kLastRoomUrl, roomUrl);
    }
  }

  Future<void> setLastRoomUrl(String url) =>
      _prefs.setString(_kLastRoomUrl, url);

  Future<void> clear() => _prefs.clear();
}
