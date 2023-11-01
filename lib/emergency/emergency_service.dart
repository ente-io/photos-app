import "dart:typed_data";

import "package:dio/dio.dart";
import "package:flutter/cupertino.dart";
import "package:logging/logging.dart";
import "package:photos/core/configuration.dart";
import "package:photos/core/network/network.dart";
import "package:photos/emergency/model.dart";
import "package:photos/generated/l10n.dart";
import "package:photos/services/user_service.dart";
import "package:photos/ui/common/user_dialogs.dart";
import "package:photos/utils/crypto_util.dart";
import "package:photos/utils/dialog_util.dart";
import "package:photos/utils/email_util.dart";

class EmergencyContactService {
  late Dio _enteDio;
  late UserService _userService;

  EmergencyContactService._privateConstructor() {
    _enteDio = NetworkClient.instance.enteDio;
    _userService = UserService.instance;
  }

  static final EmergencyContactService instance =
      EmergencyContactService._privateConstructor();

  Future<bool> addContact(BuildContext context, String email) async {
    if (!isValidEmail(email)) {
      await showErrorDialog(
        context,
        S.of(context).invalidEmailAddress,
        S.of(context).enterValidEmail,
      );
      return false;
    } else if (email.trim() == Configuration.instance.getEmail()) {
      await showErrorDialog(
        context,
        S.of(context).oops,
        S.of(context).youCannotShareWithYourself,
      );
      return false;
    }
    final String? publicKey = await _userService.getPublicKey(email);
    if (publicKey == null) {
      await showInviteDialog(context, email);
      return false;
    }
    final Uint8List recoveryKey = Configuration.instance.getRecoveryKey();
    final encryptedKey = CryptoUtil.sealSync(
      recoveryKey,
      CryptoUtil.base642bin(publicKey),
    );
    await _enteDio.post(
      "/emergency-contacts/add",
      data: {
        "email": email.trim(),
        "encryptedKey": CryptoUtil.bin2base64(encryptedKey),
      },
    );
    return true;
  }

  Future<EmergencyInfo> getInfo() async {
    try {
      final response = await _enteDio.get("/emergency-contacts/info");
      return EmergencyInfo.fromJson(response.data);
    } catch (e, s) {
      Logger("EmergencyContact").severe('failed to get info', e, s);
      rethrow;
    }
  }
}
