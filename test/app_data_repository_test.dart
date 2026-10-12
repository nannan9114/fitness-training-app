import 'dart:convert';

import 'package:fitness_training_app/data/app_data_repository.dart';
import 'package:fitness_training_app/models/app_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_storage.dart';

void main() {
  test('首次启动创建四分化默认计划并保存', () async {
    final storage = MemoryAppDataStorage();
    final repository = AppDataRepository(storage: storage);
    final data = await repository.load();

    expect(data.version, AppData.currentVersion);
    expect(data.plan.splitId, SplitId.four);
    expect(data.plan.name, '练四休一');
    expect(data.plan.trainingDays.map((day) => day.name), ['胸', '背', '肩', '腿']);
    expect(
      data.currentSession.currentExerciseId,
      data.plan.trainingDays.first.exercises.first.id,
    );
    expect(storage.value, isNotNull);
  });

  test('保存的数据可以完整恢复', () async {
    final storage = MemoryAppDataStorage();
    final repository = AppDataRepository(storage: storage);
    final initial = await repository.load();
    final exercise = initial.plan.trainingDays.first.exercises.first;
    final updated = initial.copyWith(
      currentSession: CurrentSession(
        currentTrainingDayId: initial.currentSession.currentTrainingDayId,
        currentExerciseId: exercise.id,
        completedSetsByExercise: {exercise.id: 2},
        restStartedAt: 123456,
        status: SessionStatus.inProgress,
      ),
    );

    await repository.save(updated);
    final restored = await repository.load();

    expect(restored.currentSession.completedSetsByExercise[exercise.id], 2);
    expect(restored.currentSession.restStartedAt, 123456);
  });

  test('损坏数据先备份再恢复默认计划', () async {
    final storage = MemoryAppDataStorage()..value = '{broken json';
    final repository = AppDataRepository(storage: storage);
    final data = await repository.load();

    expect(storage.backup, '{broken json');
    expect(data.plan.splitId, SplitId.four);
    expect(jsonDecode(storage.value!)['version'], AppData.currentVersion);
  });
}
