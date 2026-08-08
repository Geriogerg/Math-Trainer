import 'package:flutter/material.dart';

import 'composition_root.dart';
import 'presentation/screens/home_screen.dart';

class MathTrainerApp extends StatelessWidget {
  const MathTrainerApp({super.key, required this.environment});

  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Math Trainer',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
      home: HomeScreen(environment: environment),
    );
  }
}
