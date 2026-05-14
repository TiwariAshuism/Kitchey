import 'package:kitzz/core/api/api_client.dart';
import 'package:kitzz/features/devices/data/models/device_model.dart';

class DeviceRepository {
  final ApiClient _apiClient;

  DeviceRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<DeviceModel>> getDevices() async {
    final response = await _apiClient.dio.get('/api/devices');
    final devices = (response.data['devices'] as List? ?? []).map((json) => DeviceModel.fromJson(json)).toList();
    return devices;
  }

  Future<DeviceModel> pairDevice(String alexaDeviceId, String nickname) async {
    final response = await _apiClient.dio.post('/api/devices/pair', data: {'alexa_device_id': alexaDeviceId, 'nickname': nickname});
    return DeviceModel.fromJson(response.data);
  }

  Future<void> unpairDevice(String id) async {
    await _apiClient.dio.delete('/api/devices/$id');
  }
}
