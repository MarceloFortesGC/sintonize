import { fileURLToPath } from "node:url";
import { dirname } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Nota sobre empacotamento (ver apps/desktop/scripts/prepare-bundle.mjs):
  // NÃO usamos output "standalone" aqui. O tracing do Next tenta recriar a
  // estrutura de node_modules do pnpm criando symlinks reais, e isso falha
  // com EPERM em Windows sem Modo de Desenvolvedor/elevação (o node_modules
  // do pnpm normalmente usa junctions, não symlinks, então funciona sem
  // privilégio — mas o "standalone" do Next especificamente cria symlinks).
  // Em vez disso, o instalador usa `pnpm deploy --legacy` (que copia
  // arquivos reais, sem symlinks) para gerar um node_modules autossuficiente.
  transpilePackages: ["@sintonize/shared"],
  outputFileTracingRoot: __dirname,
  webpack: (config) => {
    // Permite imports estilo ESM com extensão .js apontando para fontes .ts.
    config.resolve.extensionAlias = {
      ".js": [".ts", ".tsx", ".js", ".jsx"],
    };
    return config;
  },
};

export default nextConfig;
