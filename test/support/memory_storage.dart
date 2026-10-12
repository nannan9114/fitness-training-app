import 'package:fitness_training_app/data/app_data_repository.dart';

class MemoryAppDataStorage implements AppDataStorage {
  String? value;
  String? backup;
  bool failWrites = false;

  @override
  Future<String?> read() async => value;

  @override
  Future<bool> write(String value) async {
    if (failWrites) return false;
    this.value = value;
    return true;
  }

  @override
  Future<bool> writeBackup(String value) async {
    if (failWrites) return false;
    backup = value;
    return true;
  }
}
