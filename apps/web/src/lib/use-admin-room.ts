"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { io, type Socket } from "socket.io-client";
import {
  EVENTS,
  SOCKET_PATH,
  type AckResponse,
  type CaptureStatus,
  type RoomJoinedPayload,
  type RoomUser,
  type UserJoinedPayload,
  type UserLeftPayload,
  type UserUpdatedPayload,
} from "@sintonize/shared";
import { MeshManager } from "./webrtc/mesh-manager.js";
import { createTauriAudioStream, isTauri } from "./tauri-audio.js";
import {
  getAudioDevices,
  getCaptureStatus,
  getLocalIp,
  startCapture,
} from "./tauri-commands.js";
import type { AudioDevice } from "@sintonize/shared";

const CAPTURE_DEVICE_KEY = "sintonize.captureDevice";

export interface AdminAudioLevel {
  rms: number;
  contextState: string;
}

export interface AdminPeerState {
  peerId: string;
  connectionState: string;
}

export interface AdminRoomState {
  connected: boolean;
  users: RoomUser[];
  desktopHostId: string | null;
  localIp: string | null;
  capture: CaptureStatus;
  devices: AudioDevice[];
  audioLevel: AdminAudioLevel | null;
  peerStates: AdminPeerState[];
  selectDevice: (deviceId: string) => Promise<void>;
  refreshDevices: () => Promise<void>;
  rename: (userId: string, newName: string) => Promise<AckResponse<RoomUser>>;
  mute: (userId: string, muted: boolean) => Promise<AckResponse<RoomUser>>;
  kick: (userId: string) => Promise<AckResponse<{ userId: string }>>;
}

function emitWithAck<T>(
  socket: Socket,
  event: string,
  payload: unknown
): Promise<AckResponse<T>> {
  return new Promise((resolve) => {
    socket.emit(event, payload, (res: AckResponse<T>) => resolve(res));
  });
}

