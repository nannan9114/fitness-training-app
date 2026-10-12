import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_data.dart';
import '../state/training_app_state.dart';
import '../theme/app_theme.dart';

class PlanEditorScreen extends StatefulWidget {
  const PlanEditorScreen({super.key});

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  late List<TrainingDay> _days;
  var _selectedDayIndex = 0;
  var _idSeed = 0;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _days = context
        .read<TrainingAppState>()
        .data!
        .plan
        .trainingDays
        .where((day) => !day.isRestDay)
        .map(
          (day) => TrainingDay(
            id: day.id,
            name: day.name,
            order: day.order,
            exercises: List<Exercise>.from(day.exercises),
          ),
        )
        .toList();
    _initialized = true;
  }

  TrainingDay get _selectedDay => _days[_selectedDayIndex];

  void _replaceExercises(List<Exercise> exercises) {
    final day = _selectedDay;
    _days[_selectedDayIndex] = TrainingDay(
      id: day.id,
      name: day.name,
      order: day.order,
      exercises: exercises,
    );
  }

  void _updateExercise(int index, {String? name, int? targetSets}) {
    final exercises = List<Exercise>.from(_selectedDay.exercises);
    final old = exercises[index];
    exercises[index] = Exercise(
      id: old.id,
      name: name ?? old.name,
      targetSets: targetSets ?? old.targetSets,
      order: old.order,
    );
    _replaceExercises(exercises);
  }

  void _addExercise() {
    final exercises = List<Exercise>.from(_selectedDay.exercises);
    final order = exercises.length;
    exercises.add(
      Exercise(
        id: 'custom_${DateTime.now().microsecondsSinceEpoch}_${_idSeed++}',
        name: '新项目',
        targetSets: 4,
        order: order,
      ),
    );
    setState(() => _replaceExercises(exercises));
  }

  void _deleteExercise(int index) {
    final exercises = List<Exercise>.from(_selectedDay.exercises)
      ..removeAt(index);
    final reordered = [
      for (var itemIndex = 0; itemIndex < exercises.length; itemIndex++)
        Exercise(
          id: exercises[itemIndex].id,
          name: exercises[itemIndex].name,
          targetSets: exercises[itemIndex].targetSets,
          order: itemIndex,
        ),
    ];
    setState(() => _replaceExercises(reordered));
  }

  void _reorderExercises(int oldIndex, int newIndex) {
    final exercises = List<Exercise>.from(_selectedDay.exercises);
    final moved = exercises.removeAt(oldIndex);
    exercises.insert(newIndex, moved);
    final reordered = [
      for (var index = 0; index < exercises.length; index++)
        Exercise(
          id: exercises[index].id,
          name: exercises[index].name,
          targetSets: exercises[index].targetSets,
          order: index,
        ),
    ];
    setState(() => _replaceExercises(reordered));
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_days.any((day) => day.exercises.isEmpty)) {
      _showMessage('每个训练日至少保留一个项目');
      return;
    }
    if (_days.any(
      (day) => day.exercises.any((item) => item.name.trim().isEmpty),
    )) {
      _showMessage('项目名称不能为空');
      return;
    }
    final state = context.read<TrainingAppState>();
    final oldPlan = state.data!.plan;
    final normalizedTrainingDays = [
      for (final day in _days)
        TrainingDay(
          id: day.id,
          name: day.name,
          order: day.order,
          exercises: [
            for (final exercise in day.exercises)
              Exercise(
                id: exercise.id,
                name: exercise.name.trim(),
                targetSets: exercise.targetSets,
                order: exercise.order,
              ),
          ],
        ),
    ];
    final editedById = {for (final day in normalizedTrainingDays) day.id: day};
    final mergedDays = [
      for (final day in oldPlan.trainingDays)
        if (day.isRestDay) day else editedById[day.id]!,
    ];
    final success = await state.saveTrainingPlan(
      TrainingPlan(
        name: oldPlan.name,
        splitId: oldPlan.splitId,
        trainingDays: mergedDays,
      ),
    );
    if (!mounted) {
      return;
    }
    if (success) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('训练计划已保存')));
    } else {
      _showMessage(state.errorMessage ?? '保存失败，请重试');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TrainingAppState>();
    final activeExerciseId = state.data!.currentSession.currentExerciseId;
    return Scaffold(
      appBar: AppBar(title: const Text('训练计划')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '选择训练日',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisExtent: 48,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                            itemCount: _days.length,
                            itemBuilder: (context, index) {
                              final selected = index == _selectedDayIndex;
                              return OutlinedButton(
                                onPressed: () => setState(
                                  () => _selectedDayIndex = index,
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: selected
                                      ? AppColors.primary
                                      : AppColors.surface,
                                  foregroundColor: selected
                                      ? Colors.white
                                      : AppColors.primaryText,
                                  side: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                child: Text('${_days[index].name}日'),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${_selectedDay.name}日项目',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              Text('${_selectedDay.exercises.length} 项'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '长按项目卡片并上下拖动排序',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverReorderableList(
                      itemCount: _selectedDay.exercises.length,
                      onReorderItem: _reorderExercises,
                      itemBuilder: (context, index) {
                        final exercise = _selectedDay.exercises[index];
                        return ReorderableDelayedDragStartListener(
                          key: ValueKey(exercise.id),
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ExerciseEditor(
                              exercise: exercise,
                              isActive: exercise.id == activeExerciseId,
                              canDelete:
                                  _selectedDay.exercises.length > 1 &&
                                  exercise.id != activeExerciseId,
                              onNameChanged: (value) =>
                                  _updateExercise(index, name: value),
                              onSetsChanged: (value) => setState(
                                () => _updateExercise(
                                  index,
                                  targetSets: value,
                                ),
                              ),
                              onDelete: () => _deleteExercise(index),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    sliver: SliverToBoxAdapter(
                      child: OutlinedButton.icon(
                        onPressed: _addExercise,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('添加项目'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: FilledButton(
                onPressed: state.isSaving ? null : _save,
                child: const Text('保存训练计划'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseEditor extends StatelessWidget {
  const _ExerciseEditor({
    required this.exercise,
    required this.isActive,
    required this.canDelete,
    required this.onNameChanged,
    required this.onSetsChanged,
    required this.onDelete,
  });

  final Exercise exercise;
  final bool isActive;
  final bool canDelete;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<int> onSetsChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
        Row(
          children: [
            Icon(
              Icons.drag_indicator_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: exercise.name,
                onChanged: onNameChanged,
                decoration: InputDecoration(
                  labelText: isActive ? '项目名称 · 正在训练' : '项目名称',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: isActive ? '正在训练的项目不能删除' : '删除项目',
              onPressed: canDelete ? onDelete : null,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(child: Text('目标组数')),
            IconButton.filledTonal(
              onPressed: exercise.targetSets > 1
                  ? () => onSetsChanged(exercise.targetSets - 1)
                  : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            SizedBox(
              width: 44,
              child: Text(
                '${exercise.targetSets}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton.filledTonal(
              onPressed: () => onSetsChanged(exercise.targetSets + 1),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        ],
      ),
    ),
  );
}
