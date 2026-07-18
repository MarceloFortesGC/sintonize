import type { Server as HTTPServer } from "node:http";
import { randomUUID } from "node:crypto";
import { Server, type Socket } from "socket.io";
import {
  EVENTS,
  MAX_PARTICIPANTS,
  MAX_NAME_LENGTH,
  RECONNECT_GRACE_PERIOD_MS,
  SOCKET_PATH,
  isValidProfile,
  isValidUuidV4,
  sanitizeName,
  type AckResponse,
  type AdminForceDisconnectPayload,
  type AdminForceMutePayload,
  type AdminKickUserPayload,
  type AdminMuteUserPayload,
  type AdminRenameUserPayload,
  type AdminRoomStatePayload,
  type ErrorPayload,
  type HeartbeatPayload,
  type JoinRoomPayload,
  type RoomJoinedPayload,
  type RoomUser,
  type UserProfile,
  type WebRTCAnswerPayload,
  type WebRTCIceCandidatePayload,
  type WebRTCOfferPayload,
} from "@sintonize/shared";
import {
  clearGraceTimer,
  createRoomState,
  getActiveTransmitters,
  participantCount,
  removeUser,
  upsertUser,
  type RoomState,
} from "./room-state.js";
import { computeMeshPairs } from "./mesh.js";
import { isJoinRateLimited } from "./rate-limit.js";

type SocketRole = "client" | "admin" | "desktop-host";

const room: RoomState = createRoomState();

function log(...args: unknown[]): void {
  console.log("[signaling]", ...args);
}

function errorPayload(
  code: ErrorPayload["code"],
  message: string
): ErrorPayload {
  return { code, message };
}

function socketIp(socket: Socket): string {
  const fwd = socket.handshake.headers["x-forwarded-for"];
  if (typeof fwd === "string") return fwd.split(",")[0].trim();
  return socket.handshake.address;
}

function roomStateSnapshot(): AdminRoomStatePayload {
  return {
    users: [...room.users.values()],
    activeTransmitters: getActiveTransmitters(room),
    participantCount: participantCount(room),
  };
}

export function getRoom(): RoomState {
  return room;
}

