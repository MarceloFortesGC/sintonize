# Architecture Specification — Sintonize

> Índice: [`0 - overview.md`](./0%20-%20overview.md) · Estado: [`2 - database_and_state.md`](./2%20-%20database_and_state.md) · API: [`3 - api_and_sockets.md`](./3%20-%20api_and_sockets.md)

## 1. Visão Geral

**Sintonize** é um sistema de três camadas, 100% LAN, sem servidores externos:

```
┌─────────────────────────────────────────────────────────┐
│                    Desktop Host (Tauri)                  │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐ │
│  │ Rust/cpal   │  │ Next.js      │  │ WebView Admin  │ │
│  │ Loopback    │──│ Signaling +  │──│ UI (/admin)    │ │
│  │ capture     │  │ HTTP :3000   │  │ QR Code        │ │
│  └─────────────┘  └──────┬───────┘  └────────────────┘ │
└──────────────────────────┼──────────────────────────────┘
                           │ WebSocket (SDP/ICE/controle)
          ┌────────────────┼────────────────┐
          │                │                │
   ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐
   │ Cliente A   │  │ Cliente B   │  │ Cliente C   │
   │ (Ouvinte)   │  │ (Host mob.) │  │ (Ouvinte)   │
   └──────┬──────┘  └──────┬──────┘  └──────┬──────┘
          │    Áudio P2P direto (WebRTC)    │
          └───────────────┴─────────────────┘
```

## 2. Componentes e Responsabilidades

### 2.1 Tauri (Rust) — Camada Nativa

**Responsabilidades exclusivas do processo Rust:**

- Captura de áudio de loopback do SO via `cpal`:
  - **Windows**: WASAPI loopback
  - **macOS**: BlackHole/dispositivo agregado ou ScreenCaptureKit
  - **Linux**: PulseAudio/PipeWire monitor (`Monitor of …`)
- Encaminha o buffer capturado para o pipeline WebRTC do Desktop Host via bridge Tauri → WebView (Web Audio API com `MediaStreamTrack` sintético, ou injeção direta em `RTCPeerConnection` no processo Next.js).
- Resolve IP local (`local-ip-address` ou `if-addrs`) e expõe via `invoke('get_local_ip')`.
- Monitora mudanças de IP (polling a cada `IP_POLL_INTERVAL_MS` — ver `overview.md`).
- Gerencia ciclo de vida do servidor HTTP embutido (start/stop com o app).
- Registra exceção de firewall para porta HTTP e faixa UDP ephemeral do WebRTC.

**Comandos Tauri (`tauri::command`):**

| Comando | Retorno | Descrição |
|---------|---------|-----------|
| `get_local_ip` | `string` | IP local preferencial (Wi-Fi/Ethernet) |
| `get_audio_devices` | `AudioDevice[]` | Lista dispositivos de captura disponíveis |
| `start_capture` | `void` | Inicia captura no dispositivo selecionado |
| `stop_capture` | `void` | Para captura |
| `get_capture_status` | `CaptureStatus` | `{ active, device, error? }` |

### 2.2 Next.js — Admin UI + Signaling Server

**Modo de execução:** custom server (`server.ts`) que inicia HTTP + Socket.io na mesma porta (`PORT`, padrão `3000`). Não usar API Routes isoladas para WebSocket — o upgrade HTTP→WS exige servidor customizado.

**Rotas HTTP:**

| Rota | Acesso | Descrição |
|------|--------|-----------|
| `/admin` | Apenas WebView local do Tauri | Painel administrativo |
| `/` | Rede LAN | Redirect para cliente Flutter Web (ou landing mínima com link) |
| `/health` | Rede LAN | `{ status: "ok", roomId, participantCount }` |

**Responsabilidades do Signaling Server:**

- Registro e ciclo de vida de participantes (`join_room`, `leave_room`, `disconnect`).
- Relay de sinalização WebRTC (SDP offer/answer, ICE candidates) — **nunca transporta áudio**.
- Orquestração de negociação Mesh via evento `webrtc_peer_required`.
- Emissão de eventos administrativos (`admin_*`).
- Manutenção de `RoomState` em memória (ver `database_and_state.md`).

**O Desktop Host é sempre um Transmissor:** mesmo sem clientes conectados, o processo Next.js no Tauri mantém o stream de loopback pronto para negociação WebRTC assim que um cliente entra.

### 2.3 Flutter — Cliente (Web / iOS / Android)

- Acessa `http://<IP_LOCAL>:3000` (via QR Code ou URL digitada).
- Fluxo de onboarding definido em `frontend_flow.md`.
- Conecta ao Signaling Server e anuncia presença (`join_room`).
- Estabelece `RTCPeerConnection` direta com cada Transmissor ativo.
- **Perfil Ouvinte:** apenas recebe e reproduz áudio (mixagem de N streams quando há múltiplos Transmissores).
- **Perfil Host (mobile):** adicionalmente captura microfone (`getUserMedia`) e transmite para todos os participantes.

## 3. Topologia Mesh P2P

### 3.1 Regras de Conexão

