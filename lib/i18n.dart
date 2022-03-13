import 'package:i18n_extension/i18n_extension.dart';

extension Localization on String {
  static final _t = Translations("en_us") +
      {
        "en_us": "sign up",
        //Enter locale and translation here
      };
  String get i18n => localize(this, _t);
}
