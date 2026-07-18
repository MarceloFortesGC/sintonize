"use client";

import type { AudioDevice, CaptureStatus } from "@sintonize/shared";
import styles from "./admin.module.css";

interface CapturePanelProps {
  capture: CaptureStatus;
  devices: AudioDevice[];
  onSelect: (deviceId: string) => void;
  onRefresh: () => void;
  micGain: number;
  onMicGainChange: (value: number) => void;
}

// Slider em passos de 5% sobre uma escala 0–400% (multiplicador 0.0–4.0
// aplicado ao GainNode em tauri-audio.ts). Marcação em 100% fica em 25% da
// trilha (100/400).
const GAIN_TICK_PCT = 25;
const GAIN_WARNING_THRESHOLD_PCT = 200;

/**
 * Fonte de áudio da Estação Central: escolhe qual dispositivo de captura
 * (microfone, loopback, mesa de som) é transmitido para a sala, e permite
 * ajustar o ganho para compensar microfone fraco ou forte demais.
 */
export function CapturePanel({
  capture,
  devices,
  onSelect,
  onRefresh,
  micGain,
  onMicGainChange,
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

      <div className={styles.sectionTitle} style={{ marginTop: 20 }}>
        Ganho do microfone
      </div>
      <div className={styles.gainLabelRow}>
        <span>Ajusta o volume do áudio transmitido.</span>
        <span className={styles.gainValue}>
          {Math.round(micGain * 100)}%
        </span>
      </div>
      <div className={styles.gainSliderWrap}>
        <input
          type="range"
          className={styles.gainSlider}
          min={0}
          max={400}
          step={5}
          value={Math.round(micGain * 100)}
          onChange={(e) => onMicGainChange(Number(e.target.value) / 100)}
          aria-label="Ganho do microfone"
        />
        <span
          className={styles.gainTick}
          style={{ left: `${GAIN_TICK_PCT}%` }}
          aria-hidden="true"
        />
      </div>
      {micGain * 100 > GAIN_WARNING_THRESHOLD_PCT && (
        <div className={styles.gainWarning}>
          Ganho alto pode distorcer o áudio.
        </div>
      )}
    </div>
  );
}
