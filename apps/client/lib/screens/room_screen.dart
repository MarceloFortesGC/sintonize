import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../services/preferences_service.dart';
import '../services/room_controller.dart';
import '../services/speaker_guard.dart';
import '../theme.dart';
import '../widgets/audio_level_indicator.dart';
import 'onboarding_name_screen.dart';

/// Room View (frontend_flow.md §B.4).
class RoomScreen extends StatefulWidget {
  final PreferencesService prefs;
  final String baseUrl;
  const RoomScreen({super.key, required this.prefs, required this.baseUrl});

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
            ),
          ),
          (route) => false,
        );
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
    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Sair da Sala?'),
        content: const Text(
          'Isso encerrará sua conexão e apagará seus dados neste dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(0, 44),
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (step1 != true || !mounted) return;

    final step2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Tem certeza?'),
        content: const Text(
          'Você precisará informar seu nome e perfil novamente na próxima vez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(0, 44),
            ),
            child: const Text('Confirmar Saída'),
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
        ),
      ),
      (route) => false,
    );
  }

  String get _statusLabel {
    switch (_controller.status) {
      case RoomStatus.connected:
        return 'Conectado';
      case RoomStatus.connecting:
        return 'Conectando…';
      case RoomStatus.reconnecting:
        return 'Reconectando…';
      case RoomStatus.lost:
        return 'Conexão perdida';
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
    final c = _controller;
    final active = c.status == RoomStatus.connected && c.transmitterCount > 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Sala Ativa'),
        actions: [
          TextButton(
            onPressed: _confirmLeave,
            child: const Text('Sair', style: TextStyle(color: AppColors.text)),
          ),
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
                          c.status == RoomStatus.lost
                              ? 'Conexão perdida. Verifique sua rede.'
                              : 'Reconectando…',
                          showRetry: c.status == RoomStatus.lost,
                        ),
                      if (c.apIsolationDetected)
                        _banner(
                          'Conectado à sala, mas o áudio ainda não chegou. '
                          'Possíveis causas: firewall do computador transmissor '
                          'bloqueando a conexão, ou roteador com "Isolamento de '
                          'Cliente" ativado. A conexão continua tentando.',
                        ),
                      if (c.micError != null) _banner(c.micError!),
                      if (c.forcedMuted)
                        _banner('Seu áudio foi silenciado pelo administrador.'),
                      if (active && c.silentAudioWarning)
                        _banner(
                          'O som está chegando vazio. Verifique a fonte de '
                          'áudio na Estação Central.',
                        ),
                      const SizedBox(height: 8),
                      Text(
                        active
                            ? 'Recebendo áudio'
                            : c.status == RoomStatus.connected
                                ? 'Aguardando transmissão…'
                                : 'Transmitindo: ${c.transmitterCount} fonte(s)',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      AudioLevelIndicator(active: active, level: c.audioLevel),
                      const SizedBox(height: 28),
                      const Text('Volume',
                          style: TextStyle(color: AppColors.textMuted)),
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
                          Text(_statusLabel),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Autoplay bloqueado (comum no primeiro carregamento, sobretudo
            // no Safari iOS): exige um gesto real do usuário para tocar.
            if (c.audioPlaybackBlocked) _playAudioOverlay(c),
            // Best-effort: só cobre a tela quando há confiança de que o
            // som sai pelo alto-falante do aparelho (ver speaker_guard_web.dart).
            // O overlay de autoplay tem prioridade — sem o gesto de
            // desbloqueio não há som em saída nenhuma, e este overlay
            // cobriria o botão "Tocar áudio".
            if (_likelySpeakerOutput && !c.audioPlaybackBlocked)
              _speakerGuardOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _playAudioOverlay(RoomController c) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.72),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.volume_off, color: AppColors.text, size: 40),
                  const SizedBox(height: 16),
                  const Text(
                    'Toque para ouvir',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'O navegador bloqueou a reprodução automática do som.',
                    style: TextStyle(color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => c.retryAudioPlayback(),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Tocar áudio'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _speakerGuardOverlay() {
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
                  const Text(
                    'Use fone de ouvido',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Conecte um fone de ouvido ou aparelho Bluetooth para '
                    'ouvir. O som pelo alto-falante foi bloqueado por '
                    'privacidade.',
                    style: TextStyle(color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Assim que detectarmos o fone, a tela libera sozinha.',
                    style: TextStyle(
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

  Widget _banner(String message, {bool showRetry = false}) {
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
              child: const Text('Tentar novamente'),
            ),
        ],
      ),
    );
  }
}
