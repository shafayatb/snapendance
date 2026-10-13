import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';

void main() {
  // Draw behind the system bars on every Android version, not only 15+.
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const SnapendanceApp());
}
