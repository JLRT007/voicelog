import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicelog/main.dart';

void main() {
  testWidgets('VoiceLog renders the floating voice home screen', (
    tester,
  ) async {
    final store = LocalRecordStore.inMemory([]);

    await tester.pumpWidget(VoiceLogApp(store: store));

    await tester.pumpAndSettle();

    expect(find.text('待办'), findsWidgets);
    expect(find.text('今日待办'), findsNothing);
    expect(find.text('时间'), findsOneWidget);
    expect(find.text('待办事项'), findsOneWidget);
    expect(find.byType(Checkbox), findsWidgets);
    expect(find.text('记录'), findsWidgets);
    expect(find.text('总览'), findsOneWidget);
    expect(find.text('本周'), findsNothing);
    expect(find.text('直接记录'), findsNothing);
    expect(find.text('智能拆分'), findsNothing);
    expect(RecordCategory.next.label, '后续计划');
    expect(find.text('下周计划'), findsNothing);
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
  });

  testWidgets('todo card shows today and tomorrow groups', (tester) async {
    final now = DateTime.now();
    final todayTodo = DailyTodo.create(
      title: '完成今日清单',
      scheduledAt: DateTime(now.year, now.month, now.day, 9),
    );
    final tomorrow = DateUtils.dateOnly(now).add(const Duration(days: 1));
    final tomorrowTodo = DailyTodo.create(
      title: '准备明日会议',
      scheduledAt: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10),
    );
    final store = LocalRecordStore.inMemory([], [todayTodo, tomorrowTodo]);

    await tester.pumpWidget(VoiceLogApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('今天'), findsWidgets);
    expect(find.text('明天'), findsOneWidget);
    expect(find.text('完成今日清单'), findsOneWidget);
    expect(find.text('准备明日会议'), findsOneWidget);
  });

  testWidgets('overdue incomplete todo rolls over to today', (tester) async {
    final now = DateTime.now();
    final yesterday = DateUtils.dateOnly(now).subtract(const Duration(days: 1));
    final overdue = DailyTodo.create(
      title: '补交昨天材料',
      scheduledAt: DateTime(yesterday.year, yesterday.month, yesterday.day, 15),
    );
    final store = LocalRecordStore.inMemory([], [overdue]);

    await tester.pumpWidget(VoiceLogApp(store: store));
    await tester.pumpAndSettle();

    final todayTodos = store.todosForDay(now);
    expect(todayTodos, hasLength(1));
    expect(todayTodos.single.title, '补交昨天材料');
    expect(todayTodos.single.scheduledAt.hour, 15);
    expect(find.text('补交昨天材料'), findsOneWidget);
  });

  testWidgets('overdue completed todo does not roll over or display', (
    tester,
  ) async {
    final now = DateTime.now();
    final yesterday = DateUtils.dateOnly(now).subtract(const Duration(days: 1));
    final completed = DailyTodo.create(
      title: '已经完成的旧事项',
      scheduledAt: DateTime(yesterday.year, yesterday.month, yesterday.day, 16),
      completed: true,
    );
    final store = LocalRecordStore.inMemory([], [completed]);

    await tester.pumpWidget(VoiceLogApp(store: store));
    await tester.pumpAndSettle();

    expect(store.todosForDay(now), isEmpty);
    expect(store.todosForDay(yesterday), hasLength(1));
    expect(find.text('已经完成的旧事项'), findsNothing);
  });

  testWidgets('todo checkbox marks an item as completed', (tester) async {
    final todo = DailyTodo.create(title: '确认发布清单', scheduledAt: DateTime.now());
    final store = LocalRecordStore.inMemory([], [todo]);

    await tester.pumpWidget(VoiceLogApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(store.todosForDay(DateTime.now()).single.completed, isTrue);
  });

  testWidgets('home todo checkbox updates without flashing loading state', (
    tester,
  ) async {
    final todo = DailyTodo.create(title: '稳定完成状态', scheduledAt: DateTime.now());
    final store = LocalRecordStore.inMemory([], [todo]);

    await tester.pumpWidget(VoiceLogApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('稳定完成状态'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('稳定完成状态'), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(store.todosForDay(DateTime.now()).single.completed, isTrue);
  });

  testWidgets('overview tab shows calendar task overview', (tester) async {
    final store = LocalRecordStore.inMemory([], []);

    await tester.pumpWidget(VoiceLogApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('总览'));
    await tester.pumpAndSettle();

    expect(find.text('任务总览'), findsOneWidget);
    expect(find.text('点击日历中的某一天，查看这一天有什么任务待办'), findsOneWidget);
    expect(find.text('一'), findsOneWidget);
    expect(find.text('日'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('这一天还没有待办。'), findsOneWidget);
  });

  testWidgets('overview calendar shows tasks for selected day', (tester) async {
    final now = DateTime.now();
    final todayTodo = DailyTodo.create(
      title: '总览页今日待办',
      scheduledAt: DateTime(now.year, now.month, now.day, 11),
    );
    final store = LocalRecordStore.inMemory([], [todayTodo]);

    await tester.pumpWidget(VoiceLogApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('总览'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('总览页今日待办'), findsOneWidget);
  });

  testWidgets('overview checkbox marks selected day todo as completed', (
    tester,
  ) async {
    final now = DateTime.now();
    final todo = DailyTodo.create(
      title: '在总览页确认完成',
      scheduledAt: DateTime(now.year, now.month, now.day, 13),
    );
    final store = LocalRecordStore.inMemory([], [todo]);

    await tester.pumpWidget(VoiceLogApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('总览'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(find.text('在总览页确认完成'), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
    expect(store.todosForDay(now).single.completed, isTrue);
  });

  test('TodoDateParser resolves next Wednesday from a fixed base date', () {
    final schedule = TodoDateParser.parse(
      '下周三下午3点整理项目材料',
      baseDate: DateTime(2026, 5, 20),
      now: DateTime(2026, 5, 20, 8, 30),
    );

    expect(schedule.title, '整理项目材料');
    expect(schedule.hasExplicitDate, isTrue);
    expect(schedule.scheduledAt, DateTime(2026, 5, 27, 15));
  });

  test('TodoDateParser defaults to 6 AM without explicit time', () {
    final schedule = TodoDateParser.parse(
      '明天确认发布清单',
      baseDate: DateTime(2026, 5, 20),
      now: DateTime(2026, 5, 20, 18, 30),
    );

    expect(schedule.title, '确认发布清单');
    expect(schedule.scheduledAt, DateTime(2026, 5, 21, 6));
  });

  test('TodoDateParser keeps explicit hour in todo time', () {
    final schedule = TodoDateParser.parse(
      '明天上午10点确认发布清单',
      baseDate: DateTime(2026, 5, 20),
      now: DateTime(2026, 5, 20, 18, 30),
    );

    expect(schedule.title, '确认发布清单');
    expect(schedule.scheduledAt, DateTime(2026, 5, 21, 10));
  });
}
