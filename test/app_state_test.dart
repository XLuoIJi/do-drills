import 'package:flutter_test/flutter_test.dart';
import 'package:simple_quiz/models/app_data.dart';
import 'package:simple_quiz/models/practice_progress.dart';
import 'package:simple_quiz/models/question.dart';
import 'package:simple_quiz/services/storage_service.dart';
import 'package:simple_quiz/state/app_state.dart';

class _MemoryStorage extends StorageService {
  AppData data = const AppData();

  @override
  Future<void> initialize() async {}

  @override
  AppData load() => data;

  @override
  void save(AppData value) {
    data = value;
  }
}

Question _question(String id) {
  return Question(
    id: id,
    number: 1,
    type: QuestionType.single,
    content: '测试题',
    options: const [
      QuestionOption(key: 'A', text: '甲'),
      QuestionOption(key: 'B', text: '乙'),
    ],
    answer: const ['A'],
  );
}

void main() {
  test('空存储加载后可以正常新增章节和错题', () async {
    final storage = _MemoryStorage();
    final state = AppState(storage: storage);
    await state.load();

    state.addChapter(
      name: '第一章',
      questions: [_question('q1')],
      importedAt: 1,
    );

    expect(state.chapters.length, 1);
    expect(state.chapters.single.name, '第一章');

    state.recordWrong(
      question: state.chapters.single.questions.single,
      chapterId: state.chapters.single.id,
      selected: const ['B'],
    );

    expect(state.wrongCount, 1);
    expect(storage.data.chapters.length, 1);
    expect(storage.data.wrongItems.length, 1);
  });

  test('练习进度可以保存、读取和清理', () async {
    final storage = _MemoryStorage();
    final state = AppState(storage: storage);
    await state.load();
    state.addChapter(
      name: '第一章',
      questions: [_question('q1'), _question('q2')],
      importedAt: 1,
    );
    final chapterId = state.chapters.single.id;

    final progress = PracticeProgress(
      chapterId: chapterId,
      type: 'all',
      random: false,
      recite: false,
      questionIds: const ['q1', 'q2'],
      currentIndex: 1,
      selections: const {'q1': ['B']},
      answered: const ['q1'],
      wrong: const ['q1'],
      savedAt: 100,
    );
    state.saveProgress(progress);

    expect(state.progressFor(chapterId)?.currentIndex, 1);
    expect(storage.data.progress.length, 1);

    state.clearProgress(chapterId);
    expect(state.progressFor(chapterId), isNull);
  });

  test('章节被覆盖后进度同步失效', () async {
    final storage = _MemoryStorage();
    final state = AppState(storage: storage);
    await state.load();
    state.addChapter(
      name: '第一章',
      questions: [_question('q1'), _question('q2')],
      importedAt: 1,
    );
    final chapterId = state.chapters.single.id;

    state.saveProgress(PracticeProgress(
      chapterId: chapterId,
      type: 'all',
      random: false,
      recite: false,
      questionIds: const ['q1'],
      currentIndex: 0,
      selections: const {},
      answered: const [],
      wrong: const [],
      savedAt: 1,
    ));

    state.replaceChapter(
      chapterId: chapterId,
      name: '第一章',
      questions: [_question('q9')],
      importedAt: 2,
    );
    expect(state.progressFor(chapterId), isNull);

    state.deleteChapter(chapterId);
    expect(storage.data.progress, isEmpty);
  });
}
