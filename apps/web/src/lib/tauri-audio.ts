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

/**
 * Assina o evento `audio-chunk` emitido pelo processo Rust e converte o PCM
 * recebido em um MediaStream reproduzível/transmissível via WebRTC.
 * Retorna null quando não está rodando dentro do Tauri.
 */
export async function createTauriAudioStream(): Promise<TauriAudioBridge | null> {
  if (!isTauri()) return null;

  const { listen } = await import("@tauri-apps/api/event");

  const audioCtx = new AudioContext({ sampleRate: 48000 });
  const destination = audioCtx.createMediaStreamDestination();

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
