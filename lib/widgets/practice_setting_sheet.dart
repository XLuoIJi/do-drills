import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/chapter.dart';
import '../models/practice_progress.dart';
import '../models/question.dart';
import '../theme.dart';

/// 练习方式：顺序 / 随机 / 真实考试。
enum PracticeMode { order, random, exam }

class PracticeConfig {
  final List<Question> questions;
  final PracticeMode mode;

  /// 题型筛选：'all' 或 single / multiple / judge（随进度保存）。
  final String type;

  /// 背题模式：直接显示答案，可自由滑动。
  final bool recite;

  /// 考试时长（分钟），仅 [PracticeMode.exam] 时有效。
  final int examMinutes;

  /// 非空表示从上次进度恢复（[questions] 已按保存的顺序排列）。
  final PracticeProgress? resume;

  const PracticeConfig({
    required this.questions,
    required this.mode,
    this.type = 'all',
    this.recite = false,
    this.examMinutes = 45,
    this.resume,
  });

  bool get isExam => mode == PracticeMode.exam;
}

Future<PracticeConfig?> showPracticeSettingSheet(
  BuildContext context,
  Chapter chapter, {
  PracticeProgress? savedProgress,
}) {
  return showModalBottomSheet<PracticeConfig>(
    context: context,
    backgroundColor: AppColors.pageBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(kRadius)),
    ),
    isScrollControlled: true,
    builder: (_) => _PracticeSettingSheet(
      chapter: chapter,
      savedProgress: savedProgress,
    ),
  );
}

class _PracticeSettingSheet extends StatefulWidget {
  final Chapter chapter;
  final PracticeProgress? savedProgress;

  const _PracticeSettingSheet({
    required this.chapter,
    this.savedProgress,
  });

  @override
  State<_PracticeSettingSheet> createState() => _PracticeSettingSheetState();
}

class _PracticeSettingSheetState extends State<_PracticeSettingSheet> {
  String _selectedType = 'all';
  PracticeMode _mode = PracticeMode.order;
  bool _recite = false;

  int _examCount = 0; // 惰性初始化为筛选后题数
  int _examMinutes = 45;
  bool _examCountInitialized = false;

  List<Question> get _filteredQuestions {
    if (_selectedType == 'all') {
      return List<Question>.from(widget.chapter.questions);
    }
    return widget.chapter.questions
        .where((question) => question.type == _selectedType)
        .toList();
  }

  void _ensureExamCount() {
    if (_examCountInitialized) return;
    _examCount = _filteredQuestions.length;
    _examCountInitialized = true;
  }

  void _start() {
    var questions = _filteredQuestions;
    if (questions.isEmpty) return;
    if (_mode == PracticeMode.exam) {
      _ensureExamCount();
      final shuffled = List<Question>.from(questions)..shuffle(Random());
      questions =
          shuffled.take(_examCount.clamp(1, shuffled.length).toInt()).toList();
    } else if (_mode == PracticeMode.random) {
      questions = List<Question>.from(questions)..shuffle(Random());
    }

    Navigator.of(context).pop(PracticeConfig(
      questions: questions,
      mode: _mode,
      type: _selectedType,
      recite: _mode == PracticeMode.order || _mode == PracticeMode.random
          ? _recite
          : false,
      examMinutes: _examMinutes,
    ));
  }

