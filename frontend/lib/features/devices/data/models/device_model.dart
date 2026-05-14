class DeviceModel {
  final String id;
  final String alexaDeviceId;
  final String deviceNickname;
  final DateTime createdAt;

  DeviceModel({required this.id, required this.alexaDeviceId, required this.deviceNickname, required this.createdAt});

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'],
      alexaDeviceId: json['alexa_device_id'],
      deviceNickname: json['device_nickname'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
