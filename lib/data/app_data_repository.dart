import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_data.dart';
import 'default_plans.dart';

abstract interface class AppDataStorage {
  Future<String?> read();
  Future<bool> write(String value);
  Future<bool> writeBackup(String value);
}

class SharedPreferencesAppDataStorage implements AppDataStorage {
  static const dataKey = 'fitness_app_data_v1';
  static const backupKey = 'fitness_app_data_backup';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(dataKey);

  @override
  Future<bool> write(String value) async =>
      (await SharedPreferences.getInstance()).setString(dataKey, value);

  @override
  Future<bool> writeBackup(String value) async =>
      (await SharedPreferences.getInstance()).setString(backupKey, value);
}

class AppDataRepository {
  AppDataRepository({required this.storage});
  final AppDataStorage storage;

  Future<AppData> load() async {
    final raw = await storage.read();
    if (raw == null || raw.trim().isEmpty) {
      final initial = DefaultPlans.create();
      await save(initial);
      return initial;
    }
    late AppData data;
    var needsMigration = false;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('根数据无效');
      }
      if (decoded['version'] != 1 &&
          decoded['version'] != AppData.currentVersion) {
        throw const AppDataStorageException('数据版本不受支持，请使用匹配的应用版本');
      }
      needsMigration = decoded['version'] == 1;
      data = AppData.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } on AppDataStorageException {
      rethrow;
    } catch (_) {
      if (!await storage.writeBackup(raw)) {
        throw const AppDataStorageException('旧数据备份失败');
      }
      final initial = DefaultPlans.create();
      await save(initial);
      return initial;
    }
    if (needsMigration) {
      // Never replace the user's only copy if backup or migration saving fails.
      if (!await storage.writeBackup(raw)) {
        throw const AppDataStorageException('升级前备份失败，请重试');
      }
      await save(data);
    }
    return data;
  }

  Future<void> save(AppData data) async {
    if (!await storage.write(jsonEncode(data.toJson()))) {
      throw const AppDataStorageException('保存失败，请重试');
    }
  }
}

class AppDataStorageException implements Exception {
  const AppDataStorageException(this.message);
  final String message;

  @override
  String toString() => message;
}
