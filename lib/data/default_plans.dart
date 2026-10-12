import '../models/app_data.dart';

class DefaultPlans {
  const DefaultPlans._();

  static AppData create({
    SplitId splitId = SplitId.four,
    int? scheduleDayStartedOn,
  }) {
    final plan = planFor(splitId);
    final firstDay = plan.trainingDays.first;
    return AppData(
      version: AppData.currentVersion,
      plan: plan,
      currentSession: CurrentSession(
        currentTrainingDayId: firstDay.id,
        currentExerciseId: firstDay.exercises.first.id,
        completedSetsByExercise: const {},
        restStartedAt: null,
        status: SessionStatus.inProgress,
        scheduleDayStartedOn: scheduleDayStartedOn,
      ),
    );
  }

  static TrainingPlan planFor(SplitId splitId) {
    final template = switch (splitId) {
      SplitId.three => _threeDay,
      SplitId.four => _fourDay,
      SplitId.five => _fiveDay,
    };
    return TrainingPlan(
      name: template.planName,
      splitId: splitId,
      trainingDays: [
        for (var dayIndex = 0; dayIndex < template.days.length; dayIndex++)
          TrainingDay(
            id: '${splitId.value}_day_$dayIndex',
            name: template.days[dayIndex].name,
            order: dayIndex,
            exercises: [
              for (
                var exerciseIndex = 0;
                exerciseIndex < template.days[dayIndex].exercises.length;
                exerciseIndex++
              )
                Exercise(
                  id: '${splitId.value}_day_${dayIndex}_exercise_$exerciseIndex',
                  name: template.days[dayIndex].exercises[exerciseIndex],
                  targetSets: 4,
                  order: exerciseIndex,
                ),
            ],
          ),
      ],
    );
  }
}

class _PlanTemplate {
  const _PlanTemplate(this.planName, this.days);
  final String planName;
  final List<_DayTemplate> days;
}

class _DayTemplate {
  const _DayTemplate(this.name, this.exercises);
  final String name;
  final List<String> exercises;
}

const _threeDay = _PlanTemplate('三分化', [
  _DayTemplate('推', ['杠铃卧推', '杠铃肩推', '哑铃侧平举', '绳索下压']),
  _DayTemplate('拉', ['引体向上', '高位下拉', '坐姿划船', '哑铃弯举']),
  _DayTemplate('腿', ['深蹲', '腿伸展', '内侧肌', '外侧肌']),
]);

const _fourDay = _PlanTemplate('练四休一', [
  _DayTemplate('胸', ['杠铃卧推', '杠铃斜推', '哑铃斜推', '双杆臂屈伸', '器械推胸']),
  _DayTemplate('背', ['引体向上', '高位下拉', '坐姿划船', '哑铃划船', '直臂下压']),
  _DayTemplate('肩', ['杠铃肩推', '哑铃肩推', '哑铃侧平举', '器械侧平举', '器械飞鸟']),
  _DayTemplate('腿', ['深蹲', '腿伸展', '内侧肌', '外侧肌']),
]);

const _fiveDay = _PlanTemplate('五分化', [
  _DayTemplate('胸', ['杠铃卧推', '杠铃斜推', '哑铃斜推', '双杆臂屈伸', '器械推胸']),
  _DayTemplate('背', ['引体向上', '高位下拉', '坐姿划船', '哑铃划船']),
  _DayTemplate('肩', ['杠铃肩推', '哑铃侧平举', '器械侧平举']),
  _DayTemplate('腿', ['深蹲', '腿伸展', '内侧肌', '外侧肌']),
  _DayTemplate('手臂', ['杠铃弯举', '哑铃弯举', '绳索下压', '臂屈伸']),
]);
