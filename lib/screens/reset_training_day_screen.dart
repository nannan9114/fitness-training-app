import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/training_app_state.dart';
import '../theme/app_theme.dart';

class ResetTrainingDayScreen extends StatefulWidget {
  const ResetTrainingDayScreen({super.key});

  @override
  State<ResetTrainingDayScreen> createState() => _ResetTrainingDayScreenState();
}

class _ResetTrainingDayScreenState extends State<ResetTrainingDayScreen> {
  String? _selectedDayId;

  Future<void> _confirmReset() async {
    final state = context.read<TrainingAppState>();
    final selectedId = _selectedDayId;
    if (selectedId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先选择训练日')));
      return;
    }
    final day = state.data!.plan.trainingDays.firstWhere(
      (item) => item.id == selectedId,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('重置${day.name}日？'),
        content: Text('将清空${day.name}日的完成进度与组间计时，其他训练日不受影响。'),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('确认重置'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final success = await state.resetTrainingDay(selectedId);
    if (!mounted) {
      return;
    }
    if (success) {
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text('已切换到${day.name}日')));
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(state.errorMessage ?? '保存失败，请重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TrainingAppState>();
    final days = state.data!.plan.trainingDays
        .where((day) => !day.isRestDay)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('重置训练日')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                children: [
                  Text(
                    '选择重新开始的位置',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  const Text('确认后只清空所选训练日的进度，并停止当前休息计时。'),
                  const SizedBox(height: 18),
                  RadioGroup<String>(
                    groupValue: _selectedDayId,
                    onChanged: (value) =>
                        setState(() => _selectedDayId = value),
                    child: Column(
                      children: [
                        for (final day in days)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: RadioListTile<String>(
                              value: day.id,
                              tileColor: AppColors.surface,
                              selectedTileColor: AppColors.completedSurface,
                              selected: _selectedDayId == day.id,
                              shape: RoundedRectangleBorder(
                                side: const BorderSide(color: AppColors.border),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              title: Text('${day.name}日'),
                              subtitle: Text('${day.exercises.length} 个项目'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: FilledButton(
                onPressed: state.isSaving ? null : _confirmReset,
                child: const Text('确认重置训练日'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
