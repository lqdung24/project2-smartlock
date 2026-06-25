import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:universal_ble/universal_ble.dart';
import 'package:permission_handler/permission_handler.dart';

// Renamed to AppBleService to avoid name collision with the package's BleService model
class AppBleService {
  StreamController<BleDevice>? _scanController;
  bool _isConnecting = false;

  // --- Scan ---
  Future<bool> checkPermissions() async {
    if (Platform.isAndroid) {
      final statuses = await [
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      bool isGranted = true;
      statuses.forEach((permission, status) {
        if (status != PermissionStatus.granted) {
          isGranted = false;
        }
      });
      return isGranted;
    } else if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      return status == PermissionStatus.granted;
    } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      return true;
    }
    return false;
  }

  Stream<BleDevice> startScan() {
    _scanController = StreamController<BleDevice>.broadcast();

    // Add a check for Bluetooth availability
    UniversalBle.getBluetoothAvailabilityState().then((state) {
      if (state != AvailabilityState.poweredOn) {
        _scanController!.addError(
          'Bluetooth is not available (state: $state). Please ensure it is turned on.',
        );
        return;
      }

      UniversalBle.onScanResult = (result) {
        if (!_scanController!.isClosed) {
          _scanController!.add(result);
        }
      };

      UniversalBle.startScan();
    }).catchError((error) {
      _scanController!.addError('Error checking Bluetooth availability: $error');
    });

    return _scanController!.stream;
  }

  void stopScan() {
    UniversalBle.stopScan();
    _scanController?.close();
  }

  // --- Connection ---
  Future<void> connect(String deviceId) async {
    if (_isConnecting) {
      throw UniversalBleException(
        code: UniversalBleErrorCode.unknownError,
        message: 'Operation already in progress',
      );
    }
    _isConnecting = true;
    try {
      await UniversalBle.connect(deviceId);
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> disconnect(String deviceId) async {
    if (_isConnecting) {
      // Don't throw an error here, just ignore the request
      return;
    }
    _isConnecting = true;
    try {
      await UniversalBle.disconnect(deviceId);
    } finally {
      _isConnecting = false;
    }
  }

  Stream<bool> onConnectionChanged(String deviceId) {
    final controller = StreamController<bool>.broadcast();
    UniversalBle.onConnectionChange = (String device, bool isConnected, String? error) {
      if (device == deviceId) {
        controller.add(isConnected);
      }
    };
    return controller.stream;
  }

  // --- Communication ---
  // Correctly returns a Future<List<BleService>> from the universal_ble package
  Future<List<BleService>> discoverServices(String deviceId) {
    return UniversalBle.discoverServices(deviceId);
  }

  Future<void> write(String deviceId, String service, String characteristic, List<int> value) async {
    await UniversalBle.writeValue(
      deviceId,
      service,
      characteristic,
      Uint8List.fromList(value),
      BleOutputProperty.withResponse,
    );
  }

  Stream<List<int>> onValueChanged(String deviceId, String service, String characteristic) {
    final controller = StreamController<List<int>>.broadcast();
    // Updated callback signature to match the package
    UniversalBle.onValueChange = (String device, String characteristicId, Uint8List value, int? status) {
      if (device == deviceId && characteristicId.toLowerCase() == characteristic.toLowerCase()) {
        controller.add(value);
      }
    };
    // Updated to use the correct BleInputProperty enum
    UniversalBle.setNotifiable(deviceId, service, characteristic, BleInputProperty.notification);
    return controller.stream;
  }
}