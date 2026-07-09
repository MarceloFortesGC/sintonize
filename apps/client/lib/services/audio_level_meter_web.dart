// Implementação web (compilada apenas quando `dart.library.js_interop`
// existe — ver audio_level_meter.dart).
import 'dart:async';
import 'dart:js_interop';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_webrtc/dart_webrtc.dart' show MediaStreamWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart' show MediaStream;
import 'package:web/web.dart' as web;

/// Mede o nível de áudio REAL (RMS) de um [MediaStream] remoto usando a Web
/// Audio API (AudioContext + AnalyserNode). É o único jeito confiável de
/// saber se está chegando som de verdade — o estado da RTCPeerConnection
/// diz "conectado", mas não diz se há amplitude no áudio.
class AudioLevelMeter {
  web.AudioContext? _ctx;
  web.MediaStreamAudioSourceNode? _source;
  web.AnalyserNode? _analyser;
  Timer? _timer;
  Uint8List? _buffer;

  /// Começa a medir [stream] e chama [onLevel] a cada ~120ms com um valor
  /// 0.0-1.0 representando o volume RMS instantâneo.
  Future<void> start(
    MediaStream stream,
    void Function(double level) onLevel,
  ) async {
    await stop();

    // `MediaStreamWeb.jsStream` expõe o MediaStream real do navegador
    // (dart_webrtc), necessário para o Web Audio API. Streams sem faixa de
    // áudio (ex.: vazios) não têm o que medir.
    if (stream is! MediaStreamWeb) return;
    final jsStream = stream.jsStream;
    if (jsStream.getAudioTracks().toDart.isEmpty) return;

    try {
      final ctx = web.AudioContext();
      // AudioContext pode nascer 'suspended' sem gesto do usuário recente.
      // resume() é seguro chamar sempre (não faz nada se já estiver ativo).
      try {
        await ctx.resume().toDart;
      } catch (_) {
        // Segue mesmo suspenso: será retomado no gesto do botão "Tocar áudio".
      }

      final analyser = ctx.createAnalyser()..fftSize = 512;
      final source = ctx.createMediaStreamSource(jsStream);
      source.connect(analyser);

      _ctx = ctx;
      _source = source;
      _analyser = analyser;
      _buffer = Uint8List(analyser.fftSize);

      _timer = Timer.periodic(const Duration(milliseconds: 120), (_) {
        _tick(onLevel);
      });
    } catch (_) {
      // Web Audio pode falhar em navegadores/contextos restritos; nesse
      // caso o indicador fica sem dado real (tratado como nível 0 no widget).
      await stop();
    }
  }

  void _tick(void Function(double) onLevel) {
    final analyser = _analyser;
    final buffer = _buffer;
    if (analyser == null || buffer == null) return;

    analyser.getByteTimeDomainData(buffer.toJS);

    var sumSquares = 0.0;
    for (final byte in buffer) {
      final v = (byte - 128) / 128.0;
      sumSquares += v * v;
    }
    final rms = sqrt(sumSquares / buffer.length);
    onLevel(rms.clamp(0.0, 1.0));
  }

  /// Retoma o AudioContext caso tenha ficado suspenso por política de
  /// autoplay. Chamar dentro de um gesto real do usuário (botão "Tocar
  /// áudio").
  Future<void> resume() async {
    try {
      await _ctx?.resume().toDart;
    } catch (_) {
      /* melhor esforço */
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    try {
      _source?.disconnect();
    } catch (_) {}
    try {
      await _ctx?.close().toDart;
    } catch (_) {}
    _ctx = null;
    _source = null;
    _analyser = null;
    _buffer = null;
  }
}
