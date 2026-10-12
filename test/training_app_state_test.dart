import 'package:fitness_training_app/data/app_data_repository.dart';
import 'package:fitness_training_app/data/default_plans.dart';
import 'package:fitness_training_app/models/app_data.dart';
import 'package:fitness_training_app/services/rest_timer_notification.dart';
import 'package:fitness_training_app/state/training_app_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('完成一组后保存进度并以时间戳开始休息', () async {
    const now = 1770000123456;
    final storage = MemoryAppDataStorage();
    final state = TrainingAppState(
      repository: AppDataRepository(storage: storage),
      clock: () => now,
    );
    addTearDown(state.dispose);
    await state.initialize();
    final exercise = state.currentExercise!;

    final success = await state.completeCurrentSet();

    expect(success, isTrue);
    expect(state.completedSets(exercise), 1);
    expect(state.data!.currentSession.restStartedAt, now);
    expect(state.restText, '00:00');
    expect(storage.value, contains('completedSetsByExercise'));
  });

  test('完成当前动作后进入第一个未完成动作', () async {
    var now = 1770000123456;
    final storage = MemoryAppDataStorage();
    final state = TrainingAppState(
      repository: AppDataRepository(storage: storage),
      clock: () => now++,
    );
    addTearDown(state.dispose);
    await state.initialize();
    final firstExercise = state.currentExercise!;

    for (var index = 0; index < firstExercise.targetSets; index++) {
      expect(await state.completeCurrentSet(), isTrue);
    }
    expect(state.isCurrentExerciseFinished, isTrue);
    expect(await state.startNextExercise(), isTrue);

    expect(state.currentExercise!.name, '杠铃斜推');
    expect(state.completedSets(firstExercise), firstExercise.targetSets);
  });

  test('保存失败时不提交内存中的完成组数', () async {
    final storage = MemoryAppDataStorage();
    final state = TrainingAppState(
      repository: AppDataRepository(storage: storage),
      clock: () => 1770000123456,
    );
    addTearDown(state.dispose);
    await state.initialize();
    final exercise = state.currentExercise!;
    storage.failWrites = true;

    final success = await state.completeCurrentSet();

    expect(success, isFalse);
    expect(state.completedSets(exercise), 0);
    expect(state.errorMessage, '保存失败，请重试');
  });

  test('编辑计划保留当前训练日、当前动作和进度', () async {
    final storage = MemoryAppDataStorage();
    final state = TrainingAppState(
      repository: AppDataRepository(storage: storage),
      clock: () => 1770000123456,
    );
    addTearDown(state.dispose);
    await state.initialize();
    await state.completeCurrentSet();
    final oldPlan = state.data!.plan;
    final firstDay = oldPlan.trainingDays.first;
    final renamed = Exercise(
      id: firstDay.exercises.first.id,
      name: '暂停卧推',
      targetSets: 5,
      order: 0,
    );
    final editedPlan = TrainingPlan(
      name: oldPlan.name,
      splitId: oldPlan.splitId,
      trainingDays: [
        TrainingDay(
          id: firstDay.id,
          name: firstDay.name,
          order: firstDay.order,
          exercises: [renamed, ...firstDay.exercises.skip(1)],
        ),
        ...oldPlan.trainingDays.skip(1),
      ],
    );

    expect(await state.saveTrainingPlan(editedPlan), isTrue);

    expect(state.currentDay!.id, firstDay.id);
    expect(state.currentExercise!.id, renamed.id);
    expect(state.currentExercise!.name, '暂停卧推');
    expect(state.completedSets(state.currentExercise!), 1);
  });

  test('应用分化会载入默认模板并清空进度和计时', () async {
    final storage = MemoryAppDataStorage();
    final state = TrainingAppState(
      repository: AppDataRepository(storage: storage),
      clock: () => 1770000123456,
    );
    addTearDown(state.dispose);
    await state.initialize();
    await state.completeCurrentSet();

    expect(await state.applySplit(SplitId.three), isTrue);

    expect(state.data!.plan.splitId, SplitId.three);
    expect(state.currentDay!.name, '推');
    expect(state.currentExercise!.name, '杠铃卧推');
    expect(state.data!.currentSession.completedSetsByExercise, isEmpty);
    expect(state.data!.currentSession.restStartedAt, isNull);
  });

  test('调整训练日顺序不改变当前会话', () async {
    final storage = MemoryAppDataStorage();
    final state = TrainingAppState(
      repository: AppDataRepository(storage: storage),
      clock: () => 1770000123456,
    );
    addTearDown(state.dispose);
    await state.initialize();
    await state.completeCurrentSet();
    final sessionBefore = state.data!.currentSession;
    final reversedIds = state.data!.plan.trainingDays
        .map((item) => item.id)
        .toList()
        .reversed
        .toList();

    expect(await state.saveTrainingDayOrder(reversedIds), isTrue);

    expect(state.data!.plan.trainingDays.first.id, reversedIds.first);
    expect(
      state.data!.currentSession.currentTrainingDayId,
      sessionBefore.currentTrainingDayId,
    );
    expect(
      state.data!.currentSession.currentExerciseId,
      sessionBefore.currentExerciseId,
    );
    expect(
      state.data!.currentSession.completedSetsByExercise,
      sessionBefore.completedSetsByExercise,
    );
    expect(
      state.data!.currentSession.restStartedAt,
      sessionBefore.restStartedAt,
    );
  });

  test('重置训练日只清空所选训练日进度', () async {
    final storage = MemoryAppDataStorage();
    final repository = AppDataRepository(storage: storage);
    final initial = DefaultPlans.create();
    final chestExercise = initial.plan.trainingDays[0].exercises.first;
    final backDay = initial.plan.trainingDays[1];
    final backExercise = backDay.exercises.first;
    await repository.save(
      initial.copyWith(
        currentSession: CurrentSession(
          currentTrainingDayId: initial.plan.trainingDays.first.id,
          currentExerciseId: chestExercise.id,
          completedSetsByExercise: {chestExercise.id: 2, backExercise.id: 3},
          restStartedAt: 1770000000000,
          status: SessionStatus.inProgress,
        ),
      ),
    );
    final state = TrainingAppState(
      repository: repository,
      clock: () => 1770000123456,
    );
    addTearDown(state.dispose);
    await state.initialize();

    expect(await state.resetTrainingDay(backDay.id), isTrue);

    expect(state.currentDay!.id, backDay.id);
    expect(state.currentExercise!.id, backExercise.id);
    expect(
      state.data!.currentSession.completedSetsByExercise[chestExercise.id],
      2,
    );
    expect(
      state.data!.currentSession.completedSetsByExercise[backExercise.id],
      isNull,
    );
    expect(state.data!.currentSession.restStartedAt, isNull);
  });

  test('今日训练完成后停止休息计时通知', () async {
    var now = 1770000123000;
    final notification = _FakeRestTimerNotification();
    final storage = MemoryAppDataStorage();
    final repository = AppDataRepository(storage: storage);
    const exercise = Exercise(
      id: 'only_exercise',
      name: '深蹲',
      targetSets: 2,
      order: 0,
    );
    await repository.save(
      AppData(
        version: AppData.currentVersion,
        plan: TrainingPlan(
          name: '测试计划',
          splitId: SplitId.three,
          trainingDays: [
            TrainingDay(
              id: 'only_day',
              name: '腿',
              order: 0,
              exercises: const [exercise],
            ),
          ],
        ),
        currentSession: CurrentSession(
          currentTrainingDayId: 'only_day',
          currentExerciseId: exercise.id,
          completedSetsByExercise: const {},
          restStartedAt: null,
          status: SessionStatus.inProgress,
        ),
      ),
    );
    final state = TrainingAppState(
      repository: repository,
      clock: () => now,
      restTimerNotification: notification,
    );
    addTearDown(state.dispose);
    await state.initialize();

    expect(await state.completeCurrentSet(), isTrue);
    expect(state.data!.currentSession.restStartedAt, now);
    expect(notification.startedAt, [now]);

    now += 1000;
    expect(await state.completeCurrentSet(), isTrue);
    expect(state.data!.currentSession.status, SessionStatus.completed);
    expect(state.data!.currentSession.restStartedAt, isNull);
    expect(state.restText, '00:00');
    expect(notification.stopCalls, 2);
  });

  test('训练完成后次日进入休息日，并按自定义天数进入下一训练日', () async {
    var now = DateTime(2026, 8, 30, 12).millisecondsSinceEpoch;
    final storage = MemoryAppDataStorage();
    final repository = AppDataRepository(storage: storage);
    const firstExercise = Exercise(
      id: 'first_exercise',
      name: '卧推',
      targetSets: 1,
      order: 0,
    );
    const nextExercise = Exercise(
      id: 'next_exercise',
      name: '深蹲',
      targetSets: 1,
      order: 0,
    );
    await repository.save(
      AppData(
        version: AppData.currentVersion,
        plan: TrainingPlan(
          name: '测试计划',
          splitId: SplitId.three,
          trainingDays: [
            TrainingDay(
              id: 'train_a',
              name: '胸',
              order: 0,
              exercises: const [firstExercise],
            ),
            TrainingDay(
              id: 'rest',
              name: '休息',
              order: 1,
              exercises: const [],
              isRestDay: true,
              restDurationDays: 2,
            ),
            TrainingDay(
              id: 'train_b',
              name: '腿',
              order: 2,
              exercises: const [nextExercise],
            ),
          ],
        ),
        currentSession: CurrentSession(
          currentTrainingDayId: 'train_a',
          currentExerciseId: firstExercise.id,
          completedSetsByExercise: const {},
          restStartedAt: null,
          status: SessionStatus.inProgress,
        ),
      ),
    );
    final state = TrainingAppState(repository: repository, clock: () => now);
    addTearDown(state.dispose);
    await state.initialize();

    expect(await state.completeCurrentSet(), isTrue);
    expect(await state.refreshScheduleForToday(), isTrue);
    expect(state.currentDay!.id, 'train_a');

    now = DateTime(2026, 8, 31, 12).millisecondsSinceEpoch;
    expect(await state.refreshScheduleForToday(), isTrue);
    expect(state.currentDay!.id, 'rest');
    expect(state.currentExercise, isNull);

    now = DateTime(2026, 9, 1, 12).millisecondsSinceEpoch;
    expect(await state.refreshScheduleForToday(), isTrue);
    expect(state.currentDay!.id, 'rest');

    now = DateTime(2026, 9, 2, 12).millisecondsSinceEpoch;
    expect(await state.refreshScheduleForToday(), isTrue);
    expect(state.currentDay!.id, 'train_b');
    expect(state.currentExercise!.id, nextExercise.id);
  });
}

class _FakeRestTimerNotification implements RestTimerNotification {
  final List<int> startedAt = [];
  int stopCalls = 0;

  @override
  Future<void> start(int startedAt) async {
    this.startedAt.add(startedAt);
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }
}
