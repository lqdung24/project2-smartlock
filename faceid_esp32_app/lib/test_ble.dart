import 'package:universal_ble/universal_ble.dart';

void main() {
  UniversalBle.onScanResult = (BleDevice result) {
    print(result.deviceId);
    print(result.name);
  };
}
