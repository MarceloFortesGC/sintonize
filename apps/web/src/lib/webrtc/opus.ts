import { AUDIO_BITRATE_KBPS } from "@sintonize/shared";

/**
 * Ajusta o SDP para otimizar Opus para baixa latência:
 * useinbandfec=1, minptime=10, maxaveragebitrate alvo, DTX desativado.
 */
export function tuneOpusSdp(sdp: string): string {
  const bitrate = AUDIO_BITRATE_KBPS * 1000;
  const lines = sdp.split("\r\n");

  const opusPayload = findOpusPayload(lines);
  if (opusPayload === null) return sdp;

  const fmtpPrefix = `a=fmtp:${opusPayload} `;
  const params = `useinbandfec=1;minptime=10;usedtx=0;maxaveragebitrate=${bitrate}`;

  let replaced = false;
  let fmtpIdx = -1;
  const out = lines.map((line, idx) => {
    if (line.startsWith(fmtpPrefix)) {
      replaced = true;
      fmtpIdx = idx;
      return `${fmtpPrefix}${params}`;
    }
    return line;
  });

  if (!replaced) {
    const rtpmapIdx = out.findIndex((l) =>
      l.startsWith(`a=rtpmap:${opusPayload} `)
    );
    if (rtpmapIdx >= 0) {
      out.splice(rtpmapIdx + 1, 0, `${fmtpPrefix}${params}`);
      fmtpIdx = rtpmapIdx + 1;
    }
  }

  // `minptime=10` no fmtp é só o piso aceito na negociação — não força o
  // encoder a de fato empacotar frames de 10ms. `a=ptime:10` é o atributo
  // que expressa o tamanho de frame desejado para a m-line de áudio.
  const hasPtime = out.some((l) => l.startsWith("a=ptime:"));
  if (!hasPtime && fmtpIdx >= 0) {
    out.splice(fmtpIdx + 1, 0, "a=ptime:10");
  }

  return out.join("\r\n");
}

function findOpusPayload(lines: string[]): string | null {
  for (const line of lines) {
    if (line.startsWith("a=rtpmap:") && /opus\/48000/i.test(line)) {
      const match = line.match(/^a=rtpmap:(\d+)\s/);
      if (match) return match[1];
    }
  }
  return null;
}
