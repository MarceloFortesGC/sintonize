// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Sintonize';

  @override
  String get languageLabel => 'Idioma';

  @override
  String get languagePortuguese => 'Português';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get welcomeToRoom => 'Bienvenido a la Sala';

  @override
  String get enterNameToContinue => 'Escribe tu nombre para continuar';

  @override
  String get nameLabel => 'Nombre';

  @override
  String get continueButton => 'Continuar';

  @override
  String greetingHowParticipate(String name) {
    return '¡Hola, $name! ¿Cómo vas a participar en la sala?';
  }

  @override
  String get profileListenerTitle => 'Oyente';

  @override
  String get profileListenerSubtitle => 'Solo escuchar';

  @override
  String get profileHostTitle => 'Anfitrión';

  @override
  String get profileHostSubtitle => 'Transmite el micrófono';

  @override
  String get enterRoomButton => 'Entrar a la Sala';

  @override
  String get micAccessTitle => 'Acceso al micrófono';

  @override
  String get micAccessBody =>
      'Para transmitir audio, necesitamos acceder a tu micrófono.';

  @override
  String get cancelButton => 'Cancelar';

  @override
  String get allowButton => 'Permitir';

  @override
  String get activeRoomTitle => 'Sala Activa';

  @override
  String get exitButton => 'Salir';

  @override
  String get statusConnected => 'Conectado';

  @override
  String get statusConnecting => 'Conectando…';

  @override
  String get statusReconnecting => 'Reconectando…';

  @override
  String get statusLost => 'Conexión perdida';

  @override
  String get connectionLostCheckNetwork => 'Conexión perdida. Verifica tu red.';

  @override
  String get apIsolationWarning =>
      'Conectado a la sala, pero el audio aún no ha llegado. Posibles causas: un firewall en la computadora transmisora bloqueando la conexión, o un router con \"Aislamiento de Cliente\" activado. La conexión sigue intentando.';

  @override
  String get forcedMutedWarning =>
      'Tu audio fue silenciado por el administrador.';

  @override
  String get silentAudioWarning =>
      'El sonido está llegando vacío. Verifica la fuente de audio en la Estación Central.';

  @override
  String get receivingAudio => 'Recibiendo audio';

  @override
  String get waitingForTransmission => 'Esperando transmisión…';

  @override
  String transmittingSources(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Transmitiendo: $count fuentes',
      one: 'Transmitiendo: 1 fuente',
    );
    return '$_temp0';
  }

  @override
  String get volumeLabel => 'Volumen';

  @override
  String get retryButton => 'Intentar de nuevo';

  @override
  String get leaveRoomTitle => '¿Salir de la Sala?';

  @override
  String get leaveRoomBody =>
      'Esto terminará tu conexión y borrará tus datos en este dispositivo.';

  @override
  String get backButton => 'Volver';

  @override
  String get confirmExitTitle => '¿Estás seguro?';

  @override
  String get confirmExitBody =>
      'Deberás ingresar tu nombre y perfil nuevamente la próxima vez.';

  @override
  String get confirmExitButton => 'Confirmar Salida';

  @override
  String get audioStoppedTitle => 'El sonido se detuvo';

  @override
  String get audioStoppedBody =>
      '¿Se desconectaron tus audífonos? Revísalos y toca para continuar.';

  @override
  String get connectHeadphonesTitle => 'Conecta tus audífonos';

  @override
  String get connectHeadphonesBody =>
      'Conecta tus audífonos o un dispositivo Bluetooth para escuchar con privacidad. El sonido solo comienza después de que toques el botón de abajo.';

  @override
  String get startListeningButton => '✔ Ya conecté — empezar a escuchar';

  @override
  String get tapToListenTitle => 'Toca para escuchar';

  @override
  String get tapToListenBody => 'Llegó un nuevo audio. Toca para escuchar.';

  @override
  String get playAudioButton => 'Reproducir audio';

  @override
  String get useHeadphonesTitle => 'Usa audífonos';

  @override
  String get useHeadphonesBody =>
      'Conecta audífonos o un dispositivo Bluetooth para escuchar. El sonido por el altavoz fue bloqueado por privacidad.';

  @override
  String get headphoneAutoDetectNote =>
      'En cuanto detectemos tus audífonos, la pantalla se libera automáticamente.';

  @override
  String get micBlockedError =>
      'Micrófono bloqueado. Abre la configuración del navegador para permitir el acceso.';
}
