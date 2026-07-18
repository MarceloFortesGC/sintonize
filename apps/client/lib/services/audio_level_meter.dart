// Import condicional: implementação real via Web Audio API na web, stub
// inócuo em builds nativos (iOS/Android), para não quebrar a compilação
// nativa.
export 'audio_level_meter_stub.dart'
    if (dart.library.js_interop) 'audio_level_meter_web.dart';
