class UserModel {
  final int id;
  final String email;
  final String name;
  final String role; // Thêm trường role

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'] ?? '', // Thêm fallback để tránh lỗi null
      name: json['name'] ?? 'N/A',
      role: json['role'] ?? 'MEMBER', // Mặc định là MEMBER nếu không có
    );
  }
}
