import 'dart:convert';
import 'package:faceid_esp32_app/config.dart';
import 'package:faceid_esp32_app/providers/ble_provider.dart';
import 'package:faceid_esp32_app/providers/device_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ble_service.dart';

const String wifiServiceUuid = "180A";
const String wifiCharacteristicUuid = "2A57";

enum WifiSetupStep {
  initializing,
  discoveringServices,
  enterCredentials,
  sendingCredentials,
  error,
}

class WifiSetupStepNotifier extends Notifier<WifiSetupStep> {
  @override
  WifiSetupStep build() {
    return WifiSetupStep.initializing;
  }

  void setStep(WifiSetupStep step) {
    state = step;
  }
}

final wifiSetupStepProvider = NotifierProvider<WifiSetupStepNotifier, WifiSetupStep>(WifiSetupStepNotifier.new);

final bleServiceProvider = Provider((ref) => AppBleService());

class WifiSetupScreen extends ConsumerStatefulWidget {
  final String deviceId;

  const WifiSetupScreen({super.key, required this.deviceId});

  @override
  ConsumerState<WifiSetupScreen> createState() => _WifiSetupScreenState();
}

class _WifiSetupScreenState extends ConsumerState<WifiSetupScreen> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _deviceNameController = TextEditingController();
  bool _resetToken = false;
  bool _isLogicInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(bleConnectionProvider.notifier).connect(widget.deviceId);
      }
    });
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  Future<void> _initializeLogic() async {
    if (_isLogicInitialized) return;
    _isLogicInitialized = true;

    final bleService = ref.read(bleServiceProvider);
    final stepNotifier = ref.read(wifiSetupStepProvider.notifier);

    try {
      stepNotifier.setStep(WifiSetupStep.discoveringServices);
      await bleService.discoverServices(widget.deviceId);
      stepNotifier.setStep(WifiSetupStep.enterCredentials);
    } catch (e) {
      if (kDebugMode) print('Error during service discovery: $e');
      stepNotifier.setStep(WifiSetupStep.error);
    }
  }

  Future<void> _sendCredentials() async {
    if (!mounted) return;

    final stepNotifier = ref.read(wifiSetupStepProvider.notifier);
    final ssid = _ssidController.text;
    final password = _passwordController.text;
    final deviceName = _deviceNameController.text;

    if (ssid.isNotEmpty && deviceName.isNotEmpty) {
      stepNotifier.setStep(WifiSetupStep.sendingCredentials);
      try {
        // 1. Register device and get provisionToken
        final provisionToken = await ref.read(deviceRepositoryProvider).registerDevice(deviceName, widget.deviceId, _resetToken);

        if (provisionToken == null) {
          throw Exception('Không nhận được provision token.');
        }

        // 2. Send credentials and token to ESP32
        final bleService = ref.read(bleServiceProvider);
        final serverIp = AppConfig.serverIpPublic;
        final serverPort = AppConfig.serverPort;
        final command = 'device_name=$deviceName;wifi_ssid=$ssid;wifi_pass=$password;server_host=$serverIp;server_port=$serverPort;provision_token=$provisionToken;';
        
        await bleService.write(
          widget.deviceId,
          wifiServiceUuid,
          wifiCharacteristicUuid,
          utf8.encode(command),
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi thông tin và đăng ký thiết bị thành công.'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pop();

      } catch (e) {
        if (kDebugMode) print('Error sending credentials or registering device: $e');
        stepNotifier.setStep(WifiSetupStep.error);
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền tên thiết bị và tên Wi-Fi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<BleAppConnectionState>(bleConnectionProvider, (previous, next) {
      if (next.status == ConnectionStatus.connected && !_isLogicInitialized) {
        _initializeLogic();
      }
      if (previous?.status == ConnectionStatus.connected && next.status == ConnectionStatus.disconnected) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    });

    final connectionState = ref.watch(bleConnectionProvider);
    final currentStep = ref.watch(wifiSetupStepProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt Wi-Fi')),
      body: Center(
        child: _buildContent(context, connectionState, currentStep),
      ),
    );
  }

  Widget _buildContent(BuildContext context, BleAppConnectionState connState, WifiSetupStep step) {
    if (connState.status == ConnectionStatus.error) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 50),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              connState.errorMessage ?? 'Đã xảy ra lỗi không xác định.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              ref.read(wifiSetupStepProvider.notifier).setStep(WifiSetupStep.initializing);
              _isLogicInitialized = false;
              ref.read(bleConnectionProvider.notifier).connect(widget.deviceId);
            },
            child: const Text('Thử lại'),
          )
        ],
      );
    }

    switch (connState.status) {
      case ConnectionStatus.connecting:
        return const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Đang kết nối...')],
        );
      case ConnectionStatus.connected:
        switch (step) {
          case WifiSetupStep.initializing:
          case WifiSetupStep.discoveringServices:
            return const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Đang tìm kiếm dịch vụ...')],
            );
          case WifiSetupStep.enterCredentials:
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextField(
                    controller: _deviceNameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên thiết bị',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _ssidController,
                    decoration: const InputDecoration(
                      labelText: 'Tên Wi-Fi (SSID)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text("Reset Token"),
                    value: _resetToken,
                    onChanged: (newValue) {
                      setState(() {
                        _resetToken = newValue ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: _sendCredentials,
                    child: const Text('Gửi đến ESP32 và Đăng ký'),
                  ),
                ],
              ),
            );
          case WifiSetupStep.sendingCredentials:
            return const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Đang đăng ký và gửi thông tin...')],
            );
          case WifiSetupStep.error:
             return const SizedBox.shrink(); 
        }
      case ConnectionStatus.disconnected:
         return const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_disabled, color: Colors.grey, size: 50),
            SizedBox(height: 16),
            Text('Đã ngắt kết nối.'),
          ],
        );
      case ConnectionStatus.error:
        return const SizedBox.shrink();
    }
  }
}