import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config.dart';

/// Encapsula a conexão Socket.io com reconexão automática e heartbeat.
class SocketService {
  final String baseUrl;
  io.Socket? _socket;
  Timer? _heartbeat;

  SocketService(this.baseUrl);

  io.Socket get socket {
    final s = _socket;
    if (s == null) {
      throw StateError('Socket não inicializado. Chame connect() primeiro.');
    }
    return s;
  }

  bool get isConnected => _socket?.connected ?? false;

  void connect({
    required void Function() onConnect,
    required void Function() onDisconnect,
  }) {
    final s = io.io(
      baseUrl,
      io.OptionBuilder()
          .setPath(SintonizeConfig.socketPath)
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(10000)
          .disableAutoConnect()
          .build(),
    );

    s.onConnect((_) {
      onConnect();
      _startHeartbeat();
    });
    s.onDisconnect((_) {
      _stopHeartbeat();
      onDisconnect();
    });

    _socket = s;
    s.connect();
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeat = Timer.periodic(SintonizeConfig.heartbeatInterval, (_) {
      _socket?.emit(SocketEvents.heartbeat, {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  void emit(String event, dynamic data) => _socket?.emit(event, data);

  void emitWithAck(
    String event,
    dynamic data,
    void Function(dynamic) ack,
  ) {
    _socket?.emitWithAck(event, data, ack: ack);
  }

  void on(String event, void Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void dispose() {
    _stopHeartbeat();
    _socket?.dispose();
    _socket = null;
  }
}
