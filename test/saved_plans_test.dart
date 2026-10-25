import 'dart:convert';

import 'package:fitness_training_app/data/app_data_repository.dart';
import 'package:fitness_training_app/data/default_plans.dart';
import 'package:fitness_training_app/data/plan_share_code.dart';
import 'package:fitness_training_app/models/app_data.dart';
import 'package:fitness_training_app/state/training_app_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_storage.dart';

TrainingPlan edited(TrainingPlan plan) => TrainingPlan(
  name: plan.name,
  splitId: plan.splitId,
  trainingDays: [
    for (final day in plan.trainingDays.reversed)
      TrainingDay(
        id: day.id,
        name: '${day.name}改',
        order: day.order,
        isRestDay: day.isRestDay,
        restDurationDays: day.restDurationDays,
        exercises: [
          for (final e in day.exercises.reversed)
            Exercise(
              id: e.id,
              name: '${e.name}改',
              targetSets: 7,
              order: e.order,
            ),
        ],
      ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TrainingAppState makeState(MemoryAppDataStorage storage) {
    final state = TrainingAppState(
      repository: AppDataRepository(storage: storage),
      clock: () => 1770000123456,
    );
    addTearDown(state.dispose);
    return state;
  }

  test('计划顺序在切换、编辑、复制和重启后固定，导入生成独立计划', () async {
    final storage = MemoryAppDataStorage();
    final state = makeState(storage);
    await state.initialize();
    expect(state.plans.map((p) => p.id), [
      'builtin_three',
      'builtin_four',
      'builtin_five',
    ]);
    final first = (await state.createPlan('计划一'))!;
    final second = (await state.createPlan('计划二', sourceId: first))!;
    final order = state.plans.map((p) => p.id).toList();
    for (final id in ['builtin_five', first, 'builtin_three', second, first]) {
      expect(await state.switchPlan(id), isTrue);
      expect(state.plans.map((p) => p.id), order);
      expect(await state.savePlan(id, edited(state.planById(id).plan)), isTrue);
      expect(state.plans.map((p) => p.id), order);
    }
    final restored = makeState(storage);
    await restored.initialize();
    expect(restored.plans.map((p) => p.id), order);
    final source = restored.planById(first).plan;
    final imported = (await restored.createPlan(
      '导入',
      importedPlan: PlanShareCode.decode(PlanShareCode.encode(source)),
    ))!;
    expect(restored.plans.map((p) => p.id), [...order, imported]);
    expect(
      restored.planById(imported).plan.trainingDays.first.exercises.first.name,
      source.trainingDays.first.exercises.first.name,
    );
    expect(
      restored.planById(imported).plan.trainingDays.first.id,
      isNot(source.trainingDays.first.id),
    );
    expect(
      restored.planById(imported).session.completedSetsByExercise,
      isEmpty,
    );
    expect(restored.data!.activePlanId, first);
  });

  test('切换和重启保留每套分化的动作、组数、顺序及进度', () async {
    final storage = MemoryAppDataStorage();
    final state = makeState(storage);
    await state.initialize();
    final exercise = state.currentExercise!;
    await state.completeCurrentSet();
    final changed = edited(state.data!.plan);
    expect(await state.saveTrainingPlan(changed), isTrue);
    await state.applySplit(SplitId.three);
    await state.completeCurrentSet();
    final threeExercise = state.currentExercise!;
    final restored = makeState(storage);
    await restored.initialize();
    await restored.applySplit(SplitId.four);
    expect(restored.data!.plan.toJson(), changed.toJson());
    expect(restored.completedSets(exercise), 1);
    expect(restored.data!.currentSession.restStartedAt, isNull);
    await restored.applySplit(SplitId.three);
    expect(restored.completedSets(threeExercise), 1);
  });

  test('复制和编辑未启用的方案不改变当前方案，也不共享进度', () async {
    final storage = MemoryAppDataStorage();
    final state = makeState(storage);
    await state.initialize();
    await state.completeCurrentSet();
    final original = state.data!.toJson();
    final id = (await state.createPlan(
      '上下肢',
      sourceId: state.data!.activePlanId,
    ))!;
    expect(await state.savePlan(id, edited(state.planById(id).plan)), isTrue);
    expect(state.data!.activePlanId, original['activePlanId']);
    expect(state.data!.plan.name, '四分化');
    expect(state.currentExercise!.name, '杠铃卧推');
    expect(state.planById(id).session.completedSetsByExercise, isEmpty);
    expect(await state.switchPlan(id), isTrue);
    expect(await state.deletePlan(id), isFalse);
    final restored = makeState(storage);
    await restored.initialize();
    expect(restored.data!.activePlanId, id);
    expect(restored.data!.plan.name, '上下肢');
    await restored.applySplit(SplitId.four);
    expect(restored.completedSets(restored.currentExercise!), 1);
    expect(await restored.deletePlan(id), isTrue);
  });

  test('切换保存失败时保持原方案和磁盘数据', () async {
    final storage = MemoryAppDataStorage();
    final state = makeState(storage);
    await state.initialize();
    final old = storage.value;
    storage.failWrites = true;
    expect(await state.applySplit(SplitId.three), isFalse);
    expect(state.data!.plan.splitId, SplitId.four);
    expect(storage.value, old);
    expect(await state.createPlan('上下肢'), isNull);
  });

  test('旧版数据先完整备份再迁移，保留修改和进度', () async {
    final initial = DefaultPlans.create();
    final plan = edited(initial.plan);
    final raw = jsonEncode({
      'version': 1,
      'plan': plan.toJson(),
      'currentSession': initial.currentSession.toJson(),
    });
    final storage = MemoryAppDataStorage()..value = raw;
    final data = await AppDataRepository(storage: storage).load();
    expect(storage.backup, raw);
    expect(data.plan.toJson(), plan.toJson());
    expect(data.currentSession.toJson(), initial.currentSession.toJson());
    expect(data.version, 2);
    expect(jsonDecode(storage.value!)['savedPlans'], hasLength(1));
  });

  test('迁移备份或写入失败时不覆盖旧数据', () async {
    final initial = DefaultPlans.create();
    final raw = jsonEncode({
      'version': 1,
      'plan': initial.plan.toJson(),
      'currentSession': initial.currentSession.toJson(),
    });
    for (final storage in [
      MemoryAppDataStorage()..failWrites = true,
      _MigrationWriteFailure(),
    ]) {
      storage.value = raw;
      await expectLater(
        AppDataRepository(storage: storage).load(),
        throwsA(isA<AppDataStorageException>()),
      );
      expect(storage.value, raw);
    }
  });

  test('未知数据版本不会重置，初始化失败提供重试状态', () async {
    final storage = MemoryAppDataStorage()..value = '{"version":99}';
    final state = makeState(storage);
    await state.initialize();
    expect(state.data, isNull);
    expect(state.isLoading, isFalse);
    expect(storage.value, '{"version":99}');
  });
}

class _MigrationWriteFailure extends MemoryAppDataStorage {
  @override
  Future<bool> write(String value) async => false;
}
