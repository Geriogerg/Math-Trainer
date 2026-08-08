import 'package:flutter/material.dart';

import 'presentation/screens/home_screen.dart';

class MathTrainerApp extends StatelessWidget {
  const MathTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Math Trainer',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
      home: const HomeScreen(),
    );
  }
}
