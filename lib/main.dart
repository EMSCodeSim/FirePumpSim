import 'package:flutter/material.dart';

import 'nav.dart';
import 'theme.dart';

void main() {
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
