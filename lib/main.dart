import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'nav.dart';
import 'theme.dart';

void main() {
  debugPrint('FirePumpSim build stamp: 2026-05-21 library-coming-soon+scenario-cache+daily-timer');
  runApp(const FirePumpSimApp());
}

class FirePumpSimApp extends StatelessWidget {
  const FirePumpSimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FirePumpSim',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: AppRouter.router,
    );
  }
}
