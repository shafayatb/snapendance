import 'package:flutter/material.dart';

import 'home/home_screen.dart';
import 'theme/app_theme.dart';

class SnapendanceApp extends StatelessWidget {
  const SnapendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snapendance',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      home: const HomeScreen(),
    );
  }
}
