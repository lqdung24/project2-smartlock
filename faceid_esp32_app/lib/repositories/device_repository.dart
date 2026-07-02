import '../models/device_model.dart';
import '../models/device_log_model.dart';
import '../services/device_service.dart';

class DeviceRepository {
  final DeviceService _deviceService;

  DeviceRepository(this._deviceService);

  Future<List<DeviceModel>> getDevices() {
    return _deviceService.getDevices();
  }

  Future<List<DeviceLog>> getDeviceLogs() {
    return _deviceService.getDeviceLogs();
  }

  Future<String?> registerDevice(String name, String hardwareId, bool resetToken) {
    return _deviceService.registerDevice(name, hardwareId, resetToken);
  }

  Future<void> openDevice(String hardwareId) {
    return _deviceService.openDevice(hardwareId);
  }

  Future<bool> deleteDevice(String hardwareId) {
    return _deviceService.deleteDevice(hardwareId);
  }

  Future<bool> resetDevice(String hardwareId) {
    return _deviceService.resetDevice(hardwareId);
  }
}