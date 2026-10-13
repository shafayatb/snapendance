import 'package:flutter/material.dart';

import 'home/home_screen.dart';
import 'native/attendance_launcher.dart';
import 'theme/app_theme.dart';

class SnapendanceApp extends StatelessWidget {
  const SnapendanceApp({super.key, required this.attendanceLauncher});

  final AttendanceLauncher attendanceLauncher;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snapendance',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      home: HomeScreen(attendanceLauncher: attendanceLauncher),
    );
  }
}
