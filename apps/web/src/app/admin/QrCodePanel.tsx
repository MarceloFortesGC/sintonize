"use client";

import { useEffect, useState } from "react";
import QRCode from "qrcode";
import { PORT } from "@sintonize/shared";
import styles from "./admin.module.css";

export function QrCodePanel({ localIp }: { localIp: string | null }) {
  const [dataUrl, setDataUrl] = useState<string | null>(null);

  const url = localIp ? `http://${localIp}:${PORT}` : null;

  useEffect(() => {
    if (!url) {
      setDataUrl(null);
      return;
    }
    void QRCode.toDataURL(url, {
      margin: 1,
      width: 220,
      color: { dark: "#0f1419", light: "#ffffff" },
    }).then(setDataUrl);
  }, [url]);

  return (
    <div className={styles.card}>
      <div className={styles.qrWrap}>
        {dataUrl && url ? (
          // QR gerado em memória (data URL); next/image não se aplica aqui.
          // eslint-disable-next-line @next/next/no-img-element -- data URL dinâmico do QRCode
          <img
            className={styles.qrImg}
            src={dataUrl}
            alt={`QR Code para acessar ${url}`}
          />
        ) : (
          <div className={styles.qrPlaceholder}>
            Detectando o endereço da rede local. Verifique se o Desktop Host
            está conectado à rede.
          </div>
        )}
        {url && (
          <span className={`${styles.address} mono`}>{url}</span>
        )}
      </div>
    </div>
  );
}
