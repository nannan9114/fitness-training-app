import 'package:fitness_training_app/app.dart';
import 'package:fitness_training_app/data/app_data_repository.dart';
import 'package:fitness_training_app/state/training_app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/memory_storage.dart';

void main() {
  testWidgets('分享复制代码后可粘贴创建计划，无效代码留在输入框', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
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
    await tester.tap(find.text('训练计划'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('三分化选项'));
    await tester.pumpAndSettle();
    expect(find.text('创建副本'), findsOneWidget);
    await tester.tap(find.text('分享'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制分享代码'));
    await tester.pumpAndSettle();
    expect(clipboard, startsWith('FTA1:'));
    await tester.tap(find.byTooltip('新建计划'));
    await tester.pumpAndSettle();
    expect(find.text('创建方式'), findsNothing);
    await tester.enterText(find.byType(TextFormField).last, '无效代码');
    await tester.pump();
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();
    expect(find.text('分享代码无效或版本不受支持，请复制完整代码'), findsOneWidget);
    expect(state.plans.length, 3);
    await tester.enterText(find.byType(TextFormField).last, clipboard!);
    await tester.pump();
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();
    expect(find.text('训练顺序'), findsOneWidget);
    expect(state.plans.length, 4);
    expect(state.plans.last.plan.name, '三分化');
    expect(state.data!.activePlanId, 'builtin_four');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
  testWidgets('新建分化后可改名、添加休息日、编辑项目并保存，返回时提示未保存修改', (tester) async {
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
    await tester.tap(find.text('训练计划'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('新建计划'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '上下肢');
    await tester.pump();
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();
    expect(find.text('训练顺序'), findsOneWidget);
    final id = state.plans.firstWhere((p) => p.plan.name == '上下肢').id;
    await tester.tap(find.byTooltip('修改训练日名称'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '上肢');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('有未保存的修改'), findsOneWidget);
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加休息日'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存并编辑训练项目'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '哑铃卧推');
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();
    expect(find.text('训练顺序'), findsOneWidget);
    expect(state.planById(id).plan.trainingDays.first.name, '上肢');
    expect(state.planById(id).plan.trainingDays.last.isRestDay, isTrue);
    expect(
      state.planById(id).plan.trainingDays.first.exercises.first.name,
      '哑铃卧推',
    );
    expect(state.data!.activePlanId, 'builtin_four');
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();
    expect(find.text('训练计划'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

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

    await tester.tap(find.text('训练项目'));
    await tester.pumpAndSettle();
    expect(find.text('四分化 · 选择训练日'), findsOneWidget);
    expect(find.text('保存修改'), findsOneWidget);
    expect(find.text('长按项目卡片并上下拖动排序'), findsOneWidget);

    final originalDay = state.data!.plan.trainingDays.first;
    final originalIds = originalDay.exercises.map((item) => item.id).toList();
    final cardHeight = tester
        .getSize(find.byKey(ValueKey(originalIds.first)))
        .height;
    final dragHandle = find.byIcon(Icons.drag_indicator_rounded).first;
    final gesture = await tester.startGesture(tester.getCenter(dragHandle));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
    expect(find.text('已选中项目，上下拖动后松手放置'), findsOneWidget);
    final proxy = tester.widget<Transform>(
      find.byKey(const ValueKey('exercise-drag-proxy')),
    );
    expect(proxy.transform.storage[0], greaterThan(1));
    // Move continuously, as a finger would, so the insertion gap can animate.
    for (var step = 0; step < 12; step++) {
      await gesture.moveBy(Offset(0, (cardHeight + 10) / 12));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('exercise-drag-proxy')), findsNothing);
    expect(find.text('长按项目卡片并上下拖动排序'), findsOneWidget);
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();
    expect(
      state.data!.plan.trainingDays.first.exercises.map((item) => item.id),
      [originalIds[1], originalIds[0], ...originalIds.skip(2)],
    );
    expect(state.currentExercise!.id, originalIds.first);

    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
