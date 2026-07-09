import { randomUUID } from "node:crypto";
import {
  DESKTOP_HOST_NAME,
  ROOM_ID,
  type ConnectionState,
  type RoomUser,
  type UserProfile,
} from "@sintonize/shared";

export interface RoomState {
  roomId: string;
  users: Map<string, RoomUser>;
  transmitters: Set<string>;
  desktopHostId: string;
  createdAt: string;
  graceTimers: Map<string, NodeJS.Timeout>;
}

export function createRoomState(): RoomState {
  const desktopHostId = randomUUID();
  const now = new Date().toISOString();

  const desktopHost: RoomUser = {
    id: desktopHostId,
    name: DESKTOP_HOST_NAME,
    profile: "host",
    connectedAt: now,
    socketId: "",
    muted: false,
    connectionState: "connected",
    isDesktopHost: true,
  };

  const users = new Map<string, RoomUser>();
  users.set(desktopHostId, desktopHost);

  return {
    roomId: ROOM_ID,
    users,
    transmitters: new Set<string>([desktopHostId]),
    desktopHostId,
    createdAt: now,
    graceTimers: new Map(),
  };
}

export function upsertUser(
  room: RoomState,
  input: {
    id: string;
    name: string;
    profile: UserProfile;
    socketId: string;
    connectionState?: ConnectionState;
  }
): RoomUser {
  const existing = room.users.get(input.id);
  const connectedAt = existing?.connectedAt ?? new Date().toISOString();
  const muted = existing?.muted ?? false;

  const user: RoomUser = {
    id: input.id,
    name: input.name,
    profile: input.profile,
    connectedAt,
    socketId: input.socketId,
    muted,
    connectionState: input.connectionState ?? "connected",
  };

  room.users.set(user.id, user);
  if (user.profile === "host") {
    room.transmitters.add(user.id);
  } else {
    room.transmitters.delete(user.id);
  }
  return user;
}

export function removeUser(room: RoomState, userId: string): void {
  room.users.delete(userId);
  room.transmitters.delete(userId);
  clearGraceTimer(room, userId);
}

export function clearGraceTimer(room: RoomState, userId: string): void {
  const timer = room.graceTimers.get(userId);
  if (timer) {
    clearTimeout(timer);
    room.graceTimers.delete(userId);
  }
}

export function getUserBySocketId(
  room: RoomState,
  socketId: string
): RoomUser | undefined {
  for (const user of room.users.values()) {
    if (user.socketId === socketId) return user;
  }
  return undefined;
}

export function getActiveTransmitters(room: RoomState): string[] {
  return [...room.transmitters].filter((id) => {
    const user = room.users.get(id);
    return user !== undefined && user.connectionState !== "disconnected";
  });
}

export function participantCount(room: RoomState): number {
  return room.users.size;
}

/**
 * Estimativa de conexões Mesh: cada Transmissor mantém uma conexão com cada
 * outro participante. Usado para o indicador de carga na Admin UI.
 */
export function estimatedMeshConnections(room: RoomState): number {
  const total = room.users.size;
  const transmitters = room.transmitters.size;
  if (total <= 1) return 0;
  // Cada transmissor conecta com (total - 1) peers; pares transmissor-transmissor
  // não são contados em dobro.
  const listeners = total - transmitters;
  const transmitterToListener = transmitters * listeners;
  const transmitterToTransmitter = (transmitters * (transmitters - 1)) / 2;
  return transmitterToListener + transmitterToTransmitter;
}
