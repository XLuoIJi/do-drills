import 'question.dart';

class Chapter {
  final String id;
  final String name;
  final int importedAt;
  final List<Question> questions;

  const Chapter({
    required this.id,
    required this.name,
    required this.importedAt,
    required this.questions,
  });

  int get singleCount =>
      questions.where((q) => q.type == QuestionType.single).length;
  int get multipleCount =>
      questions.where((q) => q.type == QuestionType.multiple).length;
  int get judgeCount =>
      questions.where((q) => q.type == QuestionType.judge).length;

  String get statisticsText =>
      '单选 $singleCount · 多选 $multipleCount · 判断 $judgeCount';

  /// 当前章节实际包含的题型（用于练习设置中隐藏不存在的题型）。
  List<String> get availableTypes {
    final types = <String>[];
    for (final type in QuestionType.all) {
      if (questions.any((q) => q.type == type)) {
        types.add(type);
      }
    }
    return types;
  }

  factory Chapter.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'] as List<dynamic>? ?? const [];
    return Chapter(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      importedAt: (json['importedAt'] as num?)?.toInt() ?? 0,
      questions: rawQuestions
          .whereType<Map<String, dynamic>>()
          .map(Question.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'importedAt': importedAt,
        'questions': questions.map((e) => e.toJson()).toList(),
      };
}
