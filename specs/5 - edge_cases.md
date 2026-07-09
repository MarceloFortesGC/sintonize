# Edge Cases and Failure Mitigation Specification — Sintonize

> Índice: [`0 - overview.md`](./0%20-%20overview.md) · API: [`3 - api_and_sockets.md`](./3%20-%20api_and_sockets.md) · Frontend: [`4 - frontend_flow.md`](./4%20-%20frontend_flow.md)

## 1. Problemas de Rede

### 1.1 Queda de Wi-Fi / Perda Temporária

**Detecção:**
- Socket.io: evento `disconnect`
- WebRTC: `oniceconnectionstatechange` → `disconnected` / `failed`
- Heartbeat: 3 falhas consecutivas

**Mitigação:**

| Camada | Ação |
|--------|------|
| Socket.io | Reconexão automática com backoff (1s, 2s, 4s… teto 10s) |
| Pós-reconexão | Reenviar `join_room` com mesmo `user_id` |
| WebRTC | `restartIce()` antes de recriar conexão do zero |
| UI | Banner *"Reconectando…"*; após `RECONNECT_UI_TIMEOUT_MS`, *"Conexão perdida"* + botão *"Tentar novamente"* |

**Nunca** redirecionar para onboarding durante reconexão automática.

### 1.2 Mudança de IP do Desktop Host

**Cenário:** DHCP renova ou Host muda de rede.

**Mitigação:**
- Tauri polling (`IP_POLL_INTERVAL_MS`) → regenera QR Code
- Banner na Admin UI: *"Endereço da sala mudou"*
- Clientes conectados: socket cai → fluxo 1.1; se não reconectarem, precisam reescanear QR

### 1.3 AP Isolation (Client Isolation)

**Cenário:** roteador impede P2P entre dispositivos na mesma rede.

**Detecção:** ICE não atinge `connected` em `ICE_NEGOTIATION_TIMEOUT_MS`.

**UX:**
```
Não foi possível conectar diretamente na rede.
Verifique se o roteador permite comunicação entre
dispositivos (desative "Isolamento de Cliente").
```

### 1.4 Sala Cheia

**Cenário:** `users.size >= MAX_PARTICIPANTS`.

**Resposta:** `join_room` retorna `ROOM_FULL`.

**UX:** *"A sala atingiu o limite de {MAX_PARTICIPANTS} participantes. Tente novamente mais tarde."*

## 2. Permissões de Hardware

### 2.1 Microfone Negado (Perfil Host)

**Fluxo:**
1. Diálogo pré-permissão: *"Para transmitir áudio, precisamos acessar seu microfone."*
2. Chamar `getUserMedia`
3. Se `NotAllowedError`:
   - Opção A: *"Tentar novamente"*
   - Opção B: *"Entrar como Ouvinte"* (override de sessão, não persiste `user_profile`)

### 2.2 Permissão Bloqueada Permanentemente

Detectar via `navigator.permissions.query({ name: 'microphone' })` (quando suportado).

**UX:** tela de instruções por plataforma:
- Chrome: `chrome://settings/content/microphone`
- Safari/iOS: Ajustes → Safari → Microfone
- Android: Configurações do app

### 2.3 HTTP sem HTTPS Bloqueando `getUserMedia`

**Cenário:** `http://192.168.x.x:3000` pode ser bloqueado em Chrome recente.

| Plataforma | Impacto | Mitigação |
|------------|---------|-----------|
| Flutter iOS/Android | Sem impacto (permissão nativa) | — |
| Flutter Web / Chrome | Pode bloquear mic | Documentar flag `chrome://flags/#unsafely-treat-insecure-origin-as-secure` |
| Ouvinte (qualquer) | Sem impacto (não usa mic) | — |

**Futuro:** HTTPS com certificado self-signed servido pelo Tauri.

### 2.4 Política de Autoplay (Reprodução de Áudio)

**Cenário:** navegadores bloqueiam `audio.play()` sem interação do usuário.

**Mitigação:**
- Iniciar reprodução após toque em *"Entrar na Sala"* (já é interação)
- Se falhar, exibir botão: *"Toque para iniciar áudio"*
- Flutter nativo: sem restrição de autoplay

## 3. Falhas na Captura de Loopback (Desktop)

### 3.1 Driver Ausente ou Não Configurado

**Detecção:** `get_audio_devices` não retorna dispositivo de loopback válido.

**Mitigação por SO:**

