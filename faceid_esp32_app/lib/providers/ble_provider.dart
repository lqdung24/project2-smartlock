import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_ble/universal_ble.dart' hide BleService, BleConnectionState;
import '../services/ble_service.dart';

// --- Service Provider ---
final bleServiceProvider = Provider((ref) => AppBleService());

// --- Scan Notifier ---
class BleScanState {
  final List<BleDevice> discoveredDevices;
  final bool isScanning;
  final String? errorMessage;

  BleScanState({
    this.discoveredDevices = const [],
    this.isScanning = false,
    this.errorMessage,
  });

  BleScanState copyWith({
    List<BleDevice>? discoveredDevices,
    bool? isScanning,
    String? errorMessage,
  }) {
    return BleScanState(
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      isScanning: isScanning ?? this.isScanning,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class BleScanNotifier extends AutoDisposeNotifier<BleScanState> {
  late final AppBleService _bleService;
  StreamSubscription<BleDevice>? _scanSubscription;

  @override
  BleScanState build() {
    _bleService = ref.read(bleServiceProvider);
    ref.onDispose(() {
      _scanSubscription?.cancel();
      _bleService.stopScan();
    });
    return BleScanState();
  }

  Future<void> startScan() async {
    final hasPermission = await _bleService.checkPermissions();
    if (!hasPermission) {
      state = state.copyWith(errorMessage: 'Vui lòng cấp quyền Bluetooth và Vị trí để tìm thiết bị.');
      return;
    }
    state = state.copyWith(isScanning: true, discoveredDevices: [], errorMessage: null);
    _scanSubscription?.cancel();
    _scanSubscription = _bleService.startScan().listen((device) {
      if (device.name != null && device.name!.isNotEmpty) {
        final newList = List<BleDevice>.from(state.discoveredDevices);
        final existingIndex = newList.indexWhere((d) => d.deviceId == device.deviceId);
        if (existingIndex != -1) {
          newList[existingIndex] = device;
        } else {
          newList.add(device);
        }
        state = state.copyWith(discoveredDevices: newList);
      }
    }, onError: (error) {
      state = state.copyWith(isScanning: false, errorMessage: error.toString());
    });
  }

  void stopScan() {
    _scanSubscription?.cancel();
    _bleService.stopScan();
    state = state.copyWith(isScanning: false);
  }
}

final bleScanProvider = NotifierProvider.autoDispose<BleScanNotifier, BleScanState>(BleScanNotifier.new);

// --- Connection Notifier ---
enum ConnectionStatus { disconnected, connecting, connected, error }

class BleAppConnectionState {
  final ConnectionStatus status;
  final String? deviceId;
  final String? errorMessage;

  BleAppConnectionState({
    this.status = ConnectionStatus.disconnected,
    this.deviceId,
    this.errorMessage,
  });

  BleAppConnectionState copyWith({
    ConnectionStatus? status,
    String? deviceId,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BleAppConnectionState(
      status: status ?? this.status,
      deviceId: deviceId ?? this.deviceId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class BleConnectionNotifier extends StateNotifier<BleAppConnectionState> {
  final Ref _ref;
  late final AppBleService _bleService;
  StreamSubscription<bool>? _connectionSubscription;
  bool _isBusy = false;

  BleConnectionNotifier(this._ref) : super(BleAppConnectionState()) {
    _bleService = _ref.read(bleServiceProvider);
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    final device = state.deviceId;
    if (device != null) {
      if (kDebugMode) {
        print('Auto-disposing and disconnecting from $device');
      }
      _bleService.disconnect(device);
    }
    super.dispose();
  }

  Future<void> connect(String deviceId) async {
    if (_isBusy) return;
    _isBusy = true;

    if (!mounted) return;
    state = state.copyWith(status: ConnectionStatus.connecting, deviceId: deviceId, clearError: true);

    try {
      _connectionSubscription?.cancel();
      _connectionSubscription = _bleService.onConnectionChanged(deviceId).listen((isConnected) {
        if (!mounted) return;
        if (isConnected) {
          if (state.status != ConnectionStatus.connected) {
            state = state.copyWith(status: ConnectionStatus.connected, deviceId: deviceId);
          }
        } else {
          if (state.deviceId == deviceId) {
            state = state.copyWith(status: ConnectionStatus.disconnected, deviceId: null, errorMessage: 'Thiết bị đã ngắt kết nối.');
          }
        }
      });

      await _bleService.connect(deviceId).timeout(const Duration(seconds: 10));

    } on TimeoutException {
      if (!mounted) return;
      state = state.copyWith(status: ConnectionStatus.error, deviceId: null, errorMessage: 'Kết nối quá hạn. Vui lòng thử lại.');
      _connectionSubscription?.cancel();
    } catch (e) {
      if (kDebugMode) print("Connection error: $e");
      if (!mounted) return;
      state = state.copyWith(status: ConnectionStatus.error, deviceId: null, errorMessage: 'Không thể kết nối. Hãy chắc chắn thiết bị đang ở gần.');
      _connectionSubscription?.cancel();
    } finally {
      _isBusy = false;
    }
  }

  Future<void> disconnect(String deviceId) async {
    if (_isBusy) return;
    _isBusy = true;

    try {
      await _connectionSubscription?.cancel();
      _connectionSubscription = null;
      await _bleService.disconnect(deviceId);
    } catch (e) {
      if (kDebugMode) print("Disconnect error: $e");
    } finally {
      if (mounted) {
        state = BleAppConnectionState(); // Reset to initial state
      }
      _isBusy = false;
    }
  }

  void resetState() {
    if (mounted) {
      state = BleAppConnectionState();
    }
  }
}

final bleConnectionProvider = StateNotifierProvider.autoDispose<BleConnectionNotifier, BleAppConnectionState>(
  (ref) => BleConnectionNotifier(ref),
);