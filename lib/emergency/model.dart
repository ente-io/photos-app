import "package:photos/models/api/collection/user.dart";

class EmergencyContact {
  final User user;
  final User emergencyContact;
  final String state;

  EmergencyContact(this.user, this.emergencyContact, this.state);

  // fromJson
  EmergencyContact.fromJson(Map<String, dynamic> json)
      : user = User.fromMap(json['user']),
        emergencyContact = User.fromMap(json['emergencyContact']),
        state = json['state'];

  bool isCurrentUserContact(int userID) {
    return user.id == userID;
  }

  bool isPendingInvite() {
    return state == 'INVITED';
  }
}

class EmergencyInfo {
  // List of emergency contacts added by the user
  final List<EmergencyContact> contacts;

  // List of recovery sessions that are created to recover current user account
  final List<RecoverySessions> recoverSessions;

  // List of emergency contacts that have added current user as their emergency contact
  final List<EmergencyContact> othersEmergencyContact;

  // List of recovery sessions that are created to recover grantor's account
  final List<RecoverySessions> othersRecoverySession;

  EmergencyInfo(
    this.contacts,
    this.recoverSessions,
    this.othersEmergencyContact,
    this.othersRecoverySession,
  );

  // from json
  EmergencyInfo.fromJson(Map<String, dynamic> json)
      : contacts = (json['contacts'] as List)
            .map((contact) => EmergencyContact.fromJson(contact))
            .toList(),
        recoverSessions = (json['recoverSessions'] as List)
            .map((session) => RecoverySessions.fromJson(session))
            .toList(),
        othersEmergencyContact = (json['othersEmergencyContact'] as List)
            .map((grantor) => EmergencyContact.fromJson(grantor))
            .toList(),
        othersRecoverySession = (json['othersRecoverySession'] as List)
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
        user = User.fromMap(json['user']),
        emergencyContact = User.fromMap(json['emergencyContact']),
        status = json['status'],
        waitTill = json['waitTill'],
        createdAt = json['createdAt'];
}
