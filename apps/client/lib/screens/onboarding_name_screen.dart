import 'package:flutter/material.dart';

import '../config.dart';
import '../services/preferences_service.dart';
import '../theme.dart';
import 'onboarding_profile_screen.dart';

/// Passo 1 do onboarding — nome (frontend_flow.md §B.2).
class OnboardingNameScreen extends StatefulWidget {
  final PreferencesService prefs;
  final String baseUrl;
  const OnboardingNameScreen({
    super.key,
    required this.prefs,
    required this.baseUrl,
  });

  @override
  State<OnboardingNameScreen> createState() => _OnboardingNameScreenState();
}

class _OnboardingNameScreenState extends State<OnboardingNameScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.prefs.userName ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => _controller.text.trim().isNotEmpty;

  void _continue() {
    if (!_valid) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OnboardingProfileScreen(
          prefs: widget.prefs,
          baseUrl: widget.baseUrl,
          name: _controller.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Sintonize',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontWeight: FontWeight.w700,
                      fontSize: 34,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Bem-vindo à Sala',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Digite seu nome para continuar',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    maxLength: SintonizeConfig.maxNameLength,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _continue(),
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _valid ? _continue : null,
                    child: const Text('Continuar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
