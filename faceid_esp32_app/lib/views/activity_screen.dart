import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/device_log_model.dart';
import '../models/device_model.dart';
import '../providers/device_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/socket_provider.dart';
import '../services/socket_service.dart';

final filterDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);
final filterStatusProvider = StateProvider<bool?>((ref) => null);
final filterDeviceProvider = StateProvider<DeviceModel?>((ref) => null);
final quickFilterProvider = StateProvider<String>((ref) => 'all');

class ActivityScreenContent extends ConsumerStatefulWidget {
  const ActivityScreenContent({super.key});

  @override
  ConsumerState<ActivityScreenContent> createState() => _ActivityScreenContentState();
}

class _ActivityScreenContentState extends ConsumerState<ActivityScreenContent> {
  late final SocketService _socketService;

  @override
  void initState() {
    super.initState();
    _socketService = ref.read(socketServiceProvider);
    final notificationService = ref.read(notificationServiceProvider);
    _socketService.connect((data) {
      ref.refresh(deviceLogProvider);
      final log = DeviceLog.fromJson(data);
      notificationService.showUnlockNotification(log.device.name, log.face?['label']);
    });
  }

  @override
  void dispose() {
    _socketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final deviceLogsAsync = ref.watch(deviceLogProvider);
    final devicesAsync = ref.watch(devicesProvider);

    final dateRange = ref.watch(filterDateRangeProvider);
    final status = ref.watch(filterStatusProvider);
    final device = ref.watch(filterDeviceProvider);
    final quickFilter = ref.watch(quickFilterProvider);

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
                      color: theme.dividerTheme.color?.withAlpha(51) ?? colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.history, color: colorScheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('Nhật ký', style: textTheme.headlineMedium),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.filter_alt_outlined, color: colorScheme.primary),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => _FilterSheet(
                        devices: devicesAsync.asData?.value ?? [],
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: colorScheme.primary),
                  onPressed: () => ref.refresh(deviceLogProvider),
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
      body: Column(
        children: [
          _QuickFilterBar(),
          Expanded(
            child: deviceLogsAsync.when(
              data: (logs) {
                final filteredLogs = logs.where((log) {
                  // Quick filter
                  if (quickFilter == 'today') {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final logDate = DateTime(log.time.year, log.time.month, log.time.day);
                    if (logDate != today) return false;
                  } else if (quickFilter == 'success') {
                    if (!_ActivityTimelineItem.fromLog(log).isSuccess) return false;
                  } else if (quickFilter == 'failure') {
                    if (_ActivityTimelineItem.fromLog(log).isSuccess) return false;
                  }

                  // Advanced filter
                  if (dateRange != null && (log.time.isBefore(dateRange.start) || log.time.isAfter(dateRange.end.add(const Duration(days: 1))))) {
                    return false;
                  }
                  if (status != null && _ActivityTimelineItem.fromLog(log).isSuccess != status) {
                    return false;
                  }
                  if (device != null && log.deviceId != device.id) {
                    return false;
                  }
                  return true;
                }).toList();

                if (filteredLogs.isEmpty) {
                  return const Center(child: Text('Không có hoạt động nào.'));
                }
                final groupedLogs = _groupLogsByDate(filteredLogs);
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16).copyWith(bottom: 120),
                  itemCount: groupedLogs.length,
                  itemBuilder: (context, index) {
                    final entry = groupedLogs.entries.elementAt(index);
                    return _TimelineSection(
                      title: entry.key,
                      items: entry.value.map((log) {
                        return _ActivityTimelineItem.fromLog(log);
                      }).toList(),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Lỗi: $error'),
                    ElevatedButton(
                      onPressed: () => ref.refresh(deviceLogProvider),
                      child: const Text('Thử lại'),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<DeviceLog>> _groupLogsByDate(List<DeviceLog> logs) {
    final Map<String, List<DeviceLog>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var log in logs) {
      final logDate = DateTime(log.time.year, log.time.month, log.time.day);
      String key;
      if (logDate == today) {
        key = 'Hôm nay';
      } else if (logDate == yesterday) {
        key = 'Hôm qua';
      } else {
        key = DateFormat('dd/MM/yyyy').format(log.time);
      }
      if (grouped[key] == null) {
        grouped[key] = [];
      }
      grouped[key]!.add(log);
    }
    return grouped;
  }
}

class _QuickFilterBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFilter = ref.watch(quickFilterProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Tất cả'),
            selected: selectedFilter == 'all',
            onSelected: (selected) {
              if (selected) ref.read(quickFilterProvider.notifier).state = 'all';
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Hôm nay'),
            selected: selectedFilter == 'today',
            onSelected: (selected) {
              if (selected) ref.read(quickFilterProvider.notifier).state = 'today';
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Thành công'),
            selected: selectedFilter == 'success',
            onSelected: (selected) {
              if (selected) ref.read(quickFilterProvider.notifier).state = 'success';
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Thất bại'),
            selected: selectedFilter == 'failure',
            onSelected: (selected) {
              if (selected) ref.read(quickFilterProvider.notifier).state = 'failure';
            },
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends ConsumerWidget {
  final List<DeviceModel> devices;

  const _FilterSheet({required this.devices});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateRange = ref.watch(filterDateRangeProvider);
    final status = ref.watch(filterStatusProvider);
    final device = ref.watch(filterDeviceProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lọc nhật ký', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          // Date range filter
          ListTile(
            leading: const Icon(Icons.date_range),
            title: Text(dateRange == null ? 'Chọn ngày' : '${DateFormat('dd/MM/yyyy').format(dateRange.start)} - ${DateFormat('dd/MM/yyyy').format(dateRange.end)}'),
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange: dateRange,
              );
              if (picked != null) {
                ref.read(filterDateRangeProvider.notifier).state = picked;
              }
            },
          ),
          // Status filter
          DropdownButtonFormField<bool?>(
            value: status,
            decoration: const InputDecoration(
              labelText: 'Trạng thái',
              prefixIcon: Icon(Icons.check_circle_outline),
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('Tất cả')),
              DropdownMenuItem(value: true, child: Text('Thành công')),
              DropdownMenuItem(value: false, child: Text('Thất bại')),
            ],
            onChanged: (value) {
              ref.read(filterStatusProvider.notifier).state = value;
            },
          ),
          const SizedBox(height: 16),
          // Device filter
          DropdownButtonFormField<DeviceModel?>(
            value: device,
            decoration: const InputDecoration(
              labelText: 'Thiết bị',
              prefixIcon: Icon(Icons.device_hub),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Tất cả')),
              ...devices.map((d) => DropdownMenuItem(value: d, child: Text(d.name))),
            ],
            onChanged: (value) {
              ref.read(filterDeviceProvider.notifier).state = value;
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  ref.read(filterDateRangeProvider.notifier).state = null;
                  ref.read(filterStatusProvider.notifier).state = null;
                  ref.read(filterDeviceProvider.notifier).state = null;
                  Navigator.pop(context);
                },
                child: const Text('Xóa bộ lọc'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Áp dụng'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _TimelineSection extends StatelessWidget {
  final String title;
  final List<Widget> items;

  const _TimelineSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title.toUpperCase(), style: textTheme.labelSmall),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerTheme.color?.withAlpha(128) ?? Colors.grey.withAlpha(128)),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10)],
            ),
            child: Column(children: items),
          ),
        ],
      ),
    );
  }
}

