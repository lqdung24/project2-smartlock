import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/device_log_model.dart';
import '../providers/device_provider.dart';

class ActivityScreenContent extends ConsumerWidget {
  const ActivityScreenContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final deviceLogsAsync = ref.watch(deviceLogProvider);

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
      body: deviceLogsAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(child: Text('Không có hoạt động nào.'));
          }
          final groupedLogs = _groupLogsByDate(logs);
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
        title = 'Mở khóa bằng FaceID';
        icon = Icons.face;
        isSuccess = true;
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
    final userName = log.user?['name'];

    if (userName != null) {
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