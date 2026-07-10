// Stub não-web (iOS/Android nativo): não existem elementos <audio>/<video>
// de DOM para desmutar, então nunca há bloqueio a reportar.
Future<bool> unlockAudioElements(
  double volume, {
  bool attemptPlay = false,
  void Function()? onUnexpectedPause,
}) async =>
    false;