export function useAdminRoom(): AdminRoomState {
  const [connected, setConnected] = useState(false);
  const [users, setUsers] = useState<RoomUser[]>([]);
  const [desktopHostId, setDesktopHostId] = useState<string | null>(null);
  const [localIp, setLocalIp] = useState<string | null>(null);
  const [capture, setCapture] = useState<CaptureStatus>({
    active: false,
    device: null,
  });
  const [devices, setDevices] = useState<AudioDevice[]>([]);
  const [audioLevel, setAudioLevel] = useState<AdminAudioLevel | null>(null);
  const [peerStates, setPeerStates] = useState<AdminPeerState[]>([]);

  const socketRef = useRef<Socket | null>(null);
  const meshRef = useRef<MeshManager | null>(null);
  const audioStopRef = useRef<(() => void) | null>(null);

  useEffect(() => {
    // Flag no escopo do effect (não do handler): ROOM_JOINED pode disparar
    // mais de uma vez (reconexão) e o desmonte pode ocorrer durante o await
    // de createTauriAudioStream — sem ela o bridge ficaria órfão.
    let cancelled = false;

    const socket = io({
      path: SOCKET_PATH,
      query: { role: "desktop-host" },
      transports: ["websocket", "polling"],
    });
    socketRef.current = socket;

    socket.on("connect", () => setConnected(true));
    socket.on("disconnect", () => setConnected(false));

    socket.on(EVENTS.ROOM_JOINED, async (data: RoomJoinedPayload) => {
      setDesktopHostId(data.desktopHostId);
      setUsers(data.users);

      if (!meshRef.current) {
        const mesh = new MeshManager(socket, data.desktopHostId);
        meshRef.current = mesh;
        const bridge = await createTauriAudioStream((info) =>
          setAudioLevel(info)
        );
        if (bridge) {
          if (cancelled) {
            bridge.stop();
            return;
          }
          audioStopRef.current = bridge.stop;
          mesh.setLocalStream(bridge.stream);
        }
      }
    });

    socket.on(EVENTS.USER_JOINED, ({ user }: UserJoinedPayload) => {
      setUsers((prev) => upsert(prev, user));
    });
    socket.on(EVENTS.USER_UPDATED, ({ user }: UserUpdatedPayload) => {
      setUsers((prev) => upsert(prev, user));
    });
    socket.on(EVENTS.USER_LEFT, ({ userId }: UserLeftPayload) => {
      setUsers((prev) => prev.filter((u) => u.id !== userId));
    });

    return () => {
      cancelled = true;
      meshRef.current?.destroy();
      meshRef.current = null;
      audioStopRef.current?.();
      audioStopRef.current = null;
      socket.disconnect();
      socketRef.current = null;
    };
  }, []);

  // Captura de áudio + IP local (apenas no Tauri).
  useEffect(() => {
    if (!isTauri()) return;
    let cancelled = false;

    void (async () => {
      const ip = await getLocalIp();
      if (!cancelled && ip) setLocalIp(ip);

      const found = await getAudioDevices();
      if (!cancelled) setDevices(found);

      // Prioridade: dispositivo salvo pelo usuário → loopback → primeiro.
      const saved = localStorage.getItem(CAPTURE_DEVICE_KEY);
      const initial =
        found.find((d) => d.id === saved) ??
        found.find((d) => d.isLoopback) ??
        found[0];
      if (initial) {
        try {
          await startCapture(initial.id);
        } catch {
          /* diagnóstico exibido via getCaptureStatus */
        }
      }
    })();

    const poll = setInterval(async () => {
      const [ip, status] = await Promise.all([
        getLocalIp(),
        getCaptureStatus(),
      ]);
      if (cancelled) return;
      if (ip) setLocalIp(ip);
      setCapture(status);
    }, 5000);

    return () => {
      cancelled = true;
      clearInterval(poll);
    };
  }, []);

  // Estado das conexões WebRTC por ouvinte, para a Admin UI (item 3 do
  // indicador de transmissão). Poll leve — RTCPeerConnection não emite
  // evento agregado por peer, então lemos o snapshot periodicamente.
  useEffect(() => {
    const poll = setInterval(() => {
      setPeerStates(meshRef.current?.getPeerStates() ?? []);
    }, 2000);
    return () => clearInterval(poll);
  }, []);

  const refreshDevices = useCallback(async () => {
    const found = await getAudioDevices();
    setDevices(found);
  }, []);

  const selectDevice = useCallback(async (deviceId: string) => {
    localStorage.setItem(CAPTURE_DEVICE_KEY, deviceId);
    try {
      await startCapture(deviceId);
    } catch {
      /* diagnóstico exibido via getCaptureStatus */
    }
    setCapture(await getCaptureStatus());
  }, []);

  const rename = useCallback((userId: string, newName: string) => {
    const socket = socketRef.current;
    if (!socket) return Promise.resolve<AckResponse<RoomUser>>({
      success: false,
      error: { code: "USER_NOT_FOUND", message: "Sem conexão." },
    });
    return emitWithAck<RoomUser>(socket, EVENTS.ADMIN_RENAME_USER, {
      userId,
      newName,
    });
  }, []);

  const mute = useCallback((userId: string, muted: boolean) => {
    const socket = socketRef.current;
    if (!socket) return Promise.resolve<AckResponse<RoomUser>>({
      success: false,
      error: { code: "USER_NOT_FOUND", message: "Sem conexão." },
    });
    return emitWithAck<RoomUser>(socket, EVENTS.ADMIN_MUTE_USER, {
      userId,
      muted,
    });
  }, []);

  const kick = useCallback((userId: string) => {
    const socket = socketRef.current;
    if (!socket) return Promise.resolve<AckResponse<{ userId: string }>>({
      success: false,
      error: { code: "USER_NOT_FOUND", message: "Sem conexão." },
    });
    return emitWithAck<{ userId: string }>(socket, EVENTS.ADMIN_KICK_USER, {
      userId,
    });
  }, []);

  return {
    connected,
    users,
    desktopHostId,
    localIp,
    capture,
    devices,
    audioLevel,
    peerStates,
    selectDevice,
    refreshDevices,
    rename,
    mute,
    kick,
  };
}

function upsert(list: RoomUser[], user: RoomUser): RoomUser[] {
  const idx = list.findIndex((u) => u.id === user.id);
  if (idx === -1) return [...list, user];
  const next = [...list];
  next[idx] = user;
  return next;
}
