import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../config.dart';
import '../models/room_user.dart';
import 'audio_level_meter.dart';
import 'preferences_service.dart';
import 'socket_service.dart';
import 'web_audio_unlock.dart';
import 'webrtc_service.dart';

enum RoomStatus { connecting, connected, reconnecting, lost }

/// Orquestra a sessão da sala: sinalização, malha WebRTC, áudio e microfone.
class RoomController extends ChangeNotifier {
  final PreferencesService prefs;
  final String baseUrl;

  RoomController({required this.prefs, required this.baseUrl});

  late final SocketService _socket = SocketService(baseUrl);
  WebRTCService? _webrtc;
  MediaStream? _localStream;

  final Map<String, RTCVideoRenderer> renderers = {};
  final Map<String, AudioLevelMeter> _levelMeters = {};
  final Map<String, double> _levels = {};

  RoomStatus status = RoomStatus.connecting;
  List<RoomUser> users = [];
  String selfId = '';
  double masterVolume = 1.0;
  bool forcedMuted = false;
  UserProfile? sessionProfileOverride;

  /// True quando o navegador negou/bloqueou o acesso ao microfone. A
  /// mensagem exibida é resolvida na UI (room_screen.dart) via
  /// AppLocalizations — este controller não guarda texto de UI, só o
  /// estado, para não depender de contexto de localização aqui.
  bool micBlocked = false;
  bool apIsolationDetected = false;
  bool kicked = false;
  String kickedMessage = '';

  /// Web: true quando algum elemento de áudio/vídeo com fonte continua
  /// pausado (autoplay bloqueado, ou um novo stream chegou depois do
  /// portão já confirmado e ainda não recebeu o toque). A Room View deve
  /// mostrar o portão de áudio nesse caso.
  bool audioPlaybackBlocked = false;

  /// Portão de confirmação de áudio (ver room_screen.dart): o som NUNCA
  /// começa sozinho. Só vira `true` depois que o usuário toca o botão
  /// "Já conectei — começar a ouvir", um gesto real exigido tanto para
  /// contornar o autoplay do Safari quanto — mais importante — para
  /// garantir que o usuário conectou o fone antes de qualquer som sair
  /// (cenário: reunião silenciosa). Reseta a cada nova sessão/reload
  /// porque é um campo de instância recriado do zero a cada RoomScreen.
  bool audioGateConfirmed = false;

  /// True quando um elemento de áudio que já estava tocando parou sozinho
  /// (evento `pause` não solicitado pelo app) — o caso típico é o
  /// fone Bluetooth/cabo desconectando, que faz iOS/Chrome pausar a mídia
  /// automaticamente. Enquanto essa flag for true, a Room View volta a
  /// mostrar o portão pedindo para o usuário verificar o fone e tocar de
  /// novo — nunca retomamos o playback sozinhos (ver unlockAudioElements).
  bool audioInterrupted = false;

  /// Nível RMS (0.0-1.0) do áudio remoto mais alto entre os transmissores
  /// atuais. Alimenta o VU meter real na Room View.
  double audioLevel = 0.0;

  /// True quando há transmissão ativa mas o nível de áudio ficou
  /// praticamente em zero por mais de [SintonizeConfig.silentAudioWarningTimeout],
  /// indicando que a fonte está chegando "vazia" (silêncio na origem, não
  /// bug de playback).
  bool silentAudioWarning = false;

  static const double _silenceThreshold = 0.02;
  DateTime? _silenceSince;
  bool _disposed = false;

  /// True durante `_teardown()` (saída de sala / kick / dispose). Usado
  /// para ignorar eventos `pause` disparados pelo próprio encerramento dos
  /// renderers (não é uma "interrupção" de fone — é intencional).
  bool _tearingDown = false;

  Timer? _reconnectUiTimer;

  UserProfile get effectiveProfile =>
      sessionProfileOverride ?? prefs.userProfile;

  int get transmitterCount => _webrtc?.remoteStreams.length ?? 0;

  Future<void> connect() async {
    selfId = prefs.userId;

    if (effectiveProfile == UserProfile.host) {
      await _acquireMic();
    }

    _socket.connect(onConnect: _handleConnect, onDisconnect: _handleDisconnect);
  }

