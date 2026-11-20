import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReadingStorage {
  static const String _progressPrefix = 'reading_progress';
  static const String _lastFileKey = 'last_file_path';

  /// Сохраняет позицию скролла для конкретной книги и запоминает её как последнюю открытую
  Future<void> saveProgress(double scrollPosition, String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_getProgressKey(filePath), scrollPosition);
      await prefs.setString(_lastFileKey, filePath);
    } catch (e) {
      debugPrint('Ошибка сохранения прогресса: $e');
    }
  }

  /// Возвращает сохранённую позицию скролла для указанной книги
  Future<double?> getSavedProgress(String filePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_getProgressKey(filePath));
    } catch (e) {
      debugPrint('Ошибка получения прогресса: $e');
      return null;
    }
  }

  /// Возвращает путь к последней открытой книге
  Future<String?> getLastFile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastFileKey);
    } catch (e) {
      debugPrint('Ошибка получения последнего файла: $e');
      return null;
    }
  }

  String _getProgressKey(String filePath) {
    //final fileName = File(filePath).uri.pathSegments.last;
    final fileName = Uri.file(filePath).pathSegments.last;
    return '${_progressPrefix}_$fileName';
  }
}
