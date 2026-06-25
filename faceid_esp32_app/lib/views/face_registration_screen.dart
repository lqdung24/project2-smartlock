import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../services/cloudinary_service.dart';
import '../services/device_service.dart';

class FaceRegistrationScreen extends ConsumerStatefulWidget {
  const FaceRegistrationScreen({super.key});

  @override
  ConsumerState<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends ConsumerState<FaceRegistrationScreen> {
  bool _isLoading = false;

  Future<void> _registerFace() async {
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    final ImagePicker picker = ImagePicker();
    final XFile? image = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Chọn từ thư viện'),
                onTap: () async {
                  final pickedImage = await picker.pickImage(source: ImageSource.gallery);
                  Navigator.pop(context, pickedImage);
                },
              ),
              if (isMobile)
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Chụp ảnh mới'),
                  onTap: () async {
                    final pickedImage = await picker.pickImage(source: ImageSource.camera);
                    Navigator.pop(context, pickedImage);
                  },
                ),
            ],
          ),
        );
      },
    );

    if (image == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final cloudinaryService = CloudinaryService();
      final deviceService = DeviceService();

      // 1. Upload to Cloudinary
      final imageUrl = await cloudinaryService.uploadImage(image);

      // 2. Lấy thông tin user hiện tại (chỉ để kiểm tra xem đã login chưa)
      final currentUser = ref.read(authProvider).user;
      if (currentUser == null) {
        throw Exception('Không tìm thấy thông tin người dùng.');
      }

      // 3. Gửi URL lên server (DeviceService sẽ tự lấy hardwareId đang online)
      await deviceService.registerFace(imageUrl);

      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Đăng ký khuôn mặt thành công!')),
         );
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Đã có lỗi xảy ra: ${e.toString()}')),
         );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng ký khuôn mặt'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.face_retouching_natural,
                size: 100,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                'Đăng ký khuôn mặt của bạn để sử dụng tính năng mở khóa bằng FaceID.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _registerFace,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Bắt đầu đăng ký'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}