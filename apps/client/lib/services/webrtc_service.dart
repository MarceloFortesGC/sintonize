import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../config.dart';
import 'socket_service.dart';

const Map<String, dynamic> _rtcConfig = {
  'iceServers': [],
  'bundlePolicy': 'max-bundle',
  'rtcpMuxPolicy': 'require',
};

class _Peer {
  final RTCPeerConnection pc;
  bool makingOffer = false;
  Timer? iceTimer;
  _Peer(this.pc);
}

/// Malha WebRTC do cliente: mantém uma RTCPeerConnection por peer,
/// recebe os streams remotos e (perfil Host) envia o microfone local.
class WebRTCService {
  final SocketService _socket;
  final String selfId;

  final Map<String, _Peer> _peers = {};
  final Map<String, MediaStream> remoteStreams = {};
  MediaStream? _localStream;

  void Function()? onStreamsChanged;
  void Function(String peerId)? onIceFailed;
  void Function(String peerId)? onIceConnected;

  final Set<String> _connectedPeers = {};

  WebRTCService(this._socket, this.selfId);

  void registerHandlers() {
    _socket.on(SocketEvents.webrtcPeerRequired, _onPeerRequired);
    _socket.on(SocketEvents.webrtcOffer, _onOffer);
    _socket.on(SocketEvents.webrtcAnswer, _onAnswer);
    _socket.on(SocketEvents.webrtcIceCandidate, _onIceCandidate);
    _socket.on(SocketEvents.webrtcPeerClosed, (data) {
      closePeer(data['peerId'] as String);
    });
  }

  void setLocalStream(MediaStream stream) {
    _localStream = stream;
    for (final peer in _peers.values) {
      _attachTracks(peer.pc);
    }
  }

  Future<_Peer> _ensurePeer(String peerId) async {
    final existing = _peers[peerId];
    if (existing != null) return existing;

    final pc = await createPeerConnection(_rtcConfig);
    final peer = _Peer(pc);
    _peers[peerId] = peer;

    _attachTracks(pc);

    pc.onIceCandidate = (candidate) {
      _socket.emit(SocketEvents.webrtcIceCandidate, {
        'from': selfId,
        'to': peerId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    pc.onTrack = (event) async {
      if (event.streams.isNotEmpty) {
        remoteStreams[peerId] = event.streams.first;
      } else {
        // Track sem stream associado (sender remoto sem a=msid):
        // embrulha em um stream local para não descartar o áudio.
        final wrapper = await createLocalMediaStream('remote-$peerId');
        await wrapper.addTrack(event.track);
        remoteStreams[peerId] = wrapper;
      }
      onStreamsChanged?.call();
    };

    pc.onIceConnectionState = (state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        peer.iceTimer?.cancel();
        _connectedPeers.add(peerId);
        onIceConnected?.call(peerId);
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        peer.iceTimer?.cancel();
        if (!_connectedPeers.contains(peerId) &&
            !remoteStreams.containsKey(peerId)) {
          onIceFailed?.call(peerId);
        }
        pc.restartIce();
      }
    };

    peer.iceTimer = Timer(SintonizeConfig.iceNegotiationTimeout, () {
      if (_connectedPeers.contains(peerId) ||
          remoteStreams.containsKey(peerId)) {
        return;
      }
      final s = pc.iceConnectionState;
      if (s != RTCIceConnectionState.RTCIceConnectionStateConnected &&
          s != RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        onIceFailed?.call(peerId);
      }
    });

    return peer;
  }

  void _attachTracks(RTCPeerConnection pc) {
    final stream = _localStream;
    if (stream == null) return;
    for (final track in stream.getAudioTracks()) {
      pc.addTrack(track, stream);
    }
  }

  Future<void> _onPeerRequired(dynamic data) async {
    final peerId = data['peerId'] as String;
    final peer = await _ensurePeer(peerId);
    if (data['initiator'] == true) {
      await _makeOffer(peerId, peer);
    }
  }

  Future<void> _makeOffer(String peerId, _Peer peer) async {
    try {
      peer.makingOffer = true;
      final offer = await peer.pc.createOffer();
      await peer.pc.setLocalDescription(offer);
      _socket.emit(SocketEvents.webrtcOffer, {
        'from': selfId,
        'to': peerId,
        'sdp': {'type': offer.type, 'sdp': offer.sdp},
      });
    } finally {
      peer.makingOffer = false;
    }
  }

  Future<void> _onOffer(dynamic data) async {
    if (data['to'] != selfId) return;
    final from = data['from'] as String;
    final peer = await _ensurePeer(from);
    final pc = peer.pc;

    final collision = peer.makingOffer ||
        pc.signalingState !=
            RTCSignalingState.RTCSignalingStateStable;
    // Glare: o id menor é "polite" e cede; o maior ignora o offer conflitante.
    final polite = selfId.compareTo(from) < 0;
    if (collision && !polite) return;

    final sdp = data['sdp'];
    await pc.setRemoteDescription(
      RTCSessionDescription(sdp['sdp'] as String, sdp['type'] as String),
    );
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    _socket.emit(SocketEvents.webrtcAnswer, {
      'from': selfId,
      'to': from,
      'sdp': {'type': answer.type, 'sdp': answer.sdp},
    });
  }

  Future<void> _onAnswer(dynamic data) async {
    if (data['to'] != selfId) return;
    final peer = _peers[data['from']];
    if (peer == null) return;
    final sdp = data['sdp'];
    await peer.pc.setRemoteDescription(
      RTCSessionDescription(sdp['sdp'] as String, sdp['type'] as String),
    );
  }

  Future<void> _onIceCandidate(dynamic data) async {
    if (data['to'] != selfId) return;
    final peer = _peers[data['from']];
    if (peer == null) return;
    final c = data['candidate'];
    await peer.pc.addCandidate(
      RTCIceCandidate(
        c['candidate'] as String?,
        c['sdpMid'] as String?,
        c['sdpMLineIndex'] as int?,
      ),
    );
  }

  void closePeer(String peerId) {
    final peer = _peers.remove(peerId);
    if (peer == null) return;
    peer.iceTimer?.cancel();
    peer.pc.close();
    remoteStreams.remove(peerId);
    _connectedPeers.remove(peerId);
    onStreamsChanged?.call();
  }

  Future<void> dispose() async {
    for (final peerId in _peers.keys.toList()) {
      closePeer(peerId);
    }
    await _localStream?.dispose();
  }
}
