import 'package:flutter/material.dart';

import '../models/question.dart';
import '../theme.dart';

class TypeTag extends StatelessWidget {
  final String type;
  final bool compact;

  const TypeTag({super.key, required this.type, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        QuestionType.label(type),
        style: TextStyle(
          color: AppColors.primary,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
