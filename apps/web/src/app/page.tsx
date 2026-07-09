import { redirect } from "next/navigation";
import { existsSync } from "node:fs";
import { join } from "node:path";

export const dynamic = "force-dynamic";

export default function Home() {
  const clientBuilt = existsSync(
    join(process.cwd(), "public", "client", "index.html")
  );

  if (clientBuilt) {
    redirect("/client/index.html");
  }

  return (
    <main
      style={{
        minHeight: "100dvh",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        gap: 16,
        padding: 24,
        textAlign: "center",
      }}
    >
      <h1 style={{ fontSize: 32 }}>Sintonize</h1>
      <p style={{ color: "var(--color-text-muted)", maxWidth: 420 }}>
        O cliente ainda não foi compilado. Execute{" "}
        <span className="mono">pnpm build:client</span> para gerar o app Flutter
        Web, ou rode o cliente em modo de desenvolvimento com{" "}
        <span className="mono">pnpm dev:client</span>.
      </p>
    </main>
  );
}
