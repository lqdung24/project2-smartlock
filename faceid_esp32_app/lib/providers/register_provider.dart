import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../services/auth_service.dart';

// Enum để định nghĩa lựa chọn của người dùng
enum HouseSetupOption { none, join, create }

// State để lưu trữ toàn bộ thông tin của luồng đăng ký
class RegisterState {
  // Step 1
  final String name;
  final String email;
  final String password;
  
  // Step 2
  final HouseSetupOption houseOption;
  final String ownerEmail;
  final String newHouseName;

  // Trạng thái chung
  final bool isLoading;
  final String? errorMessage;

  RegisterState({
    this.name = '',
    this.email = '',
    this.password = '',
    this.houseOption = HouseSetupOption.none,
    this.ownerEmail = '',
    this.newHouseName = '',
    this.isLoading = false,
    this.errorMessage,
  });

  RegisterState copyWith({
    String? name,
    String? email,
    String? password,
    HouseSetupOption? houseOption,
    String? ownerEmail,
    String? newHouseName,
    bool? isLoading,
    String? errorMessage,
    // Thêm lựa chọn để xóa errorMessage
    bool clearErrorMessage = false,
  }) {
    return RegisterState(
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      houseOption: houseOption ?? this.houseOption,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      newHouseName: newHouseName ?? this.newHouseName,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class RegisterNotifier extends Notifier<RegisterState> {
  late final AuthRepository _authRepository;

  @override
  RegisterState build() {
    _authRepository = AuthRepository(AuthService());
    return RegisterState();
  }

  void saveCredentials({required String name, required String email, required String password}) {
    state = state.copyWith(name: name, email: email, password: password);
  }

  void setHouseOption(HouseSetupOption option) {
    state = state.copyWith(houseOption: option);
  }

  void setOwnerEmail(String email) {
    state = state.copyWith(ownerEmail: email);
  }

  void setNewHouseName(String name) {
    state = state.copyWith(newHouseName: name);
  }

  Future<bool> submitRegistration() async {
    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    
    final error = await _authRepository.register(state);

    if (error == null) {
      // Luôn set isLoading về false khi xong
      state = state.copyWith(isLoading: false);
      return true;
    } else {
      // Luôn set isLoading về false khi xong
      state = state.copyWith(isLoading: false, errorMessage: error);
      return false;
    }
  }
}

final registerProvider = NotifierProvider<RegisterNotifier, RegisterState>(RegisterNotifier.new);