class _ActivityTimelineItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String time;
  final IconData subtitleIcon;
  final String subtitle;
  final bool showDivider;
  final bool isSuccess;

  const _ActivityTimelineItem({
    required this.icon,
    required this.title,
    required this.time,
    required this.subtitleIcon,
    required this.subtitle,
    this.showDivider = true,
    this.isSuccess = false,
  });

  factory _ActivityTimelineItem.fromLog(DeviceLog log) {
    String title = 'Hành động không xác định';
    IconData icon = Icons.help_outline;
    IconData subtitleIcon = Icons.device_unknown;
    String subtitle;
    bool isSuccess = false;

    // Build the main title and icon based on the source
    switch (log.source.toUpperCase()) {
      case 'FACEID':
        if (log.face == null) {
          title = 'Người lạ mở khoá thất bại';
          icon = Icons.warning;
          isSuccess = false;
        } else {
          title = 'Mở khóa bằng FaceID';
          icon = Icons.face;
          isSuccess = true;
        }
        break;
      case 'APP':
        title = 'Mở khóa từ ứng dụng';
        icon = Icons.phone_android;
        isSuccess = true;
        break;
      case 'FINGERPRINT':
        title = 'Mở khóa bằng vân tay';
        icon = Icons.fingerprint;
        isSuccess = true;
        break;
    }

    // Build the subtitle
    final deviceName = log.device.name;
    final hardwareId = log.device.hardwareId;
    final faceLabel = log.face?['label'];
    final userName = log.user?['name'];

    if (faceLabel != null) {
      subtitle = '$faceLabel - $deviceName ($hardwareId)';
      subtitleIcon = Icons.person;
    } else if (userName != null) {
      subtitle = '$userName - $deviceName ($hardwareId)';
      subtitleIcon = Icons.person;
    } else {
      subtitle = '$deviceName ($hardwareId)';
      subtitleIcon = Icons.device_hub;
    }


    return _ActivityTimelineItem(
      icon: icon,
      title: title,
      time: DateFormat('HH:mm').format(log.time),
      subtitleIcon: subtitleIcon,
      subtitle: subtitle,
      isSuccess: isSuccess,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    
    Color iColor = isSuccess ? const Color(0xFF34C759) : (theme.iconTheme.color ?? Colors.grey);
    Color iBgColor = iColor.withAlpha(26);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: showDivider ? Border(bottom: BorderSide(color: theme.dividerTheme.color?.withAlpha(128) ?? Colors.grey.withAlpha(128))) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iBgColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(title, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text(time, style: textTheme.bodyMedium?.copyWith(color: textTheme.labelSmall?.color)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(subtitleIcon, size: 14, color: theme.iconTheme.color),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(subtitle, style: textTheme.bodyMedium?.copyWith(color: theme.iconTheme.color), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: theme.dividerTheme.color),
        ],
      ),
    );
  }
}