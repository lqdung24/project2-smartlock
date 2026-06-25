import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/member_provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../services/cloudinary_service.dart';
import '../services/api_service.dart';

class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key});

  String _translateRole(String role) {
    switch (role.toUpperCase()) {
      case 'OWNER':
        return 'Chủ nhà';
      case 'MEMBER':
        return 'Thành viên';
      case 'GUEST':
        return 'Khách';
      default:
        return 'Không xác định';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final membersAsyncValue = ref.watch(membersProvider);
    final currentUser = ref.watch(authProvider).user;
    final isCurrentUserOwner = currentUser?.role.toUpperCase() == 'OWNER';

    ref.listen<AsyncValue<void>>(memberNotifierProvider, (_, state) {
      if (state is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${state.error}')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý thành viên'),
        backgroundColor: colorScheme.surface,
        elevation: 1,
        actions: [
          if (isCurrentUserOwner)
            IconButton(
              icon: const Badge(
                label: Text('3'), // TODO: Cập nhật số lượng request thực tế từ API
                child: Icon(Icons.group_add_outlined),
              ),
              tooltip: 'Duyệt yêu cầu tham gia',
              onPressed: () {
                context.push('/join-requests');
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Mở dialog hoặc màn hình mời thành viên
              },
              icon: const Icon(Icons.add),
              label: const Text('Mời thành viên mới'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: membersAsyncValue.when(
              data: (members) {
                if (members.isEmpty) {
                  return const Center(child: Text('Chưa có thành viên nào.'));
                }
                
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(membersProvider.future),
                  child: ListView.separated(
                    itemCount: members.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final roleName = _translateRole(member.role);
                      final isOwner = member.role.toUpperCase() == 'OWNER';

                      return ListTile(
                        onTap: (isCurrentUserOwner && currentUser?.id != member.id) 
                            ? () => _showMemberActions(context, ref, member) 
                            : null,
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage('https://api.dicebear.com/7.x/initials/png?seed=${member.email}'),
                        ),
                        title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(member.email),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              roleName,
                              style: TextStyle(
                                color: isOwner ? colorScheme.primary : theme.textTheme.bodySmall?.color,
                                fontWeight: isOwner ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            if (isCurrentUserOwner && !isOwner)
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'remove') {
                                    ref.read(memberNotifierProvider.notifier).removeMember(member.id);
                                  }
                                },
                                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                  const PopupMenuItem<String>(
                                    value: 'change_role',
                                    child: Text('Thay đổi vai trò'),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'remove',
                                    child: Text('Xóa thành viên', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Đã có lỗi xảy ra', style: TextStyle(color: Colors.red)),
                    TextButton(
                      onPressed: () => ref.refresh(membersProvider),
                      child: const Text('Thử lại'),
                    )
                  ],
                )
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMemberActions(BuildContext context, WidgetRef ref, dynamic member) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.vpn_key_outlined),
                title: const Text('Cấp quyền sử dụng khóa'),
                onTap: () {
                  Navigator.pop(ctx);
                  // TODO: Implement grant key access logic
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chức năng đang được phát triển.')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.face_retouching_natural_outlined),
                title: const Text('Thêm khuôn mặt'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleAddFace(context, ref, member);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleAddFace(BuildContext context, WidgetRef ref, dynamic member) async {
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final cloudinaryService = CloudinaryService();
      final apiService = ApiService();

      // 1. Upload to Cloudinary
      final imageUrl = await cloudinaryService.uploadImage(image);

      // 2. Gửi URL lên server của bạn
      const hardwareId = "REPLACE_WITH_ACTUAL_HARDWARE_ID"; // TODO: Lấy hardware ID thực tế
      await apiService.registerFace(
        hardwareId: hardwareId,
        imageUrl: imageUrl,
        userId: member.id.toString(), // Sửa lỗi kiểu dữ liệu ở đây
      );
      
      if(context.mounted) Navigator.pop(context); // Tắt dialog loading

      if(context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Thêm khuôn mặt thành công!')),
         );
      }
    } catch (e) {
      if(context.mounted) Navigator.pop(context); // Tắt dialog loading
      if(context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã có lỗi xảy ra: ${e.toString()}')),
        );
      }
    }
  }
}