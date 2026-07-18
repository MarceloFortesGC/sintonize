#!/usr/bin/env node
// Prepara tudo que o instalador do Tauri precisa empacotar como recurso:
//   1. build do cliente Flutter (copiado para apps/web/public/client)
//   2. build de produção do Next (apps/web/.next)
//   3. `pnpm deploy --prod --legacy` do @sintonize/web para
//      src-tauri/resources/server — isso gera um node_modules
//      autossuficiente com arquivos REAIS (não symlinks), contendo "next"
//      e o resto do runtime, pronto pra rodar num node.exe sidecar sem
//      pnpm/monorepo na máquina do usuário final.
//      (Tentamos primeiro `output: "standalone"` do Next, mas o tracing dele
//      recria a estrutura de node_modules via symlinks reais, o que dá EPERM
//      em Windows sem Modo de Desenvolvedor/elevação — `pnpm deploy` resolve
//      isso copiando arquivos de verdade.)
//   4. bundle single-file do servidor customizado (server.ts + Socket.io)
//      via esbuild -> server.mjs; remove fontes .ts/config de dev e
//      sourcemaps/typings que não são necessários em runtime.
//   5. cópia do node.exe usado para rodar este script para
//      src-tauri/binaries/node-<target-triple>.exe (sidecar externalBin)
//
// É invocado via tauri.conf.json -> build.beforeBuildCommand, com cwd em
// apps/desktop. Pode rodar isolado via `pnpm --filter @sintonize/desktop
// prepare-bundle` para testar sem disparar o build do Tauri.
//
// Cross-platform de propósito (nada de `&&`/shell unix inline) porque o
// tauri build roda no Windows no fluxo real do instalador.

import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";
import fs from "node:fs";
import * as esbuild from "esbuild";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const desktopDir = path.resolve(scriptDir, "..");
const rootDir = path.resolve(desktopDir, "..", "..");
const webDir = path.join(rootDir, "apps", "web");
const srcTauriDir = path.join(desktopDir, "src-tauri");
const resourcesServerDir = path.join(srcTauriDir, "resources", "server");

// Arquivos/pastas copiados pelo `pnpm deploy` que só servem pra dev
// (fontes TS, config de lint/tsc) e não são usados pelo servidor em
// runtime — removidos pra não inflar o instalador.
const PRUNE_AFTER_DEPLOY = [
  "server.ts",
  "src",
  "tsconfig.json",
  "tsconfig.tsbuildinfo",
  "next-env.d.ts",
  "eslint.config.mjs",
  // Cache de build incremental do Next (webpack/SWC) — só serve pra acelerar
  // rebuilds em dev; não é lido em runtime por `next()`/`next start`. Sozinho
  // costuma pesar dezenas/centenas de MB, então vale a pena remover.
  path.join(".next", "cache"),
];

function log(msg) {
  console.log(`[prepare-bundle] ${msg}`);
}

function run(cmd, args, cwd) {
  log(`$ ${cmd} ${args.join(" ")}  (cwd=${path.relative(rootDir, cwd) || "."})`);
  const result = spawnSync(cmd, args, {
    cwd,
    stdio: "inherit",
    shell: process.platform === "win32",
  });
  if (result.status !== 0) {
    throw new Error(`Comando falhou (${result.status}): ${cmd} ${args.join(" ")}`);
  }
}

// Não usa fs.readdirSync(..., {recursive:true}): o node_modules/.pnpm usa
// junctions do NTFS pra resolver dependências entre pacotes, e o Node segue
// junctions como se fossem diretórios normais nesse modo — dá uma explosão
// combinatória de contagem (o mesmo pacote compartilhado é recontado uma vez
// por junction que aponta pra ele). Deduplicamos por realpath.
function dirSizeBytes(dir) {
  const visited = new Set();
  let total = 0;
  function walk(current) {
    let real;
    try {
      real = fs.realpathSync.native(current);
    } catch {
      real = current;
    }
    if (visited.has(real)) return;
    visited.add(real);
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) {
        walk(full);
      } else if (entry.isFile()) {
        try {
          total += fs.statSync(full).size;
        } catch {
          // arquivo pode ter sumido entre o readdir e o stat; ignora.
        }
      }
    }
  }
  walk(dir);
  return total;
}

