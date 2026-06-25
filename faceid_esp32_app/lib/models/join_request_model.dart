class RequestUser {
  final int id;
  final String email;
  final String name;

  RequestUser({
    required this.id,
    required this.email,
    required this.name,
  });

  factory RequestUser.fromJson(Map<String, dynamic> json) {
    return RequestUser(
      id: json['id'],
      email: json['email'] ?? '',
      name: json['name'] ?? '',
    );
  }
}

class JoinRequestModel {
  final int id;
  final String createAt;
  final int requesterId;
  final int ownerId;
  final String status;
  final RequestUser requestUser;

  JoinRequestModel({
    required this.id,
    required this.createAt,
    required this.requesterId,
    required this.ownerId,
    required this.status,
    required this.requestUser,
  });

  factory JoinRequestModel.fromJson(Map<String, dynamic> json) {
    return JoinRequestModel(
      id: json['id'],
      createAt: json['createAt'] ?? '',
      requesterId: json['requesterId'] ?? 0,
      ownerId: json['ownerId'] ?? 0,
      status: json['status'] ?? 'PENDING',
      requestUser: RequestUser.fromJson(json['requestUser'] ?? {}),
    );
  }
}
