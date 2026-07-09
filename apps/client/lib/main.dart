import 'package:flutter/material.dart';

import 'services/preferences_service.dart';
import 'screens/onboarding_name_screen.dart';
import 'screens/room_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await PreferencesService.create();
  runApp(SintonizeApp(prefs: prefs));
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
  const SintonizeApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    final baseUrl = resolveBaseUrl();
    return MaterialApp(
      title: 'Sintonize',
      debugShowCheckedModeBanner: false,
      theme: buildSintonizeTheme(),
      home: prefs.isCacheValid
          ? RoomScreen(prefs: prefs, baseUrl: baseUrl)
          : OnboardingNameScreen(prefs: prefs, baseUrl: baseUrl),
    );
  }
}
