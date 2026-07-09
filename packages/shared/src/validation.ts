import { MAX_NAME_LENGTH } from "./constants.js";
import type { UserProfile } from "./types.js";

const UUID_V4_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function isValidUuidV4(value: unknown): value is string {
  return typeof value === "string" && UUID_V4_REGEX.test(value);
}

export function isValidProfile(value: unknown): value is UserProfile {
  return value === "host" || value === "listener";
}

/**
 * Remove HTML angle brackets/ampersands e limita ao comprimento máximo.
 * Retorna null se o nome ficar vazio após sanitização.
 */
export function sanitizeName(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const cleaned = raw
    .replace(/[<>&]/g, "")
    .trim()
    .slice(0, MAX_NAME_LENGTH);
  return cleaned.length > 0 ? cleaned : null;
}
