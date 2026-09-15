import 'package:flutter/material.dart';

import 'screens/first_contact_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const EarthExeApp());
}

class EarthExeApp extends StatelessWidget {
  const EarthExeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EARTH.exe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const FirstContactScreen(),
    );
  }
}
