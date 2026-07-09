/// Constantes espelhadas de `@sintonize/shared` (constants.ts).
class SintonizeConfig {
  static const int port = 3000;
  static const String socketPath = '/socket.io';
  static const String roomId = 'main';
  static const int maxParticipants = 20;
  static const int maxNameLength = 40;
  static const Duration reconnectUiTimeout = Duration(milliseconds: 30000);
  static const Duration iceNegotiationTimeout = Duration(milliseconds: 10000);
  static const Duration heartbeatInterval = Duration(milliseconds: 5000);
  // Tempo com o nível de áudio real (RMS) praticamente zerado antes de
  // avisar o usuário que a transmissão está chegando "vazia" (fonte
  // silenciosa, não bug de playback).
  static const Duration silentAudioWarningTimeout = Duration(seconds: 3);
}

/// Nomes dos eventos Socket.io (events.ts).
class SocketEvents {
  static const joinRoom = 'join_room';
  static const roomJoined = 'room_joined';
  static const userJoined = 'user_joined';
  static const userUpdated = 'user_updated';
  static const leaveRoom = 'leave_room';
  static const userLeft = 'user_left';
  static const webrtcPeerRequired = 'webrtc_peer_required';
  static const webrtcOffer = 'webrtc_offer';
  static const webrtcAnswer = 'webrtc_answer';
  static const webrtcIceCandidate = 'webrtc_ice_candidate';
  static const webrtcPeerClosed = 'webrtc_peer_closed';
  static const adminForceMute = 'admin_force_mute';
  static const adminForceDisconnect = 'admin_force_disconnect';
  static const heartbeat = 'heartbeat';
  static const heartbeatAck = 'heartbeat_ack';
  static const error = 'error';
}
