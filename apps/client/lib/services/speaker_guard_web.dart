// Implementação web (compilada apenas quando `dart.library.js_interop`
// existe — ver speaker_guard.dart).
import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Tenta detectar, de forma conservadora, se o áudio provavelmente está
/// saindo pelo alto-falante do aparelho (em vez de fone/Bluetooth).
///
/// LIMITAÇÃO DE PLATAFORMA: a Web API não informa qual saída de áudio está
/// ativa, só a LISTA de saídas disponíveis (`enumerateDevices`), e mesmo
/// essa lista só vem com rótulos legíveis se o usuário já concedeu
/// permissão de microfone. iOS Safari não expõe `audiooutput` de forma
/// utilizável. Por isso a regra é deliberadamente conservadora: só
/// bloqueamos quando dá pra afirmar com confiança (Android Chrome, único
/// dispositivo de saída e o rótulo bate com "alto-falante"). Em qualquer
/// caso de dúvida, permitimos — preferimos não incomodar a bloquear
/// erroneamente quem já está de fone.
class SpeakerGuard {
  JSFunction? _deviceChangeListener;
  Timer? _pollTimer;
  bool _disposed = false;

  bool _looksLikeAndroid() {
    final ua = web.window.navigator.userAgent.toLowerCase();
    return ua.contains('android');
  }

  /// Feature-detect: em origem insegura (http://IP, nosso caso de uso via
  /// QR code na LAN), `navigator.mediaDevices` simplesmente NÃO EXISTE em
  /// Safari (iOS) e é omitido pelo Chrome fora de contexto seguro — a
  /// propriedade volta `undefined`. `Navigator.mediaDevices` no package:web
  /// é tipado como não-nulo (segue a spec), então o getter em si não
  /// quebra; mas qualquer MÉTODO chamado sobre esse valor `undefined`
  /// lança um TypeError de JS não capturado, que sobe e derruba o app
  /// Flutter inteiro (tela branca). Por isso checamos a definição real do
  /// valor JS antes de tocar em qualquer API de mediaDevices.
  bool _mediaDevicesSupported() {
    try {
      final md = web.window.navigator.mediaDevices;
      return (md as JSAny?).isDefinedAndNotNull;
    } catch (_) {
      return false;
    }
  }

  bool _looksLikeSpeakerLabel(String label) {
    final l = label.toLowerCase();
    return l.contains('speaker') ||
        l.contains('alto-falante') ||
        l.contains('altofalante') ||
        l.contains('earpiece');
  }

  bool _looksLikeHeadsetLabel(String label) {
    final l = label.toLowerCase();
    return l.contains('headphone') ||
        l.contains('headset') ||
        l.contains('fone') ||
        l.contains('bluetooth') ||
        l.contains('wired') ||
        l.contains('earbud') ||
        l.contains('airpod');
  }

  /// Retorna `true` só quando há confiança razoável de que o som sairá pelo
  /// alto-falante do aparelho.
  Future<bool> isLikelySpeakerOutput() async {
    if (!_looksLikeAndroid()) return false;
    if (!_mediaDevicesSupported()) return false;

    try {
      final devices =
          (await web.window.navigator.mediaDevices.enumerateDevices().toDart)
              .toDart;
      final outputs =
          devices.where((d) => d.kind == 'audiooutput').toList();
      if (outputs.isEmpty) return false;

      final hasLabels = outputs.any((d) => d.label.isNotEmpty);
      if (!hasLabels) return false; // sem permissão de mic: não dá pra saber

      final hasHeadsetLike =
          outputs.any((d) => _looksLikeHeadsetLabel(d.label));
      if (hasHeadsetLike) return false; // já há fone/bluetooth disponível

      return outputs.length == 1 && _looksLikeSpeakerLabel(outputs.first.label);
    } catch (_) {
      return false; // qualquer erro: permite (conservador)
    }
  }

  /// Observa mudanças de dispositivo de saída (evento `devicechange` +
  /// verificação periódica de segurança a cada 3s) e chama [onChange]
  /// sempre que o resultado da checagem mudar.
  void startWatching(void Function(bool likelySpeaker) onChange) {
    var last = false;
    Future<void> check() async {
      if (_disposed) return;
      final result = await isLikelySpeakerOutput();
      if (_disposed) return;
      if (result != last) {
        last = result;
        onChange(result);
      }
    }

    check();

    // O poll periódico é puro Dart (Timer), sem interop — sempre seguro,
    // continua funcionando mesmo se o listener de `devicechange` abaixo
    // não puder ser registrado (ex.: sem `mediaDevices`).
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => check());

    // A checagem periódica já é 100% defensiva e funciona (retornando
    // false) mesmo sem `mediaDevices`. O `addEventListener('devicechange')`
    // abaixo é só uma otimização (reage mais rápido a troca de fone) —
    // nunca deve ser motivo de crash em origem insegura (ver
    // `_mediaDevicesSupported`).
    if (!_mediaDevicesSupported()) return;

    try {
      // package:web não expõe Streams prontas (diferente do antigo
      // dart:html); usamos addEventListener bruto com uma JSFunction para
      // poder remover no dispose().
      // Corpo em bloco (não `=>`) para que o fechamento retorne `void`
      // explicitamente — `.toJS` rejeita assinaturas que retornem Future.
      final listener = ((web.Event _) {
        check();
      }).toJS;
      _deviceChangeListener = listener;
      web.window.navigator.mediaDevices
          .addEventListener('devicechange', listener);
    } catch (_) {
      // Best-effort: se o interop falhar por qualquer motivo, seguimos só
      // com o poll — nunca derrubamos o app.
    }
  }

  void dispose() {
    _disposed = true;
    final listener = _deviceChangeListener;
    if (listener != null && _mediaDevicesSupported()) {
      try {
        web.window.navigator.mediaDevices
            .removeEventListener('devicechange', listener);
      } catch (_) {
        // Best-effort.
      }
    }
    _deviceChangeListener = null;
    _pollTimer?.cancel();
  }
}
