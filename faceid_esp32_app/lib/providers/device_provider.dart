import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device_model.dart';
import '../models/device_log_model.dart';
import '../repositories/device_repository.dart';
import '../services/device_service.dart';

// 1. Provider cho Repository
final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  return DeviceRepository(DeviceService());
});

// 2. FutureProvider để gọi API và cung cấp danh sách thiết bị
final devicesProvider = FutureProvider.autoDispose<List<DeviceModel>>((ref) {
  final repository = ref.watch(deviceRepositoryProvider);
  return repository.getDevices();
});

// 3. FutureProvider để gọi API và cung cấp danh sách log
final deviceLogProvider = FutureProvider.autoDispose<List<DeviceLog>>((ref) {
  final repository = ref.watch(deviceRepositoryProvider);
  return repository.getDeviceLogs();
});

class DeviceNotifier extends AutoDisposeNotifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncData(null);
  }

  Future<void> deleteDevice(String hardwareId) async {
    state = const AsyncLoading();
    final repository = ref.read(deviceRepositoryProvider);
    final success = await repository.deleteDevice(hardwareId);
    if (success) {
      ref.invalidate(devicesProvider);
      state = const AsyncData(null);
    } else {
      state = AsyncError('Failed to delete device', StackTrace.current);
    }
  }

  Future<void> resetDevice(String hardwareId) async {
    state = const AsyncLoading();
    final repository = ref.read(deviceRepositoryProvider);
    final success = await repository.resetDevice(hardwareId);
    if (success) {
      ref.invalidate(devicesProvider);
      state = const AsyncData(null);
    } else {
      state = AsyncError('Failed to reset device', StackTrace.current);
    }
  }
}

final deviceNotifierProvider = NotifierProvider.autoDispose<DeviceNotifier, AsyncValue<void>>(
  DeviceNotifier.new,
);