import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class SettingsScreenContent extends StatelessWidget {
  const SettingsScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ColorFilter.mode(colorScheme.surface.withAlpha(204), BlendMode.srcOver),
            child: AppBar(
              backgroundColor: Colors.transparent,
              toolbarHeight: 80,
              title: Text('Cài đặt', style: textTheme.headlineMedium),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16).copyWith(bottom: 120),
        children: [
          const _ProfileSection(),
          const SizedBox(height: 24),
          _SettingsGroup(
            title: 'Quản lý',
            children: [
              _SettingsItem(
                icon: Icons.group_outlined,
                title: 'Quản lý thành viên',
                trailingType: _TrailingType.chevron,
                onTap: () => context.push('/members'), // Điều hướng đến màn hình members
              ),
              _SettingsItem(
                icon: Icons.key_outlined,
                title: 'Mật khẩu',
                trailingType: _TrailingType.chevron,
                onTap: () => context.push('/change-password'),
                showDivider: false,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsGroup(
            title: 'Bảo mật',
            children: [
               _SettingsItem(
                icon: Icons.face,
                isPrimaryIcon: true,
                title: 'FaceID',
                trailingType: _TrailingType.switchToggle,
                switchValue: true,
              ),
              _SettingsItem(
                icon: Icons.face_retouching_natural_outlined,
                title: 'Đăng ký khuôn mặt',
                trailingType: _TrailingType.chevron,
                onTap: () => context.push('/face-registration'),
                showDivider: false,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SettingsGroup(
            title: 'Thông báo',
            children: [
              _SettingsItem(
                icon: Icons.notifications_none,
                title: 'Cảnh báo đẩy',
                trailingType: _TrailingType.chevron,
              ),
              _SettingsItem(
                icon: Icons.warning,
                isDangerIcon: true,
                title: 'Cảnh báo quan trọng',
                trailingType: _TrailingType.switchToggle,
                switchValue: true,
                showDivider: false,
              ),
            ],
          ),
          const SizedBox(height: 32),
          const _LogOutButton(),
        ],
      ),
    );
  }
}

class _ProfileSection extends ConsumerWidget {
  const _ProfileSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final user = ref.watch(authProvider).user;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 15, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.dividerTheme.color?.withAlpha(51) ?? colorScheme.surfaceContainerHighest, width: 2),
              image: const DecorationImage(
                image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuACITc2ZHSJynZMl5bg8sNP4ZeLCPbMY01SDCjYPFjoPJh7Q478UU4Ti_hXxCJK6a8DHQAYb8JCIV-jOHsKJc7yPtSDfT4NF9tYTfsSvsmFIMsog6oG61H_GgzIw6D5BfEjORupFPdd8YORDe-BPMkOANAiVOJAaPHlFpfKcy7XTEPmOxNqf_YqNuq2-WGQr2KkumWjuy4GGzCbQLzFfD3VJx-jeRzuRNCoyFaRKj-Sdsrain1ob1Umk4S-ia-L62UT3bwhvcIBQyo'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user?.name ?? 'Đang tải...', style: textTheme.headlineMedium),
                const SizedBox(height: 2),
                Text(user?.email ?? '...', style: textTheme.bodyMedium?.copyWith(color: textTheme.labelSmall?.color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsGroup({required this.title, required this.children, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(title.toUpperCase(), style: textTheme.labelSmall),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 15, offset: const Offset(0, 4))],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

enum _TrailingType { chevron, switchToggle, textAndChevron, textOnly }

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final bool isPrimaryIcon;
  final bool isDangerIcon;
  final String title;
  final _TrailingType trailingType;
  final bool showDivider;
  final bool switchValue;
  final String? trailingText;
  final VoidCallback? onTap;

  const _SettingsItem({
    required this.icon,
    this.isPrimaryIcon = false,
    this.isDangerIcon = false,
    required this.title,
    required this.trailingType,
    this.showDivider = true,
    this.switchValue = false,
    this.trailingText,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    Color iColor = theme.iconTheme.color ?? Colors.grey;
    if (isPrimaryIcon) iColor = colorScheme.primary;
    if (isDangerIcon) iColor = colorScheme.error;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            border: showDivider ? Border(bottom: BorderSide(color: theme.dividerTheme.color?.withAlpha(128) ?? Colors.grey.withAlpha(128))) : null,
          ),
          child: Row(
            children: [
              Icon(icon, color: iColor),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: textTheme.bodyLarge)),
              if (trailingType == _TrailingType.chevron)
                Icon(Icons.chevron_right, color: theme.dividerTheme.color)
              else if (trailingType == _TrailingType.switchToggle)
                Switch(value: switchValue, onChanged: (val) {})
              else if (trailingType == _TrailingType.textAndChevron)
                Row(
                  children: [
                    Text(trailingText ?? '', style: textTheme.bodyMedium?.copyWith(color: textTheme.labelSmall?.color)),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, color: theme.dividerTheme.color),
                  ],
                )
              else if (trailingType == _TrailingType.textOnly)
                Text(trailingText ?? '', style: textTheme.bodyMedium?.copyWith(color: textTheme.labelSmall?.color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogOutButton extends ConsumerWidget {
  const _LogOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 15, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async => await ref.read(authProvider.notifier).logout(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Đăng xuất',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: colorScheme.error),
            ),
          ),
        ),
      ),
    );
  }
}