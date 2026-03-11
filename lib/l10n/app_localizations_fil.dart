// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Filipino Pilipino (`fil`).
class AppLocalizationsFil extends AppLocalizations {
  AppLocalizationsFil([String locale = 'fil']) : super(locale);

  @override
  String get appTitle => 'Kiosk Kalusugan';

  @override
  String get welcome => 'Mabuhay';

  @override
  String get loginPrompt => 'Ilagay ang Patient ID';

  @override
  String get loginBtn => 'Pumasok';

  @override
  String get mainMenuTitle => 'Pangunahing Menu';

  @override
  String get mainMenuSubtitle => 'Ano ang nais mong gawin?';

  @override
  String get btnHealthCheck => 'Health Check';

  @override
  String get btnHistory => 'Tingnan ang Kasaysayan';

  @override
  String get btnTests => 'Iba pang Pagsusuri';

  @override
  String get btnSpo2 => 'Suriin ang SPO2';

  @override
  String get btnHealthTips => 'Payong Kalusugan';

  @override
  String get btnHelp => 'Tulong at Impormasyon';

  @override
  String get btnLogout => 'Umalis';

  @override
  String get stepConsentTitle => 'Pahintulot sa Datos';

  @override
  String get stepConsentBody => 'Kailangan namin ang iyong pahintulot.';

  @override
  String get btnAgree => 'Sumasang-ayon Ako';

  @override
  String get btnCancel => 'Kanselahin';

  @override
  String get scanTitle => 'Kasalukuyang Sinusukat...';

  @override
  String get scanBody => 'Manatiling nakahinto';

  @override
  String get resultTitle => 'Ang Iyong Resulta';

  @override
  String get btnSave => 'I-save at Tapusin';

  @override
  String get adminPinPrompt => 'Ilagay ang Admin PIN';

  @override
  String get settingsTitle => 'Mga Setting ng System';

  @override
  String get kioskAccess => 'Kiosk Access';

  @override
  String get securePatientLogin => 'Ligtas na Pag-login';

  @override
  String get findYourAccount => '1. Hanapin ang Iyong Account';

  @override
  String get enterPassword => '2. Ilagay ang Password';

  @override
  String get noAccountCreate => 'Walang Account? Gumawa ng Bago';

  @override
  String get needAssistance => 'Kailangan ng Tulong?';

  @override
  String get assistanceMessage =>
      'Kung hindi ka makapag-login o nakalimutan ang numero, lumapit sa Barangay Health Worker desk.';

  @override
  String get close => 'Isara';

  @override
  String get accessRecord => 'BUKSAN ANG REKORD';

  @override
  String get searchName => 'I-type ang Pangalan...';

  @override
  String get phoneNumber => 'Numero ng Telepono';

  @override
  String get incorrectCredentials => 'Maling Impormasyon';

  @override
  String get patientRegistration => 'Pagpaparehistro ng Pasyente';

  @override
  String get patientInfoForm => 'Impormasyon ng Pasyente';

  @override
  String get demographics => 'Demograpiya';

  @override
  String get contact => 'Contact';

  @override
  String get createPatientRecord => 'Gumawa ng Rekord';

  @override
  String get firstName => 'Pangalan';

  @override
  String get lastName => 'Apelyido';

  @override
  String get middleInitial => 'M.I.';

  @override
  String get dateOfBirth => 'Kaarawan';

  @override
  String get gender => 'Kasarian';

  @override
  String get sitio => 'Sitio (Address)';

  @override
  String get required => 'Kailangan';

  @override
  String get phoneLengthError => 'Dapat ay 11 numero';
}
