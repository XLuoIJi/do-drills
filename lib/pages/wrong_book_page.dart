import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/question.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/type_tag.dart';

class WrongBookPage extends StatelessWidget {
  const WrongBookPage({super.key});

  Future<void> _clearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('清空错题库？'),
          content: const Text('将删除全部错题记录，此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('清空'),
            ),
          ],
        );
      },
    );
    if (confirmed == true && context.mounted) {
      context.read<AppState>().clearWrongBook();
    }
  }

  Future<void> _deleteOne(BuildContext context, WrongBookEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除该错题？'),
          content: const Text('删除后该题将不再出现在错题库中。'),
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
    if (confirmed == true && context.mounted) {
      context.read<AppState>().removeWrong(entry.question.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<AppState>().wrongEntries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('错题库'),
        actions: [
          TextButton(
            onPressed: entries.isEmpty ? null : () => _clearAll(context),
            child: Text(
              '清空',
              style: TextStyle(
                color: entries.isEmpty
                    ? AppColors.textSecondary
                    : AppColors.wrong,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: entries.isEmpty
            ? const Center(
                child: Text(
                  '暂无错题',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(kPagePadding),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: kGap),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return _WrongBookCard(
                    entry: entry,
                    onDelete: () => _deleteOne(context, entry),
                  );
                },
              ),
      ),
    );
  }
}

class _WrongBookCard extends StatelessWidget {
  final WrongBookEntry entry;
  final VoidCallback onDelete;

  const _WrongBookCard({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final question = entry.question;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        entry.chapter.name,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TypeTag(type: question.type, compact: true),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '删除',
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                question.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                _answerLine(question, entry.item.lastAnswer),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _answerLine(Question question, List<String> lastAnswer) {
    final mine = lastAnswer.isEmpty ? '未作答' : lastAnswer.join();
    final correct = question.answer.join();
    return '我的答案：$mine　正确答案：$correct';
  }
}
