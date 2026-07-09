// Stub não-web (iOS/Android nativo): sem Web Audio API disponível, então
// não há medição de RMS real. O nível fica sempre em 0 (o widget trata
// nível 0 com stream ativo como "sem dado", não como aviso de silêncio,
// já que no nativo não implementamos a medição ainda).
import 'package:flutter_webrtc/flutter_webrtc.dart' show MediaStream;

class AudioLevelMeter {
  Future<void> start(
    MediaStream stream,
    void Function(double level) onLevel,
  ) async {}

  Future<void> resume() async {}

  Future<void> stop() async {}
}
