import 'package:flutter/material.dart';

import 'app/router/app_root.dart';
import 'shared/theme/theme.dart';

class GowaykiLabApp extends StatelessWidget {
  const GowaykiLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gowayki Lab',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AppRoot(),
    );
  }
}
