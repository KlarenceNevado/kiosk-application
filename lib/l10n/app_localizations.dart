import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fil.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('fil')
  ];

  /// App Title
  ///
  /// In en, this message translates to:
  /// **'Kiosk Health'**
  String get appTitle;

  /// Welcome text
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// Login input hint
  ///
  /// In en, this message translates to:
  /// **'Enter Patient ID'**
  String get loginPrompt;

  /// Login button
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginBtn;

  /// Main menu header
  ///
  /// In en, this message translates to:
  /// **'Main Menu'**
  String get mainMenuTitle;

  /// Main menu subheader
  ///
  /// In en, this message translates to:
  /// **'What would you like to do today?'**
  String get mainMenuSubtitle;

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'Full Health Check'**
  String get btnHealthCheck;

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'View History'**
  String get btnHistory;

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'Individual Tests'**
  String get btnTests;

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'SPO2 Check'**
  String get btnSpo2;

  /// Button text for health education
  ///
  /// In en, this message translates to:
  /// **'Health Tips'**
  String get btnHealthTips;

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'Help & Info'**
  String get btnHelp;

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get btnLogout;

  /// Step title
  ///
  /// In en, this message translates to:
  /// **'Data Privacy'**
  String get stepConsentTitle;

  /// Step body
  ///
  /// In en, this message translates to:
  /// **'We need your permission.'**
  String get stepConsentBody;

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'I Agree, Start'**
  String get btnAgree;

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get btnCancel;

  /// Step title
  ///
  /// In en, this message translates to:
  /// **'Measuring Vitals...'**
  String get scanTitle;

  /// Step body
  ///
  /// In en, this message translates to:
  /// **'Please remain still'**
  String get scanBody;

  /// Step title
  ///
  /// In en, this message translates to:
  /// **'Your Results'**
  String get resultTitle;

  /// Button text
  ///
  /// In en, this message translates to:
  /// **'Save & Finish'**
  String get btnSave;

  /// Admin prompt
  ///
  /// In en, this message translates to:
  /// **'Enter Admin PIN'**
  String get adminPinPrompt;

  /// Settings title
  ///
  /// In en, this message translates to:
  /// **'System Settings'**
  String get settingsTitle;

  /// No description provided for @kioskAccess.
  ///
  /// In en, this message translates to:
  /// **'Kiosk Access'**
  String get kioskAccess;

  /// No description provided for @securePatientLogin.
  ///
  /// In en, this message translates to:
  /// **'Secure Patient Login'**
  String get securePatientLogin;

  /// No description provided for @findYourAccount.
  ///
  /// In en, this message translates to:
  /// **'1. Find Your Account'**
  String get findYourAccount;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'2. Enter Password'**
  String get enterPassword;

  /// No description provided for @noAccountCreate.
  ///
  /// In en, this message translates to:
  /// **'No Account? Create New Record'**
  String get noAccountCreate;

  /// No description provided for @needAssistance.
  ///
  /// In en, this message translates to:
  /// **'Need Assistance?'**
  String get needAssistance;

  /// No description provided for @assistanceMessage.
  ///
  /// In en, this message translates to:
  /// **'If you cannot log in or forgot your number, please approach the Barangay Health Worker desk.'**
  String get assistanceMessage;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @accessRecord.
  ///
  /// In en, this message translates to:
  /// **'ACCESS RECORD'**
  String get accessRecord;

  /// No description provided for @searchName.
  ///
  /// In en, this message translates to:
  /// **'Type Name...'**
  String get searchName;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @incorrectCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect Credentials'**
  String get incorrectCredentials;

  /// No description provided for @patientRegistration.
  ///
  /// In en, this message translates to:
  /// **'New Patient Registration'**
  String get patientRegistration;

  /// No description provided for @patientInfoForm.
  ///
  /// In en, this message translates to:
  /// **'Patient Information Form'**
  String get patientInfoForm;

  /// No description provided for @demographics.
  ///
  /// In en, this message translates to:
  /// **'Demographics'**
  String get demographics;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @createPatientRecord.
  ///
  /// In en, this message translates to:
  /// **'Create Patient Record'**
  String get createPatientRecord;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get lastName;

  /// No description provided for @middleInitial.
  ///
  /// In en, this message translates to:
  /// **'M.I.'**
  String get middleInitial;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dateOfBirth;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @sitio.
  ///
  /// In en, this message translates to:
  /// **'Sitio (Address)'**
  String get sitio;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @phoneLengthError.
  ///
  /// In en, this message translates to:
  /// **'Must be 11 digits'**
  String get phoneLengthError;
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
      <String>['en', 'fil'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fil':
      return AppLocalizationsFil();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
