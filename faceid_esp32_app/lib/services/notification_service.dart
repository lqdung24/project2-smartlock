import 'package:desktop_notifications/desktop_notifications.dart';

class NotificationService {
  final _client = NotificationsClient();

  Future<void> showUnlockNotification(String deviceName, String? faceLabel) async {
    String title = 'Mở khóa thành công';
    String body = 'Thiết bị $deviceName đã được mở khóa.';

    if (faceLabel != null) {
      body = '$faceLabel đã mở khóa thiết bị $deviceName.';
    }

    await _client.notify(
      title,
      body: body,
    );
  }
}