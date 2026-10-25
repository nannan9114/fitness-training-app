import 'package:flutter/material.dart';

import '../app.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('训练设置')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text('配置', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          const Text('所有修改仅保存在本机，保存后立即生效。'),
          const SizedBox(height: 24),
          _SettingsTile(
            icon: Icons.edit_note_rounded,
            title: '训练项目',
            subtitle: '编辑每日动作与目标组数',
            onTap: () => Navigator.pushNamed(context, AppRoutes.planEditor),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.view_week_outlined,
            title: '训练计划',
            subtitle: '切换、新建或分享计划，编辑训练日和顺序',
            onTap: () => Navigator.pushNamed(context, AppRoutes.splitSettings),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.restart_alt_rounded,
            title: '重置训练日',
            subtitle: '从指定训练日重新开始',
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.resetTrainingDay),
          ),
        ],
      ),
    ),
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.border),
      borderRadius: BorderRadius.circular(14),
    ),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      minTileHeight: 78,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.completedSurface,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}
