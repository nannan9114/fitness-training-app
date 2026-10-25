import 'dart:convert';

import 'package:fitness_training_app/data/default_plans.dart';
import 'package:fitness_training_app/data/plan_share_code.dart';
import 'package:fitness_training_app/models/app_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('分享代码往返保留名称、动作、组数、顺序和休息日，不包含进度和ID', () {
    final base = DefaultPlans.planFor(SplitId.three);
    final plan = TrainingPlan(
      name: '推拉腿',
      splitId: SplitId.three,
      trainingDays: [
        ...base.trainingDays,
        TrainingDay(
          id: 'rest',
          name: '休息',
          order: 3,
          exercises: [],
          isRestDay: true,
          restDurationDays: 2,
        ),
      ],
    );
    final code = PlanShareCode.encode(plan);
    final data = utf8.decode(base64Url.decode(code.substring(5)));
    expect(data, isNot(contains('session')));
    expect(data, isNot(contains('"id"')));
    final restored = PlanShareCode.decode(' \n$code\n');
    expect(PlanShareCode.encode(restored), code);
    expect(restored.splitId, SplitId.custom);
    expect(restored.trainingDays.any((day) => day.isRestDay), isTrue);
  });

  test('拒绝无效、未知版本、超长和结构不完整的分享代码', () {
    for (final code in [
      '',
      'FTA2:abc',
      'FTA1:@@',
      'FTA1:${'x' * 262145}',
      'FTA1:${base64Url.encode(utf8.encode(jsonEncode({'name': '测试', 'days': []})))}',
      'FTA1:${base64Url.encode(utf8.encode(jsonEncode({
        'name': '测试',
        'days': [
          {'name': '休息', 'rest': true, 'duration': 1, 'exercises': []},
        ],
      })))}',
    ]) {
      expect(() => PlanShareCode.decode(code), throwsFormatException);
    }
  });
}
