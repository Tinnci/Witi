#!/usr/bin/env dart

/// Comprehensive asset build script
/// Validates assets, builds atlases, and generates strongly-typed references

import 'dart:io';
import 'asset_validator.dart' as validator;
import 'atlas_builder.dart' as atlas_builder;

void main(List<String> arguments) async {
  print('=== Sims-like Game Asset Build Pipeline ===\n');

  final stopwatch = Stopwatch()..start();
  bool hasErrors = false;

  // Step 1: Validate assets
  print('Step 1: Validating assets...');
  try {
    final validationResult = await validator.AssetValidator(
      assetPath: 'assets',
      strictMode: false,
    ).validate();

    print('Validation completed:');
    print('  - Files checked: ${validationResult.totalFiles}');
    print('  - Errors: ${validationResult.errors.length}');
    print('  - Warnings: ${validationResult.warnings.length}');

    if (validationResult.errors.isNotEmpty) {
      print('\nValidation errors:');
      for (final error in validationResult.errors) {
        print('  ❌ $error');
      }
      hasErrors = true;
    }

    if (validationResult.warnings.isNotEmpty) {
      print('\nValidation warnings:');
      for (final warning in validationResult.warnings) {
        print('  ⚠️  $warning');
      }
    }
  } catch (e) {
    print('❌ Asset validation failed: $e');
    hasErrors = true;
  }

  if (hasErrors) {
    print('\n❌ Build failed due to validation errors');
    exit(1);
  }

  print('✅ Asset validation passed\n');

  // Step 2: Build sprite atlas
  print('Step 2: Building sprite atlas...');
  try {
    atlas_builder.main([
      '--input',
      'assets/images/sprites',
      '--output',
      'assets/images',
      '--name',
      'atlas',
      '--max-size',
      '2048',
    ]);
    print('✅ Sprite atlas built successfully\n');
  } catch (e) {
    print('❌ Atlas building failed: $e');
    hasErrors = true;
  }

  // Step 3: Generate strongly-typed asset references
  print('Step 3: Generating asset references...');
  try {
    final result = await Process.run('dart', [
      'run',
      'build_runner',
      'build',
      '--delete-conflicting-outputs',
    ], workingDirectory: Directory.current.path);

    if (result.exitCode == 0) {
      print('✅ Asset references generated successfully');
    } else {
      print('❌ Asset reference generation failed:');
      print(result.stderr);
      hasErrors = true;
    }
  } catch (e) {
    print('❌ Asset reference generation failed: $e');
    hasErrors = true;
  }

  stopwatch.stop();

  // Summary
  print('\n=== Build Summary ===');
  print('Total time: ${stopwatch.elapsedMilliseconds}ms');

  if (hasErrors) {
    print('❌ Build completed with errors');
    exit(1);
  } else {
    print('✅ Build completed successfully');

    // Print next steps
    print('\nNext steps:');
    print('1. Add your sprite images to assets/images/sprites/');
    print('2. Run "dart tool/build_assets.dart" to rebuild when assets change');
    print(
      '3. Use "dart tool/build_atlas.dart --watch" for automatic rebuilding during development',
    );
  }
}
