// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Sintonize';

  @override
  String get languageLabel => 'Language';

  @override
  String get languagePortuguese => 'Português';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get welcomeToRoom => 'Welcome to the Room';

  @override
  String get enterNameToContinue => 'Enter your name to continue';

  @override
  String get nameLabel => 'Name';

  @override
  String get continueButton => 'Continue';

  @override
  String greetingHowParticipate(String name) {
    return 'Hi, $name! How will you join the room?';
  }

  @override
  String get profileListenerTitle => 'Listener';

  @override
  String get profileListenerSubtitle => 'Just listen';

  @override
  String get profileHostTitle => 'Host';

  @override
  String get profileHostSubtitle => 'Broadcasts microphone';

  @override
  String get enterRoomButton => 'Enter Room';

  @override
  String get micAccessTitle => 'Microphone access';

  @override
  String get micAccessBody =>
      'To broadcast audio, we need access to your microphone.';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get allowButton => 'Allow';

  @override
  String get activeRoomTitle => 'Active Room';

  @override
  String get exitButton => 'Leave';

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusConnecting => 'Connecting…';

  @override
  String get statusReconnecting => 'Reconnecting…';

  @override
  String get statusLost => 'Connection lost';

  @override
  String get connectionLostCheckNetwork =>
      'Connection lost. Check your network.';

  @override
  String get apIsolationWarning =>
      'Connected to the room, but the audio hasn\'t arrived yet. Possible causes: a firewall on the broadcasting computer blocking the connection, or a router with \"Client Isolation\" enabled. The connection keeps trying.';

  @override
  String get forcedMutedWarning => 'Your audio was muted by the administrator.';

  @override
  String get silentAudioWarning =>
      'The sound is arriving empty. Check the audio source on the Central Station.';

  @override
  String get receivingAudio => 'Receiving audio';

  @override
  String get waitingForTransmission => 'Waiting for broadcast…';

  @override
  String transmittingSources(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Broadcasting: $count sources',
      one: 'Broadcasting: 1 source',
    );
    return '$_temp0';
  }

  @override
  String get volumeLabel => 'Volume';

  @override
  String get retryButton => 'Try again';

  @override
  String get leaveRoomTitle => 'Leave the Room?';

  @override
  String get leaveRoomBody =>
      'This will end your connection and erase your data on this device.';

  @override
  String get backButton => 'Back';

  @override
  String get confirmExitTitle => 'Are you sure?';

  @override
  String get confirmExitBody =>
      'You will need to enter your name and profile again next time.';

  @override
  String get confirmExitButton => 'Confirm Exit';

  @override
  String get audioStoppedTitle => 'The sound stopped';

  @override
  String get audioStoppedBody =>
      'Did your headphones disconnect? Check them and tap to continue.';

  @override
  String get connectHeadphonesTitle => 'Connect your headphones';

  @override
  String get connectHeadphonesBody =>
      'Connect your headphones or a Bluetooth device to listen privately. The sound only starts after you tap the button below.';

  @override
  String get startListeningButton => '✔ I\'m connected — start listening';

  @override
  String get tapToListenTitle => 'Tap to listen';

  @override
  String get tapToListenBody => 'New audio has arrived. Tap to listen.';

  @override
  String get playAudioButton => 'Play audio';

  @override
  String get useHeadphonesTitle => 'Use headphones';

  @override
  String get useHeadphonesBody =>
      'Connect headphones or a Bluetooth device to listen. Sound through the speaker was blocked for privacy.';

  @override
  String get headphoneAutoDetectNote =>
      'As soon as we detect your headphones, the screen unlocks on its own.';

  @override
  String get micBlockedError =>
      'Microphone blocked. Open your browser settings to allow access.';
}
