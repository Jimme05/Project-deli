class UserResponse {
  final String uid;
  final String phone;
  final String name;
  final String role;       // 'user' | 'rider'
  final String? photoUrl;

  UserResponse({
    required this.uid,
    required this.phone,
    required this.name,
    required this.role,
    this.photoUrl,
  });

  factory UserResponse.fromFirestore(String uid, Map<String, dynamic> data) {
    return UserResponse(
      uid: uid,
      phone: data['phone'] ?? '',
      name: data['name'] ?? '',
      role: data['role'] ?? 'user',
      photoUrl: data['photoUrl'],
    );
  }
}

class AuthResult {
  final bool success;
  final String? message;
  final UserResponse? user;
  AuthResult({required this.success, this.message, this.user});
}
