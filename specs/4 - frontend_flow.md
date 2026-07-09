# Frontend Flow Specification — Sintonize

> Índice: [`0 - overview.md`](./0%20-%20overview.md) · Estado: [`2 - database_and_state.md`](./2%20-%20database_and_state.md) · API: [`3 - api_and_sockets.md`](./3%20-%20api_and_sockets.md)

Este documento cobre os fluxos de UI do app **Sintonize** — **cliente Flutter** e **Admin UI** (Next.js no Tauri) — além de diretrizes de design e acessibilidade derivadas das skills do projeto.

---

## Parte A — Diretrizes de Design

### A.1 Identidade Visual

**Sujeito:** transmissão de áudio ao vivo para acessibilidade em espaços compartilhados.
**Audiência:** pessoas que precisam ouvir com clareza; administradores configurando a sala rapidamente.
**Tom:** calmo, confiável, alto contraste — a interface deve transmitir estabilidade, não urgência.

**Direção estética (evitar defaults genéricos de IA):**

| Token | Valor | Uso |
|-------|-------|-----|
| `--color-bg` | `#0F1419` | Fundo principal (escuro, reduz glare) |
| `--color-surface` | `#1A2332` | Cards e painéis |
| `--color-primary` | `#3B9EFF` | Ações primárias, indicadores de conexão ativa |
| `--color-accent` | `#F5A623` | Alertas, estado de reconexão |
| `--color-success` | `#34C759` | Conectado, áudio fluindo |
| `--color-text` | `#E8ECF1` | Texto principal |
| `--color-text-muted` | `#8B9CB3` | Labels secundários |

**Tipografia:**
- Display: **DM Sans** (peso 600–700) — geométrica, legível em tamanhos grandes
- Corpo: **Inter** (peso 400–500) — neutra, excelente em mobile
- Dados/monospace: **JetBrains Mono** — status, IP, contadores

**Elemento assinatura:** indicador de áudio vivo — barra de nível animada com `transform`/`opacity` apenas, respeitando `prefers-reduced-motion` (versão estática: barra sem animação).

### A.2 Voz e Copy (pt-BR)

- Nome do app sempre como **Sintonize** em telas, títulos e mensagens ao usuário.
- Voz ativa, segunda pessoa: *"Digite seu nome"* (não *"Seu nome deve ser digitado"*).
- Botões com verbo específico: *"Entrar na Sala"*, *"Confirmar Saída"* (não *"OK"* ou *"Continuar"* genérico).
- Estados de carregamento terminam com reticência unicode: *"Conectando…"*, *"Reconectando…"*.
- Erros explicam o problema **e** o próximo passo: *"Microfone bloqueado. Abra as configurações do navegador para permitir o acesso."*
- Mesmo termo em todo o fluxo: *"Sair da Sala"* no botão, no modal e no toast.

### A.3 Acessibilidade (Obrigatório)

Derivado das Web Interface Guidelines do projeto:

| Requisito | Implementação |
|-----------|--------------|
| Contraste | Mínimo WCAG AA (4.5:1 texto, 3:1 elementos grandes) |
| Alvos de toque | Mínimo 48×48 dp (Flutter) / 44×44 px (web) |
| Foco visível | `focus-visible` ring em todos os interativos — nunca `outline: none` sem substituto |
| Leitores de tela | `Semantics` (Flutter) / `aria-label` (web) em botões icon-only |
| Movimento reduzido | `@media (prefers-reduced-motion: reduce)` desativa animações de waveform |
| Formulários | Labels associados (`htmlFor` / `InputDecoration.labelText`); erros inline |
| Zoom | Nunca `user-scalable=no` — usuários de acessibilidade dependem de zoom |
| Safe areas | `SafeArea` (Flutter) / `env(safe-area-inset-*)` (web) |
| Autoplay | Interação do usuário antes de iniciar reprodução de áudio (ver `edge_cases.md`) |

---

## Parte B — Cliente Flutter

### B.1 Máquina de Estados de Navegação

```
[App Start]
    │
    ▼
[Cache válido?] ──false──► [Passo 1: Nome] ──► [Passo 2: Perfil] ──► [Persiste cache]
    │                                                                        │
    true                                                                     │
    │                                                                        ▼
    └──────────────────────────────────────────────────────────────► [Room View]
```

**Entrada via QR Code / deep link:** se URL contém host, salvar em `last_room_url` e usar como endpoint do socket.

### B.2 Passo 1 — Nome

```
┌───────────────────────────────────┐
│         [Logo Sintonize]          │
│                                   │
│      Bem-vindo à Sala             │
│   Digite seu nome para continuar  │
│                                   │
│  ┌─────────────────────────────┐  │
│  │ Nome                        │  │
│  └─────────────────────────────┘  │
│                                   │
│         [ Continuar ]             │
│         (disabled se vazio)       │
└───────────────────────────────────┘
```

| Regra | Detalhe |
|-------|---------|
| Validação | Trim automático, 1–40 chars |
| Botão | Desabilitado se vazio ou só espaços |
| Persistência | Nome fica em estado temporário até Passo 2 |
| Back (Android/web) | Sem ação — tela raiz |

### B.3 Passo 2 — Perfil

```
┌───────────────────────────────────┐
│  ← Voltar                         │
│                                   │
│   Olá, {Nome}! Como você vai      │
│   participar da sala?             │
│                                   │
│  ┌─────────────┐  ┌─────────────┐ │
│  │  [ícone]    │  │  [ícone]    │ │
│  │  Ouvinte    │  │  Host       │ │
│  │  Apenas     │  │  Transmite  │ │
│  │  ouvir      │  │  microfone  │ │
│  └─────────────┘  └─────────────┘ │
│                                   │
│         [ Entrar na Sala ]        │
└───────────────────────────────────┘
```

