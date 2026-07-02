import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:faceid_esp32_app/config.dart';

class SocketService {
  late IO.Socket socket;

  void connect(Function(dynamic) onUnlockEvent) {
    socket = IO.io(AppConfig.serverBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket.on('connect', (_) {
      print('connected to websocket');
    });

    socket.on('unlock_event', onUnlockEvent);

    socket.on('disconnect', (_) {
      print('disconnected from websocket');
    });
  }

  void disconnect() {
    socket.disconnect();
  }
}