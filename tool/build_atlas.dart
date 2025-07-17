#!/usr/bin/env dart

/// Convenience script for building sprite atlases
/// This script provides a simpler interface to the atlas builder

import 'dart:io';
import 'atlas_builder.dart' as atlas_builder;

void main(List<String> arguments) async {
  print('=== Sims-like Game Atlas Builder ===');

  // Check if sprites directory exists
  final spritesDir = Directory('assets/images/sprites');
  if (!await spritesDir.exists()) {
    print('Creating sprites directory: ${spritesDir.path}');
    await spritesDir.create(recursive: true);

    // Create example subdirectories
    await Directory('assets/images/sprites/tiles').create();
    await Directory('assets/images/sprites/objects').create();
    await Directory('assets/images/sprites/characters').create();

    print('Created example sprite directories:');
    print('  - assets/images/sprites/tiles/');
    print('  - assets/images/sprites/objects/');
    print('  - assets/images/sprites/characters/');
    print('');
    print(
      'Add your sprite images to these directories and run this script again.',
    );
    return;
  }

  // Default arguments for the atlas builder
  final args = [
    '--input', 'assets/images/sprites',
    '--output', 'assets/images',
    '--name', 'atlas',
    '--max-size', '2048',
    ...arguments, // Allow overriding with command line args
  ];

  atlas_builder.main(args);
}
