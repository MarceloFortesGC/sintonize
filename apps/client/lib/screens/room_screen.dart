import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../l10n/app_localizations.dart';
import '../services/locale_controller.dart';
import '../services/preferences_service.dart';
import '../services/room_controller.dart';
import '../services/speaker_guard.dart';
import '../theme.dart';
import '../widgets/audio_level_indicator.dart';
import '../widgets/language_selector.dart';
import 'onboarding_name_screen.dart';

/// Room View (frontend_flow.md §B.4).
class RoomScreen extends StatefulWidget {
  final PreferencesService prefs;
  final String baseUrl;
  final LocaleController localeController;
  const RoomScreen({
    super.key,
    required this.prefs,
    required this.baseUrl,
    required this.localeController,
  });

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final RoomController _controller;
  late final SpeakerGuard _speakerGuard;
  bool _redirected = false;
  bool _likelySpeakerOutput = false;
  late double _masterVolume;

  @override
  void initState() {
    super.initState();
    _controller = RoomController(prefs: widget.prefs, baseUrl: widget.baseUrl);
    _masterVolume = _controller.masterVolume;
    _controller.addListener(_onChange);
    _controller.connect();

    // Best-effort (só web/Android com confiança suficiente — ver
    // speaker_guard_web.dart): bloqueia a Room View enquanto o áudio
    // parecer estar saindo pelo alto-falante do aparelho.
    _speakerGuard = SpeakerGuard();
    _speakerGuard.startWatching((likelySpeaker) {
      if (mounted) setState(() => _likelySpeakerOutput = likelySpeaker);
    });
  }

