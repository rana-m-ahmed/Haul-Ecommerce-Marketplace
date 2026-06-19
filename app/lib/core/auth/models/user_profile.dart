import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String? email;
  final String? displayName;
  final bool isGuest;
  final List<String> preferences;
  final bool preferencesCompleted;
  final DateTime createdAt;
  final DateTime lastActiveAt;

  const UserProfile({
    required this.uid,
    this.email,
    this.displayName,
    required this.isGuest,
    required this.preferences,
    required this.preferencesCompleted,
    required this.createdAt,
    required this.lastActiveAt,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
      isGuest: data['isGuest'] as bool? ?? false,
      preferences: (data['preferences'] as List<dynamic>?)?.cast<String>() ?? [],
      preferencesCompleted: data['preferencesCompleted'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActiveAt: (data['lastActiveAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'isGuest': isGuest,
      'preferences': preferences,
      'preferencesCompleted': preferencesCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActiveAt': Timestamp.fromDate(lastActiveAt),
    };
  }
}
