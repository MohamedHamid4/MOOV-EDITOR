/// Represents an authenticated user.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.projectsCount = 0,
    this.totalMinutesEdited = 0,
    this.exportsCount = 0,
  });

  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final int projectsCount;
  final int totalMinutesEdited;
  final int exportsCount;

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    int? projectsCount,
    int? totalMinutesEdited,
    int? exportsCount,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      projectsCount: projectsCount ?? this.projectsCount,
      totalMinutesEdited: totalMinutesEdited ?? this.totalMinutesEdited,
      exportsCount: exportsCount ?? this.exportsCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'projectsCount': projectsCount,
        'totalMinutesEdited': totalMinutesEdited,
        'exportsCount': exportsCount,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        uid: json['uid'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String,
        photoUrl: json['photoUrl'] as String?,
        projectsCount: (json['projectsCount'] as int?) ?? 0,
        totalMinutesEdited: (json['totalMinutesEdited'] as int?) ?? 0,
        exportsCount: (json['exportsCount'] as int?) ?? 0,
      );
}
