import 'avatars.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.email,
    required this.gender,
    required this.avatarId,
    required this.emailVerified,
  });

  final String id;
  final String displayName;
  final String email;
  final String gender;
  final int avatarId;
  final bool emailVerified;

  factory UserProfile.fromJson(Map<String, dynamic> j) {
    final gender = (j['gender'] as String?) ?? Gender.unspecified;
    final avatar = (j['avatarId'] as num?)?.toInt() ?? Avatars.defaultFor(gender);
    return UserProfile(
      id: '${j['id']}',
      displayName: (j['displayName'] as String?) ?? '',
      email: (j['email'] as String?) ?? '',
      gender: gender,
      avatarId: avatar,
      emailVerified: (j['emailVerified'] as bool?) ?? false,
    );
  }
}
