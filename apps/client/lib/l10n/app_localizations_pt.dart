// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

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
  String get welcomeToRoom => 'Bem-vindo à Sala';

  @override
  String get enterNameToContinue => 'Digite seu nome para continuar';

  @override
  String get nameLabel => 'Nome';

  @override
  String get continueButton => 'Continuar';

  @override
  String greetingHowParticipate(String name) {
    return 'Olá, $name! Como você vai participar da sala?';
  }

  @override
  String get profileListenerTitle => 'Ouvinte';

  @override
  String get profileListenerSubtitle => 'Apenas ouvir';

  @override
  String get profileHostTitle => 'Host';

  @override
  String get profileHostSubtitle => 'Transmite microfone';

  @override
  String get enterRoomButton => 'Entrar na Sala';

  @override
  String get micAccessTitle => 'Acesso ao microfone';

  @override
  String get micAccessBody =>
      'Para transmitir áudio, precisamos acessar seu microfone.';

  @override
  String get cancelButton => 'Cancelar';

  @override
  String get allowButton => 'Permitir';

  @override
  String get activeRoomTitle => 'Sala Ativa';

  @override
  String get exitButton => 'Sair';

  @override
  String get statusConnected => 'Conectado';

  @override
  String get statusConnecting => 'Conectando…';

  @override
  String get statusReconnecting => 'Reconectando…';

  @override
  String get statusLost => 'Conexão perdida';

  @override
  String get connectionLostCheckNetwork =>
      'Conexão perdida. Verifique sua rede.';

  @override
  String get apIsolationWarning =>
      'Conectado à sala, mas o áudio ainda não chegou. Possíveis causas: firewall do computador transmissor bloqueando a conexão, ou roteador com \"Isolamento de Cliente\" ativado. A conexão continua tentando.';

  @override
  String get forcedMutedWarning =>
      'Seu áudio foi silenciado pelo administrador.';

  @override
  String get silentAudioWarning =>
      'O som está chegando vazio. Verifique a fonte de áudio na Estação Central.';

  @override
  String get receivingAudio => 'Recebendo áudio';

  @override
  String get waitingForTransmission => 'Aguardando transmissão…';

  @override
  String transmittingSources(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Transmitindo: $count fontes',
      one: 'Transmitindo: 1 fonte',
    );
    return '$_temp0';
  }

  @override
  String get volumeLabel => 'Volume';

  @override
  String get retryButton => 'Tentar novamente';

  @override
  String get leaveRoomTitle => 'Sair da Sala?';

  @override
  String get leaveRoomBody =>
      'Isso encerrará sua conexão e apagará seus dados neste dispositivo.';

  @override
  String get backButton => 'Voltar';

  @override
  String get confirmExitTitle => 'Tem certeza?';

  @override
  String get confirmExitBody =>
      'Você precisará informar seu nome e perfil novamente na próxima vez.';

  @override
  String get confirmExitButton => 'Confirmar Saída';

  @override
  String get audioStoppedTitle => 'O som parou';

  @override
  String get audioStoppedBody =>
      'Seu fone desconectou? Verifique o fone e toque para continuar.';

  @override
  String get connectHeadphonesTitle => 'Conecte seu fone de ouvido';

  @override
  String get connectHeadphonesBody =>
      'Conecte seu fone de ouvido ou aparelho Bluetooth para ouvir com privacidade. O som só começa depois que você tocar no botão abaixo.';

  @override
  String get startListeningButton => '✔ Já conectei — começar a ouvir';

  @override
  String get tapToListenTitle => 'Toque para ouvir';

  @override
  String get tapToListenBody => 'Chegou um novo áudio. Toque para ouvir.';

  @override
  String get playAudioButton => 'Tocar áudio';

  @override
  String get useHeadphonesTitle => 'Use fone de ouvido';

  @override
  String get useHeadphonesBody =>
      'Conecte um fone de ouvido ou aparelho Bluetooth para ouvir. O som pelo alto-falante foi bloqueado por privacidade.';

  @override
  String get headphoneAutoDetectNote =>
      'Assim que detectarmos o fone, a tela libera sozinha.';

  @override
  String get micBlockedError =>
      'Microfone bloqueado. Abra as configurações do navegador para permitir o acesso.';
}
