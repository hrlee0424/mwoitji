import 'package:flutter/material.dart';

import 'models/app_theme_style.dart';
import 'screens/home_screen.dart';
import 'viewmodels/theme_view_model.dart';

export 'models/app_theme_style.dart';
export 'models/food_item.dart';
export 'models/ocr_scan_result.dart';
export 'screens/add_food_screen.dart';
export 'screens/home_screen.dart';
export 'screens/live_scanner_screen.dart';
export 'services/database_service.dart';
export 'services/ocr_service.dart';

void main() => runApp(const MwoitjiApp());

class MwoitjiApp extends StatefulWidget {
  const MwoitjiApp({super.key});

  @override
  State<MwoitjiApp> createState() => _MwoitjiAppState();
}

class _MwoitjiAppState extends State<MwoitjiApp> {
  final _themeViewModel = ThemeViewModel();

  @override
  void initState() {
    super.initState();
    _themeViewModel
      ..addListener(_refresh)
      ..initialize();
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _themeViewModel
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '뭐있지',
    theme: buildAppTheme(_themeViewModel.style),
    home: MwoitjiHome(themeViewModel: _themeViewModel),
  );
}
