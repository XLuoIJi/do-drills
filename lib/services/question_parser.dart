import '../models/question.dart';

class ParseResult {
  final List<Question> questions;
  final int skipped;

  const ParseResult({required this.questions, required this.skipped});
}

/// 解析纯文本题库。一个文件对应一个章节。
class QuestionParser {
  static int _questionIdSeed = 0;

  static final RegExp _sectionPattern = RegExp(
    r'^[【\[]\s*(单选题|多选题|判断题|单选|多选|判断)\s*[】\]]$',
  );
  static final RegExp _questionPattern = RegExp(r'^(\d+)\s*[.、]\s*(.+)$');
  static final RegExp _optionPattern = RegExp(r'^([A-Fa-f])\s*[.、]\s*(.*)$');
  static final RegExp _answerPattern = RegExp(r'^答案\s*[：:]?\s*(.*)$');
  static final RegExp _letterPattern = RegExp(r'[A-Fa-f]');

  ParseResult parse(String source) {
    // 去掉 UTF-8 BOM，避免首行题型标记无法识别。
    final text = source.startsWith('\uFEFF') ? source.substring(1) : source;
    final questions = <Question>[];
    var skipped = 0;
    var sectionType = QuestionType.single;
    _Draft? draft;

    void finishDraft() {
      if (draft == null) return;
      final result = _buildQuestion(draft!);
      if (result == null) {
        skipped++;
      } else {
        questions.add(result);
      }
      draft = null;
    }

    for (final rawLine in text.split(RegExp(r'\r\n|\r|\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final sectionMatch = _sectionPattern.firstMatch(line);
      if (sectionMatch != null) {
        finishDraft();
        sectionType = _sectionType(sectionMatch.group(1)!);
        continue;
      }

      final questionMatch = _questionPattern.firstMatch(line);
      if (questionMatch != null) {
        finishDraft();
        draft = _Draft(
          number: int.tryParse(questionMatch.group(1)!) ?? 0,
          content: questionMatch.group(2)!.trim(),
          sectionType: sectionType,
        );
        continue;
      }

      final optionMatch = _optionPattern.firstMatch(line);
      if (optionMatch != null && draft != null) {
        final key = optionMatch.group(1)!.toUpperCase();
        draft!.options.putIfAbsent(key, () => optionMatch.group(2)!.trim());
        continue;
      }

      final answerMatch = _answerPattern.firstMatch(line);
      if (answerMatch != null && draft != null) {
        draft!.rawAnswer = answerMatch.group(1)!.trim();
        continue;
      }

      // 未识别行直接忽略。
    }

    finishDraft();
    return ParseResult(questions: questions, skipped: skipped);
  }

  String _sectionType(String raw) {
    if (raw.contains('多选')) return QuestionType.multiple;
    if (raw.contains('判断')) return QuestionType.judge;
    return QuestionType.single;
  }

  Question? _buildQuestion(_Draft draft) {
    if (draft.content.isEmpty || draft.rawAnswer == null) return null;

    var type = draft.sectionType;
    var options = <QuestionOption>[];
    var answer = <String>[];

    if (type == QuestionType.judge) {
      final normalized = _judgeAnswer(draft.rawAnswer!);
      if (normalized == null) return null;
      answer = [normalized];
      options = const [
        QuestionOption(key: 'A', text: '正确'),
        QuestionOption(key: 'B', text: '错误'),
      ];
    } else {
      options = draft.options.entries
          .map((e) => QuestionOption(key: e.key, text: e.value))
          .toList();
      // 单/多选题至少需要两个有效选项。
      if (options.length < 2) return null;

      var letters = _letterPattern
          .allMatches(draft.rawAnswer!)
          .map((m) => m.group(0)!.toUpperCase())
          .toList();
      // 去重并保持原顺序。
      letters = letters.toSet().toList();
      if (letters.isEmpty) return null;

      if (type == QuestionType.multiple && letters.length >= 2) {
        type = QuestionType.multiple;
        answer = letters;
      } else {
        // 单选题取第一个字母；多选题不足两个字母时按单选题处理。
        type = QuestionType.single;
        answer = [letters.first];
      }

      final optionKeys = options.map((e) => e.key).toSet();
      if (!answer.every(optionKeys.contains)) return null;
    }

    final id = _nextQuestionId();
    return Question(
      id: id,
      number: draft.number,
      type: type,
      content: draft.content,
      options: options,
      answer: answer,
    );
  }

  String? _judgeAnswer(String raw) {
    final value = raw.trim().toUpperCase();
    if (value == '对' ||
        value == '正确' ||
        value == '√' ||
        value == 'A' ||
        value == 'TRUE') {
      return 'A';
    }
    if (value == '错' ||
        value == '错误' ||
        value == '×' ||
        value == 'B' ||
        value == 'FALSE') {
      return 'B';
    }
    return null;
  }

  static String _nextQuestionId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    _questionIdSeed++;
    return 'q_${now}_$_questionIdSeed';
  }
}

class _Draft {
  final int number;
  final String content;
  final String sectionType;
  final Map<String, String> options = {};
  String? rawAnswer;

  _Draft({
    required this.number,
    required this.content,
    required this.sectionType,
  });
}
