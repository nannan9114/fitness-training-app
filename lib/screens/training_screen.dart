import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../models/app_data.dart';
import '../state/training_app_state.dart';
import '../theme/app_theme.dart';

class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TrainingAppState>();
    if (state.isLoading) {
      return const _LoadingScreen();
    }
    final day = state.currentDay;
    final exercise = state.currentExercise;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PageHeader(day: day),
              const SizedBox(height: 18),
              if (day?.isRestDay ?? false)
                _RestDayCard(day: day!)
              else if (exercise != null)
                _CurrentExerciseCard(exercise: exercise)
              else
                const _EmptyTrainingCard(),
              const SizedBox(height: 18),
              if (!(day?.isRestDay ?? false)) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('本日项目', style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      '${day?.exercises.length ?? 0} 项',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Expanded(
                  child: day == null
                      ? const SizedBox.shrink()
                      : Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: day.exercises.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: AppColors.divider,
                            ),
                            itemBuilder: (context, index) =>
                                _ExerciseRow(exercise: day.exercises[index]),
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomActionBar(day: day, exercise: exercise),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.day});

  final TrainingDay? day;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _trainingTitle(context, day),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(_dateText(DateTime.now())),
          ],
        ),
      ),
      Tooltip(
        message: '训练设置',
        child: SizedBox.square(
          dimension: 56,
          child: FilledButton(
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
            ),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
            child: const Icon(Icons.tune_rounded, size: 21),
          ),
        ),
      ),
    ],
  );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SkeletonBlock(height: 58),
            SizedBox(height: 18),
            _SkeletonBlock(height: 92),
            SizedBox(height: 12),
            _SkeletonBlock(height: 142),
          ],
        ),
      ),
    ),
  );
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: AppColors.completedSurface,
      borderRadius: BorderRadius.circular(14),
    ),
  );
}

class _CurrentExerciseCard extends StatelessWidget {
  const _CurrentExerciseCard({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TrainingAppState>();
    final completed = state.completedSets(exercise);
    final finished = completed >= exercise.targetSets;
    final currentSet = (completed + 1).clamp(1, exercise.targetSets);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 118),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '当前动作',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  exercise.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 5),
                Text('第 $currentSet 组 / 共 ${exercise.targetSets} 组'),
                const SizedBox(height: 18),
                Row(
                  children: [
                    for (
                      var index = 0;
                      index < exercise.targetSets;
                      index++
                    ) ...[
                      _ProgressNode(
                        state: index < completed
                            ? _NodeState.done
                            : index == completed && !finished
                            ? _NodeState.current
                            : _NodeState.pending,
                      ),
                      if (index < exercise.targetSets - 1)
                        const SizedBox(width: 12),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                state.restText,
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 32,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '组间休息',
                style: TextStyle(color: AppColors.accent, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _NodeState { done, current, pending }

class _ProgressNode extends StatelessWidget {
  const _ProgressNode({required this.state});
  final _NodeState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _NodeState.done => AppColors.primary,
      _NodeState.current => AppColors.accent,
      _NodeState.pending => AppColors.border,
    };
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: state == _NodeState.done ? color : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: color,
          width: state == _NodeState.current ? 2.5 : 1.5,
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TrainingAppState>();
    final completed = state.completedSets(exercise);
    final finished = completed >= exercise.targetSets;
    final current = state.currentExercise?.id == exercise.id && !finished;
    return Material(
      color: current ? AppColors.activeSurface : Colors.transparent,
      child: InkWell(
        onTap: finished || current || state.isSaving
            ? null
            : () => state.selectExercise(exercise.id),
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 3,
                height: current ? 34 : 0,
                color: AppColors.accent,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text('$completed / ${exercise.targetSets} 组'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  finished
                      ? '已完成'
                      : current
                      ? '当前'
                      : '未开始',
                  style: TextStyle(
                    color: current || !finished
                        ? AppColors.accent
                        : AppColors.secondaryText,
                    fontSize: 13,
                    fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTrainingCard extends StatelessWidget {
  const _EmptyTrainingCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Column(
      children: [
        Text('今日项目已完成', style: TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(height: 6),
        Text('训练进度已经自动保存。'),
      ],
    ),
  );
}

class _RestDayCard extends StatelessWidget {
  const _RestDayCard({required this.day});

  final TrainingDay day;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        const Icon(Icons.self_improvement_rounded, size: 32),
        const SizedBox(height: 10),
        Text('今日休息', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text('本次计划休息 ${day.restDurationDays} 天，无需记录训练。'),
      ],
    ),
  );
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({required this.day, required this.exercise});

  final TrainingDay? day;
  final Exercise? exercise;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TrainingAppState>();
    final completed = exercise == null ? 0 : state.completedSets(exercise!);
    final finished = exercise != null && completed >= exercise!.targetSets;
    final sessionCompleted =
        state.data?.currentSession.status == SessionStatus.completed;
    final isRestDay = day?.isRestDay ?? false;
    final label = isRestDay
        ? '休息日，无需训练'
        : sessionCompleted || exercise == null
        ? '今日训练已完成'
        : state.isSaving
        ? '正在保存'
        : finished
        ? '开始下一个项目'
        : '完成第 ${completed + 1} 组';
    return Material(
      color: AppColors.background,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          onPressed:
              state.isSaving ||
                  isRestDay ||
                  sessionCompleted ||
                  exercise == null
              ? null
              : () => _handleAction(context, state),
          child: Text(label),
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    TrainingAppState state,
  ) async {
    final success = await state.handleCurrentAction();
    if (!success && context.mounted && state.errorMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(state.errorMessage!)));
    }
  }
}

String _dateText(DateTime date) {
  const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
  return '${date.month}月${date.day}日 ${weekdays[date.weekday - 1]}';
}

String _trainingTitle(BuildContext context, TrainingDay? day) {
  final plan = context.read<TrainingAppState>().data?.plan;
  if (plan == null || day == null) {
    return '今日训练';
  }
  final split = switch (plan.splitId) {
    SplitId.three => '三分化',
    SplitId.four => '四分化',
    SplitId.five => '五分化',
  };
  final dayName = _trainingDayName(day.name);
  if (day.isRestDay) {
    return '$split · 休息日';
  }
  return '$split · $dayName';
}

String _trainingDayName(String rawName) {
  final name = rawName.trim();
  final displayName = name.startsWith('练') ? name.substring(1) : name;
  return displayName.endsWith('日') ? displayName : '$displayName日';
}