  Future<void> _acquireMic() async {
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      _localStream = stream;
      micBlocked = false;
    } catch (e) {
      micBlocked = true;
      sessionProfileOverride = UserProfile.listener;
    }
    notifyListeners();
  }

  void _handleConnect() {
    final webrtc = WebRTCService(_socket, selfId);
    webrtc.onStreamsChanged = _syncRenderers;
    webrtc.onIceConnected = (_) {
      if (apIsolationDetected) {
        apIsolationDetected = false;
        notifyListeners();
      }
    };
    webrtc.onIceFailed = (_) {
      if (transmitterCount > 0) return;
      apIsolationDetected = true;
      notifyListeners();
    };
    webrtc.registerHandlers();
    if (_localStream != null) {
      webrtc.setLocalStream(_localStream!);
    }
    _webrtc = webrtc;

    _registerRoomHandlers();

    _socket.emitWithAck(SocketEvents.joinRoom, {
      'id': selfId,
      'name': prefs.userName,
      'profile': profileToString(effectiveProfile),
      'roomUrl': baseUrl,
    }, _onJoinAck);
  }

  void _onJoinAck(dynamic response) {
    if (response is Map && response['success'] == true) {
      final data = response['data'] as Map<String, dynamic>;
      selfId = data['id'] as String;
      users = (data['users'] as List)
          .map((u) => RoomUser.fromJson(u as Map<String, dynamic>))
          .toList();
      status = RoomStatus.connected;
      apIsolationDetected = false;
      _cancelReconnectUiTimer();
      notifyListeners();
    }
  }

  void _registerRoomHandlers() {
    _socket.on(SocketEvents.userJoined, (data) {
      _upsertUser(RoomUser.fromJson(data['user'] as Map<String, dynamic>));
    });
    _socket.on(SocketEvents.userUpdated, (data) {
      _upsertUser(RoomUser.fromJson(data['user'] as Map<String, dynamic>));
    });
    _socket.on(SocketEvents.userLeft, (data) {
      users = users.where((u) => u.id != data['userId']).toList();
      notifyListeners();
    });
    _socket.on(SocketEvents.adminForceMute, (data) {
      forcedMuted = data['muted'] == true;
      _applyMicEnabled();
      notifyListeners();
    });
    _socket.on(SocketEvents.adminForceDisconnect, (data) async {
      kicked = true;
      kickedMessage =
          (data['reason'] as String?) ?? 'Você foi removido da sala.';
      await prefs.clear();
      await _teardown();
      notifyListeners();
    });
  }

  void _upsertUser(RoomUser user) {
    final idx = users.indexWhere((u) => u.id == user.id);
    if (idx == -1) {
      users = [...users, user];
    } else {
      final copy = [...users];
      copy[idx] = user;
      users = copy;
    }
    notifyListeners();
  }

  void _handleDisconnect() {
    if (kicked) return;
    status = RoomStatus.reconnecting;
    notifyListeners();
    _reconnectUiTimer ??= Timer(SintonizeConfig.reconnectUiTimeout, () {
      status = RoomStatus.lost;
      notifyListeners();
    });
  }

  void _cancelReconnectUiTimer() {
    _reconnectUiTimer?.cancel();
    _reconnectUiTimer = null;
  }

  Future<void> _syncRenderers() async {
    final webrtc = _webrtc;
    if (webrtc == null) return;

    for (final entry in webrtc.remoteStreams.entries) {
      if (!renderers.containsKey(entry.key)) {
        final renderer = RTCVideoRenderer();
        await renderer.initialize();
        renderer.srcObject = entry.value;
        renderers[entry.key] = renderer;

        final meter = AudioLevelMeter();
        _levelMeters[entry.key] = meter;
        final peerId = entry.key;
        unawaited(
          meter.start(entry.value, (level) => _onAudioLevel(peerId, level)),
        );
      }
    }
    for (final peerId in renderers.keys.toList()) {
      if (!webrtc.remoteStreams.containsKey(peerId)) {
        await renderers.remove(peerId)?.dispose();
        await _levelMeters.remove(peerId)?.stop();
        _levels.remove(peerId);
      }
    }
    _applyMasterVolume();
    // Web: desmuta/ajusta volume dos elementos de mídia sempre que o
    // conjunto de streams remotos muda (ver web_audio_unlock_web.dart para
    // o porquê disso ser necessário). NÃO chama play() aqui — sem gesto do
    // usuário — para não ressuscitar playback sozinho; um stream novo
    // chegando depois do portão já confirmado volta a bloquear até o
    // usuário tocar de novo (mesmo mecanismo do overlay único).
    audioPlaybackBlocked = await unlockAudioElements(
      masterVolume,
      onUnexpectedPause: _handleUnexpectedPause,
    );
    _updateAudioLevel();
    notifyListeners();
  }

  void setMasterVolume(double value) {
    masterVolume = value.clamp(0.0, 1.0);
    _applyMasterVolume();
    unawaited(_reapplyWebVolume());
  }

  Future<void> _reapplyWebVolume() async {
    // Web: Helper.setVolume nem sempre tem efeito sobre o elemento <audio>
    // de fato (depende do browser); aplicamos o volume também direto no
    // elemento DOM. Mexer no volume não é o gesto de "começar a ouvir", só
    // ajuste — por isso também sem attemptPlay.
    audioPlaybackBlocked = await unlockAudioElements(
      masterVolume,
      onUnexpectedPause: _handleUnexpectedPause,
    );
    notifyListeners();
  }

  /// Chamado quando um elemento de áudio que já estava tocando pausa
  /// sozinho (evento DOM `pause`, ver web_audio_unlock_web.dart). Ignorado
  /// durante o teardown da sala (esse pause é intencional, não uma
  /// desconexão de fone) e antes do portão ser confirmado (nesse ponto o
  /// elemento nunca chegou a tocar de verdade).
  void _handleUnexpectedPause() {
    if (_disposed || _tearingDown || !audioGateConfirmed) return;
    audioInterrupted = true;
    notifyListeners();
  }

  void _applyMasterVolume() {
    final webrtc = _webrtc;
    if (webrtc == null) return;
    for (final stream in webrtc.remoteStreams.values) {
      for (final track in stream.getAudioTracks()) {
        try {
          Helper.setVolume(masterVolume, track);
        } catch (_) {
          /* nem toda plataforma suporta ajuste por faixa */
        }
      }
    }
  }

  /// ÚNICO ponto do app que chama `play()` em elementos de mídia. Deve ser
  /// invocado só a partir de um gesto real do usuário — o toque no botão
  /// do portão de áudio ("Já conectei — começar a ouvir" no primeiro
  /// acesso, ou "Toque para continuar" ao reaparecer após bloqueio/
  /// interrupção). É esse tap que autoriza o autoplay no Safari/Chrome e
  /// confirma que o usuário de fato conectou o fone antes do som sair.
  Future<void> confirmAudioGate() async {
    for (final meter in _levelMeters.values) {
      await meter.resume();
    }
    audioGateConfirmed = true;
    audioInterrupted = false;
    audioPlaybackBlocked = await unlockAudioElements(
      masterVolume,
      attemptPlay: true,
      onUnexpectedPause: _handleUnexpectedPause,
    );
    notifyListeners();
  }

  void _onAudioLevel(String peerId, double level) {
    _levels[peerId] = level;
    _updateAudioLevel();
    notifyListeners();
  }

  void _updateAudioLevel() {
    audioLevel = _levels.values.isEmpty
        ? 0.0
        : _levels.values.reduce((a, b) => a > b ? a : b);

    // A medição real de RMS só existe na web (ver audio_level_meter_stub.dart);
    // no nativo não há como distinguir "silêncio na fonte" de "sem dado",
    // então nunca acionamos o aviso fora da web.
    final hasStream = renderers.isNotEmpty;
    if (!kIsWeb || !hasStream || audioLevel > _silenceThreshold) {
      _silenceSince = null;
      silentAudioWarning = false;
      return;
    }
    _silenceSince ??= DateTime.now();
    silentAudioWarning = DateTime.now().difference(_silenceSince!) >=
        SintonizeConfig.silentAudioWarningTimeout;
  }

  void _applyMicEnabled() {
    final stream = _localStream;
    if (stream == null) return;
    for (final track in stream.getAudioTracks()) {
      track.enabled = !forcedMuted;
    }
  }

  Future<void> leaveRoom() async {
    _socket.emit(SocketEvents.leaveRoom, {});
    await prefs.clear();
    await _teardown();
  }

  Future<void> _teardown() async {
    _tearingDown = true;
    _cancelReconnectUiTimer();
    for (final r in renderers.values) {
      await r.dispose();
    }
    renderers.clear();
    for (final meter in _levelMeters.values) {
      await meter.stop();
    }
    _levelMeters.clear();
    _levels.clear();
    await _webrtc?.dispose();
    _webrtc = null;
    await _localStream?.dispose();
    _localStream = null;
    _socket.dispose();
  }

  @override
  void dispose() {
    // _teardown() é async e só cancela os timers dos meters depois de
    // vários awaits; sem a guarda abaixo, um tick de 120ms do meter podia
    // chamar notifyListeners() com o notifier já descartado (assert em
    // debug). A flag silencia qualquer callback atrasado.
    _disposed = true;
    _teardown();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}
