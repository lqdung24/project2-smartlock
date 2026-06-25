class DeviceModel {
  final int id;
  final String name;
  final String hardwareId;
  final String mqttToken;
  final DateTime tokenExpiry;
  final int houseId;
  final String status;

  DeviceModel({
    required this.id,
    required this.name,
    required this.hardwareId,
    required this.mqttToken,
    required this.tokenExpiry,
    required this.houseId,
    required this.status,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'],
      name: json['name'] ?? 'Thiết bị không tên',
      hardwareId: json['hardwareId'] ?? '',
      mqttToken: json['mqttToken'] ?? '',
      tokenExpiry: json['tokenExpiry'] != null 
          ? DateTime.parse(json['tokenExpiry']) 
          : DateTime.now(),
      houseId: json['houseId'] ?? 0,
      status: json['status'] ?? 'offline',
    );
  }
}