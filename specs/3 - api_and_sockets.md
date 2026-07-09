# API and WebSocket Contracts Specification — Sintonize

> Índice: [`0 - overview.md`](./0%20-%20overview.md) · Estado: [`2 - database_and_state.md`](./2%20-%20database_and_state.md) · Edge cases: [`5 - edge_cases.md`](./5%20-%20edge_cases.md)

> Transporte: Socket.io 4.x sobre o servidor HTTP do Next.js (`PORT` = `3000`, path `/socket.io`). Payloads JSON. Tipos compartilhados em pacote `@sintonize/shared` (TypeScript) com equivalente Dart gerado manualmente.

## 1. Convenções

| Direção | Padrão de nome | Exemplo |
|---------|---------------|---------|
| Cliente → Servidor | verbo_ação | `join_room` |
| Servidor → Cliente(s) | substantivo_estado | `room_joined` |
| Admin → Servidor | prefixo `admin_` | `admin_mute_user` |
| Servidor → Cliente (forçado) | prefixo `admin_force_` | `admin_force_mute` |

**Acknowledgments:** eventos críticos (`join_room`, `admin_*`) devem usar callback de acknowledgment do Socket.io para confirmar sucesso/erro ao emissor.

## 2. HTTP Endpoints

| Método | Rota | Resposta |
|--------|------|----------|
| `GET` | `/health` | `{ status: "ok", roomId, participantCount, uptime }` |
| `GET` | `/admin` | Admin UI (HTML) |
| `GET` | `/` | Cliente Flutter Web ou redirect |

## 3. Eventos de Ciclo de Vida da Sala

### 3.1 `join_room` (cliente → servidor)

Enviado após onboarding ou ao reconectar.

```typescript
// Payload
{
  id?: string;           // UUID persistido; omitir no primeiro acesso
  name: string;
  profile: "host" | "listener";
  roomUrl?: string;      // Para persistir last_room_url no cliente
}

// Ack response
{ success: true, data: RoomJoinedPayload }
| { success: false, error: ErrorPayload }
```

**Validações do servidor:**
- Rejeitar se `users.size >= MAX_PARTICIPANTS` → `ROOM_FULL`
- Sanitizar `name` (ver `database_and_state.md`)
- Gerar `id` se ausente/inválido

### 3.2 `room_joined` (servidor → cliente que entrou)

```typescript
{
  id: string;
  roomId: string;
  users: RoomUser[];
  activeTransmitters: string[];  // IDs dos Transmissores ativos
  desktopHostId: string;
}
```

### 3.3 `user_joined` (servidor → todos, exceto quem entrou)

```typescript
{ user: RoomUser }
```

### 3.4 `user_updated` (servidor → todos)

Disparado após rename, mute, ou mudança de `connectionState`.

```typescript
{ user: RoomUser }
```

### 3.5 `leave_room` (cliente → servidor)

Saída voluntária (após dupla confirmação na UI).

```typescript
{ }  // userId inferido do socket autenticado via join_room prévio
```

**Efeito:** remove do `RoomState`, emite `user_left` (`reason: "left_voluntarily"`), fecha conexões WebRTC dos peers via `webrtc_peer_closed`.

### 3.6 `user_left` (servidor → todos)

```typescript
{
  userId: string;
  reason: "disconnected" | "kicked" | "left_voluntarily";
}
```

## 4. Eventos de Sinalização WebRTC (Mesh)

> O servidor atua apenas como relay, identificando remetente/destinatário por `id`. Não interpreta SDP.

### 4.1 Regras de Iniciador

| Par | Iniciador (`initiator: true`) | Motivo |
|-----|-------------------------------|--------|
| Transmissor → Ouvinte | Transmissor | Transmissor sempre cria offer |
| Transmissor → Transmissor | Quem já estava na sala | Participante existente inicia com novo entrante |
| Desktop Host → qualquer | Desktop Host | Desktop é Transmissor permanente |

### 4.2 `webrtc_peer_required` (servidor → cliente)

Instrui um cliente a iniciar (ou aceitar) negociação com um peer.

```typescript
{
  peerId: string;
  peerProfile: "host" | "listener";
  peerIsDesktopHost: boolean;
  initiator: boolean;   // true = este cliente cria o offer
}
```

### 4.3 `webrtc_offer` (cliente → servidor → cliente-alvo)

```typescript
{
  from: string;
  to: string;
  sdp: RTCSessionDescriptionInit;
}
```

### 4.4 `webrtc_answer` (cliente → servidor → cliente-alvo)

```typescript
{
  from: string;
  to: string;
  sdp: RTCSessionDescriptionInit;
}
```

