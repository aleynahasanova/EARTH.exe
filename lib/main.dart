import 'package:flutter/material.dart';

import 'database/database_helper.dart';
import 'screens/first_contact_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Open the local database before the UI starts so any problem shows up
  // immediately in the console, tagged [DB].
  try {
    await DatabaseHelper.instance.database;
    await DatabaseHelper.instance.purgeEmptySessions();
    await DatabaseHelper.instance.debugDump();
  } catch (e, st) {
    debugPrint('[DB][ERROR] startup failed: $e\n$st');
  }

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
