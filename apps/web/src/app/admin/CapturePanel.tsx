"use client";

import type { AudioDevice, CaptureStatus } from "@sintonize/shared";
import styles from "./admin.module.css";

interface CapturePanelProps {
  capture: CaptureStatus;
  devices: AudioDevice[];
  onSelect: (deviceId: string) => void;
  onRefresh: () => void;
}

/**
 * Fonte de áudio da Estação Central: escolhe qual dispositivo de captura
 * (microfone, loopback, mesa de som) é transmitido para a sala.
 */
export function CapturePanel({
  capture,
  devices,
  onSelect,
  onRefresh,
}: CapturePanelProps) {
  const current =
    devices.find((d) => d.name === capture.device)?.id ??
    devices.find((d) => d.id === capture.device)?.id ??
    "";

  return (
    <div className={styles.card} style={{ marginTop: 24 }}>
      <div className={styles.sectionTitle}>Fonte de áudio</div>

      {devices.length === 0 ? (
        <div className={styles.footRow}>
          Nenhum dispositivo de captura encontrado. Conecte um microfone ou
          habilite o loopback do sistema e atualize.
        </div>
      ) : (
        <select
          className={styles.captureSelect}
          value={current}
          onChange={(e) => onSelect(e.target.value)}
          aria-label="Dispositivo de captura de áudio"
        >
          {current === "" && (
            <option value="" disabled>
              Selecione um dispositivo…
            </option>
          )}
          {devices.map((d) => (
            <option key={d.id} value={d.id}>
              {d.name}
              {d.isLoopback ? " (som do computador)" : ""}
            </option>
          ))}
        </select>
      )}

      <div className={styles.footRow}>
        {capture.active ? (
          <>Capturando de: {capture.device ?? "—"}</>
        ) : (
          <>Captura parada.</>
        )}
        {capture.error && <> Erro: {capture.error}</>}
        {" · "}
        <button
          type="button"
          className={styles.linkButton}
          onClick={onRefresh}
        >
          Atualizar lista
        </button>
      </div>
    </div>
  );
}
