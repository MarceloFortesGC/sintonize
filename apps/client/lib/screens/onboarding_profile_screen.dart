import 'package:flutter/material.dart';

import '../models/room_user.dart';
import '../services/preferences_service.dart';
import '../theme.dart';
import 'room_screen.dart';

/// Passo 2 do onboarding — perfil (frontend_flow.md §B.3).
class OnboardingProfileScreen extends StatefulWidget {
  final PreferencesService prefs;
  final String baseUrl;
  final String name;
  const OnboardingProfileScreen({
    super.key,
    required this.prefs,
    required this.baseUrl,
    required this.name,
  });

  @override
  State<OnboardingProfileScreen> createState() =>
      _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends State<OnboardingProfileScreen> {
  UserProfile? _selected;

  Future<void> _enter() async {
    final profile = _selected;
    if (profile == null) return;

    if (profile == UserProfile.host) {
      final proceed = await _showMicDialog();
      if (proceed != true) return;
    }

    await widget.prefs.completeOnboarding(
      name: widget.name,
      profile: profile,
      roomUrl: widget.baseUrl,
    );

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            RoomScreen(prefs: widget.prefs, baseUrl: widget.baseUrl),
      ),
      (route) => false,
    );
  }

  Future<bool?> _showMicDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Acesso ao microfone'),
        content: const Text(
          'Para transmitir áudio, precisamos acessar seu microfone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: const Text('Permitir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Olá, ${widget.name}! Como você vai participar da sala?',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: _ProfileCard(
                          icon: Icons.headphones,
                          title: 'Ouvinte',
                          subtitle: 'Apenas ouvir',
                          selected: _selected == UserProfile.listener,
                          onTap: () =>
                              setState(() => _selected = UserProfile.listener),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _ProfileCard(
                          icon: Icons.mic,
                          title: 'Host',
                          subtitle: 'Transmite microfone',
                          selected: _selected == UserProfile.host,
                          onTap: () =>
                              setState(() => _selected = UserProfile.host),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: _selected != null ? _enter : null,
                    child: const Text('Entrar na Sala'),
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

class _ProfileCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $subtitle',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 40,
                  color: selected ? AppColors.primary : AppColors.textMuted),
              const SizedBox(height: 12),
              Text(title,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
