import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/register_provider.dart';
import '../providers/auth_provider.dart';

class SetupHouseScreen extends ConsumerWidget {
  const SetupHouseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final registerState = ref.watch(registerProvider);
    final registerNotifier = ref.read(registerProvider.notifier);

    // Lắng nghe lỗi
    ref.listen<RegisterState>(registerProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bước 2: Thiết lập nhà'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tham gia hoặc tạo mới',
              style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn muốn tham gia một ngôi nhà có sẵn hay tạo một ngôi nhà mới cho riêng mình?',
              style: textTheme.bodyLarge?.copyWith(color: textTheme.labelSmall?.color),
            ),
            const SizedBox(height: 32),

            // Option: Join an existing house
            _buildOptionCard(
              context: context,
              title: 'Tham gia nhà có sẵn',
              subtitle: 'Yêu cầu quyền truy cập từ chủ nhà.',
              icon: Icons.group_add,
              isSelected: registerState.houseOption == HouseSetupOption.join,
              onTap: () => registerNotifier.setHouseOption(HouseSetupOption.join),
            ),
            const SizedBox(height: 16),

            // Option: Create a new house
            _buildOptionCard(
              context: context,
              title: 'Tạo nhà mới',
              subtitle: 'Bạn sẽ là chủ sở hữu của ngôi nhà này.',
              icon: Icons.add_home,
              isSelected: registerState.houseOption == HouseSetupOption.create,
              onTap: () => registerNotifier.setHouseOption(HouseSetupOption.create),
            ),
            const SizedBox(height: 32),

            // Conditional input field based on selection
            if (registerState.houseOption == HouseSetupOption.join)
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Email của chủ nhà',
                  hintText: 'Nhập email người đã mời bạn',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: registerNotifier.setOwnerEmail,
              ),
            
            if (registerState.houseOption == HouseSetupOption.create)
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Tên ngôi nhà của bạn',
                  hintText: 'Ví dụ: Nhà riêng, Chung cư...',
                  prefixIcon: const Icon(Icons.home_work_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: registerNotifier.setNewHouseName,
              ),

            const SizedBox(height: 40),

            // Finish Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (registerState.houseOption == HouseSetupOption.none || registerState.isLoading)
                    ? null
                    : () async {
                        final success = await registerNotifier.submitRegistration();
                        if (success && context.mounted) {
                           // Gọi hàm checkInitialAuth để tải lại thông tin user và cập nhật state chính
                           ref.read(authProvider.notifier).checkInitialAuth();
                        }
                      },
                child: registerState.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Hoàn tất đăng ký'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withOpacity(0.1) : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colorScheme.primary : (theme.dividerTheme.color ?? Colors.grey),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? colorScheme.primary : theme.iconTheme.color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.labelSmall?.color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
