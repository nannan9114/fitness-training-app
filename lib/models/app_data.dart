enum SplitId {
  three('three'),
  four('four'),
  five('five'),
  custom('custom');

  const SplitId(this.value);
  final String value;

  static SplitId fromJson(Object? value) => SplitId.values.firstWhere(
    (item) => item.value == value,
    orElse: () => throw const FormatException('无效的训练分化'),
  );
}

enum SessionStatus {
  inProgress('in_progress'),
  completed('completed');

  const SessionStatus(this.value);
  final String value;

  static SessionStatus fromJson(Object? value) =>
      SessionStatus.values.firstWhere(
        (item) => item.value == value,
        orElse: () => throw const FormatException('无效的训练状态'),
      );
}

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.targetSets,
    required this.order,
  });

  final String id;
  final String name;
  final int targetSets;
  final int order;

  factory Exercise.fromJson(Map<String, Object?> json) {
    final targetSets = json['targetSets'];
    if (targetSets is! int || targetSets < 1) {
      throw const FormatException('目标组数无效');
    }
    return Exercise(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      targetSets: targetSets,
      order: _requiredInt(json, 'order'),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'targetSets': targetSets,
    'order': order,
  };
}

class TrainingDay {
  TrainingDay({
    required this.id,
    required this.name,
    required this.order,
    required List<Exercise> exercises,
    this.isRestDay = false,
    this.restDurationDays = 1,
  }) : exercises = List.unmodifiable(exercises);

  final String id;
  final String name;
  final int order;
  final List<Exercise> exercises;
  final bool isRestDay;
  final int restDurationDays;

  factory TrainingDay.fromJson(Map<String, Object?> json) {
    final exercises = json['exercises'];
    if (exercises is! List) {
      throw const FormatException('训练动作列表无效');
    }
    final isRestDay = json['isRestDay'] ?? false;
    final restDurationDays = json['restDurationDays'] ?? 1;
    if (isRestDay is! bool ||
        restDurationDays is! int ||
        restDurationDays < 1) {
      throw const FormatException('休息日数据无效');
    }
    return TrainingDay(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      order: _requiredInt(json, 'order'),
      exercises: exercises
          .map((item) => Exercise.fromJson(_jsonMap(item)))
          .toList(),
      isRestDay: isRestDay,
      restDurationDays: restDurationDays,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'order': order,
    'exercises': exercises.map((item) => item.toJson()).toList(),
    'isRestDay': isRestDay,
    'restDurationDays': restDurationDays,
  };
}

class TrainingPlan {
  TrainingPlan({
    required this.name,
    required this.splitId,
    required List<TrainingDay> trainingDays,
  }) : trainingDays = List.unmodifiable(trainingDays);

  final String name;
  final SplitId splitId;
  final List<TrainingDay> trainingDays;

  factory TrainingPlan.fromJson(Map<String, Object?> json) {
    final trainingDays = json['trainingDays'];
    if (trainingDays is! List || trainingDays.isEmpty) {
      throw const FormatException('训练日列表无效');
    }
    return TrainingPlan(
      name: _requiredString(json, 'name'),
      splitId: SplitId.fromJson(json['splitId']),
      trainingDays: trainingDays
          .map((item) => TrainingDay.fromJson(_jsonMap(item)))
          .toList(),
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'splitId': splitId.value,
    'trainingDays': trainingDays.map((item) => item.toJson()).toList(),
  };
}

class CurrentSession {
  CurrentSession({
    required this.currentTrainingDayId,
    required this.currentExerciseId,
    required Map<String, int> completedSetsByExercise,
    required this.restStartedAt,
    required this.status,
    this.scheduleDayStartedOn,
  }) : completedSetsByExercise = Map.unmodifiable(completedSetsByExercise);

  final String currentTrainingDayId;
  final String? currentExerciseId;
  final Map<String, int> completedSetsByExercise;
  final int? restStartedAt;
  final SessionStatus status;
  final int? scheduleDayStartedOn;

  factory CurrentSession.fromJson(Map<String, Object?> json) {
    final completed = json['completedSetsByExercise'];
    if (completed is! Map) {
      throw const FormatException('完成组数数据无效');
    }
    final completedSets = <String, int>{};
    for (final entry in completed.entries) {
      if (entry.key is! String ||
          entry.value is! int ||
          (entry.value as int) < 0) {
        throw const FormatException('完成组数数据无效');
      }
      completedSets[entry.key as String] = entry.value as int;
    }
    final exerciseId = json['currentExerciseId'];
    final restStartedAt = json['restStartedAt'];
    final scheduleDayStartedOn = json['scheduleDayStartedOn'];
    if (exerciseId != null && exerciseId is! String) {
      throw const FormatException('当前动作无效');
    }
    if (restStartedAt != null && restStartedAt is! int) {
      throw const FormatException('休息时间无效');
    }
    if (scheduleDayStartedOn != null && scheduleDayStartedOn is! int) {
      throw const FormatException('训练日期无效');
    }
    return CurrentSession(
      currentTrainingDayId: _requiredString(json, 'currentTrainingDayId'),
      currentExerciseId: exerciseId as String?,
      completedSetsByExercise: completedSets,
      restStartedAt: restStartedAt as int?,
      status: SessionStatus.fromJson(json['status']),
      scheduleDayStartedOn: scheduleDayStartedOn as int?,
    );
  }

