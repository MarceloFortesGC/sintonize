import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt'),
  ];

  /// Nome do app, exibido na tela inicial do onboarding.
  ///
  /// In pt, this message translates to:
  /// **'Sintonize'**
  String get appName;

  /// Rótulo de acessibilidade do seletor de idioma.
  ///
  /// In pt, this message translates to:
  /// **'Idioma'**
  String get languageLabel;

  /// No description provided for @languagePortuguese.
  ///
  /// In pt, this message translates to:
  /// **'Português'**
  String get languagePortuguese;

  /// No description provided for @languageEnglish.
  ///
  /// In pt, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSpanish.
  ///
  /// In pt, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// No description provided for @welcomeToRoom.
  ///
  /// In pt, this message translates to:
  /// **'Bem-vindo à Sala'**
  String get welcomeToRoom;

  /// No description provided for @enterNameToContinue.
  ///
  /// In pt, this message translates to:
  /// **'Digite seu nome para continuar'**
  String get enterNameToContinue;

  /// No description provided for @nameLabel.
  ///
  /// In pt, this message translates to:
  /// **'Nome'**
  String get nameLabel;

  /// No description provided for @continueButton.
  ///
  /// In pt, this message translates to:
  /// **'Continuar'**
  String get continueButton;

  /// Pergunta na tela de escolha de perfil, com o nome do usuário.
  ///
  /// In pt, this message translates to:
  /// **'Olá, {name}! Como você vai participar da sala?'**
  String greetingHowParticipate(String name);

  /// No description provided for @profileListenerTitle.
  ///
  /// In pt, this message translates to:
  /// **'Ouvinte'**
  String get profileListenerTitle;

  /// No description provided for @profileListenerSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Apenas ouvir'**
  String get profileListenerSubtitle;

  /// No description provided for @profileHostTitle.
  ///
  /// In pt, this message translates to:
  /// **'Host'**
  String get profileHostTitle;

  /// No description provided for @profileHostSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Transmite microfone'**
  String get profileHostSubtitle;

  /// No description provided for @enterRoomButton.
  ///
  /// In pt, this message translates to:
  /// **'Entrar na Sala'**
  String get enterRoomButton;

  /// No description provided for @micAccessTitle.
  ///
  /// In pt, this message translates to:
  /// **'Acesso ao microfone'**
  String get micAccessTitle;

  /// No description provided for @micAccessBody.
  ///
  /// In pt, this message translates to:
  /// **'Para transmitir áudio, precisamos acessar seu microfone.'**
  String get micAccessBody;

  /// No description provided for @cancelButton.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get cancelButton;

  /// No description provided for @allowButton.
  ///
  /// In pt, this message translates to:
  /// **'Permitir'**
  String get allowButton;

  /// No description provided for @activeRoomTitle.
  ///
  /// In pt, this message translates to:
  /// **'Sala Ativa'**
  String get activeRoomTitle;

  /// No description provided for @exitButton.
  ///
  /// In pt, this message translates to:
  /// **'Sair'**
  String get exitButton;

  /// No description provided for @statusConnected.
  ///
  /// In pt, this message translates to:
  /// **'Conectado'**
  String get statusConnected;

  /// No description provided for @statusConnecting.
  ///
  /// In pt, this message translates to:
  /// **'Conectando…'**
  String get statusConnecting;

  /// No description provided for @statusReconnecting.
  ///
  /// In pt, this message translates to:
  /// **'Reconectando…'**
  String get statusReconnecting;

  /// No description provided for @statusLost.
  ///
  /// In pt, this message translates to:
  /// **'Conexão perdida'**
  String get statusLost;

  /// No description provided for @connectionLostCheckNetwork.
  ///
  /// In pt, this message translates to:
  /// **'Conexão perdida. Verifique sua rede.'**
  String get connectionLostCheckNetwork;

  /// No description provided for @apIsolationWarning.
  ///
  /// In pt, this message translates to:
  /// **'Conectado à sala, mas o áudio ainda não chegou. Possíveis causas: firewall do computador transmissor bloqueando a conexão, ou roteador com \"Isolamento de Cliente\" ativado. A conexão continua tentando.'**
  String get apIsolationWarning;

  /// No description provided for @forcedMutedWarning.
  ///
  /// In pt, this message translates to:
  /// **'Seu áudio foi silenciado pelo administrador.'**
  String get forcedMutedWarning;

  /// No description provided for @silentAudioWarning.
  ///
  /// In pt, this message translates to:
  /// **'O som está chegando vazio. Verifique a fonte de áudio na Estação Central.'**
  String get silentAudioWarning;

  /// No description provided for @receivingAudio.
  ///
  /// In pt, this message translates to:
  /// **'Recebendo áudio'**
  String get receivingAudio;

  /// No description provided for @waitingForTransmission.
  ///
  /// In pt, this message translates to:
  /// **'Aguardando transmissão…'**
  String get waitingForTransmission;

  /// Contagem de fontes transmitindo, exibida enquanto a sala ainda não está conectada.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, one{Transmitindo: 1 fonte} other{Transmitindo: {count} fontes}}'**
  String transmittingSources(int count);

  /// No description provided for @volumeLabel.
  ///
  /// In pt, this message translates to:
  /// **'Volume'**
  String get volumeLabel;

  /// No description provided for @retryButton.
  ///
  /// In pt, this message translates to:
  /// **'Tentar novamente'**
  String get retryButton;

  /// No description provided for @leaveRoomTitle.
  ///
  /// In pt, this message translates to:
  /// **'Sair da Sala?'**
  String get leaveRoomTitle;

  /// No description provided for @leaveRoomBody.
  ///
  /// In pt, this message translates to:
  /// **'Isso encerrará sua conexão e apagará seus dados neste dispositivo.'**
  String get leaveRoomBody;

  /// No description provided for @backButton.
  ///
  /// In pt, this message translates to:
  /// **'Voltar'**
  String get backButton;

  /// No description provided for @confirmExitTitle.
  ///
  /// In pt, this message translates to:
  /// **'Tem certeza?'**
  String get confirmExitTitle;

  /// No description provided for @confirmExitBody.
  ///
  /// In pt, this message translates to:
  /// **'Você precisará informar seu nome e perfil novamente na próxima vez.'**
  String get confirmExitBody;

  /// No description provided for @confirmExitButton.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar Saída'**
  String get confirmExitButton;

  /// No description provided for @audioStoppedTitle.
  ///
  /// In pt, this message translates to:
  /// **'O som parou'**
  String get audioStoppedTitle;

  /// No description provided for @audioStoppedBody.
  ///
  /// In pt, this message translates to:
  /// **'Seu fone desconectou? Verifique o fone e toque para continuar.'**
  String get audioStoppedBody;

  /// No description provided for @connectHeadphonesTitle.
  ///
  /// In pt, this message translates to:
  /// **'Conecte seu fone de ouvido'**
  String get connectHeadphonesTitle;

  /// No description provided for @connectHeadphonesBody.
  ///
  /// In pt, this message translates to:
  /// **'Conecte seu fone de ouvido ou aparelho Bluetooth para ouvir com privacidade. O som só começa depois que você tocar no botão abaixo.'**
  String get connectHeadphonesBody;

  /// No description provided for @startListeningButton.
  ///
  /// In pt, this message translates to:
  /// **'✔ Já conectei — começar a ouvir'**
  String get startListeningButton;

  /// No description provided for @tapToListenTitle.
  ///
  /// In pt, this message translates to:
  /// **'Toque para ouvir'**
  String get tapToListenTitle;

  /// No description provided for @tapToListenBody.
  ///
  /// In pt, this message translates to:
  /// **'Chegou um novo áudio. Toque para ouvir.'**
  String get tapToListenBody;

  /// No description provided for @playAudioButton.
  ///
  /// In pt, this message translates to:
  /// **'Tocar áudio'**
  String get playAudioButton;

  /// No description provided for @useHeadphonesTitle.
  ///
  /// In pt, this message translates to:
  /// **'Use fone de ouvido'**
  String get useHeadphonesTitle;

  /// No description provided for @useHeadphonesBody.
  ///
  /// In pt, this message translates to:
  /// **'Conecte um fone de ouvido ou aparelho Bluetooth para ouvir. O som pelo alto-falante foi bloqueado por privacidade.'**
  String get useHeadphonesBody;

  /// No description provided for @headphoneAutoDetectNote.
  ///
  /// In pt, this message translates to:
  /// **'Assim que detectarmos o fone, a tela libera sozinha.'**
  String get headphoneAutoDetectNote;

  /// No description provided for @micBlockedError.
  ///
  /// In pt, this message translates to:
  /// **'Microfone bloqueado. Abra as configurações do navegador para permitir o acesso.'**
  String get micBlockedError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
