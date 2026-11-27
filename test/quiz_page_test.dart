import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:simple_quiz/models/app_data.dart';
import 'package:simple_quiz/models/question.dart';
import 'package:simple_quiz/pages/quiz_page.dart';
import 'package:simple_quiz/services/storage_service.dart';
import 'package:simple_quiz/state/app_state.dart';
import 'package:simple_quiz/theme.dart';

Question _singleQuestion({
  required String id,
  required String content,
  required String answer,
}) {
  return Question(
    id: id,
    number: 1,
    type: QuestionType.single,
    content: content,
    options: const [
      QuestionOption(key: 'A', text: '上海'),
      QuestionOption(key: 'B', text: '北京'),
      QuestionOption(key: 'C', text: '广州'),
    ],
    answer: [answer],
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

void main() {
  testWidgets('单选答错后显示下一题，并写入错题库', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final questions = [
      _singleQuestion(id: 'q1', content: '中华人民共和国的首都是？', answer: 'B'),
      _singleQuestion(id: 'q2', content: '第二题的内容？', answer: 'A'),
    ];
    final appState = AppState(storage: _NoopStorage());
    await appState.load();
    appState.addChapter(
      name: '测试章节',
      questions: questions,
      importedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: QuizPage(
            chapterId: appState.chapters.single.id,
            questions: questions,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('提交'), findsNothing);

    // 选择错误答案：正确项应变绿且出现下一题。
    await tester.tap(find.text('上海'));
    await tester.pump();
    expect(find.text('下一题'), findsOneWidget);
    expect(appState.wrongCount, 1);

    await tester.tap(find.text('下一题'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);

    // 最后一题答对 800ms 后弹出完成提示。
    await tester.tap(find.text('上海'));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(find.text('本节练习完成'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
  });

  testWidgets('多选未选择时提交按钮置灰', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final question = Question(
      id: 'q_multi',
      number: 1,
      type: QuestionType.multiple,
      content: '下列哪些属于可再生能源？',
      options: const [
        QuestionOption(key: 'A', text: '太阳能'),
        QuestionOption(key: 'B', text: '煤炭'),
        QuestionOption(key: 'C', text: '风能'),
      ],
      answer: const ['A', 'C'],
    );
    final appState = AppState(storage: _NoopStorage());
    await appState.load();
    appState.addChapter(
      name: '测试章节',
      questions: [question],
      importedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: QuizPage(
            chapterId: appState.chapters.single.id,
            questions: [question],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final submitFinder = find.widgetWithText(FilledButton, '提交');
    expect(submitFinder, findsOneWidget);
    expect(tester.widget<FilledButton>(submitFinder).onPressed, isNull);

    await tester.tap(find.text('太阳能'));
    await tester.pump();
    expect(tester.widget<FilledButton>(submitFinder).onPressed, isNotNull);
  });
}