  Map<String, Object?> toJson() => {
    'currentTrainingDayId': currentTrainingDayId,
    'currentExerciseId': currentExerciseId,
    'completedSetsByExercise': completedSetsByExercise,
    'restStartedAt': restStartedAt,
    'status': status.value,
    'scheduleDayStartedOn': scheduleDayStartedOn,
  };
}

class AppData {
  const AppData({
    required this.version,
    required this.plan,
    required this.currentSession,
    this._activePlanId,
    this._savedPlans = const [],
  });

  static const currentVersion = 2;
  final int version;
  final TrainingPlan plan;
  final CurrentSession currentSession;
  final String? _activePlanId;
  final List<SavedPlan> _savedPlans;

  String get activePlanId => _activePlanId ?? 'builtin_${plan.splitId.value}';

  // The active snapshot is always derived from the current plan/session.
  // Updating progress cannot accidentally leave its saved copy out of date.
  List<SavedPlan> get savedPlans => List.unmodifiable([
    for (final saved in _savedPlans)
      if (saved.id == activePlanId)
        SavedPlan(id: activePlanId, plan: plan, session: currentSession)
      else
        saved,
    if (!_savedPlans.any((saved) => saved.id == activePlanId))
      SavedPlan(id: activePlanId, plan: plan, session: currentSession),
  ]);

  factory AppData.fromJson(Map<String, Object?> json) {
    final version = _requiredInt(json, 'version');
    if (version == 1) {
      final oldPlan = TrainingPlan.fromJson(_jsonMap(json['plan']));
      return AppData(
        version: currentVersion,
        plan: TrainingPlan(
          name: oldPlan.name == '练四休一' ? '四分化' : oldPlan.name,
          splitId: oldPlan.splitId,
          trainingDays: oldPlan.trainingDays,
        ),
        currentSession: CurrentSession.fromJson(
          _jsonMap(json['currentSession']),
        ),
      );
    }
    if (version != currentVersion || json['savedPlans'] is! List) {
      throw const FormatException('方案数据版本无效');
    }
    final plans = (json['savedPlans'] as List)
        .map((item) => SavedPlan.fromJson(_jsonMap(item)))
        .toList();
    final activeId = _requiredString(json, 'activePlanId');
    if (plans.map((item) => item.id).toSet().length != plans.length ||
        !plans.any((item) => item.id == activeId)) {
      throw const FormatException('当前方案无效');
    }
    final active = plans.firstWhere((item) => item.id == activeId);
    return AppData(
      version: currentVersion,
      plan: active.plan,
      currentSession: active.session,
      activePlanId: activeId,
      savedPlans: plans,
    );
  }

  Map<String, Object?> toJson() => {
    'version': version,
    'activePlanId': activePlanId,
    'savedPlans': savedPlans.map((item) => item.toJson()).toList(),
  };

  AppData copyWith({
    TrainingPlan? plan,
    CurrentSession? currentSession,
    String? activePlanId,
    List<SavedPlan>? savedPlans,
  }) => AppData(
    version: version,
    plan: plan ?? this.plan,
    currentSession: currentSession ?? this.currentSession,
    activePlanId: activePlanId ?? this.activePlanId,
    savedPlans: savedPlans ?? this.savedPlans,
  );
}

class SavedPlan {
  const SavedPlan({
    required this.id,
    required this.plan,
    required this.session,
  });
  final String id;
  final TrainingPlan plan;
  final CurrentSession session;

  factory SavedPlan.fromJson(Map<String, Object?> json) => SavedPlan(
    id: _requiredString(json, 'id'),
    plan: TrainingPlan.fromJson(_jsonMap(json['plan'])),
    session: CurrentSession.fromJson(_jsonMap(json['session'])),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'plan': plan.toJson(),
    'session': session.toJson(),
  };
}

Map<String, Object?> _jsonMap(Object? value) {
  if (value is! Map) {
    throw const FormatException('JSON 对象无效');
  }
  return value.map((key, item) => MapEntry(key.toString(), item));
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key 无效');
  }
  return value;
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('$key 无效');
  }
  return value;
}
