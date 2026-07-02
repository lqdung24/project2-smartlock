class FaceModel {
  final int id;
  final String label;
  final String imgUrl;
  final int userId;
  final DateTime createAt;
  final FaceUserModel user;

  FaceModel({
    required this.id,
    required this.label,
    required this.imgUrl,
    required this.userId,
    required this.createAt,
    required this.user,
  });

  factory FaceModel.fromJson(Map<String, dynamic> json) {
    return FaceModel(
      id: json['id'],
      label: json['label'],
      imgUrl: json['img_url'],
      userId: json['userId'],
      createAt: DateTime.parse(json['createAt']),
      user: FaceUserModel.fromJson(json['user']),
    );
  }
}

class FaceUserModel {
  final int id;
  final String name;

  FaceUserModel({
    required this.id,
    required this.name,
  });

  factory FaceUserModel.fromJson(Map<String, dynamic> json) {
    return FaceUserModel(
      id: json['id'],
      name: json['name'],
    );
  }
}