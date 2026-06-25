// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Smart Lock App';

  @override
  String get welcomeBack => 'Welcome Back';

  @override
  String get loginToManageHome => 'Login to manage your home';

  @override
  String get phoneNumber => 'PHONE NUMBER';

  @override
  String get enterPhoneNumber => 'Enter phone number';

  @override
  String get continueButton => 'Continue';

  @override
  String get loginWithFaceID => 'Login with FaceID';

  @override
  String get registerAccount => 'Register Account';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get myDevices => 'My Devices';

  @override
  String get add => 'Add';

  @override
  String get mainDoor => 'Main Door';

  @override
  String get backDoor => 'Back Door';

  @override
  String get bedroom => 'Bedroom';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String unlockedBy(Object name) {
    return 'Unlocked by $name';
  }

  @override
  String get autoLock => 'Auto Lock';

  @override
  String get after5Minutes => 'After 5 minutes';

  @override
  String get activityLog => 'Activity Log';

  @override
  String get searchEvents => 'Search events...';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get thisWeek => 'This Week';

  @override
  String get selectDate => 'Select Date';

  @override
  String get morning => 'Morning';

  @override
  String doorOpened(Object doorName) {
    return '$doorName opened';
  }

  @override
  String get byAdminFaceID => 'By Admin (FaceID)';

  @override
  String doorLocked(Object doorName) {
    return '$doorName locked';
  }

  @override
  String get autoLockScheduled => 'Auto lock scheduled';

  @override
  String get warningLowBattery => 'Warning: Low Battery';

  @override
  String mainDoorBattery(Object percentage) {
    return 'Main Door: $percentage remaining';
  }

  @override
  String byMemberFingerprint(Object name) {
    return 'By Member: $name (Fingerprint)';
  }

  @override
  String timesOpenedToday(Object count) {
    return '$count times opened today';
  }

  @override
  String get safety => 'Safety';

  @override
  String get alerts => 'Alerts';

  @override
  String get deviceManagement => 'Device Management';

  @override
  String devicesConnected(Object count) {
    return '$count devices connected';
  }

  @override
  String get frontHall => 'Location: Front Hall';

  @override
  String get backyard => 'Location: Backyard';

  @override
  String get firstFloor => 'Location: First Floor';

  @override
  String get unlock => 'Unlock';

  @override
  String get disconnected => 'Disconnected from device';

  @override
  String get addNewDevice => 'Add new device';

  @override
  String get settings => 'Settings';

  @override
  String get accountSecurity => 'Account Security';

  @override
  String get faceID => 'FaceID';

  @override
  String get password => 'Password';

  @override
  String get notifications => 'Notifications';

  @override
  String get pushAlerts => 'Push Alerts';

  @override
  String get criticalAlerts => 'Critical Alerts';

  @override
  String get smartFeatures => 'Smart Features';

  @override
  String get autoLockTimer => 'Auto Lock Timer';

  @override
  String get speakerVolume => 'Speaker Volume';

  @override
  String seconds(Object count) {
    return '$count seconds';
  }

  @override
  String get medium => 'Medium';

  @override
  String get helpAndSupport => 'Help & Support';

  @override
  String get faq => 'FAQ';

  @override
  String get contactUs => 'Contact Us';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get logout => 'Logout';

  @override
  String get account => 'ACCOUNT';

  @override
  String get passwordLabel => 'PASSWORD';

  @override
  String get enterEmailOrPhone => 'Enter email or phone';

  @override
  String get enterPassword => 'Enter password';

  @override
  String get loginButton => 'Login';

  @override
  String get changePassword => 'Change Password';

  @override
  String get oldPassword => 'Old Password';

  @override
  String get enterOldPassword => 'Enter your old password';

  @override
  String get pleaseEnterOldPassword => 'Please enter your old password';

  @override
  String get newPassword => 'New Password';

  @override
  String get enterNewPassword => 'Enter your new password';

  @override
  String get pleaseEnterNewPassword => 'Please enter your new password';

  @override
  String get passwordTooShort => 'Password must be at least 6 characters';

  @override
  String get confirmNewPassword => 'Confirm New Password';

  @override
  String get enterConfirmNewPassword => 'Confirm your new password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';
}
