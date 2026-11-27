/// 单个章节的练习进度（每章只保留最近一次）。
/// 用于退出练习后恢复：题目顺序、当前题号、已选/已答/答错记录。
class PracticeProgress {
  final String chapterId;

  /// 题型筛选：'all' 或 single / multiple / judge。
  final String type;

  /// 是否随机练习（决定恢复时的题目顺序语义，仅作记录）。
  final bool random;

  /// 是否背题模式。
  final bool recite;

  /// 本次练习的题目 id 顺序。
  final List<String> questionIds;

  /// 恢复时的当前题号（0 基）。
  final int currentIndex;

  /// questionId -> 用户选择的选项字母。
  final Map<String, List<String>> selections;

  /// 已作答的题目 id。
  final List<String> answered;

  /// 答错的题目 id。
  final List<String> wrong;

  /// 保存时间（毫秒）。
  final int savedAt;

  const PracticeProgress({
    required this.chapterId,
    required this.type,
    required this.random,
    required this.recite,
    required this.questionIds,
    required this.currentIndex,
    required this.selections,
    required this.answered,
    required this.wrong,
    required this.savedAt,
  });

  factory PracticeProgress.fromJson(Map<String, dynamic> json) {
    Map<String, List<String>> selections = {};
    final rawSelections = json['selections'];
    if (rawSelections is Map<String, dynamic>) {
      rawSelections.forEach((key, value) {
        if (value is List) {
          selections[key] = value
              .map((e) => e.toString().toUpperCase())
              .toList(growable: false);
        }
      });
    }
    return PracticeProgress(
      chapterId: json['chapterId'] as String? ?? '',
      type: json['type'] as String? ?? 'all',
      random: json['random'] as bool? ?? false,
      recite: json['recite'] as bool? ?? false,
      questionIds: (json['questionIds'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      currentIndex: (json['currentIndex'] as num?)?.toInt() ?? 0,
      selections: selections,
      answered: (json['answered'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      wrong: (json['wrong'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      savedAt: (json['savedAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'chapterId': chapterId,
        'type': type,
        'random': random,
        'recite': recite,
        'questionIds': questionIds,
        'currentIndex': currentIndex,
        'selections':
            selections.map((key, value) => MapEntry(key, value.toList())),
        'answered': answered,
        'wrong': wrong,
        'savedAt': savedAt,
      };
}
