import { isTauri } from "@tauri-apps/api/core";

export { isTauri };

export interface TauriAudioBridge {
  stream: MediaStream;
  stop: () => void;
  /** Ajusta o ganho aplicado ao áudio capturado (0.0–4.0, 1.0 = original). */
  setGain: (value: number) => void;
  /** Ganho atualmente configurado (alvo — pode estar em transição suave). */
  getGain: () => number;
}

interface AudioChunkEvent {
  payload: {
    /** PCM em i16 (o Rust converte de f32 para reduzir o payload JSON). */
    samples: number[];
    sampleRate: number;
    channels: number;
  };
}

/** Amplitude máxima de um sample i16 — usada para normalizar de volta a [-1, 1]. */
const INT16_MAX = 32767;

/** Teto de lookahead do agendamento: evita que um engasgo (GC/IPC) empurre a
 * reprodução cada vez mais pra frente e acumule latência sem limite. */
const MAX_LOOKAHEAD_SEC = 0.08;

export interface AudioLevelInfo {
  rms: number;
  contextState: AudioContextState;
}

const LEVEL_THROTTLE_MS = 100;

/**
 * Assina o evento `audio-chunk` emitido pelo processo Rust e converte o PCM
 * recebido em um MediaStream reproduzível/transmissível via WebRTC.
 * Retorna null quando não está rodando dentro do Tauri.
 *
 * `onLevel` (opcional) recebe o RMS do chunk e o estado do AudioContext, mas
 * no máximo a cada ~100ms — chunks chegam bem mais rápido que isso e chamar
 * o callback por chunk sobrecarregaria o React sem ganho perceptível.
 */
export async function createTauriAudioStream(
  onLevel?: (info: AudioLevelInfo) => void
): Promise<TauriAudioBridge | null> {
  if (!isTauri()) return null;

  const { listen } = await import("@tauri-apps/api/event");

  const audioCtx = new AudioContext({
    sampleRate: 48000,
    latencyHint: "interactive",
  });
  const destination = audioCtx.createMediaStreamDestination();
  // GainNode fica entre cada fonte e o destination: permite o operador
  // compensar microfone fraco/forte sem recapturar no Rust.
  const gainNode = audioCtx.createGain();
  gainNode.connect(destination);
  let currentGain = 1;
  let lastLevelEmitAt = 0;

  // Autoplay policy pode criar o contexto suspenso (sem gesto do usuário).
  // Suspenso = destination gera silêncio e o ouvinte não escuta nada.
  const ensureRunning = () => {
    if (audioCtx.state === "suspended") void audioCtx.resume();
  };
  ensureRunning();
  const resumeTimer = setInterval(ensureRunning, 2000);
  document.addEventListener("click", ensureRunning);

  let nextStartTime = audioCtx.currentTime;

  const unlisten = await listen<AudioChunkEvent["payload"]>(
    "audio-chunk",
    ({ payload }) => {
      const { samples, sampleRate, channels } = payload;
      if (!samples?.length) return;

      if (onLevel) {
        const nowMs = performance.now();
        if (nowMs - lastLevelEmitAt >= LEVEL_THROTTLE_MS) {
          lastLevelEmitAt = nowMs;
          let sumSquares = 0;
          for (let i = 0; i < samples.length; i++) {
            // Normaliza de i16 para [-1, 1] antes de acumular, senão o RMS
            // fica na escala errada (samples chegam como inteiros do Rust).
            const normalized = samples[i] / INT16_MAX;
            sumSquares += normalized * normalized;
          }
          // RMS multiplicado pelo ganho atual: o VU meter deve refletir o
          // sinal PÓS-ganho (o que está de fato sendo transmitido), não o
          // PCM cru vindo do Rust. Usamos o valor-alvo do gain (não o real
          // instantâneo da rampa do setTargetAtTime) — a diferença é
          // imperceptível numa janela de 100ms e evita ler a AudioParam.
          const rms = Math.sqrt(sumSquares / samples.length) * currentGain;
          onLevel({ rms, contextState: audioCtx.state });
        }
      }

      const frameCount = Math.floor(samples.length / channels);
      const buffer = audioCtx.createBuffer(
        channels,
        frameCount,
        sampleRate || 48000
      );

      for (let ch = 0; ch < channels; ch++) {
        const channelData = buffer.getChannelData(ch);
        for (let i = 0; i < frameCount; i++) {
          channelData[i] = samples[i * channels + ch] / INT16_MAX;
        }
      }

      const source = audioCtx.createBufferSource();
      source.buffer = buffer;
      source.connect(gainNode);

      const now = audioCtx.currentTime;
      if (nextStartTime < now) {
        nextStartTime = now;
      } else if (nextStartTime - now > MAX_LOOKAHEAD_SEC) {
        // Engasgo (GC/IPC) empurrou o agendamento longe demais — puxa de
        // volta. Um mini-glitch controlado é preferível a latência
        // permanente crescente pro resto da sessão.
        nextStartTime = now + MAX_LOOKAHEAD_SEC;
      }
      source.start(nextStartTime);
      nextStartTime += buffer.duration;
    }
  );

  return {
    stream: destination.stream,
    stop: () => {
      clearInterval(resumeTimer);
      document.removeEventListener("click", ensureRunning);
      unlisten();
      void audioCtx.close();
    },
    setGain: (value: number) => {
      const clamped = Math.min(4, Math.max(0, value));
      currentGain = clamped;
      // Rampa suave (20ms) em vez de salto abrupto: evita clicks/estalos
      // audíveis quando o operador mexe no slider durante a transmissão.
      gainNode.gain.setTargetAtTime(clamped, audioCtx.currentTime, 0.02);
    },
    getGain: () => currentGain,
  };
}
