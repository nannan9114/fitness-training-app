import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/app_data.dart';
import '../state/training_app_state.dart';
import 'editor_helpers.dart';
import 'plan_editor_screen.dart';

class TrainingScheduleScreen extends StatefulWidget {
  const TrainingScheduleScreen({super.key, required this.planId});
  final String planId;
  @override
  State<TrainingScheduleScreen> createState() => _TrainingScheduleScreenState();
}

class _TrainingScheduleScreenState extends State<TrainingScheduleScreen> {
  late List<TrainingDay> _days;
  bool _initialized = false;
  bool _dirty = false;
  bool _dragging = false;
  int _seed = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _days = List.of(
        context
            .read<TrainingAppState>()
            .planById(widget.planId)
            .plan
            .trainingDays,
      );
      _initialized = true;
    }
  }

  TrainingDay _copy(
    TrainingDay day, {
    String? name,
    int? duration,
    int? order,
  }) => TrainingDay(
    id: day.id,
    name: name ?? day.name,
    order: order ?? day.order,
    exercises: day.exercises,
    isRestDay: day.isRestDay,
    restDurationDays: duration ?? day.restDurationDays,
  );

  Future<bool> _save() async {
    final state = context.read<TrainingAppState>();
    final plan = state.planById(widget.planId).plan;
    final success = await state.savePlan(
      widget.planId,
      TrainingPlan(
        name: plan.name,
        splitId: plan.splitId,
        trainingDays: [
          for (var i = 0; i < _days.length; i++) _copy(_days[i], order: i),
        ],
      ),
    );
    if (mounted) {
      if (success) {
        setState(() => _dirty = false);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.errorMessage ?? '保存失败')));
      }
    }
    return success;
  }

  Future<void> _add(bool rest) async {
    final name = rest ? '休息' : await requestName(context, '添加训练日', '');
    if (name == null || !mounted) return;
    final id = 'day_${DateTime.now().microsecondsSinceEpoch}_${_seed++}';
    setState(() {
      _days.add(
        TrainingDay(
          id: id,
          name: name,
          order: _days.length,
          isRestDay: rest,
          exercises: rest
              ? []
              : [
                  Exercise(
                    id: '${id}_exercise',
                    name: '新项目',
                    targetSets: 4,
                    order: 0,
                  ),
                ],
        ),
      );
      _dirty = true;
    });
  }

  Future<void> _delete(TrainingDay day) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除${day.name}？'),
        content: const Text('该训练日的项目也会删除，保存后生效。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        _days.removeWhere((item) => item.id == day.id);
        _dirty = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TrainingAppState>();
    final plan = state.planById(widget.planId).plan;
    final activeDay = state.data!.activePlanId == widget.planId
        ? state.data!.currentSession.currentTrainingDayId
        : null;
    return EditorBackGuard(
      dirty: _dirty,
      onSave: _save,
      child: Scaffold(
        appBar: AppBar(title: Text(plan.name)),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('训练顺序', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(_dragging ? '已选中，上下拖动后松手放置' : '长按拖动排序，点击铅笔修改训练日名称。'),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_note),
                      label: Text(_dirty ? '保存并编辑训练项目' : '编辑训练项目'),
                      onPressed: state.isSaving
                          ? null
                          : () async {
                              if (_dirty && !await _save()) return;
                              if (!context.mounted) return;
                              await Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      PlanEditorScreen(planId: widget.planId),
                                ),
                              );
                              if (mounted) {
                                setState(
                                  () => _days = List.of(
                                    state
                                        .planById(widget.planId)
                                        .plan
                                        .trainingDays,
                                  ),
                                );
                              }
                            },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  buildDefaultDragHandles: false,
                  itemCount: _days.length,
                  onReorderStart: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _dragging = true);
                  },
                  onReorderEnd: (_) => setState(() => _dragging = false),
                  onReorderItem: (oldIndex, newIndex) => setState(() {
                    final day = _days.removeAt(oldIndex);
                    _days.insert(newIndex, day);
                    _dirty = true;
                  }),
                  proxyDecorator: (child, index, animation) => AnimatedBuilder(
                    animation: animation,
                    child: child,
                    builder: (context, child) => Transform.scale(
                      scale: 1 + animation.value * .025,
                      child: Material(
                        elevation: 12 * animation.value,
                        borderRadius: BorderRadius.circular(14),
                        child: child,
                      ),
                    ),
                  ),
                  itemBuilder: (context, index) {
                    final day = _days[index];
                    final canDelete =
                        day.id != activeDay &&
                        (day.isRestDay ||
                            _days.where((item) => !item.isRestDay).length > 1);
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(day.id),
                      index: index,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.drag_indicator),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      day.isRestDay ? '休息' : day.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                  if (!day.isRestDay)
                                    IconButton(
                                      tooltip: '修改训练日名称',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () async {
                                        final name = await requestName(
                                          context,
                                          '训练日名称',
                                          day.name,
                                        );
                                        if (name != null && mounted) {
                                          setState(() {
                                            _days[index] = _copy(
                                              day,
                                              name: name,
                                            );
                                            _dirty = true;
                                          });
                                        }
                                      },
                                    ),
                                  IconButton(
                                    tooltip: day.id == activeDay
                                        ? '当前训练日不能删除'
                                        : '删除训练日',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: canDelete
                                        ? () => _delete(day)
                                        : null,
                                  ),
                                ],
                              ),
                              if (day.isRestDay)
                                Row(
                                  children: [
                                    const Expanded(child: Text('休息天数')),
                                    IconButton(
                                      onPressed: day.restDurationDays > 1
                                          ? () => setState(() {
                                              _days[index] = _copy(
                                                day,
                                                duration:
                                                    day.restDurationDays - 1,
                                              );
                                              _dirty = true;
                                            })
                                          : null,
                                      icon: const Icon(Icons.remove),
                                    ),
                                    Text('${day.restDurationDays}'),
                                    IconButton(
                                      onPressed: day.restDurationDays < 30
                                          ? () => setState(() {
                                              _days[index] = _copy(
                                                day,
                                                duration:
                                                    day.restDurationDays + 1,
                                              );
                                              _dirty = true;
                                            })
                                          : null,
                                      icon: const Icon(Icons.add),
                                    ),
                                  ],
                                )
                              else
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${day.exercises.length} 个训练项目${day.id == activeDay ? ' · 当前训练日' : ''}',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: state.isSaving
                                ? null
                                : () => _add(false),
                            child: const Text('添加训练日'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: state.isSaving ? null : () => _add(true),
                            child: const Text('添加休息日'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: state.isSaving
                          ? null
                          : () async {
                              if (await _save() && mounted) {
                                await WidgetsBinding.instance.endOfFrame;
                                if (context.mounted) Navigator.pop(context);
                              }
                            },
                      child: const Text('保存修改'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
