import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/face_model.dart';
import '../providers/face_provider.dart';
import 'package:intl/intl.dart';
import '../services/device_service.dart';
import 'widgets/edit_face_dialog.dart';

class FacesScreen extends ConsumerWidget {
  const FacesScreen({super.key});

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final facesAsyncValue = ref.watch(facesProvider);

    ref.listen<AsyncValue<void>>(faceNotifierProvider, (_, state) {
      if (state is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${state.error}')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý khuôn mặt'),
        backgroundColor: colorScheme.surface,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Thêm khuôn mặt',
            onPressed: () {
              context.push('/face-registration');
            },
          ),
        ],
      ),
      body: facesAsyncValue.when(
        data: (faces) {
          if (faces.isEmpty) {
            return const Center(child: Text('Chưa có khuôn mặt nào được đăng ký.'));
          }

          final sortedFaces = List<FaceModel>.from(faces)
            ..sort((a, b) => b.createAt.compareTo(a.createAt));

          return RefreshIndicator(
            onRefresh: () => ref.refresh(facesProvider.future),
            child: ListView.separated(
              itemCount: sortedFaces.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final face = sortedFaces[index];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(face.imgUrl),
                    radius: 24,
                  ),
                  title: Text(face.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Người dùng: ${face.user.name}'),
                      Text('Ngày tạo: ${_formatDate(face.createAt)}'),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'delete') {
                        final deviceService = DeviceService();
                        final hardwareId = await deviceService.getOnlineDevice();
                        ref.read(faceNotifierProvider.notifier).deleteFace(face.id, hardwareId);
                      } else if (value == 'edit') {
                        final newLabel = await showDialog<String>(
                          context: context,
                          builder: (context) => EditFaceDialog(initialLabel: face.label),
                        );
                        if (newLabel != null && newLabel.isNotEmpty) {
                          ref.read(faceNotifierProvider.notifier).updateFace(face.id, newLabel);
                        }
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('Sửa'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Xóa', style: TextStyle(color: Colors.red)),
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
                onPressed: () => ref.refresh(facesProvider),
                child: const Text('Thử lại'),
              )
            ],
          )
        ),
      ),
    );
  }
}