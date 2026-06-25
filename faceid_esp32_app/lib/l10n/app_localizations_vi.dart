// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Ứng dụng Khóa Thông Minh';

  @override
  String get welcomeBack => 'Chào mừng trở lại';

  @override
  String get loginToManageHome => 'Đăng nhập để quản lý ngôi nhà của bạn';

  @override
  String get phoneNumber => 'SỐ ĐIỆN THOẠI';

  @override
  String get enterPhoneNumber => 'Nhập số điện thoại';

  @override
  String get continueButton => 'Tiếp tục';

  @override
  String get loginWithFaceID => 'Đăng nhập bằng FaceID';

  @override
  String get registerAccount => 'Đăng ký tài khoản';

  @override
  String get forgotPassword => 'Quên mật khẩu?';

  @override
  String get myDevices => 'Thiết bị của tôi';

  @override
  String get add => 'Thêm';

  @override
  String get mainDoor => 'Cửa chính';

  @override
  String get backDoor => 'Cửa sau';

  @override
  String get bedroom => 'Phòng ngủ';

  @override
  String get online => 'Trực tuyến';

  @override
  String get offline => 'Ngoại tuyến';

  @override
  String get recentActivity => 'Hoạt động gần đây';

  @override
  String unlockedBy(Object name) {
    return 'Đã mở khóa bởi $name';
  }

  @override
  String get autoLock => 'Khóa tự động';

  @override
  String get after5Minutes => 'Sau 5 phút';

  @override
  String get activityLog => 'Nhật ký';

  @override
  String get searchEvents => 'Tìm kiếm sự kiện...';

  @override
  String get today => 'Hôm nay';

  @override
  String get yesterday => 'Hôm qua';

  @override
  String get thisWeek => 'Tuần này';

  @override
  String get selectDate => 'Chọn ngày';

  @override
  String get morning => 'Sáng nay';

  @override
  String doorOpened(Object doorName) {
    return '$doorName đã mở';
  }

  @override
  String get byAdminFaceID => 'Bởi Admin (FaceID)';

  @override
  String doorLocked(Object doorName) {
    return '$doorName đã khóa';
  }

  @override
  String get autoLockScheduled => 'Tự động khóa định kỳ';

  @override
  String get warningLowBattery => 'Cảnh báo: Pin yếu';

  @override
  String mainDoorBattery(Object percentage) {
    return 'Cửa chính: Còn lại $percentage';
  }

  @override
  String byMemberFingerprint(Object name) {
    return 'Bởi Thành viên: $name (Vân tay)';
  }

  @override
  String timesOpenedToday(Object count) {
    return '$count lần mở hôm nay';
  }

  @override
  String get safety => 'An toàn';

  @override
  String get alerts => 'Cảnh báo';

  @override
  String get deviceManagement => 'Quản lý thiết bị';

  @override
  String devicesConnected(Object count) {
    return '$count thiết bị được kết nối';
  }

  @override
  String get frontHall => 'Vị trí: Sảnh trước';

  @override
  String get backyard => 'Vị trí: Sân sau';

  @override
  String get firstFloor => 'Vị trí: Lầu 1';

  @override
  String get unlock => 'Mở khóa';

  @override
  String get disconnected => 'Mất kết nối với thiết bị';

  @override
  String get addNewDevice => 'Thêm thiết bị mới';

  @override
  String get settings => 'Cài đặt';

  @override
  String get accountSecurity => 'Bảo mật tài khoản';

  @override
  String get faceID => 'FaceID';

  @override
  String get password => 'Mật khẩu';

  @override
  String get notifications => 'Thông báo';

  @override
  String get pushAlerts => 'Cảnh báo đẩy';

  @override
  String get criticalAlerts => 'Cảnh báo quan trọng';

  @override
  String get smartFeatures => 'Tính năng thông minh';

  @override
  String get autoLockTimer => 'Hẹn giờ tự động khóa';

  @override
  String get speakerVolume => 'Âm lượng loa';

  @override
  String seconds(Object count) {
    return '$count giây';
  }

  @override
  String get medium => 'Trung bình';

  @override
  String get helpAndSupport => 'Trợ giúp & Hỗ trợ';

  @override
  String get faq => 'Câu hỏi thường gặp';

  @override
  String get contactUs => 'Liên hệ';

  @override
  String get about => 'Giới thiệu';

  @override
  String get version => 'Phiên bản';

  @override
  String get termsOfService => 'Điều khoản dịch vụ';

  @override
  String get logout => 'Đăng xuất';

  @override
  String get account => 'TÀI KHOẢN';

  @override
  String get passwordLabel => 'MẬT KHẨU';

  @override
  String get enterEmailOrPhone => 'Nhập email hoặc số điện thoại';

  @override
  String get enterPassword => 'Nhập mật khẩu';

  @override
  String get loginButton => 'Đăng nhập';

  @override
  String get changePassword => 'Đổi mật khẩu';

  @override
  String get oldPassword => 'Mật khẩu cũ';

  @override
  String get enterOldPassword => 'Nhập mật khẩu cũ của bạn';

  @override
  String get pleaseEnterOldPassword => 'Vui lòng nhập mật khẩu cũ của bạn';

  @override
  String get newPassword => 'Mật khẩu mới';

  @override
  String get enterNewPassword => 'Nhập mật khẩu mới của bạn';

  @override
  String get pleaseEnterNewPassword => 'Vui lòng nhập mật khẩu mới của bạn';

  @override
  String get passwordTooShort => 'Mật khẩu phải có ít nhất 6 ký tự';

  @override
  String get confirmNewPassword => 'Xác nhận mật khẩu mới';

  @override
  String get enterConfirmNewPassword => 'Xác nhận mật khẩu mới của bạn';

  @override
  String get passwordsDoNotMatch => 'Mật khẩu không khớp';
}
