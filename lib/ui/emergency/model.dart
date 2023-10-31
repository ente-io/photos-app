import "package:photos/models/api/collection/user.dart";

class EmergencyContact {
  final User user;
  final User emergencyContact;
  final String state;

  EmergencyContact(this.user, this.emergencyContact, this.state);

  // fromJson
  EmergencyContact.fromJson(Map<String, dynamic> json)
      : user = User.fromJson(json['user']),
        emergencyContact = User.fromJson(json['emergencyContact']),
        state = json['state'];

  bool isCurrentUserContact(int userID) {
    return user.id == userID;
  }
}

class EmergencyInfo {
  // List of emergency contacts added by the user
  final List<EmergencyContact> userContacts;

  // List of recovery sessions that are created to recover current user account
  final List<RecoverySessions> userAccountRecoverySessions;

  // List of emergency contacts that have added current user as their emergency contact
  final List<EmergencyContact> grantors;

  // List of recovery sessions that are created to recover grantor's account
  final List<RecoverySessions> grantorAccountRecoverySession;

  EmergencyInfo(
    this.userContacts,
    this.userAccountRecoverySessions,
    this.grantors,
    this.grantorAccountRecoverySession,
  );

  // from json
  EmergencyInfo.fromJson(Map<String, dynamic> json)
      : userContacts = (json['userContacts'] as List)
            .map((contact) => EmergencyContact.fromJson(contact))
            .toList(),
        userAccountRecoverySessions =
            (json['userAccountRecoverySessions'] as List)
                .map((session) => RecoverySessions.fromJson(session))
                .toList(),
        grantors = (json['grantors'] as List)
            .map((grantor) => EmergencyContact.fromJson(grantor))
            .toList(),
        grantorAccountRecoverySession =
            (json['grantorAccountRecoverySession'] as List)
                .map((session) => RecoverySessions.fromJson(session))
                .toList();
}

class RecoverySessions {
  final String id;
  final User user;
  final User emergencyContact;
  final String status;
  final int waitTill;
  final int createdAt;

  RecoverySessions(
    this.id,
    this.user,
    this.emergencyContact,
    this.status,
    this.waitTill,
    this.createdAt,
  );

  // fromJson
  RecoverySessions.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        user = User.fromJson(json['user']),
        emergencyContact = User.fromJson(json['emergencyContact']),
        status = json['status'],
        waitTill = json['waitTill'],
        createdAt = json['createdAt'];
}
