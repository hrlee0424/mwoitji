import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'models/app_theme_style.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'viewmodels/theme_view_model.dart';

export 'models/app_theme_style.dart';
export 'models/food_item.dart';
export 'models/ocr_scan_result.dart';
export 'screens/add_food_screen.dart';
export 'screens/home_screen.dart';
export 'screens/live_scanner_screen.dart';
export 'screens/login_screen.dart';
export 'screens/receipt_scan_screen.dart';
export 'services/auth_service.dart';
export 'services/database_service.dart';
export 'services/fridge_invite_service.dart';
export 'services/ocr_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MwoitjiApp());
}

class MwoitjiApp extends StatelessWidget {
  const MwoitjiApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) return const _AuthenticatedApp();
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            title: '뭐있지',
            home: LoginScreen(),
          );
        }
        return _AuthenticatedApp(key: ValueKey(user.uid));
      },
    );
  }
}

class _AuthenticatedApp extends StatefulWidget {
  const _AuthenticatedApp({super.key});

  @override
  State<_AuthenticatedApp> createState() => _AuthenticatedAppState();
}

class _AuthenticatedAppState extends State<_AuthenticatedApp> {
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
