// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Kiosk Health';

  @override
  String get welcome => 'Welcome';

  @override
  String get loginPrompt => 'Enter Patient ID';

  @override
  String get loginBtn => 'Login';

  @override
  String get mainMenuTitle => 'Main Menu';

  @override
  String get mainMenuSubtitle => 'What would you like to do today?';

  @override
  String get btnHealthCheck => 'Full Health Check';

  @override
  String get btnHistory => 'View History';

  @override
  String get btnTests => 'Individual Tests';

  @override
  String get btnSpo2 => 'SPO2 Check';

  @override
  String get btnHealthTips => 'Health Tips';

  @override
  String get btnHelp => 'Help & Info';

  @override
  String get btnLogout => 'Log Out';

  @override
  String get stepConsentTitle => 'Data Privacy';

  @override
  String get stepConsentBody => 'We need your permission.';

  @override
  String get btnAgree => 'I Agree, Start';

  @override
  String get btnCancel => 'Cancel';

  @override
  String get scanTitle => 'Measuring Vitals...';

  @override
  String get scanBody => 'Please remain still';

  @override
  String get resultTitle => 'Your Results';

  @override
  String get btnSave => 'Save & Finish';

  @override
  String get adminPinPrompt => 'Enter Admin PIN';

  @override
  String get settingsTitle => 'System Settings';

  @override
  String get kioskAccess => 'Kiosk Access';

  @override
  String get securePatientLogin => 'Secure Patient Login';

  @override
  String get findYourAccount => '1. Find Your Account';

  @override
  String get enterPassword => '2. Enter Password';

  @override
  String get noAccountCreate => 'No Account? Create New Record';

  @override
  String get needAssistance => 'Need Assistance?';

  @override
  String get assistanceMessage =>
      'If you cannot log in or forgot your number, please approach the Barangay Health Worker desk.';

  @override
  String get close => 'Close';

  @override
  String get accessRecord => 'ACCESS RECORD';

  @override
  String get searchName => 'Type Name...';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get incorrectCredentials => 'Incorrect Credentials';

  @override
  String get patientRegistration => 'New Patient Registration';

  @override
  String get patientInfoForm => 'Patient Information Form';

  @override
  String get demographics => 'Demographics';

  @override
  String get contact => 'Contact';

  @override
  String get createPatientRecord => 'Create Patient Record';

  @override
  String get firstName => 'First Name';

  @override
  String get lastName => 'Last Name';

  @override
  String get middleInitial => 'M.I.';

  @override
  String get dateOfBirth => 'Date of Birth';

  @override
  String get gender => 'Gender';

  @override
  String get sitio => 'Sitio (Address)';

  @override
  String get required => 'Required';

  @override
  String get phoneLengthError => 'Must be 11 digits';
}
