// Stub não-web (iOS/Android nativo): não existem elementos <audio>/<video>
// de DOM para desmutar, então nunca há bloqueio a reportar.
Future<bool> unlockAudioElements(double volume) async => false;
