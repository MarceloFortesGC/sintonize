import { JOIN_RATE_LIMIT, JOIN_RATE_WINDOW_MS } from "@sintonize/shared";

const hits = new Map<string, number[]>();

/**
 * Retorna true se o IP excedeu o limite de join_room na janela de tempo.
 */
export function isJoinRateLimited(ip: string): boolean {
  const now = Date.now();
  const timestamps = (hits.get(ip) ?? []).filter(
    (t) => now - t < JOIN_RATE_WINDOW_MS
  );
  timestamps.push(now);
  hits.set(ip, timestamps);
  return timestamps.length > JOIN_RATE_LIMIT;
}
