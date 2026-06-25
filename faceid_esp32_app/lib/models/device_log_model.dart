import 'device_model.dart';

class DeviceLog {
  final int id;
  final int deviceId;
  final DateTime time;
  final int? userId;
  final String source;
  final dynamic user; // Can be null or a user object
  final DeviceModel device;

  DeviceLog({
    required this.id,
    required this.deviceId,
    required this.time,
    this.userId,
    required this.source,
    this.user,
    required this.device,
  });

  factory DeviceLog.fromJson(Map<String, dynamic> json) {
    return DeviceLog(
      id: json['id'],
      deviceId: json['deviceId'],
      time: DateTime.parse(json['time']).toLocal(),
      userId: json['userId'],
      source: json['source'],
      user: json['user'],
      device: DeviceModel.fromJson(json['device']),
    );
  }
}