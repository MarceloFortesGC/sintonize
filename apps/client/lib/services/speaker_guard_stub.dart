// Stub não-web (iOS/Android nativo): a checagem de saída de áudio é
// exclusiva do fluxo "Ouvinte" no navegador; no app nativo nunca bloqueia.
class SpeakerGuard {
  Future<bool> isLikelySpeakerOutput() async => false;

  void startWatching(void Function(bool likelySpeaker) onChange) {}

  void dispose() {}
}