function formatBytes(bytes) {
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function pruneByExtension(dir, extensions) {
  let removed = 0;
  function walk(current) {
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) {
        walk(full);
      } else if (entry.isFile() && extensions.some((ext) => entry.name.endsWith(ext))) {
        fs.rmSync(full, { force: true });
        removed++;
      }
    }
  }
  walk(dir);
  return removed;
}

function hostTargetTriple() {
  const result = spawnSync("rustc", ["-vV"], { encoding: "utf8" });
  if (result.status === 0) {
    const match = result.stdout.match(/host:\s*(\S+)/);
    if (match) return match[1];
  }
  log("aviso: não consegui detectar o target triple via rustc, usando fallback x86_64-pc-windows-msvc");
  return "x86_64-pc-windows-msvc";
}

async function main() {
  const skipClient = process.env.SINTONIZE_SKIP_CLIENT_BUILD === "1";
  if (skipClient) {
    log("SINTONIZE_SKIP_CLIENT_BUILD=1 — pulando build do cliente Flutter (usando public/client existente)");
    if (!fs.existsSync(path.join(webDir, "public", "client", "index.html"))) {
      throw new Error("public/client ausente e build do cliente foi pulado — remova SINTONIZE_SKIP_CLIENT_BUILD ou rode `pnpm build:client` manualmente.");
    }
  } else {
    log("1/5 build do cliente Flutter (pnpm build:client)");
    run("pnpm", ["run", "build:client"], rootDir);
  }

  log("2/5 build de produção do Next (@sintonize/web)");
  run("pnpm", ["--filter", "@sintonize/web", "build"], rootDir);

  log("3/5 pnpm deploy --prod --legacy (hoisted) do @sintonize/web -> src-tauri/resources/server");
  fs.rmSync(resourcesServerDir, { recursive: true, force: true });
  fs.mkdirSync(resourcesServerDir, { recursive: true });
  run(
    "pnpm",
    [
      "--filter",
      "@sintonize/web",
      "deploy",
      "--prod",
      "--legacy",
      // node_modules FLAT (estilo npm), sem o virtual store .pnpm: os nomes
      // de pasta do .pnpm (ex.: next@15.5.20_react-dom@19.2.7_react@...)
      // empurram caminhos acima de 260 chars, e o WiX 3 (bundler MSI do
      // Tauri) falha com LGHT0103 em qualquer caminho além de MAX_PATH.
      "--config.node-linker=hoisted",
      resourcesServerDir,
    ],
    rootDir
  );
  // `pnpm deploy --prod` deixa node_modules/.pnpm-workspace-state-v1.json do
  // MONOREPO (não só do alvo do deploy) marcado com production:true/dev:false.
  // Sem isso, o próximo `pnpm run <script>` no repo acha que o node_modules
  // da raiz está "fora de sincronia" e tenta rodar `pnpm install --production`
  // sozinho — o que removeria as devDependencies de todo o monorepo (e falha
  // de qualquer forma em ambiente não interativo). Restauramos o estado normal
  // (dev+prod) logo em seguida pra não deixar esse efeito colateral vazar pro
  // resto do workspace.
  run("pnpm", ["install"], rootDir);

  const deployedServerTs = path.join(resourcesServerDir, "server.ts");
  if (!fs.existsSync(deployedServerTs)) {
    throw new Error(`pnpm deploy não produziu ${deployedServerTs} — algo mudou na estrutura do pacote @sintonize/web?`);
  }

  log("4/5 bundle do server.ts (Socket.io + signaling) com esbuild -> server.mjs");
  // Formato ESM (não CJS): server.ts tem `await app.prepare()` no
  // top-level, que o esbuild não suporta em saída CJS. @sintonize/web já
  // é "type": "module", então um .mjs roda direto no node.exe sidecar.
  const serverMjs = path.join(resourcesServerDir, "server.mjs");
  await esbuild.build({
    entryPoints: [deployedServerTs],
    outfile: serverMjs,
    bundle: true,
    platform: "node",
    format: "esm",
    target: "node20",
    // "next" fica fora do bundle: o node_modules real gerado pelo `pnpm
    // deploy` já traz o next (e o que ele precisa) — bundlar de novo
    // quebraria (requires dinâmicos/binários internos do Next).
    // bufferutil/utf-8-validate são addons nativos OPCIONAIS do pacote
    // "ws" (dependência do socket.io); não estão instalados no projeto,
    // então precisam ficar external pro esbuild não tentar resolvê-los
    // (o próprio "ws" já trata a ausência deles em try/catch em runtime).
    external: ["next", "bufferutil", "utf-8-validate", "fsevents"],
    logLevel: "info",
    legalComments: "none",
    // socket.io é distribuído em CJS e faz `require("http")` etc. internamente.
    // Bundlado pra ESM, o esbuild reescreve isso com um shim __require que só
    // conhece módulos que ele mesmo bundlou — builtins do Node externos (http,
    // crypto, ...) caem em "Dynamic require of X is not supported" em runtime.
    // Injetando um `require` real (via createRequire) antes do bundle rodar,
    // o esbuild usa esse `require` de verdade em vez do shim sintético.
    banner: {
      js: "import { createRequire as __sintonizeCreateRequire } from 'node:module';\nconst require = __sintonizeCreateRequire(import.meta.url);",
    },
  });
  if (!fs.existsSync(serverMjs)) {
    throw new Error("esbuild não gerou server.mjs — abortando.");
  }

  log("prunando fontes TS/config de dev que não são usadas em runtime");
  for (const rel of PRUNE_AFTER_DEPLOY) {
    fs.rmSync(path.join(resourcesServerDir, rel), { recursive: true, force: true });
  }
  // Sobras do modo hoisted: node_modules/.pnpm só contém um lock.yaml.
  fs.rmSync(path.join(resourcesServerDir, "node_modules", ".pnpm"), {
    recursive: true,
    force: true,
  });
  // Sourcemaps e declarações de tipo dentro de node_modules não são usados
  // em runtime e pesam dezenas de MB (só o pacote next traz milhares).
  const prunedCount = pruneByExtension(path.join(resourcesServerDir, "node_modules"), [
    ".map",
    ".d.ts",
    ".d.mts",
    ".d.cts",
  ]);
  log(`removidos ${prunedCount} arquivos .map/.d.ts de node_modules`);

  log("5/5 copiando node.exe usado para rodar este script como sidecar do Tauri");
  const targetTriple = hostTargetTriple();
  const binariesDir = path.join(srcTauriDir, "binaries");
  fs.mkdirSync(binariesDir, { recursive: true });
  const ext = process.platform === "win32" ? ".exe" : "";
  const sidecarDest = path.join(binariesDir, `node-${targetTriple}${ext}`);
  fs.copyFileSync(process.execPath, sidecarDest);

  const resourcesSize = formatBytes(dirSizeBytes(resourcesServerDir));
  const sidecarSize = formatBytes(fs.statSync(sidecarDest).size);
  log("---");
  log(`server.mjs: ${serverMjs}`);
  log(`resources/server pronto em ${resourcesServerDir} (${resourcesSize})`);
  log(`sidecar node em ${sidecarDest} (${sidecarSize})`);
  log("prepare-bundle concluído.");
}

main().catch((err) => {
  console.error(`[prepare-bundle] ERRO: ${err.message}`);
  process.exit(1);
});
