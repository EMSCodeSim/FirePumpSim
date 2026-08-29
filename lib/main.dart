import 'package:flutter/material.dart';

import 'nav.dart';
import 'services/scenario_purchase_service.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Start store setup without blocking the first frame. The service handles
  // unavailable stores/platform errors internally, so web/Dreamflow preview
  // can still render normally.
  ScenarioPurchaseService.instance.initialize();
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
