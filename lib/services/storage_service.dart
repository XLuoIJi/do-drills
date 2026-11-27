import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/app_data.dart';

/// 应用私有目录下的 JSON 持久化。
/// 文件位置：<应用私有目录>/data/questions.json
class StorageService {
  File? _file;

  Future<void> initialize() async {
    final documents = await getApplicationDocumentsDirectory();
    final dataDirectory = Directory('${documents.path}/data');
    if (!dataDirectory.existsSync()) {
      dataDirectory.createSync(recursive: true);
    }
    _file = File('${dataDirectory.path}/questions.json');
  }

  AppData load() {
    final file = _file;
    if (file == null || !file.existsSync()) {
      return const AppData();
    }
    final content = file.readAsStringSync();
    if (content.trim().isEmpty) return const AppData();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) return const AppData();
    return AppData.fromJson(decoded);
  }

  /// 每次变更立即同步写盘。
  void save(AppData data) {
    final file = _file;
    if (file == null) {
      throw StateError('题库存储尚未初始化');
    }
    final encoded = jsonEncode(data.toJson());
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(encoded, flush: true);
  }
}
