import 'package:flutter/material.dart';

import 'screens/training_screen.dart';
import 'screens/plan_editor_screen.dart';
import 'screens/reset_training_day_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/split_settings_screen.dart';
import 'theme/app_theme.dart';

class AppRoutes {
  const AppRoutes._();
  static const settings = '/settings';
  static const planEditor = '/settings/plan';
  static const splitSettings = '/settings/split';
  static const resetTrainingDay = '/settings/reset-day';
}

class FitnessTrainingApp extends StatelessWidget {
  const FitnessTrainingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '训练记录',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const TrainingScreen(),
      routes: {
        AppRoutes.settings: (_) => const SettingsScreen(),
        AppRoutes.planEditor: (_) => const PlanEditorScreen(),
        AppRoutes.splitSettings: (_) => const SplitSettingsScreen(),
        AppRoutes.resetTrainingDay: (_) => const ResetTrainingDayScreen(),
      },
    );
  }
}
