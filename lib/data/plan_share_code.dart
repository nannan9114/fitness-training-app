import 'dart:convert';

import '../models/app_data.dart';

/// Portable plan data only; never exports sessions or device identifiers.
class PlanShareCode {
  static const prefix = 'FTA1:';

  static String encode(TrainingPlan plan) =>
      prefix +
      base64Url.encode(
        utf8.encode(
          jsonEncode({
            'name': plan.name,
            'days': [
              for (final day in plan.trainingDays)
                {
                  'name': day.name,
                  'rest': day.isRestDay,
                  'duration': day.restDurationDays,
                  'exercises': [
                    for (final e in day.exercises)
                      {'name': e.name, 'sets': e.targetSets},
                  ],
                },
            ],
          }),
        ),
      );

  static TrainingPlan decode(String code) {
    try {
      if (code.length > 262144) throw const FormatException();
      final compact = code.replaceAll(RegExp(r'\s'), '');
      if (!compact.startsWith(prefix)) throw const FormatException();
      final data = jsonDecode(
        utf8.decode(base64Url.decode(compact.substring(prefix.length))),
      );
      if (data is! Map || data['days'] is! List) throw const FormatException();
      final rawDays = data['days'] as List;
      if (rawDays.isEmpty || rawDays.length > 100) {
        throw const FormatException();
      }
      final days = <TrainingDay>[];
      for (var i = 0; i < rawDays.length; i++) {
        final day = rawDays[i];
        if (day is! Map || day['rest'] is! bool || day['exercises'] is! List) {
          throw const FormatException();
        }
        final rest = day['rest'] as bool;
        final duration = _number(day['duration'], 365);
        final rawExercises = day['exercises'] as List;
        if (rawExercises.length > 200 ||
            (rest ? rawExercises.isNotEmpty : rawExercises.isEmpty)) {
          throw const FormatException();
        }
        final exercises = <Exercise>[];
        for (var j = 0; j < rawExercises.length; j++) {
          final e = rawExercises[j];
          if (e is! Map) throw const FormatException();
          exercises.add(
            Exercise(
              id: 'import_${i}_$j',
              name: _name(e['name'], 100),
              targetSets: _number(e['sets'], 1000),
              order: j,
            ),
          );
        }
        days.add(
          TrainingDay(
            id: 'import_$i',
            name: _name(day['name'], 100),
            order: i,
            exercises: exercises,
            isRestDay: rest,
            restDurationDays: duration,
          ),
        );
      }
      if (!days.any((day) => !day.isRestDay)) throw const FormatException();
      return TrainingPlan(
        name: _name(data['name'], 30),
        splitId: SplitId.custom,
        trainingDays: days,
      );
    } catch (_) {
      throw const FormatException('分享代码无效或版本不受支持，请复制完整代码');
    }
  }

  static String _name(Object? value, int max) {
    if (value is! String || value.trim().isEmpty || value.length > max) {
      throw const FormatException();
    }
    return value.trim();
  }

  static int _number(Object? value, int max) {
    if (value is! int || value < 1 || value > max) {
      throw const FormatException();
    }
    return value;
  }
}
