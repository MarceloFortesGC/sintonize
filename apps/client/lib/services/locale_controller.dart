import 'package:flutter/material.dart';

import 'preferences_service.dart';

/// Controla o idioma ativo do app.
///
/// Prioridade (ver l10n.yaml / requisito de i18n):
/// 1. Escolha manual do usuário, persistida em [PreferencesService]
///    (chave 'sintonize.locale') — tem prioridade sobre tudo.
/// 2. Se o usuário nunca escolheu, [locale] fica `null` e o MaterialApp usa
///    o mecanismo padrão do Flutter (`localeResolutionCallback`) para
///    detectar o idioma do dispositivo na primeira visita, caindo para
///    português quando o idioma do aparelho não é pt/en/es.
class LocaleController extends ChangeNotifier {
  final PreferencesService prefs;

  static const List<Locale> supportedLocales = [
    Locale('pt'),
    Locale('en'),
    Locale('es'),
  ];

  Locale? _locale;

  LocaleController(this.prefs) {
    final saved = prefs.userLocale;
    if (saved != null && _isSupported(saved)) {
      _locale = Locale(saved);
    }
  }

  /// `null` quando não há escolha manual salva — o MaterialApp deve
  /// resolver o locale sozinho (via `localeResolutionCallback`).
  Locale? get locale => _locale;

  bool _isSupported(String languageCode) =>
      supportedLocales.any((l) => l.languageCode == languageCode);

  Future<void> setLocale(Locale locale) async {
    if (!_isSupported(locale.languageCode)) return;
    _locale = locale;
    notifyListeners();
    await prefs.setUserLocale(locale.languageCode);
  }

  /// Resolve o idioma do dispositivo para um dos suportados, com fallback
  /// para português — usado em [MaterialApp.localeResolutionCallback].
  static Locale resolveDeviceLocale(
    Locale? deviceLocale,
    Iterable<Locale> supported,
  ) {
    if (deviceLocale != null) {
      for (final candidate in supported) {
        if (candidate.languageCode == deviceLocale.languageCode) {
          return candidate;
        }
      }
    }
    return const Locale('pt');
  }
}
