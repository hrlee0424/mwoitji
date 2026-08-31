import 'package:flutter/foundation.dart';

import '../models/app_theme_style.dart';
import '../services/database_service.dart';

class ThemeViewModel extends ChangeNotifier {
  ThemeViewModel({DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService.instance;

  static const _settingKey = 'theme_style';
  final DatabaseService _databaseService;
  AppThemeStyle _style = AppThemeStyle.fresh;
  bool _disposed = false;

  AppThemeStyle get style => _style;

  Future<void> initialize() async {
    try {
      final savedStyle = await _databaseService.getSetting(_settingKey);
      if (_disposed) return;
      _style = AppThemeStyle.fromName(savedStyle);
      notifyListeners();
    } catch (_) {
      // DB를 사용할 수 없으면 기본 프레시 테마를 유지합니다.
    }
  }

  Future<void> setStyle(AppThemeStyle style) async {
    if (_disposed || _style == style) return;
    final previous = _style;
    _style = style;
    notifyListeners();
    try {
      await _databaseService.saveSetting(_settingKey, style.name);
    } catch (_) {
      if (_disposed) return;
      _style = previous;
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
