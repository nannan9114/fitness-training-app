import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_data.dart';
import '../state/training_app_state.dart';
import '../theme/app_theme.dart';

class SplitSettingsScreen extends StatefulWidget {
  const SplitSettingsScreen({super.key});

  @override
  State<SplitSettingsScreen> createState() => _SplitSettingsScreenState();
}

class _SplitSettingsScreenState extends State<SplitSettingsScreen> {
  late SplitId _selectedSplit;
  late List<TrainingDay> _schedule;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    final plan = context.read<TrainingAppState>().data!.plan;
    _selectedSplit = plan.splitId;
    _schedule = List.of(plan.trainingDays);
    _initialized = true;
  }

  Future<void> _applySplit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('应用分化方案？'),
        content: Text(
          '将重新载入${_splitLabel(_selectedSplit)}默认动作，并清空当前训练进度及休息计时。',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('确认应用'),
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
    final state = context.read<TrainingAppState>();
    final messenger = ScaffoldMessenger.of(context);
    final success = await state.applySplit(_selectedSplit);
    if (!mounted) {
      return;
    }
    if (success) {
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('分化方案已应用')));
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(state.errorMessage ?? '保存失败，请重试')),
      );
    }
  }

  Future<void> _saveSchedule() async {
    final state = context.read<TrainingAppState>();
    final success = await state.saveTrainingSchedule(_schedule);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '训练安排已保存' : state.errorMessage ?? '保存失败，请重试'),
      ),
    );
  }

  void _move(int index, int offset) {
    final target = index + offset;
    if (target < 0 || target >= _schedule.length) {
      return;
    }
    setState(() {
      final item = _schedule.removeAt(index);
      _schedule.insert(target, item);
    });
  }

  Future<void> _insertRestDay() async {
    var duration = 1;
    var insertIndex = _schedule.length;
    final result = await showDialog<(int, int)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('插入休息日'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('休息时长'),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: duration == 1
                        ? null
                        : () => setDialogState(() => duration--),
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  Expanded(
                    child: Text(
                      '$duration 天',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: duration == 30
                        ? null
                        : () => setDialogState(() => duration++),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: insertIndex,
                decoration: const InputDecoration(labelText: '插入位置'),
                items: [
                  const DropdownMenuItem(value: 0, child: Text('最前面')),
                  for (var index = 0; index < _schedule.length; index++)
                    DropdownMenuItem(
                      value: index + 1,
                      child: Text('在${_scheduleLabel(_schedule[index])}之后'),
                    ),
                ],
                onChanged: (value) =>
                    setDialogState(() => insertIndex = value ?? insertIndex),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, (duration, insertIndex)),
                      child: const Text('确认插入'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _schedule.insert(
        result.$2,
        TrainingDay(
          id: 'rest_${DateTime.now().microsecondsSinceEpoch}',
          name: '休息',
          order: result.$2,
          exercises: const [],
          isRestDay: true,
          restDurationDays: result.$1,
        ),
      );
    });
  }

  void _changeRestDuration(int index, int offset) {
    final day = _schedule[index];
    final duration = (day.restDurationDays + offset).clamp(1, 30);
    setState(() {
      _schedule[index] = TrainingDay(
        id: day.id,
        name: day.name,
        order: day.order,
        exercises: day.exercises,
        isRestDay: true,
        restDurationDays: duration,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TrainingAppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('训练分化与顺序')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text('内置分化', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('应用方案会恢复该方案的默认动作。'),
            const SizedBox(height: 14),
            for (final split in SplitId.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SplitOption(
                  split: split,
                  selected: split == _selectedSplit,
                  onTap: () => setState(() => _selectedSplit = split),
                ),
              ),
            FilledButton(
              onPressed: state.isSaving ? null : _applySplit,
              child: const Text('应用分化方案'),
            ),
            const SizedBox(height: 30),
            Text('当前训练安排', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('可调整顺序，并在任意位置插入自定义时长的休息日。'),
            const SizedBox(height: 12),
            for (var index = 0; index < _schedule.length; index++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: AppColors.completedSurface,
                          foregroundColor: AppColors.primaryText,
                          child: Text('${index + 1}'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _scheduleLabel(_schedule[index]),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (_schedule[index].isRestDay)
                          IconButton(
                            tooltip: '删除休息日',
                            onPressed: () =>
                                setState(() => _schedule.removeAt(index)),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        IconButton(
                          tooltip: '上移',
                          onPressed: index == 0 ? null : () => _move(index, -1),
                          icon: const Icon(Icons.keyboard_arrow_up_rounded),
                        ),
                        IconButton(
                          tooltip: '下移',
                          onPressed: index == _schedule.length - 1
                              ? null
                              : () => _move(index, 1),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                      ],
                    ),
                    if (_schedule[index].isRestDay)
                      Row(
                        children: [
                          const SizedBox(width: 42),
                          const Expanded(child: Text('连续休息时长')),
                          IconButton(
                            tooltip: '减少一天',
                            onPressed: _schedule[index].restDurationDays == 1
                                ? null
                                : () => _changeRestDuration(index, -1),
                            icon: const Icon(Icons.remove_rounded),
                          ),
                          SizedBox(
                            width: 42,
                            child: Text(
                              '${_schedule[index].restDurationDays} 天',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          IconButton(
                            tooltip: '增加一天',
                            onPressed: _schedule[index].restDurationDays == 30
                                ? null
                                : () => _changeRestDuration(index, 1),
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: state.isSaving ? null : _insertRestDay,
              icon: const Icon(Icons.add_rounded),
              label: const Text('插入休息日'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: state.isSaving ? null : _saveSchedule,
              child: const Text('保存训练安排'),
            ),
          ],
        ),
      ),
    );
  }
}

String _scheduleLabel(TrainingDay day) =>
    day.isRestDay ? '休息日' : '${day.name}日';

class _SplitOption extends StatelessWidget {
  const _SplitOption({
    required this.split,
    required this.selected,
    required this.onTap,
  });

  final SplitId split;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Ink(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? AppColors.completedSurface : AppColors.surface,
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _splitLabel(split),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(_splitDays(split)),
              ],
            ),
          ),
          Icon(
            selected ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: selected ? AppColors.accent : AppColors.border,
          ),
        ],
      ),
    ),
  );
}

String _splitLabel(SplitId split) => switch (split) {
  SplitId.three => '三分化',
  SplitId.four => '四分化（练四休一）',
  SplitId.five => '五分化',
};

String _splitDays(SplitId split) => switch (split) {
  SplitId.three => '推 · 拉 · 腿',
  SplitId.four => '胸 · 背 · 肩 · 腿',
  SplitId.five => '胸 · 背 · 肩 · 腿 · 手臂',
};
