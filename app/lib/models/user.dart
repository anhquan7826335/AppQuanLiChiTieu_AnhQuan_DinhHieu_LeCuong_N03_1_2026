import 'dart:convert';

class AppUser {
  final String id;
  final String email;
  final String displayName;
  final String passwordHash;
  final String role;           // <-- NEW

  final String? gender;
  final DateTime? birthday;

  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.passwordHash,
    this.gender,
    this.birthday,
    this.role = 'user',        // <-- NEW
  });

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? passwordHash,
    String? gender,
    DateTime? birthday,
    String? role,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      passwordHash: passwordHash ?? this.passwordHash,
      gender: gender ?? this.gender,
      birthday: birthday ?? this.birthday,
      role: role ?? this.role,                     // <-- NEW
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'passwordHash': passwordHash,
    'gender': gender,
    'birthday': birthday?.toIso8601String(),
    'role': role,                               // <-- NEW
  };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    DateTime? dob;
    final rawDob = json['birthday'];
    if (rawDob is String && rawDob.isNotEmpty) {
      try { dob = DateTime.parse(rawDob); } catch (_) {}
    }
    return AppUser(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      displayName: (json['displayName'] ?? json['name'] ?? '').toString(),
      passwordHash: (json['passwordHash'] ?? '').toString(),
      gender: json['gender'] as String?,
      birthday: dob,
      role: (json['role'] ?? 'user').toString(),    // <-- NEW
    );
  }

  static AppUser fromJsonString(String s) =>
      AppUser.fromJson(jsonDecode(s));
  String toJsonString() => jsonEncode(toJson());
}
