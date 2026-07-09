# Sintonize — Visão Geral e Índice das Especificações

## Nome da Aplicação

| Campo | Valor |
|-------|-------|
| **Nome** | **Sintonize** |
| Uso na UI | Sempre com "S" maiúsculo — nunca "sintonize" ou "SINTONIZE" |
| Título da janela (Desktop Host) | `Sintonize — Estação Central` |
| Título do app (cliente mobile/web) | `Sintonize` |
| Pacotes / namespaces | `sintonize` em minúsculo (ex: `@sintonize/shared`, `com.sintonize.app`) |

## O que é

**Sintonize** é um sistema de transmissão de áudio em rede local (LAN) para acessibilidade em ambientes compartilhados — salas de aula, teatros, reuniões, igrejas. Um computador desktop atua como estação central; participantes entram via celular ou navegador e ouvem o áudio do ambiente com latência mínima (alvo: 10–30 ms).

## Premissas do MVP

| Premissa | Decisão |
|----------|---------|
| Conectividade | 100% LAN — sem dependência de internet |
| Salas | Uma sala por instância do Desktop Host |
| Persistência | Nenhum banco de dados; estado efêmero em memória |
| Autenticação | Confiança implícita na rede local (sem login) |
| Topologia de mídia | WebRTC Mesh P2P (sem SFU/TURN no MVP) |
| Idioma da UI | Português Brasil (pt-BR) |
| Plataformas cliente | Flutter Web, iOS e Android |
| Plataforma host | Tauri (Windows, macOS, Linux) + Next.js embutido |

## Glossário

| Termo | Definição |
|-------|-----------|
| **Desktop Host** | Aplicação Tauri + Next.js no computador central. Captura áudio de loopback do sistema, hospeda a Admin UI e o Signaling Server. Sempre transmite áudio. |
| **Cliente** | App Flutter (Web/iOS/Android) que entra na sala via QR Code ou URL. |
| **Perfil Ouvinte** | Cliente que apenas recebe áudio. Não usa microfone. |
| **Perfil Host (mobile)** | Cliente que, além de ouvir, transmite áudio do microfone local para os demais participantes. |
| **Signaling Server** | Servidor WebSocket (Socket.io) no Next.js. Roteia SDP/ICE e eventos administrativos. **Não transporta áudio.** |
| **Transmissor** | Qualquer participante que envia áudio: Desktop Host (loopback) e/ou Clientes com perfil Host (microfone). |
| **Mesh** | Topologia em que cada Transmissor mantém uma `RTCPeerConnection` direta com cada participante da sala. |
| **Admin UI** | Painel web servido em `/admin`, acessível apenas localmente no WebView do Tauri. |
| **Sala** | Instância única de `RoomState` em memória, identificada por `roomId: "main"`. |

## Constantes Globais

Valores compartilhados entre todos os documentos. Alterações devem ser refletidas em todos os specs que os referenciam.

| Constante | Valor | Uso |
|-----------|-------|-----|
| `PORT` | `3000` | HTTP + WebSocket (upgrade) |
| `SOCKET_PATH` | `/socket.io` | Path do Socket.io |
| `ROOM_ID` | `"main"` | ID fixo da sala no MVP |
| `MAX_PARTICIPANTS` | `20` | Limite de participantes por sala |
| `MAX_NAME_LENGTH` | `40` | Nome de exibição |
| `RECONNECT_GRACE_PERIOD_MS` | `30_000` | Tempo antes de remover usuário desconectado |
| `RECONNECT_UI_TIMEOUT_MS` | `30_000` | Tempo exibindo "Reconectando…" antes de "Conexão perdida" |
| `ICE_NEGOTIATION_TIMEOUT_MS` | `10_000` | Timeout para ICE atingir `connected` |
| `HEARTBEAT_INTERVAL_MS` | `5_000` | Intervalo do heartbeat Socket.io |
| `IP_POLL_INTERVAL_MS` | `5_000` | Polling de IP local no Tauri |
| `ROOM_LOAD_WARNING_THRESHOLD` | `15` | Conexões Mesh totais para aviso de carga |
| `AUDIO_BUFFER_FRAMES` | `256` | Buffer de captura cpal a 48 kHz |
| `AUDIO_BITRATE_KBPS` | `96` | Bitrate Opus alvo (64–128 kbps aceitável) |

## Índice dos Documentos

| # | Arquivo | Conteúdo |
|---|---------|----------|
| 0 | `overview.md` | Este arquivo — glossário, premissas, constantes |
| 1 | `architecture.md` | Componentes, topologia, portas, latência, limitações |
| 2 | `database_and_state.md` | Contratos de dados, cache local, estado da sala |
| 3 | `api_and_sockets.md` | Eventos Socket.io, payloads, erros, sequência WebRTC |
| 4 | `frontend_flow.md` | Fluxos de UI (Flutter + Admin), design, acessibilidade |
| 5 | `edge_cases.md` | Falhas de rede, permissões, loopback, segurança |

## Stack Tecnológica

| Camada | Tecnologia | Versão mínima sugerida |
|--------|-----------|------------------------|
| Desktop nativo | Tauri 2.x + Rust | — |
| Captura de áudio | `cpal` | — |
| Admin + Signaling | Next.js (App Router) + Socket.io | Next 15+, Node 20+ |
| Cliente | Flutter + `flutter_webrtc` | Flutter 3.24+ |
| Cache cliente | `shared_preferences` | — |
| Comunicação | WebRTC (Opus), Socket.io 4.x | — |

## Ordem de Implementação Sugerida

1. **Signaling Server** — `RoomState` em memória + eventos de ciclo de vida (`join_room`, `leave_room`)
2. **Admin UI** — QR Code, lista de dispositivos, ações administrativas
3. **Captura Tauri** — loopback + injeção de áudio no pipeline WebRTC do Desktop Host
4. **Cliente Flutter** — onboarding → Room View → recepção de áudio
5. **Mesh completo** — múltiplos Transmissores, mixagem, reconexão
6. **Edge cases** — reconexão, permissões, diagnósticos

## Critérios de Aceite do MVP

- [ ] Desktop Host inicia, exibe QR Code com IP local correto
- [ ] Cliente Flutter entra via QR Code, completa onboarding e ouve áudio do Desktop Host com latência perceptível < 50 ms em LAN estável
- [ ] Admin UI lista dispositivos conectados em tempo real
- [ ] Admin pode renomear, silenciar e remover participantes
- [ ] Cliente com perfil Host (mobile) transmite microfone para os demais
- [ ] Reconexão automática após queda de Wi-Fi sem duplicar usuário na lista
- [ ] Saída voluntária com dupla confirmação limpa cache local
- [ ] Mensagem clara quando ICE falha (AP Isolation)
