// Import condicional: detecção real de saída de áudio na web, stub inócuo
// em builds nativos (iOS/Android), para não quebrar a compilação nativa.
export 'speaker_guard_stub.dart'
    if (dart.library.js_interop) 'speaker_guard_web.dart';
