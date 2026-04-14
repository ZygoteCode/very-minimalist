import 'package:flutter/material.dart';
import 'launcher_ui.dart';

void main() {
  runApp(const LauncherApp());
}

class LauncherApp extends StatelessWidget {
  const LauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: LauncherUi(),
      debugShowCheckedModeBanner: false,
    );
  }
}
