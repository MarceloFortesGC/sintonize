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
/// Safari iOS). Por isso deve ser chamada tanto quando o stream remoto
/// muda quanto dentro de um gesto de toque (botão "Tocar áudio").
///
/// Retorna `true` se, após a tentativa, algum elemento de mídia continua
/// pausado (ou seja, ainda bloqueado por política de autoplay).
Future<bool> unlockAudioElements(double volume) async {
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
    // `blocked` ficaria true para sempre e o overlay "Toque para ouvir"
    // nunca fecharia.
    if (media.srcObject == null) continue;

    media.muted = false;
    media.volume = clamped;

    try {
      await media.play().toDart;
    } catch (_) {
      // Rejeitado por política de autoplay (sem gesto do usuário ainda).
      // O chamador decide o que fazer com o retorno `blocked`.
    }

    if (media.paused) blocked = true;
  }

  return blocked;
}
