import 'package:flutter/services.dart';

abstract interface class RestTimerNotification {
  Future<void> start(int startedAt);
  Future<void> stop();
}

class MethodChannelRestTimerNotification implements RestTimerNotification {
  static const _channel = MethodChannel(
    'com.megumin.fitness_training_app/rest_timer',
  );

  @override
  Future<void> start(int startedAt) async {
    try {
      await _channel.invokeMethod<void>('start', {'startedAt': startedAt});
    } on PlatformException {
      // The in-app timer remains authoritative if Android rejects a notification.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException {
      // A missing notification is already equivalent to the desired state.
    }
  }
}

class NoopRestTimerNotification implements RestTimerNotification {
  const NoopRestTimerNotification();

  @override
  Future<void> start(int startedAt) async {}

  @override
  Future<void> stop() async {}
}
