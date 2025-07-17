import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'sims_game.dart';

class GameApp extends StatelessWidget {
  const GameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sims-Like Game',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: GameWidget<SimsGame>.controlled(
        gameFactory: SimsGame.new,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}