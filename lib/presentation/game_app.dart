import 'package:flutter/material.dart';
import 'package:flame/game.dart';

import '../infra/dependency_injection.dart';
import 'sims_game.dart';

class GameApp extends StatelessWidget {
  const GameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sims-Like Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, brightness: Brightness.dark),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late SimsGame _game;
  bool _isInitialized = false;
  String? _initializationError;

  @override
  void initState() {
    super.initState();
    _initializeDependencies();
  }

  Future<void> _initializeDependencies() async {
    try {
      // Initialize dependency injection system
      await DependencyInjection.initialize();
      await DependencyInjection.waitForReady();

      // Create game instance using DI
      _game = SimsGame();

      setState(() {
        _isInitialized = true;
      });
    } catch (error, stackTrace) {
      setState(() {
        _initializationError = error.toString();
      });

      // Log the error
      debugPrint('Failed to initialize dependencies: $error');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializationError != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Failed to initialize game',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _initializationError!,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _initializationError = null;
                    _isInitialized = false;
                  });
                  _initializeDependencies();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Initializing game systems...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return GameWidget(game: _game);
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _game.onRemove();
    }
    super.dispose();
  }
}
