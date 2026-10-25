import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/plan_share_code.dart';
import '../models/app_data.dart';
import '../state/training_app_state.dart';
import 'editor_helpers.dart';
import 'training_schedule_screen.dart';

class SplitSettingsScreen extends StatelessWidget {
  const SplitSettingsScreen({super.key});

  void _edit(BuildContext context, String id) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TrainingScheduleScreen(planId: id),
      ),
    );
  }

  Future<void> _create(BuildContext context, {SavedPlan? source}) async {
    final state = context.read<TrainingAppState>();
    var name = source == null ? '' : '${source.plan.name}副本';
    var code = '';
    String? error;
    final result = await showDialog<(String, TrainingPlan?)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(source == null ? '新建计划' : '创建副本'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  autofocus: true,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    labelText: '名称',
                    hintText: '例如：上下肢',
                  ),
                  onChanged: (text) => update(() => name = text.trim()),
                ),
                const SizedBox(height: 12),
                if (source == null)
                  TextFormField(
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 262144,
                    decoration: InputDecoration(
                      labelText: '粘贴分享代码（可选）',
                      helperText: '留空创建空白计划；粘贴代码导入计划。',
                      helperMaxLines: 2,
                      counterText: '',
                      errorText: error,
                      errorMaxLines: 3,
                    ),
                    onChanged: (text) => update(() {
                      code = text;
                      error = null;
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: name.isEmpty && code.trim().isEmpty
                  ? null
                  : () {
                      TrainingPlan? imported;
                      if (source == null && code.trim().isNotEmpty) {
                        try {
                          imported = PlanShareCode.decode(code);
                        } on FormatException catch (e) {
                          update(() => error = e.message);
                          return;
                        }
                      }
                      Navigator.pop(context, (
                        name.isEmpty ? imported!.name : name,
                        imported,
                      ));
                    },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    final id = await state.createPlan(
      result.$1,
      sourceId: source?.id,
      importedPlan: result.$2,
    );
    if (!context.mounted) return;
    if (id != null) {
      _edit(context, id);
    } else {
      _message(context, state.errorMessage ?? '创建失败，请重试');
    }
  }

  void _message(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _share(BuildContext context, SavedPlan saved) async {
    final pageContext = context;
    final code = PlanShareCode.encode(saved.plan);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('分享${saved.plan.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('复制代码发给对方，在「新建计划」中粘贴即可导入。仅分享项目和安排，不含训练进度。'),
                const SizedBox(height: 16),
                SelectableText(code, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('复制分享代码'),
            onPressed: () async {
              try {
                await Clipboard.setData(ClipboardData(text: code));
                if (context.mounted) Navigator.pop(context);
                if (pageContext.mounted) _message(pageContext, '分享代码已复制');
              } catch (_) {
                if (context.mounted) _message(context, '复制失败，请长按代码手动复制');
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _menu(
    BuildContext context,
    SavedPlan saved,
    String action,
  ) async {
    final state = context.read<TrainingAppState>();
    if (action == 'share') {
      await _share(context, saved);
      return;
    }
    if (action == 'copy') {
      await _create(context, source: saved);
      return;
    }
    if (action == 'rename') {
      final name = await requestName(context, '计划名称', saved.plan.name);
      if (name == null || !context.mounted) return;
      final success = await state.savePlan(
        saved.id,
        TrainingPlan(
          name: name,
          splitId: saved.plan.splitId,
          trainingDays: saved.plan.trainingDays,
        ),
      );
      if (context.mounted && !success) {
        _message(context, state.errorMessage ?? '保存失败');
      }
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('删除${saved.plan.name}？'),
          content: const Text('将删除这套方案的训练项目、顺序和进度。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      final success = await state.deletePlan(saved.id);
      if (context.mounted && !success) {
        _message(context, state.errorMessage ?? '请先切换到其他方案');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TrainingAppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('训练计划'),
        actions: [
          IconButton(
            tooltip: '新建计划',
            onPressed: state.isSaving ? null : () => _create(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('每个计划独立保存训练项目、顺序和进度。'),
          const SizedBox(height: 16),
          for (final saved in state.plans)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            saved.plan.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: '${saved.plan.name}选项',
                          enabled: !state.isSaving,
                          onSelected: (action) => _menu(context, saved, action),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Text('重命名'),
                            ),
                            const PopupMenuItem(
                              value: 'copy',
                              child: Text('创建副本'),
                            ),
                            const PopupMenuItem(
                              value: 'share',
                              child: Text('分享'),
                            ),
                            if (!saved.id.startsWith('builtin_'))
                              PopupMenuItem(
                                value: 'delete',
                                enabled: saved.id != state.data!.activePlanId,
                                child: const Text('删除'),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      saved.plan.trainingDays
                          .map(
                            (day) => day.isRestDay
                                ? '休息${day.restDurationDays}天'
                                : day.name,
                          )
                          .join(' → '),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: state.isSaving
                                ? null
                                : () => _edit(context, saved.id),
                            child: const Text('编辑'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed:
                                state.isSaving ||
                                    saved.id == state.data!.activePlanId
                                ? null
                                : () async {
                                    final success = await state.switchPlan(
                                      saved.id,
                                    );
                                    if (context.mounted) {
                                      _message(
                                        context,
                                        success
                                            ? '已切换到${saved.plan.name}'
                                            : state.errorMessage ?? '切换失败',
                                      );
                                    }
                                  },
                            child: Text(
                              saved.id == state.data!.activePlanId
                                  ? '使用中'
                                  : '切换使用',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: state.isSaving ? null : () => _create(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('新建计划'),
          ),
        ],
      ),
    );
  }
}
