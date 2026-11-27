class WrongItem {
  final String questionId;
  final String chapterId;
  final int wrongCount;
  final int lastWrongAt;

  /// 最近一次答错时用户选择的选项。
  /// 需求要求错题库展示「我的答案」，因此在最小数据结构上补充该字段。
  final List<String> lastAnswer;

  const WrongItem({
    required this.questionId,
    required this.chapterId,
    required this.wrongCount,
    required this.lastWrongAt,
    this.lastAnswer = const [],
  });

  WrongItem copyWith({
    int? wrongCount,
    int? lastWrongAt,
    List<String>? lastAnswer,
  }) {
    return WrongItem(
      questionId: questionId,
      chapterId: chapterId,
      wrongCount: wrongCount ?? this.wrongCount,
      lastWrongAt: lastWrongAt ?? this.lastWrongAt,
      lastAnswer: lastAnswer ?? this.lastAnswer,
    );
  }

  factory WrongItem.fromJson(Map<String, dynamic> json) {
    final rawAnswer = json['lastAnswer'] as List<dynamic>? ?? const [];
    return WrongItem(
      questionId: json['questionId'] as String? ?? '',
      chapterId: json['chapterId'] as String? ?? '',
      wrongCount: (json['wrongCount'] as num?)?.toInt() ?? 1,
      lastWrongAt: (json['lastWrongAt'] as num?)?.toInt() ?? 0,
      lastAnswer: rawAnswer.map((e) => e.toString().toUpperCase()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'chapterId': chapterId,
        'wrongCount': wrongCount,
        'lastWrongAt': lastWrongAt,
        'lastAnswer': lastAnswer,
      };
}
