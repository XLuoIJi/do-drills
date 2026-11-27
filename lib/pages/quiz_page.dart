import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/practice_progress.dart';
import '../models/question.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/practice_setting_sheet.dart';
import '../widgets/type_tag.dart';

class QuizPage extends StatefulWidget {
  final String chapterId;
  final List<Question> questions;
  final PracticeMode mode;
  final bool recite;
  final int examMinutes;

  /// 题型筛选，随练习进度一起保存。
  final String practiceType;

  /// 非空表示从上次进度恢复。
  final PracticeProgress? initialProgress;

  const QuizPage({
    super.key,
    required this.chapterId,
    required this.questions,
    this.mode = PracticeMode.order,
    this.recite = false,
    this.examMinutes = 45,
    this.practiceType = 'all',
    this.initialProgress,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  late final PageController _pageController;
  int _currentIndex = 0;

  final Map<String, Set<String>> _selections = {};
  final Set<String> _answered = {};
  final Set<String> _wrong = {};

  Timer? _autoTimer;
  Timer? _progressDebounce;
  bool _completionShown = false;
  bool _exitDialogOpen = false;
  bool _promptOpen = false;

  /// 题号预览面板是否展开。
  bool _previewOpen = false;

  // ---- 考试模式 ----
  Timer? _examTicker;
  DateTime? _examStartedAt;
  int _examRemainingSeconds = 0;
  bool _timeUpPrompted = false;
  bool _lowRatePrompted = false;

  /// 考试已结束（结果已展示，可能处于回顾状态）。
  bool _examFinished = false;

  Question get _currentQuestion => widget.questions[_currentIndex];
  bool get _isExam => widget.mode == PracticeMode.exam;
  bool get _locked => widget.recite || _examFinished;

  @override
  void initState() {
    super.initState();
    _restoreProgress();
    _pageController = PageController(initialPage: _currentIndex);
    if (_isExam) {
      _examStartedAt = DateTime.now();
      _examRemainingSeconds = widget.examMinutes * 60;
      _examTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _examFinished) return;
        setState(() => _examRemainingSeconds--);
        if (_examRemainingSeconds <= 0 && !_timeUpPrompted) {
          _timeUpPrompted = true;
          _promptExamInterrupt('time');
        }
      });
    }
  }

  void _restoreProgress() {
    final progress = widget.initialProgress;
    if (progress == null) return;
    for (final entry in progress.selections.entries) {
      _selections[entry.key] = Set<String>.from(entry.value);
    }
    _answered.addAll(progress.answered);
    _wrong.addAll(progress.wrong);
    if (progress.questionIds.isNotEmpty) {
      _currentIndex = progress.currentIndex
          .clamp(0, progress.questionIds.length - 1)
          .toInt();
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _progressDebounce?.cancel();
    _examTicker?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Set<String> _selectedFor(Question question) =>
      _selections[question.id] ?? <String>{};

  bool _isAnswered(Question question) => _answered.contains(question.id);
  bool _isWrong(Question question) => _wrong.contains(question.id);

  // ---------- 练习进度 ----------

  /// 进度保存做 300ms 防抖，避免快速滑动时频繁写盘。
  void _persistProgressSoon() {
    if (_isExam) return;
    _progressDebounce?.cancel();
    _progressDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _persistProgress();
    });
  }

  void _persistProgress() {
    if (_isExam || !mounted) return;
    context.read<AppState>().saveProgress(PracticeProgress(
          chapterId: widget.chapterId,
          type: widget.practiceType,
          random: widget.mode == PracticeMode.random,
          recite: widget.recite,
          questionIds: [for (final q in widget.questions) q.id],
          currentIndex: _currentIndex,
          selections: {
            for (final entry in _selections.entries)
              entry.key: entry.value.toList(),
          },
          answered: _answered.toList(),
          wrong: _wrong.toList(),
          savedAt: DateTime.now().millisecondsSinceEpoch,
        ));
  }

  // ---------- 答题与判题 ----------

  void _onSingleTap(Question question, String key) {
    if (_locked || _isAnswered(question)) return;
    setState(() {
      _selections[question.id] = {key};
    });
    _judge(question);
  }

  void _onMultipleTap(Question question, String key) {
    if (_locked || _isAnswered(question)) return;
    setState(() {
      final selected = Set<String>.from(_selectedFor(question));
      if (!selected.remove(key)) {
        selected.add(key);
      }
      _selections[question.id] = selected;
    });
    _persistProgressSoon();
  }

  void _judge(Question question) {
    if (_locked || _isAnswered(question)) return;
    final selected = Set<String>.from(_selectedFor(question));
    if (selected.isEmpty) return;
    final answer = question.answer.toSet();
    final isCorrect =
        selected.length == answer.length && selected.containsAll(answer);

    setState(() {
      _answered.add(question.id);
      if (!isCorrect) {
        _wrong.add(question.id);
      }
    });

    if (!isCorrect) {
      context.read<AppState>().recordWrong(
            question: question,
            chapterId: widget.chapterId,
            selected: selected,
          );
      _persistProgressSoon();
      if (_isExam) {
        _checkExamLowRate();
        if (_answered.length == widget.questions.length) {
          _scheduleFinish();
        }
      }
      return;
    }
    _persistProgressSoon();
    if (_isExam) {
      _checkExamLowRate();
    }
    _scheduleAutoAdvance(question.id);
  }

  void _scheduleAutoAdvance(String questionId) {
    _autoTimer?.cancel();
    _autoTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (_isExam && _answered.length == widget.questions.length) {
        _finishExam();
        return;
      }
      if (widget.questions[_currentIndex].id != questionId) return;
      _goNext();
    });
  }

  /// 全部答完但停留在最后一题（答错）时，稍等片刻直接结算。
  void _scheduleFinish() {
    _autoTimer?.cancel();
    _autoTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted || _examFinished) return;
      _finishExam();
    });
  }

  void _checkExamLowRate() {
    if (!_isExam || _examFinished || _lowRatePrompted || _promptOpen) return;
    final total = widget.questions.length;
    final answered = _answered.length;
    if (answered * 2 <= total) return;
    if (answered == 0) return;
    final wrongRate = _wrong.length / answered;
    if (wrongRate > 0.6) {
      _lowRatePrompted = true;
      _promptExamInterrupt('rate');
    }
  }

  void _goNext() {
    _autoTimer?.cancel();
    if (_currentIndex >= widget.questions.length - 1) {
      if (_isExam) {
        _finishExam();
      } else {
        _showCompletion();
      }
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _showCompletion() async {
    if (_completionShown) return;
    _completionShown = true;
    _autoTimer?.cancel();
    _progressDebounce?.cancel();

    final state = context.read<AppState>();
    state.clearProgress(widget.chapterId);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('本节练习完成'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // ---------- 考试模式 ----------

  Future<void> _promptExamInterrupt(String reason) async {
    if (_examFinished || _promptOpen || !mounted) return;
    _promptOpen = true;
    _autoTimer?.cancel();

    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(reason == 'time' ? '考试时间已到' : '正确率过低'),
          content: Text(reason == 'time'
              ? '本场考试时间已用完，是否继续答题？'
              : '当前错误率已超过 60%，是否继续答题？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('不，查看成绩'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('继续答题'),
            ),
          ],
        );
      },
    );

    _promptOpen = false;
    if (!mounted) return;
    if (shouldContinue != true) {
      _finishExam();
    }
  }

  Future<void> _finishExam() async {
    if (_examFinished || !mounted) return;
    _examFinished = true;
    _autoTimer?.cancel();
    _progressDebounce?.cancel();
    _examTicker?.cancel();
    setState(() {});

    final total = widget.questions.length;
    final answered = _answered.length;
    final correct = answered - _wrong.length;
    final score = total == 0 ? 0.0 : correct * 100.0 / total;
    final accuracy = answered == 0 ? 0.0 : correct * 100.0 / answered;
    final elapsed = _examStartedAt == null
        ? 0
        : DateTime.now().difference(_examStartedAt!).inSeconds;

    final stayForReview = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('考试结束'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ResultRow(label: '用时', value: _formatClock(elapsed)),
              _ResultRow(
                  label: '答题情况', value: '答对 $correct / 已答 $answered / 共 $total'),
              _ResultRow(
                  label: '正确率', value: '${accuracy.toStringAsFixed(1)}%'),
              _ResultRow(
                label: '得分',
                value: '${_formatScore(score)} / 100',
                highlight: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('结束'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('查看详情'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (stayForReview == true) return;
    Navigator.of(context).pop();
  }

  String _formatScore(double score) {
    return score == score.roundToDouble()
        ? score.toInt().toString()
        : score.toStringAsFixed(1);
  }

  String _formatClock(int seconds) {
    final m = seconds.abs() ~/ 60;
    final s = seconds.abs() % 60;
    final sign = seconds < 0 ? '+' : '';
    return '$sign${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ---------- 退出 ----------

  Future<void> _requestExit() async {
    if (_examFinished) {
      Navigator.of(context).pop();
      return;
    }
    if (_exitDialogOpen) return;
    _exitDialogOpen = true;
    _autoTimer?.cancel();

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_isExam ? '退出考试？' : '退出练习？'),
          content: Text(_isExam
              ? '退出后本次考试成绩将不保存。'
              : '退出后下次可从当前进度继续。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('退出'),
            ),
          ],
        );
      },
    );

    _exitDialogOpen = false;
    if (shouldExit == true && mounted) {
      _progressDebounce?.cancel();
      _persistProgress();
      Navigator.of(context).pop();
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final question = _currentQuestion;
    final showSubmit = question.isMultiple &&
        !_isAnswered(question) &&
        !_locked;
    final showNext = _isWrong(question) && !_locked;

    final fabBottom = 14.0 +
        (_previewOpen ? 158.0 : 0.0) +
        ((showSubmit || showNext) ? 86.0 : 0.0);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _requestExit();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回',
            onPressed: _requestExit,
            icon: const Icon(Icons.arrow_back),
          ),
          title: _buildTitle(),
          actions: [
            if (widget.recite)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Center(
                  child: Text(
                    '背题',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: kPagePadding),
              child: Center(child: TypeTag(type: question.type)),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const ClampingScrollPhysics(),
                    onPageChanged: (index) {
                      _autoTimer?.cancel();
                      setState(() => _currentIndex = index);
                      _persistProgressSoon();
                    },
                    itemCount: widget.questions.length,
                    itemBuilder: (context, index) {
                      final item = widget.questions[index];
                      return _QuestionView(
                        question: item,
                        selected: _selectedFor(item),
                        answered: _isAnswered(item) || widget.recite,
                        recite: widget.recite,
                        onTap: item.isMultiple
                            ? (key) => _onMultipleTap(item, key)
                            : (key) => _onSingleTap(item, key),
                      );
                    },
                  ),
                ),
                if (_previewOpen)
                  _PreviewPanel(
                    questions: widget.questions,
                    currentIndex: _currentIndex,
                    answered: _answered,
                    wrong: _wrong,
                    onSelect: (index) {
                      if (index == _currentIndex) return;
                      _autoTimer?.cancel();
                      // 直接跳转，避免逐页经过中间页面造成卡顿。
                      _pageController.jumpToPage(index);
                      setState(() => _currentIndex = index);
                      _persistProgressSoon();
                    },
                  ),
                if (showSubmit || showNext)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        kPagePadding,
                        8,
                        kPagePadding,
                        kPagePadding,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: showNext
                              ? _goNext
                              : (_selectedFor(question).isEmpty
                                  ? null
                                  : () => _judge(question)),
                          child: Text(showNext ? '下一题' : '提交'),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Positioned(
              right: 14,
              bottom: fabBottom,
              child: SizedBox(
                width: 44,
                height: 44,
                child: FloatingActionButton(
                  tooltip: _previewOpen ? '收起题号' : '题号预览',
                  onPressed: () => setState(() => _previewOpen = !_previewOpen),
                  child: Icon(
                    _previewOpen ? Icons.close : Icons.grid_view,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    final base = '${_currentIndex + 1} / ${widget.questions.length}';
    if (!_isExam) {
      return Text(base);
    }
    final urgent = _examRemainingSeconds <= 60;
    return Text(
      '$base  ·  ${_formatClock(_examRemainingSeconds)}',
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: urgent ? AppColors.wrong : AppColors.textPrimary,
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _ResultRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: highlight ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部题号预览面板：固定高度内嵌在布局中，不遮挡题目区域。
class _PreviewPanel extends StatelessWidget {
  final List<Question> questions;
  final int currentIndex;
  final Set<String> answered;
  final Set<String> wrong;
  final ValueChanged<int> onSelect;

  const _PreviewPanel({
    required this.questions,
    required this.currentIndex,
    required this.answered,
    required this.wrong,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 144,
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(kPagePadding, 8, kPagePadding, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '题号预览',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '已答 ${answered.length} / ${questions.length}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < questions.length; i++)
                    _buildNumberChip(i),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberChip(int index) {
    final question = questions[index];
    final isCurrent = index == currentIndex;
    final isWrong = wrong.contains(question.id);
    final isAnswered = answered.contains(question.id);

    Color background = Colors.white;
    Color foreground = AppColors.textSecondary;
    Color borderColor = AppColors.border;
    FontWeight fontWeight = FontWeight.w500;

    if (isWrong) {
      background = AppColors.wrong.withValues(alpha: 0.12);
      foreground = AppColors.wrong;
      borderColor = AppColors.wrong.withValues(alpha: 0.5);
      fontWeight = FontWeight.w700;
    } else if (isAnswered) {
      background = AppColors.correct.withValues(alpha: 0.12);
      foreground = AppColors.correct;
      borderColor = AppColors.correct.withValues(alpha: 0.5);
      fontWeight = FontWeight.w700;
    }
    if (isCurrent) {
      borderColor = AppColors.primary;
      background = AppColors.primary.withValues(alpha: 0.12);
      foreground = AppColors.primary;
      fontWeight = FontWeight.w700;
    }

    return InkWell(
      onTap: () => onSelect(index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 40,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: Text(
          '${index + 1}',
          style: TextStyle(fontSize: 13, fontWeight: fontWeight, color: foreground),
        ),
      ),
    );
  }
}

class _QuestionView extends StatelessWidget {
  final Question question;
  final Set<String> selected;
  final bool answered;
  final bool recite;
  final ValueChanged<String> onTap;

  const _QuestionView({
    required this.question,
    required this.selected,
    required this.answered,
    required this.recite,
    required this.onTap,
  });

  bool _isCorrectOption(String key) => question.answer.contains(key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        kPagePadding,
        kPagePadding,
        kPagePadding,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            question.content,
            style: const TextStyle(
              fontSize: 18,
              height: 1.6,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          for (final option in question.options) ...[
            _OptionTile(
              option: option,
              state: _stateFor(option.key),
              onTap: answered ? null : () => onTap(option.key),
            ),
            const SizedBox(height: kGap),
          ],
          if (recite) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.correct.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(kRadius),
                border: Border.all(
                  color: AppColors.correct.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      size: 18, color: AppColors.correct),
                  const SizedBox(width: 8),
                  Text(
                    '答案：${question.correctAnswerText}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.correct,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  _OptionState _stateFor(String key) {
    if (!answered) {
      return selected.contains(key)
          ? _OptionState.selected
          : _OptionState.normal;
    }
    if (_isCorrectOption(key)) {
      return _OptionState.correct;
    }
    if (selected.contains(key)) {
      return _OptionState.wrong;
    }
    return _OptionState.normal;
  }
}

enum _OptionState { normal, selected, correct, wrong }

class _OptionTile extends StatelessWidget {
  final QuestionOption option;
  final _OptionState state;
  final VoidCallback? onTap;

  const _OptionTile({
    required this.option,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color background;
    Color borderColor;
    Color badgeColor;
    Color badgeTextColor;
    IconData? trailingIcon;
    Color? trailingColor;

    switch (state) {
      case _OptionState.correct:
        background = const Color(0xFFF0FDF4);
        borderColor = AppColors.correct;
        badgeColor = AppColors.correct;
        badgeTextColor = Colors.white;
        trailingIcon = Icons.check_circle;
        trailingColor = AppColors.correct;
        break;
      case _OptionState.wrong:
        background = const Color(0xFFFEF2F2);
        borderColor = AppColors.wrong;
        badgeColor = AppColors.wrong;
        badgeTextColor = Colors.white;
        trailingIcon = Icons.cancel;
        trailingColor = AppColors.wrong;
        break;
      case _OptionState.selected:
        background = const Color(0xFFEFF6FF);
        borderColor = AppColors.primary;
        badgeColor = AppColors.primary;
        badgeTextColor = Colors.white;
        trailingIcon = null;
        trailingColor = null;
        break;
      case _OptionState.normal:
        background = AppColors.cardBackground;
        borderColor = AppColors.border;
        badgeColor = Colors.white;
        badgeTextColor = AppColors.textSecondary;
        trailingIcon = null;
        trailingColor = null;
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: state == _OptionState.normal
                        ? AppColors.border
                        : badgeColor,
                  ),
                ),
                child: Text(
                  option.key,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: badgeTextColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    option.text,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.45,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trailingIcon, color: trailingColor, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
