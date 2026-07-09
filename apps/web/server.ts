import { createServer } from "node:http";
import { parse } from "node:url";
import next from "next";
import { PORT, ROOM_ID } from "@sintonize/shared";
import { initSignaling, getRoom } from "./src/server/signaling.js";

const dev = process.env.NODE_ENV !== "production";
const hostname = "0.0.0.0";
const port = Number(process.env.PORT) || PORT;
const startedAt = Date.now();

const app = next({ dev, hostname, port });
const handle = app.getRequestHandler();

await app.prepare();

const server = createServer((req, res) => {
  const parsedUrl = parse(req.url ?? "/", true);

  if (parsedUrl.pathname === "/health") {
    const room = getRoom();
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(
      JSON.stringify({
        status: "ok",
        roomId: ROOM_ID,
        participantCount: room.users.size,
        uptime: Math.floor((Date.now() - startedAt) / 1000),
      })
    );
    return;
  }

  handle(req, res, parsedUrl);
});

initSignaling(server);

server.listen(port, hostname, () => {
  console.log(`[sintonize] servidor em http://${hostname}:${port}`);
});
