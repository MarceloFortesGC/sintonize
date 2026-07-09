import type {
  ErrorPayload,
  LeaveReason,
  PeerClosedReason,
  RoomUser,
  UserProfile,
} from "./types.js";

export interface JoinRoomPayload {
  id?: string;
  name: string;
  profile: UserProfile;
  roomUrl?: string;
}

export interface RoomJoinedPayload {
  id: string;
  roomId: string;
  users: RoomUser[];
  activeTransmitters: string[];
  desktopHostId: string;
}

export type AckResponse<T> =
  | { success: true; data: T }
  | { success: false; error: ErrorPayload };

export interface UserJoinedPayload {
  user: RoomUser;
}

export interface UserUpdatedPayload {
  user: RoomUser;
}

export interface UserLeftPayload {
  userId: string;
  reason: LeaveReason;
}

export interface WebRTCPeerRequiredPayload {
  peerId: string;
  peerProfile: UserProfile;
  peerIsDesktopHost: boolean;
  initiator: boolean;
}

export interface WebRTCOfferPayload {
  from: string;
  to: string;
  sdp: RTCSessionDescriptionInit;
}

export interface WebRTCAnswerPayload {
  from: string;
  to: string;
  sdp: RTCSessionDescriptionInit;
}

export interface WebRTCIceCandidatePayload {
  from: string;
  to: string;
  candidate: RTCIceCandidateInit;
}

export interface WebRTCPeerClosedPayload {
  peerId: string;
  reason: PeerClosedReason;
}

export interface AdminRenameUserPayload {
  userId: string;
  newName: string;
}

export interface AdminMuteUserPayload {
  userId: string;
  muted: boolean;
}

export interface AdminKickUserPayload {
  userId: string;
}

export interface AdminForceMutePayload {
  muted: boolean;
}

export interface AdminForceDisconnectPayload {
  reason: string;
}

export interface AdminRoomStatePayload {
  users: RoomUser[];
  activeTransmitters: string[];
  participantCount: number;
}

export interface HeartbeatPayload {
  timestamp: number;
}

export interface HeartbeatAckPayload {
  timestamp: number;
  serverTime: number;
}

export const EVENTS = {
  JOIN_ROOM: "join_room",
  ROOM_JOINED: "room_joined",
  USER_JOINED: "user_joined",
  USER_UPDATED: "user_updated",
  LEAVE_ROOM: "leave_room",
  USER_LEFT: "user_left",
  WEBRTC_PEER_REQUIRED: "webrtc_peer_required",
  WEBRTC_OFFER: "webrtc_offer",
  WEBRTC_ANSWER: "webrtc_answer",
  WEBRTC_ICE_CANDIDATE: "webrtc_ice_candidate",
  WEBRTC_PEER_CLOSED: "webrtc_peer_closed",
  ADMIN_RENAME_USER: "admin_rename_user",
  ADMIN_MUTE_USER: "admin_mute_user",
  ADMIN_KICK_USER: "admin_kick_user",
  ADMIN_GET_ROOM_STATE: "admin_get_room_state",
  ADMIN_FORCE_MUTE: "admin_force_mute",
  ADMIN_FORCE_DISCONNECT: "admin_force_disconnect",
  HEARTBEAT: "heartbeat",
  HEARTBEAT_ACK: "heartbeat_ack",
  ERROR: "error",
} as const;
