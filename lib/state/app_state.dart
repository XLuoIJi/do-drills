import 'package:flutter/foundation.dart';

import '../models/app_data.dart';
import '../models/chapter.dart';
import '../models/practice_progress.dart';
import '../models/question.dart';
import '../models/wrong_item.dart';
import '../services/storage_service.dart';

class WrongBookEntry {
  final WrongItem item;
  final Question question;
  final Chapter chapter;

  const WrongBookEntry({
    required this.item,
    required this.question,
    required this.chapter,
  });
}

/// 单一全局 ChangeNotifier。
class AppState extends ChangeNotifier {
  final StorageService _storage;

  List<Chapter> _chapters = [];
  List<WrongItem> _wrongItems = [];
  Map<String, PracticeProgress> _progress = {};
  bool _initialized = false;

  AppState({StorageService? storage}) : _storage = storage ?? StorageService();

  bool get initialized => _initialized;
  List<Chapter> get chapters => List.unmodifiable(_chapters);
  List<WrongItem> get wrongItems => List.unmodifiable(_wrongItems);
  int get wrongCount => wrongEntries.length;

  Future<void> load() async {
    await _storage.initialize();
    AppData data;
    try {
      data = _storage.load();
    } catch (_) {
      data = const AppData();
    }
    // 首次启动时数据为空，AppData 默认使用 const 空列表；必须拷贝为可变列表，
    // 否则后续 addChapter / recordWrong 会抛出 unmodifiable list 异常。
    _chapters = List<Chapter>.from(data.chapters);
    _wrongItems = List<WrongItem>.from(data.wrongItems);
    _progress = Map<String, PracticeProgress>.from(data.progress);
    _sortChapters();
    _removeOrphanProgress();
    final removed = _removeOrphanWrongItems();
    _initialized = true;
    if (removed) {
      _persist();
    }
  }

  void addChapter({
    required String name,
    required List<Question> questions,
    required int importedAt,
  }) {
    _chapters.add(Chapter(
      id: _nextChapterId(),
      name: name,
      importedAt: importedAt,
      questions: questions,
    ));
    _sortChapters();
    _persist();
    notifyListeners();
  }

  void replaceChapter({
    required String chapterId,
    required String name,
    required List<Question> questions,
    required int importedAt,
  }) {
    final index = _chapters.indexWhere((chapter) => chapter.id == chapterId);
    if (index < 0) {
      addChapter(name: name, questions: questions, importedAt: importedAt);
      return;
    }
    _wrongItems.removeWhere((item) => item.chapterId == chapterId);
    _progress.remove(chapterId);
    _chapters[index] = Chapter(
      id: chapterId,
      name: name,
      importedAt: importedAt,
      questions: questions,
    );
    _sortChapters();
    _persist();
    notifyListeners();
  }

  Chapter? findChapterByName(String name) {
    for (final chapter in _chapters) {
      if (chapter.name == name) return chapter;
    }
    return null;
  }

  Chapter? findChapterById(String chapterId) {
    for (final chapter in _chapters) {
      if (chapter.id == chapterId) return chapter;
    }
    return null;
  }

  /// 某章节最近一次保存的练习进度；题目已被覆盖/删除时视为无效返回 null。
  PracticeProgress? progressFor(String chapterId) {
    final progress = _progress[chapterId];
    if (progress == null) return null;
    final chapter = findChapterById(chapterId);
    if (chapter == null) return null;
    final validIds = {
      for (final question in chapter.questions) question.id,
    };
    if (!progress.questionIds.every(validIds.contains)) return null;
    return progress;
  }

  /// 保存/覆盖某章的练习进度。只写盘不广播，避免答题过程中的频繁重建。
  void saveProgress(PracticeProgress progress) {
    _progress[progress.chapterId] = progress;
    _persist();
  }

  void clearProgress(String chapterId) {
    if (_progress.remove(chapterId) == null) return;
    _persist();
  }

  /// 章节被覆盖或删除时同步清理进度。
  void _removeOrphanProgress() {
    _progress.removeWhere((chapterId, _) => findChapterById(chapterId) == null);
  }

  void deleteChapter(String chapterId) {
    _chapters.removeWhere((chapter) => chapter.id == chapterId);
    _wrongItems.removeWhere((item) => item.chapterId == chapterId);
    _progress.remove(chapterId);
    _persist();
    notifyListeners();
  }

  void recordWrong({
    required Question question,
    required String chapterId,
    required Iterable<String> selected,
  }) {
    final answer = selected.map((e) => e.toUpperCase()).toList()..sort();
    final now = DateTime.now().millisecondsSinceEpoch;
    final index =
        _wrongItems.indexWhere((item) => item.questionId == question.id);
    if (index >= 0) {
      _wrongItems[index] = _wrongItems[index].copyWith(
        wrongCount: _wrongItems[index].wrongCount + 1,
        lastWrongAt: now,
        lastAnswer: answer,
      );
    } else {
      _wrongItems.add(WrongItem(
        questionId: question.id,
        chapterId: chapterId,
        wrongCount: 1,
        lastWrongAt: now,
        lastAnswer: answer,
      ));
    }
    _persist();
    notifyListeners();
  }

  void removeWrong(String questionId) {
    _wrongItems.removeWhere((item) => item.questionId == questionId);
    _persist();
    notifyListeners();
  }

  void clearWrongBook() {
    _wrongItems.clear();
    _persist();
    notifyListeners();
  }

  /// 按最近答错时间倒序，并过滤掉章节/题目已被删除的记录。
  List<WrongBookEntry> get wrongEntries {
    final chapterMap = {for (final c in _chapters) c.id: c};
    final questionMap = <String, Question>{};
    for (final chapter in _chapters) {
      for (final question in chapter.questions) {
        questionMap[question.id] = question;
      }
    }

    final entries = <WrongBookEntry>[];
    for (final item in _wrongItems) {
      final chapter = chapterMap[item.chapterId];
      final question = questionMap[item.questionId];
      if (chapter == null || question == null) continue;
      entries.add(WrongBookEntry(
        item: item,
        question: question,
        chapter: chapter,
      ));
    }
    entries.sort((a, b) => b.item.lastWrongAt.compareTo(a.item.lastWrongAt));
    return entries;
  }

  bool _removeOrphanWrongItems() {
    final chapterIds = _chapters.map((e) => e.id).toSet();
    final questionIds = <String>{
      for (final chapter in _chapters)
        for (final question in chapter.questions) question.id,
    };
    final before = _wrongItems.length;
    _wrongItems.removeWhere(
      (item) =>
          !chapterIds.contains(item.chapterId) ||
          !questionIds.contains(item.questionId),
    );
    return before != _wrongItems.length;
  }

  void _sortChapters() {
    _chapters.sort((a, b) => b.importedAt.compareTo(a.importedAt));
  }

  void _persist() {
    _storage.save(AppData(
      chapters: _chapters,
      wrongItems: _wrongItems,
      progress: _progress,
    ));
  }

  static int _chapterSeed = 0;

  static String _nextChapterId() {
    _chapterSeed++;
    return 'ch_${DateTime.now().millisecondsSinceEpoch}_$_chapterSeed';
  }
}
