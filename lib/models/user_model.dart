import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { user, admin }

enum UserStatus { active, suspended, banned }

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoURL;
  final UserRole role;
  final UserStatus status;
  final DateTime createdAt;
  final DateTime? suspendedUntil;
  final String? suspensionReason;
  final int reportCount;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoURL,
    this.role = UserRole.user,
    this.status = UserStatus.active,
    required this.createdAt,
    this.suspendedUntil,
    this.suspensionReason,
    this.reportCount = 0,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoURL: data['photoURL'],
      role: UserRole.values.firstWhere(
        (r) => r.name == data['role'],
        orElse: () => UserRole.user,
      ),
      status: UserStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => UserStatus.active,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      suspendedUntil: data['suspendedUntil'] != null
          ? (data['suspendedUntil'] as Timestamp).toDate()
          : null,
      suspensionReason: data['suspensionReason'],
      reportCount: data['reportCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'role': role.name,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'suspendedUntil': suspendedUntil != null
          ? Timestamp.fromDate(suspendedUntil!)
          : null,
      'suspensionReason': suspensionReason,
      'reportCount': reportCount,
    };
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isSuspended => status == UserStatus.suspended && 
      (suspendedUntil?.isAfter(DateTime.now()) ?? false);
  bool get isBanned => status == UserStatus.banned;
  bool get canPost => status == UserStatus.active;
}