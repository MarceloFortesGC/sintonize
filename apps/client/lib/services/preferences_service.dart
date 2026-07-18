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
  static const _kLocale = 'sintonize.locale';

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

  /// Código de idioma escolhido manualmente pelo usuário (ex. 'pt', 'en',
  /// 'es'). `null` quando o usuário nunca escolheu — nesse caso o app usa
  /// detecção automática do idioma do dispositivo (ver LocaleController).
  String? get userLocale => _prefs.getString(_kLocale);

  Future<void> setUserLocale(String languageCode) =>
      _prefs.setString(_kLocale, languageCode);

  /// Limpa os dados da sessão (nome, perfil, id) ao sair/ser removido da
  /// sala. O idioma é uma preferência de dispositivo, não de sessão — deve
  /// sobreviver a esse reset (ver requisito de persistência da escolha de
  /// idioma).
  Future<void> clear() async {
    final locale = userLocale;
    await _prefs.clear();
    if (locale != null) {
      await _prefs.setString(_kLocale, locale);
    }
  }
}
