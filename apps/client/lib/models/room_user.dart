enum UserProfile { host, listener }

UserProfile profileFromString(String value) =>
    value == 'host' ? UserProfile.host : UserProfile.listener;

String profileToString(UserProfile profile) =>
    profile == UserProfile.host ? 'host' : 'listener';

enum ConnectionState { connecting, connected, disconnected, reconnecting }

ConnectionState connectionStateFromString(String value) {
  switch (value) {
    case 'connected':
      return ConnectionState.connected;
    case 'disconnected':
      return ConnectionState.disconnected;
    case 'reconnecting':
      return ConnectionState.reconnecting;
    default:
      return ConnectionState.connecting;
  }
}

/// Espelha o contrato `RoomUser` de `@sintonize/shared`.
class RoomUser {
  final String id;
  final String name;
  final UserProfile profile;
  final String connectedAt;
  final String socketId;
  final bool muted;
  final ConnectionState connectionState;
  final bool isDesktopHost;

  const RoomUser({
    required this.id,
    required this.name,
    required this.profile,
    required this.connectedAt,
    required this.socketId,
    required this.muted,
    required this.connectionState,
    this.isDesktopHost = false,
  });

  factory RoomUser.fromJson(Map<String, dynamic> json) {
    return RoomUser(
      id: json['id'] as String,
      name: json['name'] as String,
      profile: profileFromString(json['profile'] as String),
      connectedAt: (json['connectedAt'] ?? '') as String,
      socketId: (json['socketId'] ?? '') as String,
      muted: (json['muted'] ?? false) as bool,
      connectionState:
          connectionStateFromString((json['connectionState'] ?? 'connecting') as String),
      isDesktopHost: (json['isDesktopHost'] ?? false) as bool,
    );
  }
}
