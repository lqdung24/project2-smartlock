import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/member_provider.dart';
import 'package:intl/intl.dart';

class JoinRequestsScreen extends ConsumerWidget {
  const JoinRequestsScreen({super.key});

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final requestsAsyncValue = ref.watch(joinRequestsProvider);

    ref.listen<AsyncValue<void>>(joinRequestNotifierProvider, (_, state) {
      if (state is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${state.error}')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yêu cầu tham gia'),
        backgroundColor: colorScheme.surface,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          onPressed: () => context.pop(),
        ),
      ),
      body: requestsAsyncValue.when(
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(child: Text('Không có yêu cầu nào đang chờ.'));
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(joinRequestsProvider.future),
            child: ListView.separated(
              itemCount: requests.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final request = requests[index];
                final user = request.requestUser;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundImage: NetworkImage('https://api.dicebear.com/7.x/initials/png?seed=${user.email}'),
                        radius: 24,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.name, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(user.email, style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 4),
                            Text(
                              'Gửi lúc: ${_formatDate(request.createAt)}', 
                              style: theme.textTheme.labelSmall?.copyWith(color: theme.textTheme.labelSmall?.color?.withAlpha(150)),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: Colors.green),
                            tooltip: 'Chấp nhận',
                            onPressed: () {
                              ref.read(joinRequestNotifierProvider.notifier).acceptRequest(request.requesterId);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            tooltip: 'Từ chối',
                            onPressed: () {
                              // TODO: Gọi API từ chối yêu cầu
                               ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Đã từ chối ${user.name}')),
                              );
                            },
                          ),
                        ],
                      )
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
                onPressed: () => ref.refresh(joinRequestsProvider),
                child: const Text('Thử lại'),
              )
            ],
          )
        ),
      ),
    );
  }
}