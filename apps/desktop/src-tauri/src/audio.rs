use std::sync::mpsc;
use std::sync::Mutex;

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{Sample, SampleFormat};
use serde::Serialize;
use tauri::{AppHandle, Emitter};

/// Palavras que identificam dispositivos de captura de loopback por SO.
const LOOPBACK_HINTS: [&str; 5] = ["monitor", "loopback", "stereo mix", "blackhole", "what u hear"];

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AudioDevice {
    pub id: String,
    pub name: String,
    pub is_loopback: bool,
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CaptureStatus {
    pub active: bool,
    pub device: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
struct AudioChunk {
    samples: Vec<f32>,
    sample_rate: u32,
    channels: u16,
}

#[derive(Default)]
struct CaptureInner {
    active: bool,
    device_name: Option<String>,
    error: Option<String>,
    stop_tx: Option<mpsc::Sender<()>>,
}

#[derive(Default)]
pub struct CaptureState {
    inner: Mutex<CaptureInner>,
}

fn is_loopback(name: &str) -> bool {
    let lower = name.to_lowercase();
    LOOPBACK_HINTS.iter().any(|hint| lower.contains(hint))
}

#[tauri::command]
pub fn get_audio_devices() -> Result<Vec<AudioDevice>, String> {
    let host = cpal::default_host();
    let devices = host.input_devices().map_err(|e| e.to_string())?;

    let mut result = Vec::new();
    for device in devices {
        let name = device.name().unwrap_or_else(|_| "Dispositivo desconhecido".into());
        result.push(AudioDevice {
            id: name.clone(),
            is_loopback: is_loopback(&name),
            name,
        });
    }
    Ok(result)
}

#[tauri::command]
pub fn get_capture_status(state: tauri::State<'_, CaptureState>) -> CaptureStatus {
    let inner = state.inner.lock().unwrap();
    CaptureStatus {
        active: inner.active,
        device: inner.device_name.clone(),
        error: inner.error.clone(),
    }
}

#[tauri::command]
pub fn stop_capture(state: tauri::State<'_, CaptureState>) {
    let mut inner = state.inner.lock().unwrap();
    if let Some(tx) = inner.stop_tx.take() {
        let _ = tx.send(());
    }
    inner.active = false;
    inner.device_name = None;
}

#[tauri::command]
pub fn start_capture(
    app: AppHandle,
    state: tauri::State<'_, CaptureState>,
    device_id: String,
) -> Result<(), String> {
    // Encerra qualquer captura anterior.
    {
        let mut inner = state.inner.lock().unwrap();
        if let Some(tx) = inner.stop_tx.take() {
            let _ = tx.send(());
        }
        inner.error = None;
    }

    let (stop_tx, stop_rx) = mpsc::channel::<()>();
    let (ready_tx, ready_rx) = mpsc::channel::<Result<String, String>>();

    // cpal::Stream não é Send: mantemos a stream viva dentro de uma thread própria.
    std::thread::spawn(move || {
        let host = cpal::default_host();
        let device = match find_device(&host, &device_id) {
            Ok(d) => d,
            Err(e) => {
                let _ = ready_tx.send(Err(e));
                return;
            }
        };

        let config = match device.default_input_config() {
            Ok(c) => c,
            Err(e) => {
                let _ = ready_tx.send(Err(e.to_string()));
                return;
            }
        };

        let sample_rate = config.sample_rate().0;
        let channels = config.channels();
        let sample_format = config.sample_format();
        let stream_config: cpal::StreamConfig = config.into();

        let app_cb = app.clone();
        let err_fn = |err| eprintln!("[audio] erro de stream: {err}");

        let stream_result: Result<cpal::Stream, String> = match sample_format {
            SampleFormat::F32 => device
                .build_input_stream(
                    &stream_config,
                    move |data: &[f32], _| emit_chunk(&app_cb, data, sample_rate, channels),
                    err_fn,
                    None,
                )
                .map_err(|e| e.to_string()),
            SampleFormat::I16 => device
                .build_input_stream(
                    &stream_config,
                    move |data: &[i16], _| {
                        let converted: Vec<f32> = data.iter().map(|s| s.to_float_sample()).collect();
                        emit_chunk(&app_cb, &converted, sample_rate, channels);
                    },
                    err_fn,
                    None,
                )
                .map_err(|e| e.to_string()),
            SampleFormat::U16 => device
                .build_input_stream(
                    &stream_config,
                    move |data: &[u16], _| {
                        let converted: Vec<f32> = data.iter().map(|s| s.to_float_sample()).collect();
                        emit_chunk(&app_cb, &converted, sample_rate, channels);
                    },
                    err_fn,
                    None,
                )
                .map_err(|e| e.to_string()),
            other => Err(format!("Formato de áudio não suportado: {other:?}")),
        };

        let stream = match stream_result {
            Ok(s) => s,
            Err(e) => {
                let _ = ready_tx.send(Err(e));
                return;
            }
        };

        if let Err(e) = stream.play() {
            let _ = ready_tx.send(Err(e.to_string()));
            return;
        }

        let device_name = device.name().unwrap_or_else(|_| device_id.clone());
        let _ = ready_tx.send(Ok(device_name));

        // Mantém a stream viva até receber o sinal de parada.
        let _ = stop_rx.recv();
        drop(stream);
    });

    match ready_rx.recv().map_err(|e| e.to_string())? {
        Ok(device_name) => {
            let mut inner = state.inner.lock().unwrap();
            inner.active = true;
            inner.device_name = Some(device_name);
            inner.error = None;
            inner.stop_tx = Some(stop_tx);
            Ok(())
        }
        Err(e) => {
            let mut inner = state.inner.lock().unwrap();
            inner.active = false;
            inner.error = Some(e.clone());
            Err(e)
        }
    }
}

fn find_device(host: &cpal::Host, device_id: &str) -> Result<cpal::Device, String> {
    let devices = host.input_devices().map_err(|e| e.to_string())?;
    for device in devices {
        if let Ok(name) = device.name() {
            if name == device_id {
                return Ok(device);
            }
        }
    }
    host.default_input_device()
        .ok_or_else(|| "Nenhum dispositivo de captura disponível.".to_string())
}

fn emit_chunk(app: &AppHandle, data: &[f32], sample_rate: u32, channels: u16) {
    let chunk = AudioChunk {
        samples: data.to_vec(),
        sample_rate,
        channels,
    };
    let _ = app.emit("audio-chunk", chunk);
}
