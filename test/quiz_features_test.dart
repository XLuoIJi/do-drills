import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:simple_quiz/models/app_data.dart';
import 'package:simple_quiz/models/question.dart';
import 'package:simple_quiz/pages/quiz_page.dart';
import 'package:simple_quiz/services/storage_service.dart';
import 'package:simple_quiz/state/app_state.dart';
import 'package:simple_quiz/theme.dart';
import 'package:simple_quiz/widgets/practice_setting_sheet.dart';

Question _singleQuestion({required String id, required String content}) {
  return Question(
    id: id,
    number: 1,
    type: QuestionType.single,
    content: content,
    options: const [
      QuestionOption(key: 'A', text: '甲'),
      QuestionOption(key: 'B', text: '乙'),
    ],
    answer: const ['A'],
  );
}

class _NoopStorage extends StorageService {
  @override
  Future<void> initialize() async {}

  @override
  AppData load() => const AppData();

  @override
  void save(AppData data) {}
}

Widget _wrap(AppState appState, Widget child) {
  return ChangeNotifierProvider<AppState>.value(
    value: appState,
    child: MaterialApp(theme: buildAppTheme(), home: child),
  );
}

Future<AppState> _stateWithChapter(List<Question> questions) async {
  final appState = AppState(storage: _NoopStorage());
  await appState.load();
  appState.addChapter(
    name: '测试章节',
    questions: questions,
    importedAt: DateTime.now().millisecondsSinceEpoch,
  );
  return appState;
}

void main() {
  testWidgets('未作答也可自由滑动切换题目', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final questions = [
      _singleQuestion(id: 'q1', content: '第一题'),
      _singleQuestion(id: 'q2', content: '第二题'),
    ];
    final appState = await _stateWithChapter(questions);

    await tester.pumpWidget(_wrap(
      appState,
      QuizPage(
        chapterId: appState.chapters.single.id,
        questions: questions,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('练习进度自动保存并可恢复', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final questions = [
      _singleQuestion(id: 'q1', content: '第一题'),
      _singleQuestion(id: 'q2', content: '第二题'),
    ];
    final appState = await _stateWithChapter(questions);
    final chapterId = appState.chapters.single.id;

    await tester.pumpWidget(_wrap(
      appState,
      QuizPage(chapterId: chapterId, questions: questions),
    ));
    await tester.pumpAndSettle();

    // 答错第一题，等待防抖写盘。
    await tester.tap(find.text('乙'));
    await tester.pump(const Duration(milliseconds: 400));

    // 直接退出（保留进度）。
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('退出'));
    await tester.pumpAndSettle();

    final progress = appState.progressFor(chapterId);
    expect(progress, isNotNull);
    expect(progress!.answered, contains('q1'));
    expect(progress.wrong, contains('q1'));
    expect(progress.currentIndex, 0);

    // 从进度恢复：仍在第一题，且显示下一题按钮。
    await tester.pumpWidget(_wrap(
      appState,
      QuizPage(
        chapterId: chapterId,
        questions: questions,
        initialProgress: progress,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('下一题'), findsOneWidget);
    expect(appState.wrongCount, 1);
  });

  testWidgets('题号预览面板可跳题且不遮挡题目', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final questions = [
      _singleQuestion(id: 'q1', content: '第一题'),
      _singleQuestion(id: 'q2', content: '第二题'),
      _singleQuestion(id: 'q3', content: '第三题'),
    ];
    final appState = await _stateWithChapter(questions);

    await tester.pumpWidget(_wrap(
      appState,
      QuizPage(
        chapterId: appState.chapters.single.id,
        questions: questions,
      ),
    ));
    await tester.pumpAndSettle();

    // 题目区域在面板展开前后都可见。
    expect(find.text('第一题'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('题号预览'), findsOneWidget);
    expect(find.text('第一题'), findsOneWidget);

    // 点击题号 3 跳转。
    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text('第三题'), findsOneWidget);

    // 再点一次按钮收起面板。
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('题号预览'), findsNothing);
  });

  testWidgets('背题模式直接显示答案且不可作答', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final questions = [
      _singleQuestion(id: 'q1', content: '第一题'),
    ];
    final appState = await _stateWithChapter(questions);

    await tester.pumpWidget(_wrap(
      appState,
      QuizPage(
        chapterId: appState.chapters.single.id,
        questions: questions,
        recite: true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('背题'), findsOneWidget);
    expect(find.textContaining('答案：'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '提交'), findsNothing);

    // 点击选项不应产生作答。
    await tester.tap(find.text('乙'));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, '下一题'), findsNothing);
    expect(appState.wrongCount, 0);
  });

  testWidgets('真实考试全部完成时展示成绩', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final questions = [
      _singleQuestion(id: 'q1', content: '第一题'),
      _singleQuestion(id: 'q2', content: '第二题'),
    ];
    final appState = await _stateWithChapter(questions);

    await tester.pumpWidget(_wrap(
      appState,
      QuizPage(
        chapterId: appState.chapters.single.id,
        questions: questions,
        mode: PracticeMode.exam,
        examMinutes: 5,
      ),
    ));
    await tester.pump();

    // 答对两题：800ms 反馈后自动进入下一题/结算。
    await tester.tap(find.text('甲'));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.tap(find.text('甲'));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('考试结束'), findsOneWidget);
    expect(find.textContaining('得分'), findsOneWidget);
    expect(find.textContaining('答对 2 / 已答 2 / 共 2'), findsOneWidget);

    await tester.tap(find.text('结束'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('考试结束'), findsNothing);
  });

  testWidgets('错误率超过60%且完成过半时询问是否继续', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final questions = [
      _singleQuestion(id: 'q1', content: '第一题'),
      _singleQuestion(id: 'q2', content: '第二题'),
      _singleQuestion(id: 'q3', content: '第三题'),
    ];
    final appState = await _stateWithChapter(questions);

    await tester.pumpWidget(_wrap(
      appState,
      QuizPage(
        chapterId: appState.chapters.single.id,
        questions: questions,
        mode: PracticeMode.exam,
        examMinutes: 5,
      ),
    ));
    await tester.pump();

    // 前两题都答错：完成 2/3 超过一半，错误率 100%。
    await tester.tap(find.text('乙'));
    await tester.pump();
    await tester.tap(find.text('下一题'));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('乙'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('正确率过低'), findsOneWidget);

    // 选择不继续，直接查看成绩。
    await tester.tap(find.text('不，查看成绩'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('考试结束'), findsOneWidget);
    expect(find.text('答对 0 / 已答 2 / 共 3'), findsOneWidget);

    await tester.tap(find.text('查看详情'));
    await tester.pump(const Duration(milliseconds: 400));
    // 回顾模式：可自由滑动查看。
    expect(find.text('考试结束'), findsNothing);
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('3 / 3'), findsOneWidget);
    // 返回直接退出，不再弹确认框。
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(QuizPage), findsNothing);
  });
}