| Regra | Detalhe |
|-------|---------|
| Seleção | Obrigatória antes de habilitar botão |
| Voltar | Retorna ao Passo 1 com nome preservado |
| Confirmar | Persiste cache → Room View |
| Perfil Host | Solicita permissão de microfone **neste momento**, após diálogo explicativo |

### B.4 Room View

```
┌───────────────────────────────────┐
│  Sala Ativa          [Sair]      │
│                                   │
│  Transmitindo: {N} fonte(s)       │
│  [====------] nível de áudio      │
│                                   │
│  Volume    [====●========]        │
│                                   │
│  ● Conectado                      │
│  (ou: ○ Reconectando…)           │
└───────────────────────────────────┘
```

| Elemento | Comportamento |
|----------|--------------|
| Indicador de áudio | Reflete nível do mix; estático se `prefers-reduced-motion` |
| Volume master | Slider 0–100%, afeta mix local (não remoto) |
| Status | `Conectado` / `Conectando…` / `Reconectando…` / `Conexão perdida` |
| Banner reconexão | Não-bloqueante; após `RECONNECT_UI_TIMEOUT_MS`, botão *"Tentar novamente"* |
| Sair da Sala | Sempre visível na AppBar |

### B.5 Modal de Dupla Confirmação — Sair

**Etapa 1:**
```
┌─────────────────────────────────────┐
│  Sair da Sala?                      │
│                                     │
│  Isso encerrará sua conexão e       │
│  apagará seus dados neste           │
│  dispositivo.                       │
│                                     │
│     [ Cancelar ]    [ Sair ]        │
└─────────────────────────────────────┘
```

**Etapa 2 (após "Sair"):**
```
┌─────────────────────────────────────┐
│  Tem certeza?                       │
│                                     │
│  Você precisará informar seu nome   │
│  e perfil novamente na próxima vez. │
│                                     │
│  [ Voltar ]    [ Confirmar Saída ]  │
└─────────────────────────────────────┘
```

| Regra | Detalhe |
|-------|---------|
| Sequência | Obrigatória — nunca um único diálogo |
| Dismiss (tocar fora) | Equivale a Cancelar/Voltar |
| Confirmar Etapa 2 | Fecha WebRTC → `leave_room` → limpa cache → Passo 1 (`pushAndRemoveUntil`) |

### B.6 Tabela de Estados de Cache

| Estado | Comportamento |
|--------|--------------|
| Vazio | Passo 1 |
| Completo | Room View direto |
| Parcial/corrompido | Fail-safe → Passo 1 |
| Pós-logout | Igual a vazio |
| Pós-kick | Cache limpo pelo evento; redirect imediato para Passo 1 |

---

## Parte C — Admin UI (Next.js / Tauri WebView)

### C.1 Layout Principal

```
┌──────────────────────────────────────────────────────────┐
│  Sintonize — Estação Central          [●] Captura ativa  │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌─────────────────┐   Dispositivos Conectados ({N})     │
│  │                 │   ┌────────────────────────────────┐ │
│  │   [QR CODE]     │   │ Maria        Ouvinte   [···]  │ │
│  │                 │   │ João         Host      [···]  │ │
│  │ 192.168.1.42    │   │ Ana          Ouvinte   [···]  │ │
│  │ :3000           │   └────────────────────────────────┘ │
│  └─────────────────┘                                     │
│                                                          │
│  Carga da sala: [████░░░░░░] 12/15                       │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

### C.2 Elementos

| Elemento | Descrição |
|----------|-----------|
| QR Code | `http://<IP>:3000` — atualiza automaticamente se IP mudar |
| IP / porta | Exibidos em texto selecionável (para digitação manual) |
| Status de captura | Indicador verde/vermelho do loopback Tauri |
| Lista de dispositivos | Nome, perfil, estado de conexão, ícone de mudo |
| Menu `[···]` por dispositivo | Renomear, Silenciar/Ativar, Remover |
| Indicador de carga | Barra baseada em conexões Mesh; alerta acima do limiar |
| Alerta de IP alterado | Banner: *"Endereço da sala mudou. Peça para reescanear o QR Code."* |

### C.3 Ações Administrativas

| Ação | Confirmação | Evento |
|------|------------|--------|
| Renomear | Modal com input (1–40 chars) | `admin_rename_user` |
| Silenciar | Imediata (reversível) | `admin_mute_user` |
| Remover | Confirmação simples | `admin_kick_user` |

Desktop Host (`isDesktopHost`) não aparece na lista como removível.

### C.4 Estados da Admin UI

| Estado | UI |
|--------|-----|
| Captura OK | Badge verde *"Captura ativa"* |
| Captura falhou | Tela de diagnóstico com instruções por SO (ver `edge_cases.md`) |
| Nenhum cliente | Lista vazia com mensagem: *"Aguardando participantes. Compartilhe o QR Code."* |
| Sala cheia | Banner se `participantCount >= MAX_PARTICIPANTS` |

---

## Parte D — Checklist de Implementação UI

- [ ] Todos os botões icon-only têm `aria-label` / `Semantics`
- [ ] Modais com `overscroll-behavior: contain` e foco preso
- [ ] Sliders de volume acessíveis por teclado
- [ ] Estados vazios com mensagem orientadora (não tela em branco)
- [ ] Nomes longos truncados com tooltip/semântica completa
- [ ] `prefers-reduced-motion` respeitado em todas as animações
- [ ] Copy revisado em pt-BR consistente
