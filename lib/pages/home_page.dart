import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chapter.dart';
import '../services/txt_file_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/practice_setting_sheet.dart';
import 'quiz_page.dart';
import 'wrong_book_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TxtFileService _fileService = TxtFileService();
  bool _importing = false;
  String _importStage = '导入中...';

  Future<void> _importQuestions() async {
    if (_importing) return;
    setState(() {
      _importing = true;
      _importStage = '准备中...';
    });

    FilePickerResult? picked;
    var importedChapters = 0;
    var importedQuestions = 0;
    var skippedQuestions = 0;
    var parsedValidQuestions = 0;
    var parsedFiles = 0;
    var readFailed = false;
    var encodingFailed = false;
    var timedOut = false;
    var unexpectedFailure = false;
    Object? failure;

    try {
      if (!mounted) return;
      setState(() => _importStage = '选择文件...');
      try {
        // 不通过 withData 一次性回传文件内容，避免大文件读取时界面卡死。
        picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['txt'],
          allowMultiple: true,
          withData: false,
        );
      } catch (_) {
        readFailed = true;
        picked = null;
      }

      if (!mounted) return;
      if (picked == null || picked.files.isEmpty) {
        return;
      }

      final state = context.read<AppState>();
      for (final file in picked.files) {
        if (!mounted) return;
        setState(() => _importStage = '读取文件...');

        TxtFileImport parsed;
        try {
          parsed = await _fileService
              .parsePickedFile(file)
              .timeout(const Duration(seconds: 30));
        } on TimeoutException {
          timedOut = true;
          continue;
        } on FormatException {
          encodingFailed = true;
          continue;
        } catch (_) {
          readFailed = true;
          continue;
        }

        parsedFiles++;
        skippedQuestions += parsed.skipped;
        parsedValidQuestions += parsed.questions.length;
        if (parsed.questions.isEmpty) {
          continue;
        }

        setState(() => _importStage = '保存中...');
        final existing = state.findChapterByName(parsed.chapterName);
        if (existing != null) {
          if (!mounted) return;
          final overwrite = await _confirmOverwrite(parsed.chapterName);
          if (overwrite != true) continue;
          state.replaceChapter(
            chapterId: existing.id,
            name: parsed.chapterName,
            questions: parsed.questions,
            importedAt: DateTime.now().millisecondsSinceEpoch,
          );
        } else {
          state.addChapter(
            name: parsed.chapterName,
            questions: parsed.questions,
            importedAt: DateTime.now().millisecondsSinceEpoch,
          );
        }
        importedChapters++;
        importedQuestions += parsed.questions.length;
      }
    } catch (error, stack) {
      unexpectedFailure = true;
      failure = error;
      debugPrint('Import failed: $error\n$stack');
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
          _importStage = '导入中...';
        });
      }
    }

    if (!mounted) return;

    if (readFailed) _showSnack('文件读取失败');
    if (encodingFailed) _showSnack('请将文件另存为 UTF-8 编码');
    if (timedOut) _showSnack('文件处理超时，请检查文件大小或格式');

    if (picked == null || picked.files.isEmpty) return;

    if (unexpectedFailure) {
      await _showMessage('导入失败：${_errorText(failure)}');
      return;
    }

    if (parsedValidQuestions == 0) {
      if (parsedFiles > 0) {
        await _showMessage('未识别到有效题目，请检查文件格式');
      }
      return;
    }

    await _showMessage(
      '成功导入 $importedChapters 个章节，共 $importedQuestions 道题；跳过 $skippedQuestions 道无效题',
    );
  }

  String _errorText(Object? error) {
    final text = error?.toString() ?? '未知错误';
    if (text.length > 500) {
      return '${text.substring(0, 500)}…';
    }
    return text;
  }

  Future<bool?> _confirmOverwrite(String chapterName) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('章节已存在'),
          content: Text('已存在同名章节「$chapterName」，是否覆盖？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('覆盖'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showMessage(String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openChapter(Chapter chapter) async {
    final appState = context.read<AppState>();
    final config = await showPracticeSettingSheet(
      context,
      chapter,
      savedProgress: appState.progressFor(chapter.id),
    );
    if (config == null || !mounted) return;
    // 全新开始时清掉旧进度，避免中途退出后仍残留上一次的记录。
    if (config.resume == null) {
      appState.clearProgress(chapter.id);
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizPage(
          chapterId: chapter.id,
          questions: config.questions,
          mode: config.mode,
          recite: config.recite,
          examMinutes: config.examMinutes,
          practiceType: config.type,
          initialProgress: config.resume,
        ),
      ),
    );
  }

  Future<void> _deleteChapter(Chapter chapter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除该章节？'),
          content: const Text('章节及其关联的错题记录将一并删除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) {
      context.read<AppState>().deleteChapter(chapter.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final chapters = appState.chapters;
    final wrongCount = appState.wrongCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('刷题'),
        actions: [
          IconButton(
            tooltip: '错题库',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WrongBookPage(),
                ),
              );
            },
            icon: Badge(
              isLabelVisible: wrongCount > 0,
              backgroundColor: AppColors.wrong,
              label: Text(wrongCount > 99 ? '99+' : '$wrongCount'),
              child: const Icon(Icons.error_outline),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    kPagePadding,
                    kPagePadding,
                    kPagePadding,
                    kGap,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _importing ? null : _importQuestions,
                      icon: _importing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      label: Text(_importing ? _importStage : '导入题库'),
                    ),
                  ),
                ),
                Expanded(
                  child: chapters.isEmpty
                      ? const Center(
                          child: Text(
                            '暂无题库，请先导入',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            kPagePadding,
                            4,
                            kPagePadding,
                            28,
                          ),
                          itemCount: chapters.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: kGap),
                          itemBuilder: (context, index) {
                            final chapter = chapters[index];
                            return _ChapterCard(
                              chapter: chapter,
                              onTap: () => _openChapter(chapter),
                              onLongPress: () => _deleteChapter(chapter),
                            );
                          },
                        ),
                ),
              ],
            ),
            Positioned(
              right: 12,
              bottom: 8,
              child: IgnorePointer(
                child: Text(
                  '测试版0.2    作者 xloic',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.55),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final Chapter chapter;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ChapterCard({
    required this.chapter,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chapter.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                chapter.statisticsText,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
