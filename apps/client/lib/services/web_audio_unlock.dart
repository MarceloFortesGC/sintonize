// Import condicional: usa a implementação web quando compilado para a web
// (`dart.library.js_interop` só existe em builds web), e um stub inócuo em
// builds nativos (iOS/Android), para não quebrar a compilação nativa.
export 'web_audio_unlock_stub.dart'
    if (dart.library.js_interop) 'web_audio_unlock_web.dart';
