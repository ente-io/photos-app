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
        user = User.fromJson(json['user']),
        emergencyContact = User.fromJson(json['emergencyContact']),
        status = json['status'],
        waitTill = json['waitTill'],
        createdAt = json['createdAt'];
}

// Create Dummy User
User user1 = User(id: 1, email: 'user1@email.com');
User user2 = User(id: 2, email: 'user2@email.com');
User user3 = User(id: 3, email: 'user3@email.com');

// Create Dummy Emergency Contacts
EmergencyContact ec1 = EmergencyContact(user1, user2, 'INVITED');
EmergencyContact ec3 = EmergencyContact(user1, user3, 'ACCEPTED');
EmergencyContact ec2 = EmergencyContact(user2, user1, 'INVITED');
EmergencyContact ec4 = EmergencyContact(user3, user1, 'ACCEPTED');

List<EmergencyContact> userContacts = [ec1, ec3];
List<EmergencyContact> grantors = [ec2, ec4];

// Create Dummy Recovery Sessions
RecoverySessions rs1 =
    RecoverySessions('1', user1, user2, 'Pending', 1000, 500);
RecoverySessions rs2 =
    RecoverySessions('2', user2, user1, 'Pending', 1000, 500);

List<RecoverySessions> userAccountRecoverySessions = [rs1];
List<RecoverySessions> grantorAccountRecoverySession = [rs2];

// Create Dummy EmergencyInfo
EmergencyInfo emergencyInfo = EmergencyInfo(
  userContacts,
  userAccountRecoverySessions,
  grantors,
  grantorAccountRecoverySession,
);
