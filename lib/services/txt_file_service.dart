import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';
import 'package:file_picker/file_picker.dart';

import '../models/question.dart';
import 'question_parser.dart';

class TxtFileImport {
  final String chapterName;
  final List<Question> questions;
  final int skipped;

  const TxtFileImport({
    required this.chapterName,
    required this.questions,
    required this.skipped,
  });
}

class TxtFileService {
  final QuestionParser _parser;

  TxtFileService({QuestionParser? parser}) : _parser = parser ?? QuestionParser();

  Future<TxtFileImport> parsePickedFile(PlatformFile pickedFile) async {
    final path = pickedFile.path;
    if (path == null || path.isEmpty) {
      throw const FileSystemException('文件读取失败');
    }
    final file = File(path);
    if (!await file.exists()) {
      throw const FileSystemException('文件读取失败');
    }
    final Uint8List bytes = await file.readAsBytes();

    final text = await decodeBytes(bytes);
    if (text == null) {
      throw const FormatException('encoding');
    }

    final name = pickedFile.name.replaceFirst(
      RegExp(r'\.txt$', caseSensitive: false),
      '',
    );
    final result = _parser.parse(text);
    return TxtFileImport(
      chapterName: name.trim().isEmpty ? pickedFile.name : name.trim(),
      questions: result.questions,
      skipped: result.skipped,
    );
  }

  /// UTF-8 严格解码；失败时回退 GBK。两种方式都失败返回 null。
  Future<String?> decodeBytes(Uint8List bytes) async {
    try {
      final text = utf8.decode(bytes);
      if (!text.contains('\uFFFD')) return text;
    } on FormatException {
      // 继续尝试 GBK。
    }

    try {
      final text = await CharsetConverter.decode('GBK', bytes);
      if (!text.contains('\uFFFD')) return text;
    } catch (_) {
      // 无可用 GBK 解码器或字节无法解码。
    }
    return null;
  }
}
