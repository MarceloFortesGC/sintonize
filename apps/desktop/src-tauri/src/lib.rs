mod audio;
mod net;
mod server;

use audio::CaptureState;
use server::ServerState;
use tauri::RunEvent;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .manage(CaptureState::default())
        .manage(ServerState::default())
        .invoke_handler(tauri::generate_handler![
            net::get_local_ip,
            audio::get_audio_devices,
            audio::start_capture,
            audio::stop_capture,
            audio::get_capture_status
        ])
        .setup(|app| {
            // Em dev o servidor sobe via beforeDevCommand (pnpm dev:web); em
            // release ninguém mais garante que ele existe, então o app
            // precisa subir o sidecar embutido sozinho.
            if !cfg!(debug_assertions) {
                server::ensure_server_running(&app.handle().clone());
            }
            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("erro ao iniciar a Estação Central")
        .run(|app_handle, event| {
            if matches!(event, RunEvent::ExitRequested { .. } | RunEvent::Exit) {
                server::kill_server(app_handle);
            }
        });
}
