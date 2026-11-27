import 'chapter.dart';
import 'practice_progress.dart';
import 'wrong_item.dart';

class AppData {
  final int version;
  final List<Chapter> chapters;
  final List<WrongItem> wrongItems;

  /// 每章最近一次的练习进度，key 为 chapterId。旧版本数据无此字段。
  final Map<String, PracticeProgress> progress;

  const AppData({
    this.version = 1,
    this.chapters = const [],
    this.wrongItems = const [],
    this.progress = const {},
  });

  factory AppData.fromJson(Map<String, dynamic> json) {
    final rawChapters = json['chapters'] as List<dynamic>? ?? const [];
    final rawWrongItems = json['wrongItems'] as List<dynamic>? ?? const [];
    final rawProgress = json['progress'];
    final progress = <String, PracticeProgress>{};
    if (rawProgress is Map<String, dynamic>) {
      rawProgress.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          progress[key] = PracticeProgress.fromJson(value);
        }
      });
    }
    return AppData(
      version: (json['version'] as num?)?.toInt() ?? 1,
      chapters: rawChapters
          .whereType<Map<String, dynamic>>()
          .map(Chapter.fromJson)
          .toList(),
      wrongItems: rawWrongItems
          .whereType<Map<String, dynamic>>()
          .map(WrongItem.fromJson)
          .toList(),
      progress: progress,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'chapters': chapters.map((e) => e.toJson()).toList(),
        'wrongItems': wrongItems.map((e) => e.toJson()).toList(),
        'progress': progress.map((key, value) => MapEntry(key, value.toJson())),
      };
}
