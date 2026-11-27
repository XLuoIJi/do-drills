import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_quiz/models/question.dart';
import 'package:simple_quiz/services/question_parser.dart';

void main() {
  final parser = QuestionParser();

  test('解析示例题库：单选/多选/判断各 2 题', () {
    final content = File('sample_chapter1.txt').readAsStringSync();
    final result = parser.parse(content);

    expect(result.questions.length, 6);
    expect(result.skipped, 0);
    expect(result.questions.where((q) => q.type == QuestionType.single).length, 2);
    expect(
        result.questions.where((q) => q.type == QuestionType.multiple).length, 2);
    expect(result.questions.where((q) => q.type == QuestionType.judge).length, 2);

    final multiple = result.questions[2];
    expect(multiple.answer, ['A', 'C', 'D']);
    expect(multiple.options.length, 4);

    final judge = result.questions[4];
    expect(judge.answer, ['A']);
    expect(judge.options.map((e) => e.text), ['正确', '错误']);
  });

  test('缺少答案或选项的题目被跳过', () {
    const content = '''
【单选题】
1. 缺少答案
A. 甲
B. 乙

2. 缺少选项
答案：A

【多选题】
3. 答案不在选项内
A. 甲
B. 乙
答案：D
''';

    final result = parser.parse(content);
    expect(result.questions, isEmpty);
    expect(result.skipped, 3);
  });

  test('多选题答案不足两个字母时按单选处理', () {
    const content = '''
【多选题】
1. 只有一个答案
A. 甲
B. 乙
答案：B
''';

    final result = parser.parse(content);
    expect(result.questions.single.type, QuestionType.single);
    expect(result.questions.single.answer, ['B']);
  });

  test('题型标记前默认按单选题，判断题兼容多种写法', () {
    const content = '''
1. 默认题型
A. 甲
B. 乙
答案：AB

【判断题】
2. 判断题一
答案：×

3. 判断题二
答案：A
''';

    final result = parser.parse(content);
    expect(result.questions.length, 3);
    expect(result.questions[0].type, QuestionType.single);
    expect(result.questions[0].answer, ['A']);
    expect(result.questions[1].type, QuestionType.judge);
    expect(result.questions[1].answer, ['B']);
    expect(result.questions[2].answer, ['A']);
  });

  test('方括号题型标记、行首尾空格与未识别行', () {
    const content = '''
  [多选]  
1、下列选项
A、甲
B、乙
C、丙
答案：A,C
说明：这是未识别行
''';

    final result = parser.parse(content);
    expect(result.questions.length, 1);
    expect(result.questions.single.type, QuestionType.multiple);
    expect(result.questions.single.options.length, 3);
    expect(result.questions.single.answer, ['A', 'C']);
  });
}
