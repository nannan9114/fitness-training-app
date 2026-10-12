import 'package:fitness_training_app/app.dart';
import 'package:fitness_training_app/data/app_data_repository.dart';
import 'package:fitness_training_app/state/training_app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/memory_storage.dart';

void main() {
  testWidgets('首页完成第一组后更新进度和主按钮', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = TrainingAppState(
      repository: AppDataRepository(storage: MemoryAppDataStorage()),
      clock: () => 1770000123456,
    );
    await state.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const FitnessTrainingApp(),
      ),
    );

    expect(find.text('四分化 · 胸日'), findsOneWidget);
    expect(find.text('杠铃卧推'), findsNWidgets(2));
    expect(find.text('完成第 1 组'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('四分化 · 胸日')).dy,
      lessThan(tester.getTopLeft(find.text('当前动作')).dy),
    );
    expect(
      tester.getTopLeft(find.text('当前动作')).dy,
      lessThan(tester.getTopLeft(find.text('本日项目')).dy),
    );
    expect(
      tester.getTopLeft(find.text('本日项目')).dy,
      lessThan(tester.getTopLeft(find.text('完成第 1 组')).dy),
    );

    await tester.tap(find.widgetWithText(FilledButton, '完成第 1 组'));
    await tester.pump();
    await tester.pump();

    expect(find.text('完成第 2 组'), findsOneWidget);
    expect(find.text('1 / 4 组'), findsOneWidget);
    expect(find.text('组间休息'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets('首页可以进入训练设置及计划编辑页', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = TrainingAppState(
      repository: AppDataRepository(storage: MemoryAppDataStorage()),
    );
    await state.initialize();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const FitnessTrainingApp(),
      ),
    );

    await tester.tap(find.byTooltip('训练设置'));
    await tester.pumpAndSettle();
    expect(find.text('配置'), findsOneWidget);

    await tester.tap(find.text('训练计划'));
    await tester.pumpAndSettle();
    expect(find.text('选择训练日'), findsOneWidget);
    expect(find.text('保存训练计划'), findsOneWidget);
    expect(find.text('长按项目卡片并上下拖动排序'), findsOneWidget);

    final dragHandle = find.byIcon(Icons.drag_indicator_rounded).first;
    final gesture = await tester.startGesture(tester.getCenter(dragHandle));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    await gesture.moveBy(const Offset(0, 140));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
