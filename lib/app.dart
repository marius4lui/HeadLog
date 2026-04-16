import 'package:flutter/material.dart';

import 'screens/headlog_home_screen.dart';
import 'theme/app_theme.dart';

class HeadLogApp extends StatelessWidget {
  const HeadLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HeadLog',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const HeadLogHomeScreen(),
    );
  }
}
