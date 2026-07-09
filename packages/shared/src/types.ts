export type UserProfile = "host" | "listener";

export type ConnectionState =
  | "connecting"
  | "connected"
  | "disconnected"
  | "reconnecting";

export interface RoomUser {
  id: string;
  name: string;
  profile: UserProfile;
  connectedAt: string;
  socketId: string;
  muted: boolean;
  connectionState: ConnectionState;
  isDesktopHost?: boolean;
}

export type LeaveReason = "disconnected" | "kicked" | "left_voluntarily";

export type PeerClosedReason = "left" | "kicked" | "error";

export type ErrorCode =
  | "INVALID_PAYLOAD"
  | "ROOM_FULL"
  | "PEER_NOT_FOUND"
  | "USER_NOT_FOUND"
  | "UNAUTHORIZED_ADMIN_ACTION"
  | "CANNOT_MODIFY_DESKTOP_HOST"
  | "RATE_LIMITED";

export interface ErrorPayload {
  code: ErrorCode;
  message: string;
}

export interface AudioDevice {
  id: string;
  name: string;
  isLoopback: boolean;
}

export interface CaptureStatus {
  active: boolean;
  device: string | null;
  error?: string;
}
