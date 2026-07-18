"use client";

import { isTauri } from "@/lib/tauri-audio";
import type { AdminAudioLevel, AdminPeerState } from "@/lib/use-admin-room";
import styles from "./admin.module.css";

interface TransmissionMeterProps {
  audioLevel: AdminAudioLevel | null;
  peerStates: AdminPeerState[];
}

// Mesma fórmula do enunciado: largura% = min(100, rms * 400). rms > 0.005
// (=> 2% de largura) já conta como sinal audível para fins de indicador.
const SIGNAL_THRESHOLD = 0.005;

function peerDotClass(state: string): string {
  if (state === "connected") return styles.stateConnected;
  if (state === "connecting" || state === "new") return styles.stateReconnecting;
  if (state === "failed" || state === "disconnected") return styles.stateDanger;
  return styles.stateOther;
}

function peerLabel(state: string): string {
  switch (state) {
    case "connected":
      return "conectado";
    case "connecting":
      return "conectando";
    case "new":
      return "iniciando";
    case "failed":
      return "falhou";
    case "disconnected":
      return "desconectado";
    case "closed":
      return "encerrado";
    default:
      return state;
  }
}

/**
 * Indicador visual de transmissão na Estação Central: nível de áudio (RMS)
 * capturado e estado de conexão de cada ouvinte na malha WebRTC. Sem isso,
 * não há como saber se o áudio está realmente saindo do desktop nem se
 * algum celular está recebendo.
 */
export function TransmissionMeter({
  audioLevel,
  peerStates,
}: TransmissionMeterProps) {
  if (!isTauri()) {
    return (
      <div className={styles.card} style={{ marginTop: 24 }}>
        <div className={styles.sectionTitle}>Transmissão</div>
        <div className={styles.footRow}>
          Captura disponível apenas no app desktop.
        </div>
      </div>
    );
  }

  const rms = audioLevel?.rms ?? 0;
  const contextState = audioLevel?.contextState;
  const widthPct = Math.min(100, rms * 400);
  const barActive = rms > SIGNAL_THRESHOLD;

  let statusText: string;
  let statusHint: string | null = null;
  let statusClass = styles.transmissionStatus;

  if (contextState === "suspended") {
    statusText = "Áudio suspenso pelo navegador";
    statusClass = `${styles.transmissionStatus} ${styles.transmissionAlert}`;
  } else if (!audioLevel) {
    statusText = "Aguardando sinal de áudio…";
  } else if (barActive && contextState === "running") {
    statusText = "Transmitindo áudio";
    statusClass = `${styles.transmissionStatus} ${styles.transmissionOk}`;
  } else {
    statusText = "Sem sinal de áudio";
    statusHint =
      "Verifique o nível do dispositivo em Configurações de Som do Windows.";
  }

  return (
    <div className={styles.card} style={{ marginTop: 24 }}>
      <div className={styles.sectionTitle}>Transmissão</div>

      <div className={styles.meterTrack}>
        <div
          className={`${styles.meterFill} ${
            barActive ? styles.meterFillActive : ""
          }`}
          style={{ width: `${widthPct}%` }}
        />
      </div>

      <div className={statusClass}>{statusText}</div>
      {statusHint && <div className={styles.footRow}>{statusHint}</div>}

      <div className={styles.sectionTitle} style={{ marginTop: 20 }}>
        Conexões de áudio ({peerStates.length})
      </div>
      {peerStates.length === 0 ? (
        <div className={styles.footRow}>Nenhum ouvinte conectado ainda.</div>
      ) : (
        <ul className={styles.peerList}>
          {peerStates.map((p) => (
            <li key={p.peerId} className={styles.peerRow}>
              <span
                className={`${styles.stateDot} ${peerDotClass(
                  p.connectionState
                )}`}
              />
              <span className={styles.peerId}>{p.peerId}</span>
              <span className={styles.peerState}>
                {peerLabel(p.connectionState)}
              </span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
