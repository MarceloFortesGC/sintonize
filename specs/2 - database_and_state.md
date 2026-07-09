# Database and State Specification — Sintonize

> Índice: [`0 - overview.md`](./0%20-%20overview.md) · API: [`3 - api_and_sockets.md`](./3%20-%20api_and_sockets.md) · Frontend: [`4 - frontend_flow.md`](./4%20-%20frontend_flow.md)

> Não há banco de dados persistente. Estado efêmero no servidor (memória) e cache local no cliente. Este documento formaliza contratos de dados e regras de ciclo de vida.

## 1. Estado Local no Flutter (Cliente)

### 1.1 Mecanismo

`shared_preferences` — chave-valor local (Web: `localStorage`/IndexedDB; iOS/Android: storage nativo).

### 1.2 Chaves Persistidas

| Chave | Tipo | Descrição |
|-------|------|-----------|
| `user_id` | `String` | UUID v4, gerado no primeiro acesso, estável entre sessões |
| `user_name` | `String` | Nome do onboarding (Passo 1) |
| `user_profile` | `String` | `"host"` \| `"listener"` |
| `onboarding_completed` | `bool` | `true` pula onboarding em acessos futuros |
| `last_room_url` | `String?` | Última URL acessada, para reconexão rápida |

### 1.3 Regras de Ciclo de Vida

| Evento | Efeito no cache |
|--------|----------------|
| **App start — cache completo** | Pula onboarding → Room View → `join_room` com dados salvos |
| **App start — cache vazio/corrompido** | Força onboarding (fail-safe se falta qualquer chave obrigatória) |
| **Conclusão do Passo 2** | Persiste todas as chaves atomicamente; `onboarding_completed = true` |
| **Saída voluntária** (dupla confirmação) | `SharedPreferences.clear()` → Passo 1 |
| **Kick pelo admin** (`admin_force_disconnect`) | `SharedPreferences.clear()` → Passo 1 com mensagem |
| **Queda de conexão / reconexão** | Cache **preservado** — `user_id` nunca é alterado silenciosamente |
| **Fallback mic negado → Ouvinte** | Altera apenas estado de sessão; **não** sobrescreve `user_profile` sem confirmação |

### 1.4 Validação de Cache na Leitura

```dart
bool isCacheValid(SharedPreferences prefs) {
  return prefs.getBool('onboarding_completed') == true
      && prefs.getString('user_id')?.isNotEmpty == true
      && prefs.getString('user_name')?.isNotEmpty == true
      && ['host', 'listener'].contains(prefs.getString('user_profile'));
}
```

Se `isCacheValid` retorna `false`, tratar como primeiro acesso.

## 2. Contrato de Dados do Usuário (Cliente ↔ Servidor)

```typescript
type UserProfile = "host" | "listener";

type ConnectionState = "connecting" | "connected" | "disconnected" | "reconnecting";

interface RoomUser {
  id: string;              // UUID v4, gerado no cliente
  name: string;            // 1–40 caracteres, sanitizado
  profile: UserProfile;
  connectedAt: string;     // ISO 8601, atribuído pelo servidor no join
  socketId: string;        // ID efêmero da conexão WS atual
  muted: boolean;          // Mudo imposto pelo Admin (default: false)
  connectionState: ConnectionState;
  isDesktopHost?: boolean; // true apenas para o Desktop Host (não editável pelo admin)
}
```

### 2.1 Validações (cliente e servidor)

| Campo | Regra |
|-------|-------|
| `name` | Obrigatório, trim, 1–40 chars, sem HTML/script (`<`, `>`, `&` escapados ou rejeitados) |
| `profile` | Apenas `"host"` \| `"listener"` — rejeitar outros com `INVALID_PAYLOAD` |
| `id` | UUID v4 válido; se ausente/inválido, servidor gera novo e retorna em `room_joined` |

### 2.2 Nomes Duplicados

