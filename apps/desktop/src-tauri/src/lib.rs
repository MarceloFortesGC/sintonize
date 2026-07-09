mod audio;
mod net;

use audio::CaptureState;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .manage(CaptureState::default())
        .invoke_handler(tauri::generate_handler![
            net::get_local_ip,
            audio::get_audio_devices,
            audio::start_capture,
            audio::stop_capture,
            audio::get_capture_status
        ])
        .run(tauri::generate_context!())
        .expect("erro ao iniciar a Estação Central");
}
