import { isTauri } from "@tauri-apps/api/core";

export { isTauri };

export interface TauriAudioBridge {
  stream: MediaStream;
  stop: () => void;
}

interface AudioChunkEvent {
  payload: {
    samples: number[];
    sampleRate: number;
    channels: number;
  };
}

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

  const audioCtx = new AudioContext({ sampleRate: 48000 });
  const destination = audioCtx.createMediaStreamDestination();
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
            sumSquares += samples[i] * samples[i];
          }
          const rms = Math.sqrt(sumSquares / samples.length);
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
          channelData[i] = samples[i * channels + ch];
        }
      }

      const source = audioCtx.createBufferSource();
      source.buffer = buffer;
      source.connect(destination);

      const now = audioCtx.currentTime;
      if (nextStartTime < now) nextStartTime = now;
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
  };
}
