import type { RoomUser } from "@sintonize/shared";
import type { RoomState } from "./room-state.js";

function isTransmitter(user: RoomUser): boolean {
  return user.profile === "host" || user.isDesktopHost === true;
}

/**
 * Um par precisa de conexão WebRTC se ao menos um dos dois é Transmissor.
 * Dois Ouvintes nunca se conectam entre si.
 */
export function pairNeedsConnection(a: RoomUser, b: RoomUser): boolean {
  return isTransmitter(a) || isTransmitter(b);
}

/**
 * Determina qual dos dois usuários cria o offer (iniciador), conforme
 * as regras da spec (api_and_sockets §4.1):
 * - Desktop Host é sempre iniciador.
 * - Transmissor → Ouvinte: o Transmissor inicia.
 * - Transmissor → Transmissor: quem já estava na sala inicia.
 */
export function determineInitiator(
  existing: RoomUser,
  joining: RoomUser
): string {
  if (existing.isDesktopHost) return existing.id;
  if (joining.isDesktopHost) return joining.id;

  const existingTx = existing.profile === "host";
  const joiningTx = joining.profile === "host";

  if (existingTx && !joiningTx) return existing.id;
  if (!existingTx && joiningTx) return joining.id;

  // Ambos Transmissores: o participante existente inicia.
  return existing.id;
}

export interface MeshPair {
  existing: RoomUser;
  joining: RoomUser;
  initiatorId: string;
}

/**
 * Calcula todos os pares Mesh necessários entre o usuário que entrou/reconectou
 * e os demais participantes conectados da sala.
 */
export function computeMeshPairs(
  room: RoomState,
  joiningId: string
): MeshPair[] {
  const joining = room.users.get(joiningId);
  if (!joining) return [];

  const pairs: MeshPair[] = [];
  for (const existing of room.users.values()) {
    if (existing.id === joiningId) continue;
    if (existing.connectionState === "disconnected") continue;
    if (!pairNeedsConnection(existing, joining)) continue;

    pairs.push({
      existing,
      joining,
      initiatorId: determineInitiator(existing, joining),
    });
  }
  return pairs;
}
