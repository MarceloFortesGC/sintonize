"use client";

import { useMemo, useState } from "react";
import type { RoomUser } from "@sintonize/shared";
import styles from "./admin.module.css";

interface Props {
  users: RoomUser[];
  onRename: (userId: string, newName: string) => void;
  onMute: (userId: string, muted: boolean) => void;
  onKick: (userId: string) => void;
}

function stateClass(state: RoomUser["connectionState"]): string {
  if (state === "connected") return styles.stateConnected;
  if (state === "reconnecting") return styles.stateReconnecting;
  return styles.stateOther;
}

/**
 * Adiciona sufixo diferenciador para nomes duplicados: "Maria", "Maria (2)"...
 */
function useDisplayNames(users: RoomUser[]): Map<string, string> {
  return useMemo(() => {
    const counts = new Map<string, number>();
    const result = new Map<string, string>();
    for (const u of users) {
      const seen = counts.get(u.name) ?? 0;
      counts.set(u.name, seen + 1);
      result.set(u.id, seen === 0 ? u.name : `${u.name} (${seen + 1})`);
    }
    return result;
  }, [users]);
}

export function DeviceList({ users, onRename, onMute, onKick }: Props) {
  const displayNames = useDisplayNames(users);
  const [openMenu, setOpenMenu] = useState<string | null>(null);
  const [renaming, setRenaming] = useState<RoomUser | null>(null);
  const [renameValue, setRenameValue] = useState("");
  const [kicking, setKicking] = useState<RoomUser | null>(null);

  const visible = users.filter((u) => !u.isDesktopHost);
  const desktopHost = users.find((u) => u.isDesktopHost);

  return (
    <div className={styles.card}>
      <div className={styles.sectionTitle}>
        Dispositivos Conectados ({visible.length})
      </div>

      {desktopHost && (
        <div className={styles.deviceRow}>
          <span
            className={`${styles.stateDot} ${stateClass(
              desktopHost.connectionState
            )}`}
          />
          <span className={styles.deviceName}>{desktopHost.name}</span>
          <span className={`${styles.tag} ${styles.tagHost}`}>Transmissor</span>
        </div>
      )}

      {visible.length === 0 ? (
        <div className={styles.empty}>
          Aguardando participantes. Compartilhe o QR Code.
        </div>
      ) : (
        visible.map((u) => (
          <div key={u.id} className={styles.deviceRow}>
            <span
              className={`${styles.stateDot} ${stateClass(u.connectionState)}`}
              title={u.connectionState}
            />
            <span className={styles.deviceName}>{displayNames.get(u.id)}</span>
            <span
              className={`${styles.tag} ${
                u.profile === "host" ? styles.tagHost : ""
              }`}
            >
              {u.profile === "host" ? "Host" : "Ouvinte"}
            </span>
            {u.muted && <span className={styles.tag}>Silenciado</span>}

            <div className={styles.menu}>
              <button
                type="button"
                className={styles.iconBtn}
                aria-label={`Ações para ${displayNames.get(u.id)}`}
                aria-haspopup="menu"
                aria-expanded={openMenu === u.id}
                onClick={() => setOpenMenu(openMenu === u.id ? null : u.id)}
              >
                &#8943;
              </button>
              {openMenu === u.id && (
                <div className={styles.menuList} role="menu">
                  <button
                    type="button"
                    className={styles.menuItem}
                    role="menuitem"
                    onClick={() => {
                      setRenaming(u);
                      setRenameValue(u.name);
                      setOpenMenu(null);
                    }}
                  >
                    Renomear
                  </button>
                  <button
                    type="button"
                    className={styles.menuItem}
                    role="menuitem"
                    onClick={() => {
                      onMute(u.id, !u.muted);
                      setOpenMenu(null);
                    }}
                  >
                    {u.muted ? "Reativar áudio" : "Silenciar"}
                  </button>
                  <button
                    type="button"
                    className={`${styles.menuItem} ${styles.menuItemDanger}`}
                    role="menuitem"
                    onClick={() => {
                      setKicking(u);
                      setOpenMenu(null);
                    }}
                  >
                    Remover
                  </button>
                </div>
              )}
            </div>
          </div>
        ))
      )}

      {renaming && (
        <div
          className={styles.overlay}
          onClick={() => setRenaming(null)}
          role="presentation"
        >
          <div
            className={styles.modal}
            onClick={(e) => e.stopPropagation()}
            role="dialog"
            aria-modal="true"
            aria-label="Renomear participante"
          >
            <h2 style={{ fontSize: 18 }}>Renomear participante</h2>
            <input
              className={styles.input}
              value={renameValue}
              maxLength={40}
              autoFocus
              aria-label="Novo nome"
              onChange={(e) => setRenameValue(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter" && renameValue.trim()) {
                  onRename(renaming.id, renameValue.trim());
                  setRenaming(null);
                }
              }}
            />
            <div className={styles.modalActions}>
              <button
                type="button"
                className={styles.btn}
                onClick={() => setRenaming(null)}
              >
                Cancelar
              </button>
              <button
                type="button"
                className={`${styles.btn} ${styles.btnPrimary}`}
                disabled={!renameValue.trim()}
                onClick={() => {
                  onRename(renaming.id, renameValue.trim());
                  setRenaming(null);
                }}
              >
                Salvar
              </button>
            </div>
          </div>
        </div>
      )}

      {kicking && (
        <div
          className={styles.overlay}
          onClick={() => setKicking(null)}
          role="presentation"
        >
          <div
            className={styles.modal}
            onClick={(e) => e.stopPropagation()}
            role="dialog"
            aria-modal="true"
            aria-label="Remover participante"
          >
            <h2 style={{ fontSize: 18 }}>Remover {displayNames.get(kicking.id)}?</h2>
            <p style={{ color: "var(--color-text-muted)", marginTop: 8 }}>
              O participante será desconectado da sala e precisará entrar
              novamente.
            </p>
            <div className={styles.modalActions}>
              <button
                type="button"
                className={styles.btn}
                onClick={() => setKicking(null)}
              >
                Cancelar
              </button>
              <button
                type="button"
                className={`${styles.btn} ${styles.btnDanger}`}
                onClick={() => {
                  onKick(kicking.id);
                  setKicking(null);
                }}
              >
                Remover
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
