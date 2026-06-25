import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AddDeviceIntroScreen extends StatelessWidget {
  const AddDeviceIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm thiết bị mới'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // Hình ảnh minh họa (có thể thay bằng asset/animation)
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bluetooth_searching, size: 80, color: colorScheme.primary),
            ),
            const SizedBox(height: 40),
            Text(
              'Chuẩn bị kết nối',
              style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Làm theo các bước sau để tìm thấy khóa thông minh của bạn:',
              style: textTheme.bodyLarge?.copyWith(color: textTheme.labelSmall?.color),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Các bước hướng dẫn
            _buildInstructionStep(
              context,
              icon: Icons.bluetooth,
              title: 'Bật Bluetooth',
              description: 'Đảm bảo Bluetooth trên điện thoại của bạn đã được bật.',
            ),
            const SizedBox(height: 16),
            _buildInstructionStep(
              context,
              icon: Icons.location_on_outlined,
              title: 'Cấp quyền vị trí',
              description: 'Ứng dụng cần quyền này để quét Bluetooth xung quanh.',
            ),
            const SizedBox(height: 16),
            _buildInstructionStep(
              context,
              icon: Icons.lock_outline,
              title: 'Lại gần thiết bị',
              description: 'Hãy đứng gần khóa (khoảng cách dưới 2 mét).',
            ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  // Chuyển sang màn hình quét
                  context.push('/home/scan-devices');
                },
                child: const Text('Bắt đầu tìm kiếm'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(BuildContext context, {required IconData icon, required String title, required String description}) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: theme.dividerTheme.color ?? Colors.grey),
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(description, style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.labelSmall?.color)),
            ],
          ),
        ),
      ],
    );
  }
}
