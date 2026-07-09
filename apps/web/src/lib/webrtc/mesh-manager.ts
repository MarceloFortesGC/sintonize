import type { Socket } from "socket.io-client";
import {
  EVENTS,
  ICE_NEGOTIATION_TIMEOUT_MS,
  type WebRTCAnswerPayload,
  type WebRTCIceCandidatePayload,
  type WebRTCOfferPayload,
  type WebRTCPeerClosedPayload,
  type WebRTCPeerRequiredPayload,
} from "@sintonize/shared";
import { tuneOpusSdp } from "./opus.js";

const RTC_CONFIG: RTCConfiguration = {
  iceServers: [],
  bundlePolicy: "max-bundle",
  rtcpMuxPolicy: "require",
};

interface PeerEntry {
  pc: RTCPeerConnection;
  makingOffer: boolean;
  iceTimer: ReturnType<typeof setTimeout> | null;
}

export interface MeshEvents {
  onIceFailed?: (peerId: string) => void;
}

/**
 * Gerencia a malha WebRTC do Desktop Host: mantém uma RTCPeerConnection por
 * peer, injeta o áudio de loopback e negocia via Socket.io.
 * Implementa glare resolution (id lexicográfico menor vence).
 */
export class MeshManager {
  private readonly peers = new Map<string, PeerEntry>();
  private localStream: MediaStream | null = null;

  constructor(
    private readonly socket: Socket,
    private readonly selfId: string,
    private readonly events: MeshEvents = {}
  ) {
    this.registerSocketHandlers();
  }

  setLocalStream(stream: MediaStream): void {
    this.localStream = stream;
    for (const { pc } of this.peers.values()) {
      this.attachTracks(pc);
    }
  }

  private registerSocketHandlers(): void {
    this.socket.on(
      EVENTS.WEBRTC_PEER_REQUIRED,
      (p: WebRTCPeerRequiredPayload) => this.onPeerRequired(p)
    );
    this.socket.on(EVENTS.WEBRTC_OFFER, (p: WebRTCOfferPayload) =>
      this.onOffer(p)
    );
    this.socket.on(EVENTS.WEBRTC_ANSWER, (p: WebRTCAnswerPayload) =>
      this.onAnswer(p)
    );
    this.socket.on(
      EVENTS.WEBRTC_ICE_CANDIDATE,
      (p: WebRTCIceCandidatePayload) => this.onIceCandidate(p)
    );
    this.socket.on(EVENTS.WEBRTC_PEER_CLOSED, (p: WebRTCPeerClosedPayload) =>
      this.closePeer(p.peerId)
    );
  }

  private ensurePeer(peerId: string): PeerEntry {
    const existing = this.peers.get(peerId);
    if (existing) return existing;

    const pc = new RTCPeerConnection(RTC_CONFIG);
    const entry: PeerEntry = { pc, makingOffer: false, iceTimer: null };

    this.attachTracks(pc);

    pc.onicecandidate = ({ candidate }) => {
      if (candidate) {
        this.socket.emit(EVENTS.WEBRTC_ICE_CANDIDATE, {
          from: this.selfId,
          to: peerId,
          candidate: candidate.toJSON(),
        });
      }
    };

    pc.oniceconnectionstatechange = () => {
      const state = pc.iceConnectionState;
      if (state === "connected" || state === "completed") {
        this.clearIceTimer(entry);
      } else if (state === "failed") {
        this.clearIceTimer(entry);
        this.events.onIceFailed?.(peerId);
        pc.restartIce();
      }
    };

    entry.iceTimer = setTimeout(() => {
      if (
        pc.iceConnectionState !== "connected" &&
        pc.iceConnectionState !== "completed"
      ) {
        this.events.onIceFailed?.(peerId);
      }
    }, ICE_NEGOTIATION_TIMEOUT_MS);

    this.peers.set(peerId, entry);
    return entry;
  }

  private attachTracks(pc: RTCPeerConnection): void {
    if (!this.localStream) return;
    const senders = pc.getSenders();
    for (const track of this.localStream.getAudioTracks()) {
      const alreadyAttached = senders.some((s) => s.track === track);
      if (!alreadyAttached) {
        pc.addTrack(track, this.localStream);
      }
    }
  }

  private async onPeerRequired(p: WebRTCPeerRequiredPayload): Promise<void> {
    const entry = this.ensurePeer(p.peerId);
    if (!p.initiator) return;
    await this.makeOffer(p.peerId, entry);
  }

  private async makeOffer(peerId: string, entry: PeerEntry): Promise<void> {
    try {
      entry.makingOffer = true;
      const offer = await entry.pc.createOffer();
      offer.sdp = offer.sdp ? tuneOpusSdp(offer.sdp) : offer.sdp;
      await entry.pc.setLocalDescription(offer);
      this.socket.emit(EVENTS.WEBRTC_OFFER, {
        from: this.selfId,
        to: peerId,
        sdp: entry.pc.localDescription,
      });
    } catch (err) {
      console.error("[mesh] erro ao criar offer", err);
    } finally {
      entry.makingOffer = false;
    }
  }

  private async onOffer(p: WebRTCOfferPayload): Promise<void> {
    if (p.to !== this.selfId) return;
    const entry = this.ensurePeer(p.from);
    const { pc } = entry;

    const offerCollision =
      entry.makingOffer || pc.signalingState !== "stable";
    // Glare: o id menor é o "polite" e cede; o maior ignora o offer conflitante.
    const polite = this.selfId < p.from;
    if (offerCollision && !polite) return;

    try {
      await pc.setRemoteDescription(p.sdp);
      const answer = await pc.createAnswer();
      answer.sdp = answer.sdp ? tuneOpusSdp(answer.sdp) : answer.sdp;
      await pc.setLocalDescription(answer);
      this.socket.emit(EVENTS.WEBRTC_ANSWER, {
        from: this.selfId,
        to: p.from,
        sdp: pc.localDescription,
      });
    } catch (err) {
      console.error("[mesh] erro ao responder offer", err);
    }
  }

  private async onAnswer(p: WebRTCAnswerPayload): Promise<void> {
    if (p.to !== this.selfId) return;
    const entry = this.peers.get(p.from);
    if (!entry) return;
    try {
      await entry.pc.setRemoteDescription(p.sdp);
    } catch (err) {
      console.error("[mesh] erro ao aplicar answer", err);
    }
  }

  private async onIceCandidate(p: WebRTCIceCandidatePayload): Promise<void> {
    if (p.to !== this.selfId) return;
    const entry = this.peers.get(p.from);
    if (!entry) return;
    try {
      await entry.pc.addIceCandidate(p.candidate);
    } catch (err) {
      console.error("[mesh] erro ao adicionar ICE candidate", err);
    }
  }

  private clearIceTimer(entry: PeerEntry): void {
    if (entry.iceTimer) {
      clearTimeout(entry.iceTimer);
      entry.iceTimer = null;
    }
  }

  closePeer(peerId: string): void {
    const entry = this.peers.get(peerId);
    if (!entry) return;
    this.clearIceTimer(entry);
    entry.pc.close();
    this.peers.delete(peerId);
  }

  destroy(): void {
    for (const peerId of [...this.peers.keys()]) {
      this.closePeer(peerId);
    }
  }
}
