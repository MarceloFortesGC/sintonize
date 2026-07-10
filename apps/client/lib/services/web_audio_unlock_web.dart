// Implementação web (compilada apenas quando `dart.library.js_interop`
// existe — ver web_audio_unlock.dart).
import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Desmuta e tenta reproduzir todos os elementos `<audio>`/`<video>` da
/// página, aplicando [volume] (0.0-1.0).
///
/// Por quê isso é necessário: o flutter_webrtc web (ver
/// rtc_video_renderer_impl.dart no pacote) cria o `<audio>` que toca o
/// stream remoto com `muted = (stream.ownerTag == 'local')`. Em
/// webrtc_service.dart, quando o evento `track` chega sem stream associado
/// (comum quando o SDP do transmissor não inclui `a=msid`), o serviço
/// embrulha a faixa com `createLocalMediaStream(...)` — e essa função do
/// dart_webrtc SEMPRE cria o stream com `ownerTag = 'local'`
/// (factory_impl.dart), não importa o rótulo passado. Resultado: o
/// `<audio>` nasce mudo e nada no flutter_webrtc o desmuta depois. Esta
/// função corrige isso na marra, direto no DOM.
///
/// Também serve como "desbloqueio" de autoplay: navegadores podem manter o
/// elemento pausado até haver um gesto real do usuário (especialmente
/// Safari iOS).
///
/// [attemptPlay] controla se `play()` é chamado nos elementos pausados.
/// REGRA DE OURO (bloqueio real de alto-falante, ver room_controller.dart):
/// `play()` só pode ser chamado dentro do gesto de toque do usuário no
/// portão de confirmação — nunca automaticamente (ex.: quando um novo
/// stream remoto chega). Motivo: iOS/Chrome pausam automaticamente o
/// elemento de mídia quando o fone Bluetooth/cabo desconecta (evento
/// `pause` não solicitado); se qualquer código chamasse `play()' fora de
/// um gesto para "consertar" isso, o som voltaria a sair pelo
/// alto-falante do aparelho sem o usuário perceber — exatamente o que
/// este app existe para evitar. Por isso os chamadores fora do gesto
/// devem passar `attemptPlay: false` (padrão): ainda assim desmutamos e
/// ajustamos volume, só não retomamos playback.
///
/// [onUnexpectedPause], quando informado, é anexado (uma única vez por
/// elemento) ao evento `pause` de cada elemento com mídia — usado pelo
/// controller para detectar desconexão de fone em pleno playback.
///
/// Retorna `true` se, após a chamada, algum elemento de mídia com fonte
/// continua pausado (ou seja, precisa de um toque no portão para tocar).
Future<bool> unlockAudioElements(
  double volume, {
  bool attemptPlay = false,
  void Function()? onUnexpectedPause,
}) async {
  final elements = web.document.querySelectorAll('audio, video');
  final clamped = volume.clamp(0.0, 1.0);
  var blocked = false;

  for (var i = 0; i < elements.length; i++) {
    final node = elements.item(i);
    if (node == null || !node.isA<web.HTMLMediaElement>()) continue;
    final media = node as web.HTMLMediaElement;

    // Elementos sem fonte não têm o que tocar. Em áudio-only, o
    // RTCVideoView cria um <video> com srcObject nulo que fica
    // permanentemente pausado (play() rejeita); se ele entrasse na conta,
    // `blocked` ficaria true para sempre e o portão nunca fecharia.
    if (media.srcObject == null) continue;

    try {
      media.muted = false;
      media.volume = clamped;
    } catch (_) {
      // Nunca deixa um elemento de mídia atípico quebrar o app.
    }

    if (onUnexpectedPause != null) {
      _watchForUnexpectedPause(media, onUnexpectedPause);
    }

    if (attemptPlay) {
      try {
        await media.play().toDart;
      } catch (_) {
        // Rejeitado por política de autoplay. O chamador decide o que
        // fazer com o retorno `blocked` (reexibir o portão).
      }
    }

    if (media.paused) blocked = true;
  }

  return blocked;
}

const _watchedAttr = 'data-sintonize-pause-watch';

/// Anexa (uma única vez por elemento — marca via atributo DOM) um listener
/// de `pause` que avisa o chamador quando o elemento para de tocar sem
/// que o app tenha pedido isso. Não distingue a causa aqui (desconexão de
/// fone, `pause()` interno do browser, etc.) — quem decide se é uma
/// interrupção "real" (vs. teardown da sala) é o RoomController.
void _watchForUnexpectedPause(
  web.HTMLMediaElement media,
  void Function() onUnexpectedPause,
) {
  try {
    if (media.hasAttribute(_watchedAttr)) return;
    media.setAttribute(_watchedAttr, '1');
    media.addEventListener(
      'pause',
      ((web.Event _) {
        // A remoção do elemento do DOM (ex.: transmissor saiu da sala e o
        // renderer foi descartado em _syncRenderers) também dispara
        // 'pause' pela spec HTML — isso NÃO é fone desconectando. Fone
        // desconectado pausa o elemento, mas ele continua no documento
        // (isConnected == true); elemento removido tem
        // isConnected == false. Só o primeiro caso é interrupção real.
        if (!media.isConnected) return;
        onUnexpectedPause();
      }).toJS,
    );
  } catch (_) {
    // Best-effort: sem o listener, a detecção de interrupção fica
    // indisponível, mas o app segue funcionando normalmente.
  }
}
