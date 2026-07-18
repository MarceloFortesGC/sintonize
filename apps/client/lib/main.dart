import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'services/locale_controller.dart';
import 'services/preferences_service.dart';
import 'screens/onboarding_name_screen.dart';
import 'screens/room_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await PreferencesService.create();
  final localeController = LocaleController(prefs);
  runApp(SintonizeApp(prefs: prefs, localeController: localeController));
}

String resolveBaseUrl() {
  final base = Uri.base;
  if (base.hasAuthority && base.scheme.startsWith('http')) {
    return '${base.scheme}://${base.authority}';
  }
  return 'http://localhost:3000';
}

class SintonizeApp extends StatelessWidget {
  final PreferencesService prefs;
  final LocaleController localeController;
  const SintonizeApp({
    super.key,
    required this.prefs,
    required this.localeController,
  });

  @override
  Widget build(BuildContext context) {
    final baseUrl = resolveBaseUrl();
    // ListenableBuilder reconstrói o MaterialApp (com o novo `locale`)
    // assim que o usuário troca o idioma pelo LanguageSelector — troca
    // aplica imediatamente, em qualquer tela.
    return ListenableBuilder(
      listenable: localeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Sintonize',
          debugShowCheckedModeBanner: false,
          theme: buildSintonizeTheme(),
          locale: localeController.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: LocaleController.supportedLocales,
          // `locale` fica null até o usuário escolher manualmente (ver
          // LocaleController) — nesse caso o Flutter chama este callback
          // com o idioma do dispositivo para a detecção automática na
          // primeira visita. Fora de pt/en/es, cai para português.
          localeResolutionCallback: (deviceLocale, supportedLocales) =>
              LocaleController.resolveDeviceLocale(
                  deviceLocale, supportedLocales),
          home: prefs.isCacheValid
              ? RoomScreen(
                  prefs: prefs,
                  baseUrl: baseUrl,
                  localeController: localeController,
                )
              : OnboardingNameScreen(
                  prefs: prefs,
                  baseUrl: baseUrl,
                  localeController: localeController,
                ),
        );
      },
    );
  }
}
