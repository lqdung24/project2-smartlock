import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/device_provider.dart';
import '../providers/auth_provider.dart';

class HomeScreenContent extends ConsumerWidget {
  const HomeScreenContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    ref.listen<AsyncValue<void>>(deviceNotifierProvider, (_, state) {
      if (state.hasError && !state.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${state.error}')),
        );
      }
      if (!state.hasError && !state.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thao tác thành công!'), backgroundColor: Colors.green),
        );
        ref.refresh(devicesProvider);
      }
    });

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56.0),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ColorFilter.mode(
              colorScheme.surface.withAlpha(204),
              BlendMode.srcOver,
            ),
            child: AppBar(
              backgroundColor: Colors.transparent,
              title: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.dividerTheme.color ?? Colors.grey),
                      image: const DecorationImage(
                        image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuB1xiisbA-HsreSKphs0n25e_k8b-2Bg-sj65C08dkWt4e24I7hESegi6VDmwiskNn4B1nzoIY9dtF1h6rWGKhKNg0q8xNUM-yC2LkmTsuIpB1c5yf8NKpN2-SZ3xcYpqauijtmtHa1ZqBUpd2iTay2Y2hVMZ0lL7lYzWg7URsFJQr2WP7XUFBYD8oKXEhbivI8gYoZmz5Ix4cgsZY6TP-7BMdD2qkrdB595vK91OBNH-Lgrm4r_UWgozWZ7O_WmnMaMKVsxg1hEMc'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('My Home', style: textTheme.headlineMedium),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.add, color: colorScheme.primary),
                  onPressed: () {
                    context.push('/home/add-device-intro');
                  },
                ),
              ],
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: theme.dividerTheme.color?.withAlpha(128) ?? Colors.grey.withAlpha(128))),
                ),
              ),
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            sliver: SliverToBoxAdapter(
              child: const _HeaderSection(),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            sliver: _DeviceList(),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
        ],
      ),
    );
  }
}

class _HeaderSection extends ConsumerWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final user = ref.watch(authProvider).user;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chào mừng về nhà,', style: textTheme.bodyLarge?.copyWith(color: theme.iconTheme.color)),
        const SizedBox(height: 4),
        Text(user?.name ?? 'Đang tải...', style: textTheme.displayLarge),
      ],
    );
  }
}

class _DeviceList extends ConsumerWidget {
  const _DeviceList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsyncValue = ref.watch(devicesProvider);

    return devicesAsyncValue.when(
      data: (devices) {
        if (devices.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('Chưa có thiết bị nào được kết nối.'),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final device = devices[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _DeviceCard(
                  icon: Icons.door_front_door,
                  name: device.name,
                  hardwareId: device.hardwareId,
                  isOnline: device.status == 'online',
                ),
              );
            },
            childCount: devices.length,
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, stack) => SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                const Text('Lỗi khi tải danh sách thiết bị', style: TextStyle(color: Colors.red)),
                TextButton(
                  onPressed: () => ref.refresh(devicesProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceCard extends ConsumerWidget {
  final IconData icon;
  final String name;
  final String hardwareId;
  final bool isOnline;

  const _DeviceCard({
    required this.icon,
    required this.name,
    required this.hardwareId,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final onSurfaceVariant = theme.iconTheme.color ?? Colors.grey;

    return Opacity(
      opacity: isOnline ? 1.0 : 0.6,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 15, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isOnline ? colorScheme.primary.withAlpha(26) : onSurfaceVariant.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: isOnline ? colorScheme.primary : onSurfaceVariant, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('ID: $hardwareId', style: textTheme.bodyMedium?.copyWith(color: onSurfaceVariant)),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        ref.read(deviceNotifierProvider.notifier).deleteDevice(hardwareId);
                      } else if (value == 'reset') {
                        ref.read(deviceNotifierProvider.notifier).resetDevice(hardwareId);
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'reset',
                        child: Text('Reset'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('Xóa', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: isOnline
                  ? Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                await ref.read(deviceRepositoryProvider).openDevice(hardwareId);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã gửi yêu cầu mở khóa.'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Lỗi khi mở khóa: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            icon: Icon(Icons.lock_open, size: 20, color: colorScheme.onPrimary),
                            label: const Text('Mở khóa'),
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.dividerTheme.color?.withAlpha(51) ?? colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Mất kết nối với thiết bị',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, fontStyle: FontStyle.italic, color: onSurfaceVariant),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}