import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../config.dart';
import '../models/room_user.dart';
import 'preferences_service.dart';
import 'socket_service.dart';
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

  RoomStatus status = RoomStatus.connecting;
  List<RoomUser> users = [];
  String selfId = '';
  double masterVolume = 1.0;
  bool forcedMuted = false;
  UserProfile? sessionProfileOverride;
  String? micError;
  bool apIsolationDetected = false;
  bool kicked = false;
  String kickedMessage = '';

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
      micError = null;
    } catch (e) {
      micError =
          'Microfone bloqueado. Abra as configurações do navegador para permitir o acesso.';
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
      }
    }
    for (final peerId in renderers.keys.toList()) {
      if (!webrtc.remoteStreams.containsKey(peerId)) {
        await renderers.remove(peerId)?.dispose();
      }
    }
    _applyMasterVolume();
    notifyListeners();
  }

  void setMasterVolume(double value) {
    masterVolume = value.clamp(0.0, 1.0);
    _applyMasterVolume();
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
    _cancelReconnectUiTimer();
    for (final r in renderers.values) {
      await r.dispose();
    }
    renderers.clear();
    await _webrtc?.dispose();
    _webrtc = null;
    await _localStream?.dispose();
    _localStream = null;
    _socket.dispose();
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }
}
