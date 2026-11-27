/// 题目类型枚举，序列化为 single / multiple / judge。
class QuestionType {
  static const String single = 'single';
  static const String multiple = 'multiple';
  static const String judge = 'judge';

  static const List<String> all = [single, multiple, judge];

  static String label(String type) {
    switch (type) {
      case multiple:
        return '多选题';
      case judge:
        return '判断题';
      case single:
      default:
        return '单选题';
    }
  }

  static bool isMultiple(String type) => type == multiple;
  static bool isJudge(String type) => type == judge;
}

class QuestionOption {
  final String key;
  final String text;

  const QuestionOption({required this.key, required this.text});

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      key: (json['key'] as String? ?? '').toUpperCase(),
      text: json['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'key': key, 'text': text};
}

class Question {
  final String id;
  final int number;
  final String type;
  final String content;
  final List<QuestionOption> options;
  final List<String> answer;

  const Question({
    required this.id,
    required this.number,
    required this.type,
    required this.content,
    required this.options,
    required this.answer,
  });

  bool get isMultiple => type == QuestionType.multiple;
  bool get isJudge => type == QuestionType.judge;
  String get typeLabel => QuestionType.label(type);

  /// 判断题的答案字母需要转换成可读文字，其余题型直接展示字母。
  String answerText(String letter) {
    if (isJudge) {
      return letter == 'A' ? '正确' : '错误';
    }
    return letter;
  }

  String get correctAnswerText =>
      answer.map(answerText).join(isJudge ? '、' : '');

  factory Question.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List<dynamic>? ?? const [];
    final rawAnswer = json['answer'] as List<dynamic>? ?? const [];
    return Question(
      id: json['id'] as String? ?? '',
      number: (json['number'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? QuestionType.single,
      content: json['content'] as String? ?? '',
      options: rawOptions
          .whereType<Map<String, dynamic>>()
          .map(QuestionOption.fromJson)
          .toList(),
      answer: rawAnswer.map((e) => e.toString().toUpperCase()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'type': type,
        'content': content,
        'options': options.map((e) => e.toJson()).toList(),
        'answer': answer,
      };
}