| SO | Instrução |
|----|-----------|
| Windows | Habilitar "Stereo Mix" ou instalar VB-Audio Cable |
| Linux | `pactl load-module module-loopback` ou selecionar "Monitor of …" no PipeWire |
| macOS | Instalar BlackHole e criar dispositivo agregado |

**Comportamento:** bloquear transmissão do Desktop Host, mas permitir sala funcionar com Hosts mobile.

### 3.2 Dispositivo Desconecta Durante Transmissão

**Detecção:** `cpal` error callback.

**Mitigação:**
1. Reinicializar captura no dispositivo padrão (até 3 tentativas)
2. Admin UI: *"Captura interrompida — tentando reconectar"*
3. Após falhas: exigir seleção manual de dispositivo

### 3.3 Degradação com Múltiplos Transmissores

**Cenário:** > 5 Transmissores ou > `ROOM_LOAD_WARNING_THRESHOLD` conexões.

**Mitigação (UX preventiva):**
- Admin UI: indicador de carga com aviso
- Documentar como limitação do Mesh

## 4. Conflitos e Concorrência

### 4.1 Reconexão Durante Grace Period

**Cenário:** usuário desconecta e reconecta em < `RECONNECT_GRACE_PERIOD_MS`.

**Comportamento:** servidor restaura registro existente (mesmo `id`), sem duplicata na lista. Ver `database_and_state.md` §3.4.

### 4.2 Dois Dispositivos com Mesmo `user_id`

**Cenário:** improvável (UUID por dispositivo), mas se ocorrer (cache copiado):

**Mitigação:** servidor desconecta a sessão anterior ao aceitar `join_room` com `id` já conectado (last-write-wins).

### 4.3 Negociação WebRTC Concorrente

**Cenário:** dois offers simultâneos para o mesmo par.

**Mitigação:** glare resolution — se ambos enviam offer, o participante com `id` lexicograficamente menor recria como offerer; o outro descarta e aguarda novo offer.

## 5. Segurança (MVP)

### 5.1 Limitação Conhecida

Sem autenticação formal: qualquer dispositivo na LAN que descubra `http://<IP>:3000` pode:
- Entrar na sala (`join_room`)
- Emitir eventos `admin_*` via WebSocket

**Premissa aceita no MVP:** ambiente controlado (escola, teatro) com rede confiável.

### 5.2 Mitigações Mínimas no MVP

| Medida | Implementação |
|--------|--------------|
| Rate limiting | Máx. 5 `join_room`/min por IP |
| Validação de payload | Rejeitar campos extras e tipos inválidos |
| Proteção Desktop Host | Rejeitar `admin_kick_user` / `admin_mute_user` se `isDesktopHost` |
| Admin UI não exposta | `/admin` acessível apenas no WebView local (não linkado no QR) |

### 5.3 Versão Futura — Token Administrativo

1. Tauri gera token aleatório no boot.
2. Injeta em `window.__ADMIN_TOKEN__` apenas no WebView local.
3. Servidor valida token em todos os eventos `admin_*`.
4. Clientes remotos não recebem o token.

## 6. Compatibilidade de Plataforma

| Plataforma | WebRTC | Socket.io | getUserMedia | Notas |
|------------|--------|-----------|-------------|-------|
| Flutter iOS | Nativo | OK | Nativo | Requer permissão no Info.plist |
| Flutter Android | Nativo | OK | Nativo | Requer permissão no Manifest |
| Flutter Web (Chrome) | OK | OK | Pode exigir HTTPS | Testar autoplay |
| Flutter Web (Safari) | Parcial | OK | Restritivo | Testar em iOS Safari |
| Desktop Host (Tauri) | WebView | OK | N/A (loopback) | Testar em Win/Mac/Linux |

## 7. Matriz de Decisão Rápida

| Sintoma | Causa provável | Ação |
|---------|---------------|------|
| Sem áudio, status "Conectado" | Autoplay bloqueado | Botão *"Toque para iniciar áudio"* |
| ICE failed após 10s | AP Isolation | Mensagem de roteador |
| Mic não funciona no browser | HTTP inseguro | Usar app nativo ou flag Chrome |
| Lista duplicada | Reconexão sem `user_id` | Verificar cache e reconciliação |
| Admin não muta | Cliente não é Host | Mute só afeta Transmissores |
| Captura desktop falhou | Sem loopback | Diagnóstico por SO |
