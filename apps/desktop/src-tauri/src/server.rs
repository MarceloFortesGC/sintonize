// Gerencia o servidor Node embutido (Next.js + Socket.io) em produção.
//
// Em dev, o servidor sobe via `beforeDevCommand` (pnpm --filter @sintonize/web
// dev) e este módulo não faz nada. Em release, o instalador empacota um
// node.exe sidecar + o servidor buildado (server.mjs, .next, public) em
// resources/server (ver apps/desktop/scripts/prepare-bundle.mjs). Ao abrir o
// app:
//   1. checa se algo já responde em /health (reaproveita, ex.: usuário abriu
//      o app duas vezes ou já tem um servidor rodando manualmente);
//   2. senão, spawna o sidecar apontando pro server.mjs dos resources;
//   3. faz polling de /health por até ~30s e recarrega a janela quando o
//      servidor ficar pronto (a janela já é criada apontando pra
//      localhost:3000/admin, então pode carregar em erro de conexão até lá).
//   4. mata o processo filho ao fechar o app.

use std::io::{Read, Write};
use std::net::{SocketAddr, TcpStream};
use std::sync::Mutex;
use std::time::Duration;

use tauri::{AppHandle, Manager};
use tauri_plugin_shell::process::{CommandChild, CommandEvent};
use tauri_plugin_shell::ShellExt;

const HEALTH_ADDR: &str = "127.0.0.1:3000";
const HEALTH_PATH: &str = "/health";
const HEALTH_POLL_TOTAL: Duration = Duration::from_secs(30);
const HEALTH_POLL_INTERVAL: Duration = Duration::from_millis(500);

/// Handle do processo filho (servidor Node), guardado no state do Tauri para
/// poder matá-lo quando o app fechar.
#[derive(Default)]
pub struct ServerState(pub Mutex<Option<CommandChild>>);

/// GET manual em /health via socket cru — evita puxar reqwest/ureq (runtime
/// async ou peso extra) só pra um healthcheck simples.
fn health_check(timeout: Duration) -> bool {
    let Ok(addr) = HEALTH_ADDR.parse::<SocketAddr>() else {
        return false;
    };
    let Ok(mut stream) = TcpStream::connect_timeout(&addr, timeout) else {
        return false;
    };
    let _ = stream.set_read_timeout(Some(timeout));
    let _ = stream.set_write_timeout(Some(timeout));

    let req = format!(
        "GET {HEALTH_PATH} HTTP/1.1\r\nHost: {HEALTH_ADDR}\r\nConnection: close\r\n\r\n"
    );
    if stream.write_all(req.as_bytes()).is_err() {
        return false;
    }

    let mut buf = Vec::new();
    if stream.read_to_end(&mut buf).is_err() {
        return false;
    }
    let text = String::from_utf8_lossy(&buf);
    text.starts_with("HTTP/1.1 200") || text.starts_with("HTTP/1.0 200")
}

/// Ponto de entrada chamado no setup() do app, só em builds de release.
pub fn ensure_server_running(app: &AppHandle) {
    if health_check(Duration::from_millis(300)) {
        println!("[sintonize] servidor já ativo em {HEALTH_ADDR}, reaproveitando");
        return;
    }

    let resource_dir = match app.path().resource_dir() {
        Ok(dir) => dir,
        Err(e) => {
            eprintln!("[sintonize] não consegui resolver resource_dir: {e}");
            return;
        }
    };
    let server_dir = resource_dir.join("server");
    let server_entry = server_dir.join("server.mjs");

    if !server_entry.exists() {
        eprintln!(
            "[sintonize] servidor embutido não encontrado em {}. O instalador foi gerado sem o servidor empacotado.",
            server_entry.display()
        );
        return;
    }

    let sidecar = match app.shell().sidecar("node") {
        Ok(cmd) => cmd,
        Err(e) => {
            eprintln!("[sintonize] sidecar 'node' não configurado (externalBin): {e}");
            return;
        }
    };

    // Caminho RELATIVO de propósito: o caminho absoluto Windows (C:\...)
    // chega mutilado no Node via spawn do sidecar ("EISDIR: lstat 'C:'").
    // Com current_dir já apontando para a pasta do servidor, "server.mjs"
    // resolve sem depender do drive.
    let sidecar = sidecar
        .current_dir(server_dir)
        .env("PORT", "3000")
        .env("NODE_ENV", "production")
        .args(["server.mjs"]);

    let (mut rx, child) = match sidecar.spawn() {
        Ok(pair) => pair,
        Err(e) => {
            eprintln!("[sintonize] falha ao iniciar o servidor embutido: {e}");
            return;
        }
    };
    println!("[sintonize] servidor embutido spawnado (sidecar node), aguardando /health...");

    if let Some(state) = app.try_state::<ServerState>() {
        *state.0.lock().expect("lock ServerState") = Some(child);
    }

    // Repassa stdout/stderr do servidor pro console do app (debug em produção).
    tauri::async_runtime::spawn(async move {
        while let Some(event) = rx.recv().await {
            match event {
                CommandEvent::Stdout(bytes) => {
                    print!("[server] {}", String::from_utf8_lossy(&bytes));
                }
                CommandEvent::Stderr(bytes) => {
                    eprint!("[server] {}", String::from_utf8_lossy(&bytes));
                }
                CommandEvent::Error(err) => {
                    eprintln!("[server] erro: {err}");
                }
                CommandEvent::Terminated(payload) => {
                    eprintln!("[server] encerrado: {payload:?}");
                }
                _ => {}
            }
        }
    });

    // Poll síncrono em thread separada (sem depender de tokio::time) até o
    // servidor responder, então recarrega a janela principal — ela pode ter
    // sido criada antes do servidor subir e mostrado erro de conexão.
    let app_handle = app.clone();
    std::thread::spawn(move || {
        let attempts = HEALTH_POLL_TOTAL.as_millis() / HEALTH_POLL_INTERVAL.as_millis();
        for _ in 0..attempts {
            if health_check(HEALTH_POLL_INTERVAL) {
                println!("[sintonize] servidor pronto, recarregando janela");
                if let Some(win) = app_handle.get_webview_window("main") {
                    let _ = win.eval("window.location.reload()");
                }
                return;
            }
            std::thread::sleep(HEALTH_POLL_INTERVAL);
        }
        eprintln!("[sintonize] servidor não respondeu em /health após {}s", HEALTH_POLL_TOTAL.as_secs());
    });
}

/// Mata o processo filho do servidor, se houver. Chamado no shutdown do app.
///
/// Limitação conhecida: se o app morrer sem RunEvent (crash, kill via Task
/// Manager), o node.exe filho sobrevive segurando a porta 3000. O próximo
/// launch reaproveita esse servidor via health_check, mas nunca o adota nem
/// encerra — só some com kill manual ou reboot.
pub fn kill_server(app: &AppHandle) {
    if let Some(state) = app.try_state::<ServerState>() {
        if let Some(child) = state.0.lock().expect("lock ServerState").take() {
            if let Err(e) = child.kill() {
                eprintln!("[sintonize] falha ao encerrar servidor embutido: {e}");
            } else {
                println!("[sintonize] servidor embutido encerrado");
            }
        }
    }
}