Permitidos — a identidade é o `id`, não o `name`. A Admin UI deve exibir sufixo diferenciador quando houver nomes iguais (ex: "Maria (2)").

## 3. Estado da Sala no Servidor

### 3.1 Estrutura em Memória

```typescript
interface RoomState {
  roomId: string;                    // Constante "main" no MVP
  users: Map<string, RoomUser>;      // Chave: user.id
  transmitters: Set<string>;         // IDs com profile "host" + Desktop Host
  desktopHostId: string;             // ID fixo do Desktop Host (gerado no boot)
  createdAt: string;
  graceTimers: Map<string, NodeJS.Timeout>; // Timers de reconexão por user.id
}
```

### 3.2 Desktop Host como Participante

O Desktop Host é registrado automaticamente no boot do servidor com:

```typescript
{
  id: desktopHostId,       // UUID gerado uma vez por sessão do app
  name: "Estação Central",
  profile: "host",
  isDesktopHost: true,
  muted: false,
  connectionState: "connected",
}
```

Não aparece na lista de dispositivos como removível, mas conta como Transmissor ativo.

### 3.3 Ciclo de Vida do Estado

| Evento | Efeito |
|--------|--------|
| `join_room` | Insere/atualiza `RoomUser`; adiciona a `transmitters` se `profile === "host"`; cancela grace timer se existir |
| `leave_room` (voluntário) | Remove imediatamente do `Map`; emite `user_left` com `reason: "left_voluntarily"` |
| Socket `disconnect` | Define `connectionState: "reconnecting"`; inicia grace timer (`RECONNECT_GRACE_PERIOD_MS`); emite `user_updated` |
| Fim do grace timer | Remove do `Map`; emite `user_left` com `reason: "disconnected"`; emite `webrtc_peer_closed` aos peers afetados |
| `admin_kick_user` | Remove imediatamente; emite `user_left` (`reason: "kicked"`); emite `admin_force_disconnect` ao alvo |
| `admin_rename_user` | Atualiza `name`; emite `user_updated` |
| `admin_mute_user` | Atualiza `muted`; emite `user_updated` + `admin_force_mute` ao alvo |
| Servidor reinicia | Estado perdido — todos os clientes devem reconectar via `join_room` |

### 3.4 Reconciliação na Reconexão

Ao receber `join_room` com `id` existente no `Map` (mesmo durante grace period):

1. Cancelar grace timer.
2. Atualizar `socketId` e `connectionState: "connecting"`.
3. Restaurar `name`, `profile`, `muted` do registro existente (ignorar valores conflitantes do payload, exceto se o cliente enviar `name` diferente — nesse caso, aceitar o novo `name`).
4. Emitir `room_joined` ao cliente com snapshot atualizado.
5. Emitir `user_updated` aos demais.
6. Reemitir `webrtc_peer_required` para todas as conexões Mesh necessárias.

## 4. Estado de Sessão Efêmero (Cliente — Não Persistido)

Variáveis mantidas apenas em memória durante a sessão:

| Estado | Tipo | Descrição |
|--------|------|-----------|
| `peerConnections` | `Map<string, RTCPeerConnection>` | Chave: `peerId` |
| `remoteStreams` | `Map<string, MediaStream>` | Streams recebidos por Transmissor |
| `localStream` | `MediaStream?` | Microfone local (perfil Host) |
| `socketConnected` | `bool` | Estado do WebSocket |
| `sessionProfileOverride` | `UserProfile?` | Fallback temporário (mic negado → ouvinte) |
| `masterVolume` | `double` | 0.0–1.0, default 1.0 |

## 5. Admin Session State (MVP)

No MVP, a Admin UI não persiste estado — reconecta ao recarregar o WebView. Estado relevante vem do `RoomState` via eventos Socket.io.

**Versão futura:** token administrativo gerado no boot do Tauri, injetado apenas no WebView local, validado pelo servidor em eventos `admin_*`.