| Participante | Envia áudio? | Conexões WebRTC que mantém |
|--------------|-------------|---------------------------|
| Desktop Host | Sim (loopback) | Uma com cada participante da sala |
| Host (mobile) | Sim (microfone) | Uma com cada participante da sala |
| Ouvinte | Não | Uma com cada Transmissor ativo (apenas recebe) |

**Regra de iniciador SDP:** o Transmissor sempre cria o `offer`; o receptor cria o `answer`. Detalhes em `api_and_sockets.md`, seção 3.

### 3.2 Mixagem de Áudio (Cliente)

Quando há múltiplos Transmissores, o cliente Flutter deve:

1. Receber N `MediaStream` (um por Transmissor).
2. Mixar via Web Audio API (Web) ou mixer nativo (iOS/Android).
3. Expor controle de volume master (afeta mix final) na Room View.

### 3.3 STUN / TURN

| Serviço | MVP | Observação |
|---------|-----|------------|
| STUN local (`coturn` embarcado) | Opcional, desativado por padrão | Útil em redes com VLANs ou Wi-Fi com sub-redes distintas |
| TURN | Fora do escopo | Quebraria premissa de baixa latência |

Na maioria das LANs, candidatos ICE `host` são suficientes (mesma sub-rede).

## 4. Mapeamento de Portas

| Serviço | Porta | Protocolo | Configuração |
|---------|-------|-----------|--------------|
| HTTP + WebSocket | `3000` | TCP | Env `PORT` |
| Socket.io path | — | WS upgrade | `SOCKET_PATH` = `/socket.io` |
| WebRTC RTP | Ephemeral (49152–65535) | UDP | Negociado via ICE |
| STUN local (opcional) | `3478` | UDP | Config avançada |

> **Firewall:** o instalador Tauri deve criar regra automática (Windows Defender / `ufw` no Linux) para `PORT` TCP e faixa UDP do WebRTC.

## 5. Sequência de Conexão (Happy Path)

```
Desktop Host          Signaling Server       Cliente Flutter
     │                       │                      │
     │── inicia servidor ───►│                      │
     │── resolve IP ─────────│                      │
     │◄── QR Code na Admin ──│                      │
     │                       │                      │
     │                       │◄── join_room ────────│
     │                       │── room_joined ──────►│
     │◄── user_joined ───────│── user_joined ──────►│ (broadcast)
     │                       │                      │
     │◄── webrtc_peer_required (initiator: Desktop) ─│
     │── webrtc_offer ──────►│── webrtc_offer ─────►│
     │                       │◄── webrtc_answer ────│
     │◄── webrtc_answer ─────│                      │
     │◄──── ICE candidates (bidirecional via relay) ─►│
     │                       │                      │
     │════════════ Áudio P2P direto (fora do servidor) ════════════►│
```

1. Tauri inicia Next.js → resolve IP → Admin UI exibe QR Code.
2. Usuário escaneia QR → abre Flutter Web/App.
3. Flutter verifica cache (`shared_preferences`). Se incompleto, executa onboarding.
4. Flutter conecta WebSocket e emite `join_room`.
5. Servidor registra participante, notifica Admin UI e demais clientes.
6. Para cada Transmissor ativo, servidor emite `webrtc_peer_required` e relay SDP/ICE.
7. Áudio flui P2P — fora do Next.js.
8. Admin UI atualiza lista em tempo real.

## 6. Latência (Alvo: 10–30 ms)

| Camada | Otimização |
|--------|-----------|
| Captura (`cpal`) | Buffer de `AUDIO_BUFFER_FRAMES` frames a 48 kHz |
| Codec | Opus: `useinbandfec=1`, `minptime=10`, DTX desativado, `maxaveragebitrate` ≈ `AUDIO_BITRATE_KBPS` kbps |
| Reprodução | `playoutDelayHint` mínimo no `RTCRtpReceiver` |
| Rede | Recomendar Ethernet ou Wi-Fi 5/6 GHz no Desktop Host; 2.4 GHz como fallback documentado |
| Arquitetura | Mesh P2P elimina hop de SFU — trade-off: CPU/banda cresce com participantes |

## 7. Limitações Conhecidas

| Limitação | Impacto | Mitigação |
|-----------|---------|-----------|
| Escalabilidade Mesh | Upload do Transmissor ∝ número de participantes | Limite `MAX_PARTICIPANTS` = 20; aviso em `ROOM_LOAD_WARNING_THRESHOLD` |
| Múltiplos Transmissores | Conexões multiplicam | Indicador de carga na Admin UI |
| Sem TURN | Falha em AP Isolation | Mensagem de erro específica (ver `edge_cases.md`) |
| Sem auth no MVP | Qualquer dispositivo na LAN pode emitir `admin_*` | Token administrativo em versão futura (ver `edge_cases.md`) |
| HTTP sem HTTPS | `getUserMedia` pode falhar em alguns navegadores | Workarounds documentados; HTTPS self-signed em versão futura |

## 8. Fora do Escopo do MVP

- Múltiplas salas por instância Desktop
- Autenticação / login de usuários
- TURN / SFU
- Gravação de áudio
- HTTPS com certificado confiável
- Sincronização de legendas ou texto
- App Flutter desktop (apenas Web/iOS/Android)
