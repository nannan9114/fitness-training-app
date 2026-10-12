import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/app_data_repository.dart';
import 'services/rest_timer_notification.dart';
import 'state/training_app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => TrainingAppState(
        repository: AppDataRepository(
          storage: SharedPreferencesAppDataStorage(),
        ),
        restTimerNotification: MethodChannelRestTimerNotification(),
      )..initialize(),
      child: const FitnessTrainingApp(),
    ),
  );
}