  void _onChange() {
    if (_controller.kicked && !_redirected) {
      _redirected = true;
      final message = _controller.kickedMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => OnboardingNameScreen(
              prefs: widget.prefs,
              baseUrl: widget.baseUrl,
              localeController: widget.localeController,
            ),
          ),
          (route) => false,
        );
        // Mensagem vinda do servidor (motivo do kick) — não é traduzida
        // pelo cliente, exibida como o backend enviar.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      });
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _controller.dispose();
    _speakerGuard.dispose();
    super.dispose();
  }

  Future<void> _confirmLeave() async {
    final l10n = AppLocalizations.of(context);
    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.leaveRoomTitle),
        content: Text(l10n.leaveRoomBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(0, 44),
            ),
            child: Text(l10n.exitButton),
          ),
        ],
      ),
    );
    if (step1 != true || !mounted) return;

    final step2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.confirmExitTitle),
        content: Text(l10n.confirmExitBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.backButton),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(0, 44),
            ),
            child: Text(l10n.confirmExitButton),
          ),
        ],
      ),
    );
    if (step2 != true || !mounted) return;

    await _controller.leaveRoom();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => OnboardingNameScreen(
          prefs: widget.prefs,
          baseUrl: widget.baseUrl,
          localeController: widget.localeController,
        ),
      ),
      (route) => false,
    );
  }

  String _statusLabel(AppLocalizations l10n) {
    switch (_controller.status) {
      case RoomStatus.connected:
        return l10n.statusConnected;
      case RoomStatus.connecting:
        return l10n.statusConnecting;
      case RoomStatus.reconnecting:
        return l10n.statusReconnecting;
      case RoomStatus.lost:
        return l10n.statusLost;
    }
  }

  Color get _statusColor {
    switch (_controller.status) {
      case RoomStatus.connected:
        return AppColors.success;
      case RoomStatus.reconnecting:
      case RoomStatus.connecting:
        return AppColors.accent;
      case RoomStatus.lost:
        return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = _controller;
    final active = c.status == RoomStatus.connected && c.transmitterCount > 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(l10n.activeRoomTitle),
        actions: [
          LanguageSelector(localeController: widget.localeController),
          const SizedBox(width: 4),
          TextButton(
            onPressed: _confirmLeave,
            child: Text(l10n.exitButton,
                style: const TextStyle(color: AppColors.text)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // RTCVideoViews ocultos garantem a reprodução do áudio remoto.
            Offstage(
              child: Column(
                children: [
                  for (final r in c.renderers.values)
                    SizedBox(
                      width: 1,
                      height: 1,
                      child: RTCVideoView(r),
                    ),
                ],
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (c.status == RoomStatus.reconnecting ||
                          c.status == RoomStatus.lost)
                        _banner(
                          context,
                          c.status == RoomStatus.lost
                              ? l10n.connectionLostCheckNetwork
                              : l10n.statusReconnecting,
                          showRetry: c.status == RoomStatus.lost,
                        ),
                      if (c.apIsolationDetected)
                        _banner(context, l10n.apIsolationWarning),
                      if (c.micBlocked) _banner(context, l10n.micBlockedError),
                      if (c.forcedMuted)
                        _banner(context, l10n.forcedMutedWarning),
                      if (active && c.silentAudioWarning)
                        _banner(context, l10n.silentAudioWarning),
                      const SizedBox(height: 8),
                      Text(
                        active
                            ? l10n.receivingAudio
                            : c.status == RoomStatus.connected
                                ? l10n.waitingForTransmission
                                : l10n.transmittingSources(c.transmitterCount),
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      AudioLevelIndicator(active: active, level: c.audioLevel),
                      const SizedBox(height: 28),
                      Text(l10n.volumeLabel,
                          style: const TextStyle(color: AppColors.textMuted)),
                      Slider(
                        value: _masterVolume,
                        onChanged: (value) {
                          setState(() => _masterVolume = value);
                          c.setMasterVolume(value);
                        },
                        activeColor: AppColors.primary,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(_statusLabel(l10n)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Portão de áudio único (substitui os antigos overlays
            // separados de "Toque para ouvir" e bloqueio de alto-falante):
            // cobre a tela sempre que o som ainda não foi confirmado pelo
            // usuário, foi bloqueado pelo navegador, ou foi interrompido
            // (fone desconectado). Nunca há dois overlays de áudio ao
            // mesmo tempo — a prioridade abaixo garante isso.
            if (_audioGateOverlayVisible(c)) _audioGateOverlay(context, c),
            // Best-effort: só cobre a tela quando há confiança de que o
            // som sai pelo alto-falante do aparelho (ver speaker_guard_web.dart).
            // O portão de áudio tem prioridade — sem ele não há som saindo
            // em nenhuma saída, e este overlay cobriria o botão do portão.
            if (_likelySpeakerOutput && !_audioGateOverlayVisible(c))
              _speakerGuardOverlay(context),
          ],
        ),
      ),
    );
  }

  /// True enquanto o áudio não estiver liberado: portão ainda não
  /// confirmado (primeiro acesso/reload), tocada interrompida (fone
  /// desconectou) ou um novo stream chegou bloqueado. Um único overlay
  /// cobre os três casos — só o texto/ícone muda (ver [_audioGateOverlay]).
  bool _audioGateOverlayVisible(RoomController c) =>
      !c.audioGateConfirmed || c.audioInterrupted || c.audioPlaybackBlocked;

  /// Portão de áudio único e obrigatório. O som nunca começa sozinho: só
  /// o toque no botão (gesto real do usuário) chama play() — ver
  /// RoomController.confirmAudioGate. Mesmo widget cobre três situações,
  /// só muda o texto/ícone conforme o estado do controller.
  Widget _audioGateOverlay(BuildContext context, RoomController c) {
    final l10n = AppLocalizations.of(context);
    final IconData icon;
    final String title;
    final String body;
    final String buttonLabel;

    if (c.audioInterrupted) {
      icon = Icons.headset_off;
      title = l10n.audioStoppedTitle;
      body = l10n.audioStoppedBody;
      buttonLabel = l10n.continueButton;
    } else if (!c.audioGateConfirmed) {
      icon = Icons.headset;
      title = l10n.connectHeadphonesTitle;
      body = l10n.connectHeadphonesBody;
      buttonLabel = l10n.startListeningButton;
    } else {
      icon = Icons.volume_off;
      title = l10n.tapToListenTitle;
      body = l10n.tapToListenBody;
      buttonLabel = l10n.playAudioButton;
    }

    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.bg.withValues(alpha: 0.97),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: AppColors.primary, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: const TextStyle(color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => c.confirmAudioGate(),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(buttonLabel),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _speakerGuardOverlay(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.bg.withValues(alpha: 0.96),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.headset, color: AppColors.primary, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    l10n.useHeadphonesTitle,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.useHeadphonesBody,
                    style: const TextStyle(color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.headphoneAutoDetectNote,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _banner(BuildContext context, String message,
      {bool showRetry = false}) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent),
      ),
      child: Row(
        children: [
          Expanded(child: Text(message)),
          if (showRetry)
            TextButton(
              onPressed: () => _controller.connect(),
              child: Text(l10n.retryButton),
            ),
        ],
      ),
    );
  }
}
