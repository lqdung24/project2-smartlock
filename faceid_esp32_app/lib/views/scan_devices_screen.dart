import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_ble/universal_ble.dart';
import '../providers/ble_provider.dart';
import 'wifi_setup_screen.dart'; // Import WifiSetupScreen

class ScanDevicesScreen extends ConsumerStatefulWidget {
  const ScanDevicesScreen({super.key});

  @override
  ConsumerState<ScanDevicesScreen> createState() => _ScanDevicesScreenState();
}

class _ScanDevicesScreenState extends ConsumerState<ScanDevicesScreen> {
  @override
  void initState() {
    super.initState();
    // Start scanning as soon as the screen is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(bleScanProvider.notifier).startScan();
      }
    });
  }

  @override
  void dispose() {
    // Stop scanning when leaving the screen
    ref.read(bleScanProvider.notifier).stopScan();

    // Disconnect from any connected device
    final connectionState = ref.read(bleConnectionProvider);
    if (connectionState.status == ConnectionStatus.connected && connectionState.deviceId != null) {
      ref.read(bleConnectionProvider.notifier).disconnect(connectionState.deviceId!);
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bleScanState = ref.watch(bleScanProvider);
    final bleScanNotifier = ref.read(bleScanProvider.notifier);
    final connectionState = ref.watch(bleConnectionProvider);
    final connectionNotifier = ref.read(bleConnectionProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm thiết bị'),
        actions: [
          if (bleScanState.isScanning)
            TextButton(
              onPressed: bleScanNotifier.stopScan,
              child: const Text('DỪNG'),
            )
          else
            TextButton(
              onPressed: bleScanNotifier.startScan,
              child: const Text('QUÉT LẠI'),
            ),
        ],
      ),
      body: Column(
        children: [
          if (bleScanState.isScanning) const LinearProgressIndicator(),
          if (bleScanState.errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(bleScanState.errorMessage!,
                  style: const TextStyle(color: Colors.red)),
            ),
          // Hiển thị trạng thái kết nối tổng quát
          if (connectionState.status == ConnectionStatus.error)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Lỗi kết nối: ${connectionState.errorMessage}',
                  style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: bleScanState.discoveredDevices.isEmpty && !bleScanState.isScanning
                ? const Center(
                    child: Text('Không tìm thấy thiết bị nào.\nHãy thử quét lại.', textAlign: TextAlign.center))
                : ListView.builder(
                    itemCount: bleScanState.discoveredDevices.length,
                    itemBuilder: (context, index) {
                      final device = bleScanState.discoveredDevices[index];
                      final isThisDeviceConnecting = connectionState.deviceId == device.deviceId && connectionState.status == ConnectionStatus.connecting;
                      final isThisDeviceConnected = connectionState.deviceId == device.deviceId && connectionState.status == ConnectionStatus.connected;

                      return ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(device.name ?? 'Unknown Device'),
                        subtitle: Text(device.deviceId),
                        trailing: ElevatedButton(
                          onPressed: (isThisDeviceConnecting || isThisDeviceConnected) 
                              ? () {
                                  // Nếu đang kết nối hoặc đã kết nối, cho phép ngắt kết nối
                                  connectionNotifier.disconnect(device.deviceId);
                                }
                              : () {
                                  // Dừng quét trước khi chuyển trang
                                  bleScanNotifier.stopScan();
                                  
                                  // Navigate to WifiSetupScreen
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => WifiSetupScreen(deviceId: device.deviceId),
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isThisDeviceConnected ? Colors.green : null,
                          ),
                          child: isThisDeviceConnecting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(isThisDeviceConnected ? 'Ngắt kết nối' : 'Kết nối'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}