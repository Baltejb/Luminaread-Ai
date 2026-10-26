import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

void main() {
  runApp(const LuminaReadApp());
}

class LuminaReadApp extends StatelessWidget {
  const LuminaReadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color?>(
      valueListenable: ThemeController.instance,
      builder: (context, seed, _) {
        return MaterialApp(
          title: 'LuminaRead AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(seed: seed),
          darkTheme: AppTheme.dark(seed: seed),
          themeMode: ThemeMode.dark,
          home: const HomeScreen(),
        );
      },
    );
  }
}
