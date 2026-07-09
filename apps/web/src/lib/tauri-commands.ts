import type { AudioDevice, CaptureStatus } from "@sintonize/shared";
import { isTauri } from "./tauri-audio.js";

async function invoke<T>(cmd: string, args?: Record<string, unknown>): Promise<T> {
  const { invoke: tauriInvoke } = await import("@tauri-apps/api/core");
  return tauriInvoke<T>(cmd, args);
}

export async function getLocalIp(): Promise<string | null> {
  if (!isTauri()) return null;
  try {
    return await invoke<string>("get_local_ip");
  } catch {
    return null;
  }
}

export async function getAudioDevices(): Promise<AudioDevice[]> {
  if (!isTauri()) return [];
  try {
    return await invoke<AudioDevice[]>("get_audio_devices");
  } catch {
    return [];
  }
}

export async function startCapture(deviceId: string): Promise<void> {
  if (!isTauri()) return;
  await invoke("start_capture", { deviceId });
}

export async function stopCapture(): Promise<void> {
  if (!isTauri()) return;
  await invoke("stop_capture");
}

export async function getCaptureStatus(): Promise<CaptureStatus> {
  if (!isTauri()) {
    return { active: false, device: null };
  }
  try {
    return await invoke<CaptureStatus>("get_capture_status");
  } catch (err) {
    return { active: false, device: null, error: String(err) };
  }
}