  void _resume() {
    final progress = widget.savedProgress;
    if (progress == null) return;
    final questionMap = {
      for (final question in widget.chapter.questions) question.id: question,
    };
    final questions = <Question>[];
    for (final id in progress.questionIds) {
      final question = questionMap[id];
      if (question != null) questions.add(question);
    }
    if (questions.isEmpty) return;
    Navigator.of(context).pop(PracticeConfig(
      questions: questions,
      mode: progress.random ? PracticeMode.random : PracticeMode.order,
      type: progress.type,
      recite: progress.recite,
      resume: progress,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final types = widget.chapter.availableTypes;
    final filtered = _filteredQuestions;
    final empty = filtered.isEmpty;
    _ensureExamCount();

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          kPagePadding,
          kPagePadding,
          kPagePadding,
          kPagePadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.chapter.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (widget.savedProgress != null) ...[
              const SizedBox(height: 16),
              _ResumeCard(
                progress: widget.savedProgress!,
                onResume: _resume,
              ),
            ],
            const SizedBox(height: 20),
            const _SectionLabel(text: '题型选择'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTypeChip('all', '全部'),
                for (final type in types)
                  _buildTypeChip(type, QuestionType.label(type)),
              ],
            ),
            const SizedBox(height: 20),
            const _SectionLabel(text: '练习方式'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildModeChip(PracticeMode.order, '顺序练习'),
                _buildModeChip(PracticeMode.random, '随机练习'),
                _buildModeChip(PracticeMode.exam, '真实考试'),
              ],
            ),
            if (_mode != PracticeMode.exam) ...[
              const SizedBox(height: 16),
              _ReciteRow(
                value: _recite,
                onChanged: (value) => setState(() => _recite = value),
              ),
            ],
            if (_mode == PracticeMode.exam) ...[
              const SizedBox(height: 20),
              _buildExamSettings(filtered.length),
            ],
            const SizedBox(height: 24),
            if (empty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  '该题型暂无题目',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: empty ? null : _start,
                child: Text(_mode == PracticeMode.exam
                    ? '开始考试'
                    : (_recite ? '开始背题' : '开始答题')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamSettings(int maxCount) {
    if (_examCount > maxCount) {
      _examCount = maxCount;
    }
    final perQuestion = maxCount == 0 || _examCount == 0
        ? 0.0
        : 100.0 / _examCount;
    final perQuestionText = perQuestion == perQuestion.roundToDouble()
        ? perQuestion.toInt().toString()
        : perQuestion.toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(text: '考试设置'),
        const SizedBox(height: 8),
        _StepperRow(
          label: '题数',
          value: _examCount.clamp(1, maxCount.clamp(1, 999)).toInt(),
          minValue: 1,
          maxValue: max(1, maxCount),
          onChanged: maxCount == 0
              ? null
              : (value) => setState(() => _examCount = value),
        ),
        const SizedBox(height: 8),
        _StepperRow(
          label: '时间（分钟）',
          value: _examMinutes,
          minValue: 5,
          maxValue: 180,
          step: 5,
          onChanged: (value) => setState(() => _examMinutes = value),
        ),
        const SizedBox(height: 8),
        Text(
          '满分 100 分，每题 $perQuestionText 分',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedType == value,
      onSelected: (_) => setState(() {
        _selectedType = value;
        // 题型变化后，考试题数默认跟随当前筛选后的题量。
        _examCount = _filteredQuestions.length;
        _examCountInitialized = true;
      }),
    );
  }

  Widget _buildModeChip(PracticeMode value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _mode == value,
      onSelected: (_) => setState(() {
        _mode = value;
        if (value == PracticeMode.exam) _recite = false;
      }),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  final PracticeProgress progress;
  final VoidCallback onResume;

  const _ResumeCard({required this.progress, required this.onResume});

  @override
  Widget build(BuildContext context) {
    final total = progress.questionIds.length;
    final current = (progress.currentIndex + 1).clamp(1, total);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              progress.recite
                  ? '上次背题到第 $current / $total 题'
                  : '上次练习到第 $current / $total 题',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: onResume,
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }
}

class _ReciteRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ReciteRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(kRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '背题模式',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '直接显示答案，可自由滑动',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _StepperRow extends StatefulWidget {
  final String label;
  final int value;
  final int minValue;
  final int maxValue;
  final int step;
  final ValueChanged<int>? onChanged;

  const _StepperRow({
    required this.label,
    required this.value,
    required this.minValue,
    required this.maxValue,
    this.step = 1,
    required this.onChanged,
  });

  @override
  State<_StepperRow> createState() => _StepperRowState();
}

class _StepperRowState extends State<_StepperRow> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  bool get _enabled => widget.onChanged != null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _StepperRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 输入框聚焦时不要覆盖用户正在输入的内容；失焦后再同步。
    if (!_focusNode.hasFocus && _controller.text != '${widget.value}') {
      _setText(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) _commit();
  }

  void _setText(int value) {
    final text = '$value';
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  int _clamp(int value) => value.clamp(widget.minValue, widget.maxValue);

  void _commit() {
    final parsed = int.tryParse(_controller.text.trim());
    final next = _clamp(parsed ?? widget.value);
    _setText(next);
    if (next != widget.value) {
      widget.onChanged?.call(next);
    }
  }

  void _apply(int value) {
    if (!_enabled) return;
    final next = _clamp(value);
    _setText(next);
    if (next != widget.value) {
      widget.onChanged!(next);
    }
  }

  Widget _buildButton(IconData icon, int target, bool enabledButton) {
    return IconButton(
      onPressed: _enabled && enabledButton ? () => _apply(target) : null,
      icon: Icon(icon, size: 20),
      color: AppColors.primary,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.label,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _buildButton(
            Icons.remove,
            widget.value - widget.step,
            widget.value > widget.minValue,
          ),
          SizedBox(
            width: 68,
            height: 36,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: _enabled,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
              onChanged: (text) {
                if (!_enabled) return;
                final parsed = int.tryParse(text);
                if (parsed == null) return;
                final next = _clamp(parsed);
                if (next != widget.value) widget.onChanged!(next);
              },
              onSubmitted: (_) {
                _commit();
                _focusNode.unfocus();
              },
              onTapOutside: (_) {
                _commit();
                _focusNode.unfocus();
              },
            ),
          ),
          _buildButton(
            Icons.add,
            widget.value + widget.step,
            widget.value < widget.maxValue,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
    );
  }
}
