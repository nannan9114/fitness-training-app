import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/app_data_repository.dart';
import '../data/default_plans.dart';
import '../models/app_data.dart';
import '../services/rest_timer_notification.dart';

typedef MillisecondClock = int Function();

class TrainingAppState extends ChangeNotifier with WidgetsBindingObserver {
  TrainingAppState({
    required this.repository,
    MillisecondClock? clock,
    RestTimerNotification? restTimerNotification,
  }) : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch),
       _restTimerNotification =
           restTimerNotification ?? const NoopRestTimerNotification();

  final AppDataRepository repository;
  final MillisecondClock _clock;
  final RestTimerNotification _restTimerNotification;
  AppData? _data;
  Timer? _ticker;
  Timer? _dayBoundaryTimer;
  bool _observerRegistered = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  AppData? get data => _data;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  TrainingDay? get currentDay {
    final value = _data;
    if (value == null) {
      return null;
    }
    for (final day in value.plan.trainingDays) {
      if (day.id == value.currentSession.currentTrainingDayId) {
        return day;
      }
    }
    return value.plan.trainingDays.isEmpty
        ? null
        : value.plan.trainingDays.first;
  }

  Exercise? get currentExercise {
    final day = currentDay;
    final exerciseId = _data?.currentSession.currentExerciseId;
    if (day == null || exerciseId == null) {
      return null;
    }
    for (final exercise in day.exercises) {
      if (exercise.id == exerciseId) {
        return exercise;
      }
    }
    return null;
  }

  int completedSets(Exercise exercise) {
    final completed =
        _data?.currentSession.completedSetsByExercise[exercise.id] ?? 0;
    return completed.clamp(0, exercise.targetSets);
  }

  int get restSeconds {
    final startedAt = _data?.currentSession.restStartedAt;
    if (startedAt == null) {
      return 0;
    }
    return ((_clock() - startedAt) ~/ 1000).clamp(0, 359999);
  }

  String get restText {
    final seconds = restSeconds;
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  bool get isCurrentExerciseFinished {
    final exercise = currentExercise;
    return exercise != null && completedSets(exercise) >= exercise.targetSets;
  }

  Future<void> initialize() async {
    if (!_observerRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    }
    try {
      final loaded = await repository.load();
      final normalized = _advanceScheduleForToday(loaded);
      _data = normalized;
      if (!identical(loaded, normalized)) {
        await repository.save(normalized);
      }
      _errorMessage = null;
    } catch (_) {
      _data = DefaultPlans.create();
      _errorMessage = '本地数据读取失败，请重试';
    } finally {
      _isLoading = false;
      _syncTicker();
      _scheduleDayBoundaryRefresh();
      _syncRestNotification(previousStartedAt: null, force: true);
      notifyListeners();
    }
  }

  Future<bool> handleCurrentAction() =>
      isCurrentExerciseFinished ? startNextExercise() : completeCurrentSet();

  Future<bool> completeCurrentSet() async {
    final value = _data;
    final exercise = currentExercise;
    final day = currentDay;
    if (value == null || exercise == null || day == null || _isSaving) {
      return false;
    }
    final completed = completedSets(exercise);
    if (completed >= exercise.targetSets) {
      return false;
    }

    final updatedCompleted = Map<String, int>.from(
      value.currentSession.completedSetsByExercise,
    )..[exercise.id] = completed + 1;
    final allDone = day.exercises.every(
      (item) => (updatedCompleted[item.id] ?? 0) >= item.targetSets,
    );
    final candidate = value.copyWith(
      currentSession: CurrentSession(
        currentTrainingDayId: value.currentSession.currentTrainingDayId,
        currentExerciseId: exercise.id,
        completedSetsByExercise: updatedCompleted,
        restStartedAt: allDone ? null : _clock(),
        status: allDone ? SessionStatus.completed : SessionStatus.inProgress,
        // A delayed workout must remain completed until the day AFTER it is
        // finished, rather than advancing from an old scheduled start date.
        scheduleDayStartedOn: allDone
            ? _todayKey()
            : value.currentSession.scheduleDayStartedOn ?? _todayKey(),
      ),
    );
    return _commit(candidate);
  }

  Future<bool> startNextExercise() async {
    final value = _data;
    final day = currentDay;
    if (value == null || day == null || _isSaving) {
      return false;
    }
    Exercise? next;
    for (final exercise in day.exercises) {
      if (completedSets(exercise) < exercise.targetSets) {
        next = exercise;
        break;
      }
    }
    return _commit(
      value.copyWith(
        currentSession: CurrentSession(
          currentTrainingDayId: value.currentSession.currentTrainingDayId,
          currentExerciseId: next?.id,
          completedSetsByExercise: value.currentSession.completedSetsByExercise,
          restStartedAt: value.currentSession.restStartedAt,
          status: next == null
              ? SessionStatus.completed
              : SessionStatus.inProgress,
          scheduleDayStartedOn:
              next == null &&
                  value.currentSession.status != SessionStatus.completed
              ? _todayKey()
              : value.currentSession.scheduleDayStartedOn ?? _todayKey(),
        ),
      ),
    );
  }

  Future<bool> selectExercise(String exerciseId) async {
    final value = _data;
    final day = currentDay;
    if (value == null || day == null || _isSaving) {
      return false;
    }
    Exercise? selected;
    for (final exercise in day.exercises) {
      if (exercise.id == exerciseId) {
        selected = exercise;
      }
    }
    if (selected == null || completedSets(selected) >= selected.targetSets) {
      return false;
    }
    return _commit(
      value.copyWith(
        currentSession: CurrentSession(
          currentTrainingDayId: value.currentSession.currentTrainingDayId,
          currentExerciseId: selected.id,
          completedSetsByExercise: value.currentSession.completedSetsByExercise,
          restStartedAt: value.currentSession.restStartedAt,
          status: SessionStatus.inProgress,
          scheduleDayStartedOn:
              value.currentSession.scheduleDayStartedOn ?? _todayKey(),
        ),
      ),
    );
  }

  Future<bool> saveTrainingPlan(TrainingPlan plan) async {
    final value = _data;
    if (value == null || _isSaving) {
      return false;
    }
    final currentExerciseId = value.currentSession.currentExerciseId;
    final currentDay = plan.trainingDays
        .where((day) => day.id == value.currentSession.currentTrainingDayId)
        .firstOrNull;
    if (currentDay == null ||
        (currentExerciseId != null &&
            !currentDay.exercises.any(
              (item) => item.id == currentExerciseId,
            ))) {
      _errorMessage = '不能删除正在训练的项目或训练日';
      notifyListeners();
      return false;
    }
    return _commit(value.copyWith(plan: plan));
  }

  Future<bool> applySplit(SplitId splitId) async {
    if (_data == null || _isSaving) {
      return false;
    }
    return _commit(
      DefaultPlans.create(splitId: splitId, scheduleDayStartedOn: _todayKey()),
    );
  }

  Future<bool> saveTrainingDayOrder(List<String> orderedDayIds) async {
    final value = _data;
    if (value == null || _isSaving) {
      return false;
    }
    final daysById = {for (final day in value.plan.trainingDays) day.id: day};
    if (orderedDayIds.length != daysById.length ||
        orderedDayIds.any((id) => !daysById.containsKey(id))) {
      _errorMessage = '训练日顺序无效';
      notifyListeners();
      return false;
    }
    final reordered = <TrainingDay>[
      for (var index = 0; index < orderedDayIds.length; index++)
        TrainingDay(
          id: daysById[orderedDayIds[index]]!.id,
          name: daysById[orderedDayIds[index]]!.name,
          order: index,
          exercises: daysById[orderedDayIds[index]]!.exercises,
          isRestDay: daysById[orderedDayIds[index]]!.isRestDay,
          restDurationDays: daysById[orderedDayIds[index]]!.restDurationDays,
        ),
    ];
    return _commit(
      value.copyWith(
        plan: TrainingPlan(
          name: value.plan.name,
          splitId: value.plan.splitId,
          trainingDays: reordered,
        ),
      ),
    );
  }

  Future<bool> saveTrainingSchedule(List<TrainingDay> schedule) async {
    final value = _data;
    if (value == null || _isSaving) {
      return false;
    }
    final ids = schedule.map((day) => day.id).toSet();
    if (schedule.isEmpty ||
        ids.length != schedule.length ||
        !schedule.any((day) => !day.isRestDay) ||
        schedule.any(
          (day) => day.isRestDay
              ? day.exercises.isNotEmpty || day.restDurationDays < 1
              : day.exercises.isEmpty,
        )) {
      _errorMessage = '训练安排无效';
      notifyListeners();
      return false;
    }
    final normalized = [
      for (var index = 0; index < schedule.length; index++)
        TrainingDay(
          id: schedule[index].id,
          name: schedule[index].name,
          order: index,
          exercises: schedule[index].exercises,
          isRestDay: schedule[index].isRestDay,
          restDurationDays: schedule[index].restDurationDays,
        ),
    ];
    var session = value.currentSession;
    if (!ids.contains(session.currentTrainingDayId)) {
      final firstTrainingDay = normalized.firstWhere((day) => !day.isRestDay);
      session = CurrentSession(
        currentTrainingDayId: firstTrainingDay.id,
        currentExerciseId: firstTrainingDay.exercises.first.id,
        completedSetsByExercise: session.completedSetsByExercise,
        restStartedAt: null,
        status: SessionStatus.inProgress,
        scheduleDayStartedOn: _todayKey(),
      );
    }
    return _commit(
      value.copyWith(
        plan: TrainingPlan(
          name: value.plan.name,
          splitId: value.plan.splitId,
          trainingDays: normalized,
        ),
        currentSession: session,
      ),
    );
  }

  Future<bool> resetTrainingDay(String trainingDayId) async {
    final value = _data;
    if (value == null || _isSaving) {
      return false;
    }
    final day = value.plan.trainingDays
        .where((item) => item.id == trainingDayId)
        .firstOrNull;
    if (day == null || day.exercises.isEmpty) {
      _errorMessage = '训练日无效';
      notifyListeners();
      return false;
    }
    final resetExerciseIds = day.exercises.map((item) => item.id).toSet();
    final retainedCompleted = Map<String, int>.from(
      value.currentSession.completedSetsByExercise,
    )..removeWhere((key, _) => resetExerciseIds.contains(key));
    return _commit(
      value.copyWith(
        currentSession: CurrentSession(
          currentTrainingDayId: day.id,
          currentExerciseId: day.exercises.first.id,
          completedSetsByExercise: retainedCompleted,
          restStartedAt: null,
          status: SessionStatus.inProgress,
          scheduleDayStartedOn: _todayKey(),
        ),
      ),
    );
  }

  Future<bool> refreshScheduleForToday() async {
    final value = _data;
    if (value == null || _isSaving) {
      return false;
    }
    final candidate = _advanceScheduleForToday(value);
    if (identical(candidate, value)) {
      return true;
    }
    return _commit(candidate);
  }

  int _todayKey() {
    final now = DateTime.fromMillisecondsSinceEpoch(_clock());
    return DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
  }

  AppData _advanceScheduleForToday(AppData value) {
    final days = value.plan.trainingDays;
    if (days.isEmpty) {
      return value;
    }
    final today = _todayKey();
    var startedOn = value.currentSession.scheduleDayStartedOn ?? today;
    var currentIndex = days.indexWhere(
      (day) => day.id == value.currentSession.currentTrainingDayId,
    );
    if (currentIndex < 0) {
      currentIndex = 0;
    }
    var current = days[currentIndex];
    var shouldAdvance = current.isRestDay
        ? today - startedOn >= current.restDurationDays
        : value.currentSession.status == SessionStatus.completed &&
              today > startedOn;

    if (!shouldAdvance &&
        value.currentSession.scheduleDayStartedOn != null &&
        current.id == value.currentSession.currentTrainingDayId) {
      return value;
    }

    var session = value.currentSession;
    if (current.id != session.currentTrainingDayId) {
      session = _sessionForDay(current, startedOn, session);
    }
    while (shouldAdvance) {
      startedOn += current.isRestDay ? current.restDurationDays : 1;
      currentIndex = (currentIndex + 1) % days.length;
      current = days[currentIndex];
      session = _sessionForDay(current, startedOn, session);
      shouldAdvance =
          current.isRestDay && today - startedOn >= current.restDurationDays;
    }
    if (session.scheduleDayStartedOn == null) {
      session = CurrentSession(
        currentTrainingDayId: session.currentTrainingDayId,
        currentExerciseId: session.currentExerciseId,
        completedSetsByExercise: session.completedSetsByExercise,
        restStartedAt: session.restStartedAt,
        status: session.status,
        scheduleDayStartedOn: startedOn,
      );
    }
    return value.copyWith(currentSession: session);
  }

  CurrentSession _sessionForDay(
    TrainingDay day,
    int startedOn,
    CurrentSession previous,
  ) {
    final completed = Map<String, int>.from(previous.completedSetsByExercise);
    for (final exercise in day.exercises) {
      completed.remove(exercise.id);
    }
    return CurrentSession(
      currentTrainingDayId: day.id,
      currentExerciseId: day.isRestDay ? null : day.exercises.first.id,
      completedSetsByExercise: completed,
      restStartedAt: null,
      status: day.isRestDay
          ? SessionStatus.completed
          : SessionStatus.inProgress,
      scheduleDayStartedOn: startedOn,
    );
  }

  Future<bool> _commit(AppData candidate) async {
    final previousStartedAt = _data?.currentSession.restStartedAt;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await repository.save(candidate);
      _data = candidate;
      _syncTicker();
      _syncRestNotification(previousStartedAt: previousStartedAt);
      return true;
    } catch (_) {
      _errorMessage = '保存失败，请重试';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void _syncTicker() {
    if (_data?.currentSession.restStartedAt == null) {
      _ticker?.cancel();
      _ticker = null;
    } else {
      _ticker ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => notifyListeners(),
      );
    }
  }

  void _scheduleDayBoundaryRefresh() {
    _dayBoundaryTimer?.cancel();
    final now = DateTime.fromMillisecondsSinceEpoch(_clock());
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _dayBoundaryTimer = Timer(nextDay.difference(now), () {
      unawaited(refreshScheduleForToday());
      _scheduleDayBoundaryRefresh();
    });
  }

  void _syncRestNotification({
    required int? previousStartedAt,
    bool force = false,
  }) {
    final startedAt = _data?.currentSession.restStartedAt;
    if (!force && startedAt == previousStartedAt) {
      return;
    }
    if (startedAt == null) {
      unawaited(_restTimerNotification.stop());
    } else {
      unawaited(_restTimerNotification.start(startedAt));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshScheduleForToday());
      _scheduleDayBoundaryRefresh();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _dayBoundaryTimer?.cancel();
    if (_observerRegistered) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }
}