### 4.5 `webrtc_ice_candidate` (cliente → servidor → cliente-alvo)

```typescript
{
  from: string;
  to: string;
  candidate: RTCIceCandidateInit;
}
```

### 4.6 `webrtc_peer_closed` (servidor → cliente)

```typescript
{ peerId: string; reason: "left" | "kicked" | "error" }
```

**Ação no cliente:** fechar e remover `RTCPeerConnection` e `MediaStream` associados ao `peerId`.

## 5. Eventos Administrativos

> Emitidos pela Admin UI no WebView local. Sem autenticação no MVP (ver `edge_cases.md`).

### 5.1 `admin_rename_user` (admin → servidor)

```typescript
{ userId: string; newName: string }
```

Valida 1–40 chars. Rejeita se `isDesktopHost`. Emite `user_updated`.

### 5.2 `admin_mute_user` (admin → servidor)

```typescript
{ userId: string; muted: boolean }
```

Emite `user_updated` (broadcast) + `admin_force_mute` ao alvo.

### 5.3 `admin_kick_user` (admin → servidor)

```typescript
{ userId: string }
```

Rejeita se `isDesktopHost`. Remove do estado, emite `user_left` + `admin_force_disconnect` ao alvo.

### 5.4 `admin_force_mute` (servidor → cliente-alvo)

```typescript
{ muted: boolean }
```

**Ação Flutter:** se perfil Host, `audioTrack.enabled = !muted`. Não encerra `RTCPeerConnection`.

### 5.5 `admin_force_disconnect` (servidor → cliente-alvo)

```typescript
{ reason: string }
```

**Ação Flutter:**
1. Encerrar todas as `RTCPeerConnection`.
2. Desconectar socket.
3. Limpar `shared_preferences`.
4. Navegar para Passo 1 com mensagem: *"Você foi removido da sala pelo administrador."*

### 5.6 `admin_get_room_state` (admin → servidor)

Snapshot sob demanda (útil ao abrir Admin UI).

```typescript
// Request: { }
// Response (ack): { users: RoomUser[], activeTransmitters: string[], participantCount: number }
```

## 6. Heartbeat e Diagnóstico

### 6.1 `heartbeat` / `heartbeat_ack` (bidirecional)

```typescript
// cliente → servidor
{ timestamp: number }

// servidor → cliente
{ timestamp: number; serverTime: number }
```

Intervalo: `HEARTBEAT_INTERVAL_MS`. Se 3 heartbeats consecutivos falharem, servidor marca `connectionState: "reconnecting"`.

### 6.2 `error` (servidor → cliente)

```typescript
{
  code: ErrorCode;
  message: string;
}

type ErrorCode =
  | "INVALID_PAYLOAD"
  | "ROOM_FULL"
  | "PEER_NOT_FOUND"
  | "USER_NOT_FOUND"
  | "UNAUTHORIZED_ADMIN_ACTION"  // Reservado para token futuro
  | "CANNOT_MODIFY_DESKTOP_HOST"
  | "RATE_LIMITED";
```

## 7. Sequência de Negociação — Novo Ouvinte Entra

```
Servidor                Desktop Host           Ouvinte (novo)
   │                         │                      │
   │── user_joined ─────────►│                      │
   │── user_joined ──────────────────────────────►│ (outros)
   │                         │                      │
   │── webrtc_peer_required ─►│ (initiator: true)    │
   │── webrtc_peer_required ──────────────────────►│ (initiator: false)
   │                         │                      │
   │◄── webrtc_offer ────────│                      │
   │── webrtc_offer ──────────────────────────────►│
   │                         │◄── webrtc_answer ────│
   │◄── webrtc_answer ───────│                      │
   │◄── ice candidates (relay bidirecional) ───────►│
   │                         │════ Áudio P2P ══════►│
```

Se o novo participante for Host (mobile), repetir a sequência para cada participante existente (o novo é `initiator` ao conectar com participantes já presentes que são Ouvintes; é `non-initiator` ao conectar com Transmissores existentes).

## 8. Configuração WebRTC Recomendada

```typescript
const rtcConfig: RTCConfiguration = {
  iceServers: [],  // Vazio no MVP; adicionar STUN local se ativado
  bundlePolicy: "max-bundle",
  rtcpMuxPolicy: "require",
};

// Audio transceiver
const transceiver = pc.addTransceiver("audio", {
  direction: "sendrecv",  // ou "recvonly" para Ouvinte
});

// Opus constraints (via SDP munging ou setParameters)
// useinbandfec=1; minptime=10; maxaveragebitrate=96000
```
