import 'package:flutter/material.dart';

import 'home/home_screen.dart';

class SnapendanceApp extends StatelessWidget {
  const SnapendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Snapendance',
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}
