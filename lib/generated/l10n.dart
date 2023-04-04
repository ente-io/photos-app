// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(_current != null,
        'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.');
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(instance != null,
        'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?');
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `Enter your email address`
  String get enterYourEmailAddress {
    return Intl.message(
      'Enter your email address',
      name: 'enterYourEmailAddress',
      desc: '',
      args: [],
    );
  }

  /// `Welcome back!`
  String get accountWelcomeBack {
    return Intl.message(
      'Welcome back!',
      name: 'accountWelcomeBack',
      desc: '',
      args: [],
    );
  }

  /// `Email`
  String get email {
    return Intl.message(
      'Email',
      name: 'email',
      desc: '',
      args: [],
    );
  }

  /// `Cancel`
  String get cancel {
    return Intl.message(
      'Cancel',
      name: 'cancel',
      desc: '',
      args: [],
    );
  }

  /// `Verify`
  String get verify {
    return Intl.message(
      'Verify',
      name: 'verify',
      desc: '',
      args: [],
    );
  }

  /// `Invalid email address`
  String get invalidEmailAddress {
    return Intl.message(
      'Invalid email address',
      name: 'invalidEmailAddress',
      desc: '',
      args: [],
    );
  }

  /// `Please enter a valid email address.`
  String get enterValidEmail {
    return Intl.message(
      'Please enter a valid email address.',
      name: 'enterValidEmail',
      desc: '',
      args: [],
    );
  }

  /// `Delete account`
  String get deleteAccount {
    return Intl.message(
      'Delete account',
      name: 'deleteAccount',
      desc: '',
      args: [],
    );
  }

  /// `What is the main reason you are deleting your account?`
  String get askDeleteReason {
    return Intl.message(
      'What is the main reason you are deleting your account?',
      name: 'askDeleteReason',
      desc: '',
      args: [],
    );
  }

  /// `We are sorry to see you go. Please share your feedback to help us improve.`
  String get deleteAccountFeedbackPrompt {
    return Intl.message(
      'We are sorry to see you go. Please share your feedback to help us improve.',
      name: 'deleteAccountFeedbackPrompt',
      desc: '',
      args: [],
    );
  }

  /// `Feedback`
  String get feedback {
    return Intl.message(
      'Feedback',
      name: 'feedback',
      desc: '',
      args: [],
    );
  }

  /// `Kindly help us with this information`
  String get kindlyHelpUsWithThisInformation {
    return Intl.message(
      'Kindly help us with this information',
      name: 'kindlyHelpUsWithThisInformation',
      desc: '',
      args: [],
    );
  }

  /// `Yes, I want to permanently delete this account and all its data.`
  String get confirmDeletePrompt {
    return Intl.message(
      'Yes, I want to permanently delete this account and all its data.',
      name: 'confirmDeletePrompt',
      desc: '',
      args: [],
    );
  }

  /// `Confirm Account Deletion`
  String get confirmAccountDeletion {
    return Intl.message(
      'Confirm Account Deletion',
      name: 'confirmAccountDeletion',
      desc: '',
      args: [],
    );
  }

  /// `You are about to permanently delete your account and all its data.\nThis action is irreversible.`
  String get deleteConfirmDialogBody {
    return Intl.message(
      'You are about to permanently delete your account and all its data.\nThis action is irreversible.',
      name: 'deleteConfirmDialogBody',
      desc: '',
      args: [],
    );
  }

  /// `Delete Account Permanently`
  String get deleteAccountPermanentlyButton {
    return Intl.message(
      'Delete Account Permanently',
      name: 'deleteAccountPermanentlyButton',
      desc: '',
      args: [],
    );
  }

  /// `Your account has been deleted`
  String get yourAccountHasBeenDeleted {
    return Intl.message(
      'Your account has been deleted',
      name: 'yourAccountHasBeenDeleted',
      desc: '',
      args: [],
    );
  }

  /// `Select reason`
  String get selectReason {
    return Intl.message(
      'Select reason',
      name: 'selectReason',
      desc: '',
      args: [],
    );
  }

  /// `It’s missing a key feature that I need`
  String get deleteReason1 {
    return Intl.message(
      'It’s missing a key feature that I need',
      name: 'deleteReason1',
      desc: '',
      args: [],
    );
  }

  /// `The app or a certain feature does not \nbehave as I think it should`
  String get deleteReason2 {
    return Intl.message(
      'The app or a certain feature does not \nbehave as I think it should',
      name: 'deleteReason2',
      desc: '',
      args: [],
    );
  }

  /// `I found another service that I like better`
  String get deleteReason3 {
    return Intl.message(
      'I found another service that I like better',
      name: 'deleteReason3',
      desc: '',
      args: [],
    );
  }

  /// `My reason isn’t listed`
  String get deleteReason4 {
    return Intl.message(
      'My reason isn’t listed',
      name: 'deleteReason4',
      desc: '',
      args: [],
    );
  }

  /// `Send email`
  String get sendEmail {
    return Intl.message(
      'Send email',
      name: 'sendEmail',
      desc: '',
      args: [],
    );
  }

  /// `Your request will be processed within 72 hours.`
  String get deleteRequestSLAText {
    return Intl.message(
      'Your request will be processed within 72 hours.',
      name: 'deleteRequestSLAText',
      desc: '',
      args: [],
    );
  }

  /// `Please send an email to`
  String get pleaseSendAnEmailTo {
    return Intl.message(
      'Please send an email to',
      name: 'pleaseSendAnEmailTo',
      desc:
          'This text is part of the sentence \'Please send an email to email@ente.io from your registered email address.\'',
      args: [],
    );
  }

  /// `from your registered email address.`
  String get fromYourRegisteredEmailAddress {
    return Intl.message(
      'from your registered email address.',
      name: 'fromYourRegisteredEmailAddress',
      desc:
          'This text is part of the sentence \'Please send an email to email@ente.io from your registered email address.\'',
      args: [],
    );
  }

  /// `Ok`
  String get ok {
    return Intl.message(
      'Ok',
      name: 'ok',
      desc: '',
      args: [],
    );
  }

  /// `Create account`
  String get createAccount {
    return Intl.message(
      'Create account',
      name: 'createAccount',
      desc: '',
      args: [],
    );
  }

  /// `Create new account`
  String get createNewAccount {
    return Intl.message(
      'Create new account',
      name: 'createNewAccount',
      desc: '',
      args: [],
    );
  }

  /// `Password`
  String get password {
    return Intl.message(
      'Password',
      name: 'password',
      desc: '',
      args: [],
    );
  }

  /// `Confirm password`
  String get confirmPassword {
    return Intl.message(
      'Confirm password',
      name: 'confirmPassword',
      desc: '',
      args: [],
    );
  }

  /// `Active sessions`
  String get activeSessions {
    return Intl.message(
      'Active sessions',
      name: 'activeSessions',
      desc: '',
      args: [],
    );
  }

  /// `Oops`
  String get oops {
    return Intl.message(
      'Oops',
      name: 'oops',
      desc: '',
      args: [],
    );
  }

  /// `Something went wrong, please try again`
  String get somethingWentWrongPleaseTryAgain {
    return Intl.message(
      'Something went wrong, please try again',
      name: 'somethingWentWrongPleaseTryAgain',
      desc: '',
      args: [],
    );
  }

  /// `This will log you out of this device!`
  String get thisWillLogYouOutOfThisDevice {
    return Intl.message(
      'This will log you out of this device!',
      name: 'thisWillLogYouOutOfThisDevice',
      desc: '',
      args: [],
    );
  }

  /// `This will log you out of the following device:`
  String get thisWillLogYouOutOfTheFollowingDevice {
    return Intl.message(
      'This will log you out of the following device:',
      name: 'thisWillLogYouOutOfTheFollowingDevice',
      desc: '',
      args: [],
    );
  }

  /// `Terminate session?`
  String get terminateSession {
    return Intl.message(
      'Terminate session?',
      name: 'terminateSession',
      desc: '',
      args: [],
    );
  }

  /// `Terminate`
  String get terminate {
    return Intl.message(
      'Terminate',
      name: 'terminate',
      desc: '',
      args: [],
    );
  }

  /// `This device`
  String get thisDevice {
    return Intl.message(
      'This device',
      name: 'thisDevice',
      desc: '',
      args: [],
    );
  }

  /// `Recover`
  String get recoverButton {
    return Intl.message(
      'Recover',
      name: 'recoverButton',
      desc: '',
      args: [],
    );
  }

  /// `Recovery successful!`
  String get recoverySuccessful {
    return Intl.message(
      'Recovery successful!',
      name: 'recoverySuccessful',
      desc: '',
      args: [],
    );
  }

  /// `Decrypting...`
  String get decrypting {
    return Intl.message(
      'Decrypting...',
      name: 'decrypting',
      desc: '',
      args: [],
    );
  }

  /// `Incorrect recovery key`
  String get incorrectRecoveryKeyTitle {
    return Intl.message(
      'Incorrect recovery key',
      name: 'incorrectRecoveryKeyTitle',
      desc: '',
      args: [],
    );
  }

  /// `The recovery key you entered is incorrect`
  String get incorrectRecoveryKeyBody {
    return Intl.message(
      'The recovery key you entered is incorrect',
      name: 'incorrectRecoveryKeyBody',
      desc: '',
      args: [],
    );
  }

  /// `Forgot password`
  String get forgotPassword {
    return Intl.message(
      'Forgot password',
      name: 'forgotPassword',
      desc: '',
      args: [],
    );
  }

  /// `Enter your recovery key`
  String get enterYourRecoveryKey {
    return Intl.message(
      'Enter your recovery key',
      name: 'enterYourRecoveryKey',
      desc: '',
      args: [],
    );
  }

  /// `No recovery key?`
  String get noRecoveryKey {
    return Intl.message(
      'No recovery key?',
      name: 'noRecoveryKey',
      desc: '',
      args: [],
    );
  }

  /// `Sorry`
  String get sorry {
    return Intl.message(
      'Sorry',
      name: 'sorry',
      desc: '',
      args: [],
    );
  }

  /// `Due to the nature of our end-to-end encryption protocol, your data cannot be decrypted without your password or recovery key`
  String get noRecoveryKeyNoDecryption {
    return Intl.message(
      'Due to the nature of our end-to-end encryption protocol, your data cannot be decrypted without your password or recovery key',
      name: 'noRecoveryKeyNoDecryption',
      desc: '',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