export function initSignaling(httpServer: HTTPServer): Server {
  const io = new Server(httpServer, {
    path: SOCKET_PATH,
    cors: { origin: "*" },
  });

  function emitPeerRequired(io: Server, joiningId: string): void {
    const pairs = computeMeshPairs(room, joiningId);
    for (const { existing, joining, initiatorId } of pairs) {
      if (existing.socketId) {
        io.to(existing.socketId).emit(EVENTS.WEBRTC_PEER_REQUIRED, {
          peerId: joining.id,
          peerProfile: joining.profile,
          peerIsDesktopHost: joining.isDesktopHost === true,
          initiator: initiatorId === existing.id,
        });
      }
      if (joining.socketId) {
        io.to(joining.socketId).emit(EVENTS.WEBRTC_PEER_REQUIRED, {
          peerId: existing.id,
          peerProfile: existing.profile,
          peerIsDesktopHost: existing.isDesktopHost === true,
          initiator: initiatorId === joining.id,
        });
      }
    }
  }

  function broadcastUserUpdated(user: RoomUser): void {
    io.emit(EVENTS.USER_UPDATED, { user });
  }

  function handleJoin(
    socket: Socket,
    payload: JoinRoomPayload,
    ack?: (res: AckResponse<RoomJoinedPayload>) => void
  ): void {
    const ip = socketIp(socket);
    if (isJoinRateLimited(ip)) {
      ack?.({
        success: false,
        error: errorPayload("RATE_LIMITED", "Muitas tentativas. Aguarde um instante."),
      });
      return;
    }

    const name = sanitizeName(payload?.name);
    if (!name) {
      ack?.({
        success: false,
        error: errorPayload("INVALID_PAYLOAD", `Informe um nome válido (1–${MAX_NAME_LENGTH} caracteres).`),
      });
      return;
    }
    if (!isValidProfile(payload?.profile)) {
      ack?.({
        success: false,
        error: errorPayload("INVALID_PAYLOAD", "Perfil inválido."),
      });
      return;
    }

    const profile: UserProfile = payload.profile;
    const requestedId =
      payload.id && isValidUuidV4(payload.id) ? payload.id : undefined;
    const existing = requestedId ? room.users.get(requestedId) : undefined;

    // Sala cheia: só bloqueia novos usuários, não reconexões de existentes.
    if (!existing && participantCount(room) >= MAX_PARTICIPANTS) {
      ack?.({
        success: false,
        error: errorPayload("ROOM_FULL", `A sala atingiu o limite de ${MAX_PARTICIPANTS} participantes.`),
      });
      return;
    }

    // Last-write-wins: desconecta sessão anterior com o mesmo id.
    if (existing && existing.socketId && existing.socketId !== socket.id) {
      const prev = io.sockets.sockets.get(existing.socketId);
      prev?.disconnect(true);
    }

    const userId = requestedId ?? randomUUID();
    clearGraceTimer(room, userId);

    const user = upsertUser(room, {
      id: userId,
      name,
      profile,
      socketId: socket.id,
      connectionState: "connected",
    });

    socket.data.userId = userId;
    socket.data.role = "client" satisfies SocketRole;

    const response: RoomJoinedPayload = {
      id: userId,
      roomId: room.roomId,
      users: [...room.users.values()],
      activeTransmitters: getActiveTransmitters(room),
      desktopHostId: room.desktopHostId,
    };

    ack?.({ success: true, data: response });

    if (existing) {
      broadcastUserUpdated(user);
    } else {
      socket.broadcast.emit(EVENTS.USER_JOINED, { user });
    }

    emitPeerRequired(io, userId);
    log(existing ? "reconexão" : "entrada", user.name, user.profile);
  }

  function bindDesktopHost(socket: Socket): void {
    const host = room.users.get(room.desktopHostId);
    if (!host) return;
    clearGraceTimer(room, room.desktopHostId);
    host.socketId = socket.id;
    host.connectionState = "connected";
    room.users.set(host.id, host);
    socket.data.userId = room.desktopHostId;
    socket.data.role = "desktop-host" satisfies SocketRole;

    const snapshot: RoomJoinedPayload = {
      id: room.desktopHostId,
      roomId: room.roomId,
      users: [...room.users.values()],
      activeTransmitters: getActiveTransmitters(room),
      desktopHostId: room.desktopHostId,
    };
    socket.emit(EVENTS.ROOM_JOINED, snapshot);

    broadcastUserUpdated(host);
    emitPeerRequired(io, room.desktopHostId);
    log("desktop host vinculado");
  }

  function relayTo(
    targetId: string,
    event: string,
    payload: unknown
  ): void {
    const target = room.users.get(targetId);
    if (target?.socketId) {
      io.to(target.socketId).emit(event, payload);
    }
  }

  function handleLeave(socket: Socket): void {
    const userId: string | undefined = socket.data.userId;
    if (!userId) return;
    const user = room.users.get(userId);
    if (!user || user.isDesktopHost) return;

    removeUser(room, userId);
    io.emit(EVENTS.USER_LEFT, { userId, reason: "left_voluntarily" });
    notifyPeersClosed(userId, "left");
    log("saída voluntária", user.name);
  }

  function notifyPeersClosed(
    userId: string,
    reason: "left" | "kicked" | "error"
  ): void {
    for (const peer of room.users.values()) {
      if (peer.id === userId || !peer.socketId) continue;
      io.to(peer.socketId).emit(EVENTS.WEBRTC_PEER_CLOSED, {
        peerId: userId,
        reason,
      });
    }
  }

  function handleDisconnect(socket: Socket): void {
    const userId: string | undefined = socket.data.userId;
    if (!userId) return;
    const user = room.users.get(userId);
    if (!user) return;
    if (user.socketId !== socket.id) return;

    if (user.isDesktopHost) {
      user.connectionState = "disconnected";
      room.users.set(user.id, user);
      broadcastUserUpdated(user);
      return;
    }

    user.connectionState = "reconnecting";
    room.users.set(user.id, user);
    broadcastUserUpdated(user);

    const timer = setTimeout(() => {
      const stale = room.users.get(userId);
      if (!stale) return;
      removeUser(room, userId);
      io.emit(EVENTS.USER_LEFT, { userId, reason: "disconnected" });
      notifyPeersClosed(userId, "error");
      log("removido após grace period", stale.name);
    }, RECONNECT_GRACE_PERIOD_MS);

    room.graceTimers.set(userId, timer);
    log("desconectado, grace period iniciado", user.name);
  }

  // --- Admin actions ---

  function handleRename(
    payload: AdminRenameUserPayload,
    ack?: (res: AckResponse<RoomUser>) => void
  ): void {
    const user = room.users.get(payload?.userId);
    if (!user) {
      ack?.({ success: false, error: errorPayload("USER_NOT_FOUND", "Participante não encontrado.") });
      return;
    }
    if (user.isDesktopHost) {
      ack?.({ success: false, error: errorPayload("CANNOT_MODIFY_DESKTOP_HOST", "A Estação Central não pode ser alterada.") });
      return;
    }
    const name = sanitizeName(payload.newName);
    if (!name) {
      ack?.({ success: false, error: errorPayload("INVALID_PAYLOAD", `Nome inválido (1–${MAX_NAME_LENGTH}).`) });
      return;
    }
    user.name = name;
    room.users.set(user.id, user);
    broadcastUserUpdated(user);
    ack?.({ success: true, data: user });
  }

  function handleMute(
    payload: AdminMuteUserPayload,
    ack?: (res: AckResponse<RoomUser>) => void
  ): void {
    const user = room.users.get(payload?.userId);
    if (!user) {
      ack?.({ success: false, error: errorPayload("USER_NOT_FOUND", "Participante não encontrado.") });
      return;
    }
    if (user.isDesktopHost) {
      ack?.({ success: false, error: errorPayload("CANNOT_MODIFY_DESKTOP_HOST", "A Estação Central não pode ser alterada.") });
      return;
    }
    user.muted = payload.muted === true;
    room.users.set(user.id, user);
    broadcastUserUpdated(user);
    const force: AdminForceMutePayload = { muted: user.muted };
    relayTo(user.id, EVENTS.ADMIN_FORCE_MUTE, force);
    ack?.({ success: true, data: user });
  }

  function handleKick(
    payload: AdminKickUserPayload,
    ack?: (res: AckResponse<{ userId: string }>) => void
  ): void {
    const user = room.users.get(payload?.userId);
    if (!user) {
      ack?.({ success: false, error: errorPayload("USER_NOT_FOUND", "Participante não encontrado.") });
      return;
    }
    if (user.isDesktopHost) {
      ack?.({ success: false, error: errorPayload("CANNOT_MODIFY_DESKTOP_HOST", "A Estação Central não pode ser removida.") });
      return;
    }
    const targetSocketId = user.socketId;
    removeUser(room, user.id);
    io.emit(EVENTS.USER_LEFT, { userId: user.id, reason: "kicked" });
    notifyPeersClosed(user.id, "kicked");
    if (targetSocketId) {
      const force: AdminForceDisconnectPayload = {
        reason: "Você foi removido da sala pelo administrador.",
      };
      io.to(targetSocketId).emit(EVENTS.ADMIN_FORCE_DISCONNECT, force);
    }
    ack?.({ success: true, data: { userId: user.id } });
    log("removido pelo admin", user.name);
  }

  io.on("connection", (socket) => {
    const role = (socket.handshake.query.role as SocketRole) ?? "client";

    if (role === "desktop-host") {
      bindDesktopHost(socket);
    } else if (role === "admin") {
      socket.data.role = "admin" satisfies SocketRole;
    }

    socket.on(
      EVENTS.JOIN_ROOM,
      (payload: JoinRoomPayload, ack?: (res: AckResponse<RoomJoinedPayload>) => void) =>
        handleJoin(socket, payload, ack)
    );

    socket.on(EVENTS.LEAVE_ROOM, () => handleLeave(socket));

    socket.on(EVENTS.WEBRTC_OFFER, (payload: WebRTCOfferPayload) => {
      log("offer", payload.from?.slice(0, 8), "->", payload.to?.slice(0, 8));
      relayTo(payload.to, EVENTS.WEBRTC_OFFER, payload);
    });
    socket.on(EVENTS.WEBRTC_ANSWER, (payload: WebRTCAnswerPayload) => {
      log("answer", payload.from?.slice(0, 8), "->", payload.to?.slice(0, 8));
      relayTo(payload.to, EVENTS.WEBRTC_ANSWER, payload);
    });
    socket.on(EVENTS.WEBRTC_ICE_CANDIDATE, (payload: WebRTCIceCandidatePayload) => {
      const candObj = payload.candidate as {
        candidate?: string;
        sdpMid?: string | null;
        sdpMLineIndex?: number | null;
      } | null;
      const cand = candObj?.candidate ?? "";
      log("ice", payload.from?.slice(0, 8), "->", payload.to?.slice(0, 8), cand);
      relayTo(payload.to, EVENTS.WEBRTC_ICE_CANDIDATE, payload);

      // Navegadores mascaram candidatos host com mDNS (<uuid>.local), que
      // frequentemente não resolve entre dispositivos na LAN (multicast
      // bloqueado). O servidor conhece o IP real do remetente — relaya uma
      // cópia desmascarada para garantir um par de candidatos utilizável.
      const mdnsHost = cand.match(/\s([0-9a-f-]+\.local)\s/i)?.[1];
      if (mdnsHost && candObj?.candidate) {
        const realIp = socketIp(socket).replace(/^::ffff:/, "");
        if (realIp && realIp !== "::1" && realIp !== "127.0.0.1") {
          const unmasked = {
            ...payload,
            candidate: {
              ...candObj,
              candidate: candObj.candidate.replace(mdnsHost, realIp),
            },
          };
          log("ice-unmasked", payload.from?.slice(0, 8), "->", payload.to?.slice(0, 8), realIp);
          relayTo(payload.to, EVENTS.WEBRTC_ICE_CANDIDATE, unmasked);
        }
      }
    });

    socket.on(EVENTS.ADMIN_RENAME_USER, handleRename);
    socket.on(EVENTS.ADMIN_MUTE_USER, handleMute);
    socket.on(EVENTS.ADMIN_KICK_USER, handleKick);
    socket.on(
      EVENTS.ADMIN_GET_ROOM_STATE,
      (_req: unknown, ack?: (res: AdminRoomStatePayload) => void) =>
        ack?.(roomStateSnapshot())
    );

    socket.on(EVENTS.HEARTBEAT, (payload: HeartbeatPayload) => {
      socket.emit(EVENTS.HEARTBEAT_ACK, {
        timestamp: payload?.timestamp ?? 0,
        serverTime: Date.now(),
      });
    });

    socket.on("disconnect", () => handleDisconnect(socket));
  });

  return io;
}
