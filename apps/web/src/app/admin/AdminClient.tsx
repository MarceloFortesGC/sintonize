"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import {
  MAX_PARTICIPANTS,
  ROOM_LOAD_WARNING_THRESHOLD,
} from "@sintonize/shared";
import { useAdminRoom } from "@/lib/use-admin-room";
import { QrCodePanel } from "./QrCodePanel";
import { DeviceList } from "./DeviceList";
import { CapturePanel } from "./CapturePanel";
import { TransmissionMeter } from "./TransmissionMeter";
import styles from "./admin.module.css";

function estimateMeshConnections(
  total: number,
  transmitters: number
): number {
  if (total <= 1) return 0;
  const listeners = total - transmitters;
  const txToListener = transmitters * listeners;
  const txToTx = (transmitters * (transmitters - 1)) / 2;
  return txToListener + txToTx;
}

export function AdminClient() {
  const {
    connected,
    users,
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
  } = useAdminRoom();

  const [ipChanged, setIpChanged] = useState(false);
  const prevIp = useRef<string | null>(null);

  useEffect(() => {
    if (localIp && prevIp.current && prevIp.current !== localIp) {
      setIpChanged(true);
    }
    if (localIp) prevIp.current = localIp;
  }, [localIp]);

  const transmitters = users.filter(
    (u) => u.profile === "host" || u.isDesktopHost
  ).length;
  const load = useMemo(
    () => estimateMeshConnections(users.length, transmitters),
    [users.length, transmitters]
  );
  const loadWarn = load >= ROOM_LOAD_WARNING_THRESHOLD;
  const participantCount = users.filter((u) => !u.isDesktopHost).length;
  const roomFull = users.length >= MAX_PARTICIPANTS;

  const captureActive = capture.active;

  return (
    <div className={styles.shell}>
      <div className={styles.topbar}>
        <h1 className={styles.brand}>Sintonize — Estação Central</h1>
        <span className={styles.badge}>
          <span
            className={`${styles.dot} ${
              captureActive ? styles.dotOk : styles.dotOff
            }`}
          />
          {captureActive ? "Captura ativa" : "Captura inativa"}
        </span>
      </div>

      {ipChanged && (
        <div className={styles.banner} role="alert">
          O endereço da sala mudou. Peça para os participantes reescanearem o QR
          Code.
        </div>
      )}
      {roomFull && (
        <div className={styles.banner} role="alert">
          A sala atingiu o limite de {MAX_PARTICIPANTS} participantes.
        </div>
      )}
      {!connected && (
        <div className={styles.banner} role="status">
          Conectando ao servidor…
        </div>
      )}

      <div className={styles.content}>
        <QrCodePanel localIp={localIp} />

        <div>
          <DeviceList
            users={users}
            onRename={rename}
            onMute={mute}
            onKick={kick}
          />

          <CapturePanel
            capture={capture}
            devices={devices}
            onSelect={(id) => void selectDevice(id)}
            onRefresh={() => void refreshDevices()}
          />

          <TransmissionMeter audioLevel={audioLevel} peerStates={peerStates} />

          <div className={styles.card} style={{ marginTop: 24 }}>
            <div className={styles.sectionTitle}>Carga da sala</div>
            <div className={`${styles.address} mono`}>
              {load} conexões · {participantCount}/{MAX_PARTICIPANTS}{" "}
              participantes
            </div>
            <div className={styles.loadBar}>
              <div
                className={`${styles.loadFill} ${
                  loadWarn ? styles.loadFillWarn : ""
                }`}
                style={{
                  width: `${Math.min(
                    100,
                    (load / (ROOM_LOAD_WARNING_THRESHOLD * 1.5)) * 100
                  )}%`,
                }}
              />
            </div>
            {loadWarn && (
              <div className={styles.footRow}>
                Carga elevada. A malha P2P pode degradar com muitos
                transmissores.
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
